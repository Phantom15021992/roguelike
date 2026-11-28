extends Node
## Состояние забега (autoload «Run»): класс, этаж, уровень, опыт, статы, навыки, снаряжение, золото.
## Переживает переход между этажами, сбрасывается при смерти.
## В кооперативе у хозяина на каждого гостя свой экземпляр этого скрипта (Net.players[id].state);
## у гостя autoload Run — копия его героя, присланная хозяином (apply_net), а изменения
## (очки, навыки, профессия) отправляются хозяину (Net.cmd).

signal changed
signal leveled_up(level: int)
signal class_chosen(cls: String)
signal job_chosen(job: String)

const Items := preload("res://scripts/items.gd")
const Skills := preload("res://scripts/skills.gd")
const Crafting := preload("res://scripts/crafting.gd")
const STAT_KEYS := ["str", "agi", "vit", "int", "dex", "luk"]
const STAT_NAMES := {
	"str": "Сила", "agi": "Ловкость", "vit": "Выносливость",
	"int": "Интеллект", "dex": "Меткость", "luk": "Удача",
}
const STAT_POINTS_PER_LEVEL := 3
const SKILL_POINTS_PER_LEVEL := 1

var cls := ""        # "" — класс ещё не выбран
var job := ""        # профессия (вторая, на уровне Skills.JOB_LEVEL); "" — ещё базовый класс
var depth := 1
var level := 1
var xp := 0
var points := 0
var skill_points := 0
var skill_levels := {}
var gold := 0
var materials := {}  # материалы, найденные в этом забеге
var stats := {}
var equipment := {}
var bag: Array = []   # сумка: найденные предметы (в лагерь — только через портал)
var hp := -1  # -1 — полное (при старте забега)
# Сохраняемый герой (между забегами): сколько бонусных очков лагеря уже выдано,
# самый глубокий этаж и этаж-сохранение (5, 10, ...), с которого можно начать.
var training_given := 0
var library_given := 0
var best := 0
var checkpoint := 0
var sp := -1
var run_dmg := 0      # +% урона до конца забега (Алтарь крови)


func _ready() -> void:
	reset()


func reset() -> void:
	cls = ""
	job = ""
	depth = 1
	level = 1
	xp = 0
	points = 0
	skill_points = 1
	skill_levels = {}
	gold = 0
	materials = {}
	stats = {}
	for k in STAT_KEYS:
		stats[k] = 1
	equipment = {}
	for slot: String in Items.SLOTS:
		equipment[slot] = null
	bag = []
	hp = -1
	sp = -1
	run_dmg = 0
	training_given = 0
	library_given = 0
	best = 0
	checkpoint = 0
	changed.emit()


## Герой для сохранения (без снаряжения — оно на складе и в риске забега).
func to_hero() -> Dictionary:
	return {"cls": cls, "job": job, "level": level, "xp": xp, "points": points,
		"skill_points": skill_points, "skill_levels": skill_levels.duplicate(), "stats": stats.duplicate(),
		"training_given": training_given, "library_given": library_given,
		"best": maxi(best, depth), "checkpoint": checkpoint}


## Загрузить сохранённого героя (класс со стартовым оружием, уровень, навыки).
func load_hero(h: Dictionary) -> void:
	set_class(str(h["cls"]))
	job = str(h.get("job", ""))
	level = int(h.get("level", 1))
	xp = int(h.get("xp", 0))
	points = int(h.get("points", 0))
	skill_points = int(h.get("skill_points", 1))
	skill_levels = {}
	var sl: Dictionary = h.get("skill_levels", {})
	for k: String in sl:
		skill_levels[k] = int(sl[k])
	var sts: Dictionary = h.get("stats", {})
	for k: String in STAT_KEYS:
		stats[k] = int(sts.get(k, 1))
	training_given = int(h.get("training_given", 0))
	library_given = int(h.get("library_given", 0))
	best = int(h.get("best", 0))
	checkpoint = int(h.get("checkpoint", 0))
	if job != "":
		job_chosen.emit(job)
	changed.emit()


## Незаконченный забег — для сохранения в файл: герой + снаряжение, сумка, HP/SP.
## hp_now/sp_now — текущие значения с героя на карте (-1 — взять из состояния).
func to_run(hp_now := -1, sp_now := -1) -> Dictionary:
	var h := to_hero()
	h["equipment"] = equipment.duplicate(true)
	h["bag"] = bag.duplicate(true)
	h["hp"] = hp_now if hp_now >= 0 else hp
	h["sp"] = sp_now if sp_now >= 0 else sp
	h["run_dmg"] = run_dmg
	return h


## Продолжить сохранённый забег этим героем.
func load_run(d: Dictionary) -> void:
	load_hero(d)
	var eq: Variant = d.get("equipment", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for slot: String in Items.SLOTS:
			var it: Variant = eq.get(slot)
			equipment[slot] = Meta._fix_item(it) if typeof(it) == TYPE_DICTIONARY and Meta._valid_item(it) else null
	bag = []
	var b: Variant = d.get("bag", [])
	if typeof(b) == TYPE_ARRAY:
		for it: Variant in b:
			if typeof(it) == TYPE_DICTIONARY and Meta._valid_item(it):
				bag.append(Meta._fix_item(it))
	hp = int(d.get("hp", -1))
	sp = int(d.get("sp", -1))
	run_dmg = int(d.get("run_dmg", 0))
	changed.emit()


## Гость: изменения своего героя делает хозяин.
func _forward(method: String, args: Array) -> bool:
	if self == Run and Net.is_guest():
		Net.cmd(method, args)
		return true
	return false


## Для отправки гостю: его герой + общие золото, материалы, этаж.
func net_dict() -> Dictionary:
	return {"cls": cls, "job": job, "level": level, "xp": xp, "points": points,
		"skill_points": skill_points, "skill_levels": skill_levels, "stats": stats,
		"equipment": equipment, "bag": bag, "hp": hp, "sp": sp,
		"depth": Run.depth, "gold": Run.gold, "materials": Run.materials}


## Гость: применить присланное хозяином (и вызвать те же сигналы, что и при игре в одиночку).
func apply_net(d: Dictionary) -> void:
	var old_cls := cls
	var old_job := job
	var old_level := level
	cls = d["cls"]
	job = d["job"]
	level = int(d["level"])
	xp = int(d["xp"])
	points = int(d["points"])
	skill_points = int(d["skill_points"])
	skill_levels = {}
	for k: String in d["skill_levels"]:
		skill_levels[k] = int(d["skill_levels"][k])
	stats = {}
	for k: String in d["stats"]:
		stats[k] = int(d["stats"][k])
	equipment = d["equipment"]
	bag = d.get("bag", [])
	depth = int(d["depth"])
	gold = int(d["gold"])
	materials = d["materials"]
	if cls != old_cls and cls != "":
		class_chosen.emit(cls)
	if job != old_job and job != "":
		job_chosen.emit(job)
	if level > old_level and old_cls == cls:
		for l in range(old_level + 1, level + 1):
			leveled_up.emit(l)
	changed.emit()


func add_material(id: String, n := 1) -> void:
	materials[id] = materials.get(id, 0) + n
	changed.emit()


func set_class(new_cls: String) -> void:
	cls = new_cls
	equipment["weapon"] = Items.make(Skills.CLASSES[cls]["weapon"], 0, 1)
	equipment["weapon"]["starter"] = true
	hp = -1
	sp = -1
	class_chosen.emit(cls)
	changed.emit()


## Смена профессии: все очки навыков возвращаются, навыки — новые.
func set_job(new_job: String) -> void:
	if _forward("set_job", [new_job]):
		return
	var refund := skill_points
	for id: String in skill_levels:
		refund += skill_levels[id]
	skill_levels = {}
	skill_points = refund
	job = new_job
	job_chosen.emit(job)
	changed.emit()


## Можно ли (и пора ли) выбрать профессию.
func job_pending() -> bool:
	return cls != "" and job == "" and level >= Skills.JOB_LEVEL


## Навыки текущей профессии (или базового класса).
func skill_list() -> Array:
	return Skills.skills_for(cls, job)


## Название: профессия, если выбрана, иначе класс.
func title() -> String:
	return Skills.JOBS[job]["name"] if job != "" else class_data()["name"]


func class_data() -> Dictionary:
	return Skills.CLASSES[cls if cls != "" else "warrior"]


func xp_to_next() -> int:
	return int(round(20.0 * pow(level, 1.5)))


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		points += STAT_POINTS_PER_LEVEL
		skill_points += SKILL_POINTS_PER_LEVEL
		leveled_up.emit(level)
	changed.emit()


func add_stat(key: String) -> bool:
	if points <= 0:
		return false
	if _forward("add_stat", [key]):
		return true
	stats[key] += 1
	points -= 1
	changed.emit()
	return true


# ---------------- Навыки ----------------

func skill_level(id: String) -> int:
	return skill_levels.get(id, 0)


## Почему нельзя изучить навык ("" — можно).
func learn_block_reason(id: String) -> String:
	if skill_level(id) >= Skills.MAX_LEVEL:
		return "максимальный уровень"
	var req: Dictionary = Skills.SKILLS[id]["req"]
	for r: String in req:
		if skill_level(r) < req[r]:
			return "нужно: %s %d ур." % [Skills.SKILLS[r]["name"], req[r]]
	if skill_points <= 0:
		return "нет очков навыков"
	return ""


func learn_skill(id: String) -> bool:
	if learn_block_reason(id) != "":
		return false
	if _forward("learn_skill", [id]):
		return true
	skill_levels[id] = skill_level(id) + 1
	skill_points -= 1
	changed.emit()
	return true


# ---------------- Характеристики ----------------

## Подсказка, что даёт очко характеристики для текущего класса.
func stat_hint(key: String) -> String:
	match key:
		"str":
			return "+2 атаки ближнего боя, +3 HP"
		"agi":
			return "+2% скор. атаки, +1% бега, +3% силы крита"
		"vit":
			return "+10 HP, +0.5% защиты, реген HP"
		"int":
			return "+2 маг. атаки, +5 SP, реген SP"
		"dex":
			return "+2 атаки дальнего боя, +1 точность, +1% скорости каста, −1% перезарядки"
		"luk":
			return "+1% крит, +2% шанс дропа, бонус к крафту"
	return ""


## Можно ли надеть предмет ("" — можно, иначе причина).
func equip_block_reason(item: Dictionary) -> String:
	if not Items.fits(item, cls, job):
		var b: Dictionary = Items.BASES[item["base"]]
		if b.has("job"):
			return "только для профессии %s" % Skills.JOBS[b["job"]]["name"]
		return "не для этого класса"
	if item["slot"] == "offhand" and Items.is_two_hand(equipment["weapon"]):
		return "двуручное оружие занимает вторую руку"
	return ""


## Надевает предмет, возвращает список снятых (двуручное оружие снимает и вторую руку).
func equip(item: Dictionary) -> Array:
	var removed := []
	var old: Variant = equipment[item["slot"]]
	if old != null:
		removed.append(old)
	equipment[item["slot"]] = item
	if Items.is_two_hand(item) and equipment["offhand"] != null:
		removed.append(equipment["offhand"])
		equipment["offhand"] = null
	changed.emit()
	return removed


# ---------------- Сумка ----------------

func bag_full() -> bool:
	return bag.size() >= Meta.bag_max()


func bag_add(item: Dictionary) -> bool:
	if bag_full():
		return false
	bag.append(item)
	changed.emit()
	return true


## Надеть предмет из сумки. Снятое кладётся в сумку; что не влезло — возвращается (выбросить на пол).
func equip_from_bag(i: int) -> Array:
	if i < 0 or i >= bag.size() or equip_block_reason(bag[i]) != "":
		return []
	var item: Dictionary = bag[i]
	bag.remove_at(i)
	var overflow := []
	for old: Dictionary in equip(item):
		if old.get("starter", false) and bag_full():
			continue  # стартовое оружие не жалко
		if not bag_add(old):
			overflow.append(old)
	changed.emit()
	return overflow


## Снять предмет в сумку.
func unequip(slot: String) -> bool:
	var it: Variant = equipment.get(slot)
	if it == null or bag_full():
		return false
	equipment[slot] = null
	bag.append(it)
	changed.emit()
	return true


## Выбросить из сумки (возвращает предмет — его кладут на пол).
func take_from_bag(i: int) -> Variant:
	if i < 0 or i >= bag.size():
		return null
	var it: Dictionary = bag[i]
	bag.remove_at(i)
	changed.emit()
	return it


## Сколько частей каждого комплекта надето: {set_id: count}.
func set_counts(equip_set: Dictionary = equipment) -> Dictionary:
	var counts := {}
	for slot: String in equip_set:
		var it: Variant = equip_set[slot]
		if it != null and it.has("set"):
			counts[it["set"]] = counts.get(it["set"], 0) + 1
	return counts


## Что дают надетые вещи вместе: свойства (с заточкой) и бонусы комплектов, без урона оружия.
func gear_bonuses(equip_set: Dictionary = equipment) -> Dictionary:
	var sum := {}
	for slot: String in equip_set:
		var item: Variant = equip_set[slot]
		if item == null:
			continue
		var stats_of_item := Crafting.effective_stats(item)
		for k: String in stats_of_item:
			if k != "atk_min" and k != "atk_max":
				sum[k] = sum.get(k, 0) + stats_of_item[k]
	var counts := set_counts(equip_set)
	for sid: String in counts:
		var bonus_table: Dictionary = Items.SETS[sid]["bonus"]
		for need: int in bonus_table:
			if counts[sid] >= need:
				for k: String in bonus_table[need]:
					sum[k] = sum.get(k, 0) + bonus_table[need][k]
	return sum


## Итоговые характеристики героя. Можно передать «примерочное» снаряжение для сравнения.
func derived(equip_set: Dictionary = equipment) -> Dictionary:
	var c := class_data()
	var sum := gear_bonuses(equip_set)
	var g := func(k: String) -> int: return sum.get(k, 0)

	# Характеристики с бонусами предметов (+1 Сила и т.п.).
	var st := {}
	for k: String in STAT_KEYS:
		st[k] = stats[k] + g.call(k)
	var s := func(k: String) -> int: return st[k] - 1  # вложено сверх стартовой единицы

	# Тип атаки класса: мечник — ближний бой (Сила), лучник — дальний (Меткость), маг — магия (Интеллект).
	var primary: String = c["primary"]
	var bonus: int = s.call(primary) * 2 + g.call("atk")
	var weapon: Variant = equip_set["weapon"]

	var fort := skill_level("fortitude")
	var hawk := skill_level("hawk_eye")
	var med := skill_level("meditation")
	var dodge := skill_level("dodge")
	var faith := skill_level("faith")

	var max_hp: int = c["hp"] + s.call("vit") * 10 + s.call("str") * 3 + g.call("hp")
	if fort > 0:
		max_hp = int(round(max_hp * (1.0 + Skills.value("fortitude", fort) / 100.0)))
	if faith > 0:
		max_hp = int(round(max_hp * (1.0 + Skills.value("faith", faith) / 100.0)))
	max_hp = int(round(max_hp * Meta.hp_mult() * (1.0 + g.call("hp_pct") / 100.0)))  # Лазарет, комплекты
	var dmg_mult: float = Meta.damage_mult() * (1.0 + g.call("dmg_pct") / 100.0) * (1.0 + run_dmg / 100.0)  # Кузница, комплекты, Алтарь крови
	var dr: float = s.call("vit") * 0.5 + g.call("def") + (Skills.value("fortitude", fort, "v2") if fort > 0 else 0.0)
	return {
		"atk_min": int(round(((Crafting.effective_stats(weapon)["atk_min"] if weapon else 2) + bonus) * dmg_mult)),
		"atk_max": int(round(((Crafting.effective_stats(weapon)["atk_max"] if weapon else 4) + bonus) * dmg_mult)),
		"max_hp": max_hp,
		"hp_regen": s.call("vit") * 0.15,                                    # HP в секунду
		"max_sp": c["sp"] + s.call("int") * 5 + g.call("sp") + (int(Skills.value("meditation", med)) if med > 0 else 0),
		"sp_regen": (1.5 + s.call("int") * 0.2) * (1.0 + (Skills.value("meditation", med, "v2") / 100.0 if med > 0 else 0.0)),
		"crit": 5 + s.call("luk") + g.call("crit") + (int(Skills.value("hawk_eye", hawk)) if hawk > 0 else 0),
		"crit_mult": 2.0 + s.call("agi") * 0.03,                             # сила крита: x2 + 3% за Ловкость
		"aspd": s.call("agi") * 2 + g.call("aspd") + (int(Skills.value("hawk_eye", hawk, "v2")) if hawk > 0 else 0) + (int(Skills.value("dodge", dodge, "v2")) if dodge > 0 else 0),
		"speed": s.call("agi") + g.call("speed"),
		"dr": minf(dr, 70.0),                                               # % срезаемого урона
		"eva": mini(g.call("eva") + (int(Skills.value("dodge", dodge)) if dodge > 0 else 0), 60),
		"heal_pct": Skills.value("faith", faith, "v2") if faith > 0 else 0.0,   # сила лечения, %                                     # % уклонения от ударов монстров
		"accuracy": s.call("dex"),                                           # против уклонения монстров
		"cdr": minf(s.call("dex"), 40),                                      # % сокращения перезарядки навыков
		"cast": s.call("dex") + g.call("cast") + (Skills.value("mobile_cast", skill_level("mobile_cast")) if skill_level("mobile_cast") > 0 else 0.0),
		"drop": s.call("luk") * 2,                                           # % к шансу выпадения предметов
		"craft": s.call("luk"),                                              # бонус к крафту
		# Особые свойства предметов и комплектов:
		"lifesteal": g.call("lifesteal"), "burn": g.call("burn"), "thorns": g.call("thorns"),
		"stun": g.call("stun"), "boss": g.call("boss"), "pierce": g.call("pierce"),
		"stats": st,
	}


## Характеристики, если надеть item (двуручное снимает и вторую руку).
func derived_with(item: Dictionary) -> Dictionary:
	var trial := equipment.duplicate()
	trial[item["slot"]] = item
	if Items.is_two_hand(item):
		trial["offhand"] = null
	return derived(trial)
