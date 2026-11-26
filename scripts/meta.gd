extends Node
## Постоянный прогресс (autoload «Meta»): золото лагеря, улучшения построек, шахта, рекорды.
## Сохранения — отдельные файлы user://saves/<id>.json (на Windows: %APPDATA%\Godot\app_userdata\Roguelike\saves\),
## у каждого вид: «solo» (одиночная игра) или «coop» (кооператив). В файле — лагерь, герои
## и незаконченный забег (run_save: этаж, герои со снаряжением и сумкой, золото, материалы).
## Общие для всех сохранений вещи (настройки, последнее сохранение, номер игрока) — user://profile.json.
## В тестовых запусках (--autotest, --uitest, --camptest) ничего не сохраняется.

signal changed

var save_dir := "user://saves/"  # --savetest: своя папка
const OLD_SAVE := "user://save.json"      # до сохранений-файлов было одно сохранение
const PROFILE_PATH := "user://profile.json"
const MAX_SLOTS := 8
const Items := preload("res://scripts/items.gd")
const Skills := preload("res://scripts/skills.gd")

# cost: [цена 1-го уровня, множитель за уровень]
const UPGRADES := {
	"training": {"name": "Тренировочный плац", "max": 5, "cost": [50, 1.6],
		"desc": "+1 очко характеристик на старте забега за уровень."},
	"library": {"name": "Библиотека", "max": 3, "cost": [80, 1.8],
		"desc": "+1 очко навыков на старте забега за уровень."},
	"forge": {"name": "Кузница", "max": 5, "cost": [60, 1.6],
		"desc": "+5% урона за уровень."},
	"infirmary": {"name": "Лазарет", "max": 5, "cost": [60, 1.6],
		"desc": "+8% HP за уровень."},
	"treasury": {"name": "Сокровищница", "max": 5, "cost": [70, 1.6],
		"desc": "+15% золота с монстров за уровень."},
	"mine": {"name": "Шахта", "max": 5, "cost": [40, 1.7],
		"desc": "Добывает золото и руду, даже когда игра закрыта: 3 золота в минуту и 1 руду в 5 минут за уровень."},
	"storage": {"name": "Склад", "max": 5, "cost": [60, 1.7],
		"desc": "+15 мест на складе снаряжения и +2 места в сумке героя за уровень."},
	"workshop": {"name": "Мастерская", "max": 3, "cost": [50, 2.0],
		"desc": "Создание предметов из материалов, заточка, склад снаряжения. Уровень: сильнее и чаще редкие предметы, +3% к заточке."},
}

const STASH_BASE := 30
const STASH_PER_LEVEL := 15
const BAG_BASE := 8
const BAG_PER_LEVEL := 2


## Мест на складе (постройка «Склад» добавляет).
func stash_max() -> int:
	return STASH_BASE + STASH_PER_LEVEL * level("storage")


## Мест в сумке героя в забеге.
func bag_max() -> int:
	return BAG_BASE + BAG_PER_LEVEL * level("storage")

var gold := 0
var levels := {}
var best_depth := 0
var runs := 0
var mine_stored := 0.0
var ore_stored := 0.0
var mine_time := 0.0       # когда шахту проверяли последний раз (unix-время)
var materials := {}        # материалы лагеря
var stash: Array = []      # склад снаряжения (предметы-словари)
var last_run := {}         # итоги последнего забега — показать в лагере
var settings := {"shake": true, "numbers": true}  # настройки (меню по Esc)
var heroes := {}           # сохранённые герои по классам (см. Run.to_hero)
var hero_cls := ""        # активный класс ("" — героя ещё нет)
var quest := {}            # поручение наставника {kind, need, text, gold, mats, progress}; {} — нет
var quest_offers: Array = []  # три поручения на выбор
var shop: Array = []       # товар торговца: [{item, price}]
var shop_runs := -1        # при каком числе забегов завезён (обновляется после каждого забега)
var persist := true
var slot := ""             # текущее сохранение (имя файла без .json); "" — не выбрано
var slot_kind := "solo"    # "solo" или "coop"
var run_save := {}         # незаконченный забег (см. Game.save_run); {} — забега нет
var uid := ""              # номер этого игрока (кооп: по нему хозяин узнаёт гостя в сохранённом забеге)
var _last_slot := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	persist = not ("--autotest" in args or "--uitest" in args or "--camptest" in args or "--clicktest" in args or "--skilltest" in args or "--cooptest" in args or "--herotest" in args or "--zootest" in args or "--savetest" in args or "--coopsave" in args or "--touchtest" in args or "--forgetest" in args or "--runtest" in args or "--traptest" in args)
	# Проверочные запуски без окна (--headless) ничего не пишут — сохранения владельца не трогаем.
	if DisplayServer.get_name() == "headless":
		persist = false
	if "--savetest" in args:
		# Тест сохранений: пишет по-настоящему, но в свою папку; профиль владельца не трогает.
		save_dir = "user://savetest/"
		persist = true
		_no_profile = true
		var d := DirAccess.open(save_dir)
		if d and not "--keepsaves" in args:
			for f: String in d.get_files():
				d.remove(f)
	var reading := persist or "--loadsave" in args
	if reading and not _no_profile:
		_load_profile()
		_migrate_old_save()
	for a: String in args:
		if a.begins_with("--uid="):
			uid = a.get_slice("=", 1)
	if uid == "":
		uid = "%08x%08x" % [randi(), randi()]
		_save_profile()
	# `--loadsave` — тест на настоящем сохранении: прочитать, но ничего не записывать.
	if reading and _last_slot != "" and FileAccess.file_exists(_path(_last_slot)):
		slot = _last_slot
		load_game()
	update_mine()


func level(id: String) -> int:
	return levels.get(id, 0)


func cost(id: String) -> int:
	var c: Array = UPGRADES[id]["cost"]
	return int(round(c[0] * pow(c[1], level(id))))


func is_max(id: String) -> bool:
	return level(id) >= UPGRADES[id]["max"]


func can_upgrade(id: String) -> bool:
	return not is_max(id) and gold >= cost(id)


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	gold -= cost(id)
	if id == "mine" and level("mine") == 0:
		mine_time = Time.get_unix_time_from_system()
	levels[id] = level(id) + 1
	save_game()
	changed.emit()
	return true


## Короткое описание эффекта на уровне lvl.
func effect(id: String, lvl: int) -> String:
	match id:
		"training": return "+%d очк. характеристик" % lvl
		"library": return "+%d очк. навыков" % lvl
		"forge": return "+%d%% урона" % (lvl * 5)
		"infirmary": return "+%d%% HP" % (lvl * 8)
		"treasury": return "+%d%% золота" % (lvl * 15)
		"mine": return "%d зол./мин, руда %d за 5 мин, запас %d зол. / %d руды" % [mine_rate(lvl), lvl, mine_cap(lvl), ore_cap(lvl)]
		"storage": return "склад %d мест, сумка %d мест" % [STASH_BASE + STASH_PER_LEVEL * lvl, BAG_BASE + BAG_PER_LEVEL * lvl]
		"workshop": return "предметы %d ур., +%d%% редких, +%d%% к заточке" % [1 + lvl, lvl * 6, lvl * 3]
	return ""


# ---------------- Бонусы для забега ----------------

func damage_mult() -> float:
	return 1.0 + 0.05 * level("forge")


func hp_mult() -> float:
	return 1.0 + 0.08 * level("infirmary")


func gold_mult() -> float:
	return 1.0 + 0.15 * level("treasury")


## Стартовые очки — вызывается при начале забега.
## Бонусные очки плаца и библиотеки: герой получает только то, что ещё не получал.
func apply_to_run(st: Node = Run) -> void:
	st.points += maxi(0, level("training") - st.training_given)
	st.skill_points += maxi(0, level("library") - st.library_given)
	st.training_given = maxi(st.training_given, level("training"))
	st.library_given = maxi(st.library_given, level("library"))
	st.changed.emit()


# ---------------- Шахта ----------------

func mine_rate(lvl := -1) -> int:
	return 3 * (level("mine") if lvl < 0 else lvl)


func mine_cap(lvl := -1) -> int:
	return 100 * (level("mine") if lvl < 0 else lvl)


func ore_cap(lvl := -1) -> int:
	return 10 * (level("mine") if lvl < 0 else lvl)


func update_mine() -> void:
	var now := Time.get_unix_time_from_system()
	if level("mine") > 0 and mine_time > 0.0:
		var minutes := (now - mine_time) / 60.0
		mine_stored = minf(mine_cap(), mine_stored + minutes * mine_rate())
		ore_stored = minf(ore_cap(), ore_stored + minutes / 5.0 * level("mine"))
	mine_time = now


## Забрать из шахты: [золото, руда].
func collect_mine() -> Array:
	update_mine()
	var got := int(mine_stored)
	var ore := int(ore_stored)
	mine_stored -= got
	ore_stored -= ore
	gold += got
	add_materials({"ore": ore})
	save_game()
	changed.emit()
	return [got, ore]


# ---------------- Материалы и склад ----------------

func add_materials(mats: Dictionary) -> void:
	for id: String in mats:
		if mats[id] > 0:
			materials[id] = materials.get(id, 0) + mats[id]


func stash_add(item: Dictionary) -> bool:
	if stash.size() >= stash_max():
		return false
	stash.append(item)
	return true


# ---------------- Итоги забега ----------------

## Итоги забега. alive — вернулся через портал после босса: золото, материалы и снаряжение
## приносятся в лагерь. Погиб — всё найденное в забеге потеряно.
func bank_run(depth: int, run_gold: int, run_level: int, cls_name: String, mats: Dictionary, items: Array, alive: bool) -> void:
	var kept := 0
	if alive:
		gold += run_gold
		add_materials(mats)
		for it in items:
			if stash_add(it):
				kept += 1
	runs += 1
	best_depth = maxi(best_depth, depth)
	var mat_total := 0
	for id: String in mats:
		mat_total += mats[id]
	last_run = {"depth": depth, "gold": run_gold if alive else 0, "gold_lost": 0 if alive else run_gold,
		"level": run_level, "class": cls_name,
		"mats": mat_total if alive else 0, "mats_lost": 0 if alive else mat_total, "alive": alive, "kept": kept, "lost": 0 if alive else items.size()}
	save_game()
	changed.emit()


# ---------------- Настройки ----------------

func setting(key: String) -> bool:
	return bool(settings.get(key, true))


func set_setting(key: String, value: bool) -> void:
	settings[key] = value
	_save_profile()  # настройки общие для всех сохранений


# ---------------- Сохранённый герой ----------------

func current_hero() -> Dictionary:
	return heroes.get(hero_cls, {})


## Сохранить героя (контрольная точка или возвращение через портал).
## Гость в коопе пишет в своё собственное сохранение, не в копию лагеря хозяина.
func save_hero(h: Dictionary) -> void:
	if _is_guest_copy:
		_own_heroes[h["cls"]] = h
		_own_hero_cls = h["cls"]
		_write_own_heroes()
		return
	heroes[h["cls"]] = h
	hero_cls = h["cls"]
	save_game()
	changed.emit()


## Можно ли сменить класс: плац ≥3 ур. и текущий герой прошёл 5-й этаж.
## Гость: герой пал — запомнить только самый глубокий этаж.
func own_hero_best(depth: int) -> void:
	var h := own_hero()
	if h.is_empty():
		return
	h["best"] = maxi(int(h.get("best", 0)), depth)
	if _is_guest_copy:
		_write_own_heroes()
	else:
		save_game()


func class_change_reason() -> String:
	if hero_cls == "" or int(current_hero().get("level", 1)) <= 1:
		return ""  # герой 1 уровня (например, погиб без сохранения) — класс можно сменить свободно
	if level("training") < 3:
		return "нужен Тренировочный плац 3 уровня"
	if hero_cls != "" and int(current_hero().get("best", 0)) < 6:
		return "герой должен пройти 5-й этаж"
	return ""


func change_class(cls: String) -> void:
	if not heroes.has(cls):
		heroes[cls] = {"cls": cls, "level": 1}
	hero_cls = cls
	save_game()
	changed.emit()


# ---------------- Кооператив: у гостя — лагерь хозяина ----------------

var _own_persist := true
var _is_guest_copy := false
var _own_heroes := {}       # гость: свои герои (лагерь на экране — хозяина)
var _own_hero_cls := ""


## Гость: свой герой (для выбора у портала в лагере хозяина).
func own_hero() -> Dictionary:
	if _is_guest_copy:
		return _own_heroes.get(_own_hero_cls, {})
	return current_hero()


## Гость: записать своих героев в своё сохранение, остальное в нём не трогая.
func _write_own_heroes() -> void:
	if not _own_persist or slot == "":
		return
	var data: Variant = {}
	if FileAccess.file_exists(_path(slot)):
		data = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	data["heroes"] = _own_heroes
	data["hero_cls"] = _own_hero_cls
	data["saved_at"] = Time.get_unix_time_from_system()
	_write(slot, data)


## Хозяин: что показать гостям (постройки, склад, золото лагеря).
func net_dict() -> Dictionary:
	update_mine()
	return {"gold": gold, "levels": levels, "best_depth": best_depth, "runs": runs,
		"materials": materials, "stash": stash, "mine_stored": mine_stored, "ore_stored": ore_stored}


## Гость: временно показывает лагерь хозяина. Своё сохранение не трогается.
func apply_host(d: Dictionary) -> void:
	if not _is_guest_copy:
		_own_persist = persist
		_own_heroes = heroes.duplicate(true)
		_own_hero_cls = hero_cls
		_is_guest_copy = true
	persist = false
	gold = int(d["gold"])
	levels = {}
	for k: String in d["levels"]:
		levels[k] = int(d["levels"][k])
	best_depth = int(d["best_depth"])
	runs = int(d["runs"])
	materials = d["materials"]
	stash = d["stash"]
	mine_stored = float(d["mine_stored"])
	ore_stored = float(d["ore_stored"])
	changed.emit()


## Гость вышел из коопа — вернуть своё сохранение.
func restore_own() -> void:
	if not _is_guest_copy:
		return
	_is_guest_copy = false
	persist = _own_persist
	gold = 0
	levels = {}
	materials = {}
	stash = []
	if persist or "--loadsave" in OS.get_cmdline_user_args():
		load_game()
	update_mine()
	changed.emit()


# ---------------- Сохранение ----------------

func _path(id: String) -> String:
	if id == "__old":
		return OLD_SAVE  # --loadsave до переноса: читаем старый файл как есть
	return save_dir + id + ".json"


func _write(id: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(_path(id), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


func save_game() -> void:
	if not persist or slot == "" or _is_guest_copy:
		return
	update_mine()
	var data := {
		"kind": slot_kind, "saved_at": Time.get_unix_time_from_system(),
		"gold": gold, "levels": levels, "best_depth": best_depth, "runs": runs,
		"mine_stored": mine_stored, "ore_stored": ore_stored, "mine_time": mine_time,
		"materials": materials, "stash": stash, "heroes": heroes, "hero_cls": hero_cls,
		"run": run_save,
		"quest": quest, "quest_offers": quest_offers, "shop": shop, "shop_runs": shop_runs,
	}
	_write(slot, data)


## Сбросить всё к началу новой игры (лагерь пуст, героев нет).
func _clear() -> void:
	gold = 0
	levels = {}
	best_depth = 0
	runs = 0
	mine_stored = 0.0
	ore_stored = 0.0
	mine_time = 0.0
	materials = {}
	stash = []
	last_run = {}
	heroes = {}
	hero_cls = ""
	run_save = {}
	quest = {}
	quest_offers = []
	shop = []
	shop_runs = -1


func load_game() -> void:
	_clear()
	var data := _read(_path(slot))
	if data.is_empty():
		if FileAccess.file_exists(_path(slot)):
			push_warning("сохранение %s повреждено, начинаем с нуля" % slot)
		return
	slot_kind = "coop" if str(data.get("kind", "solo")) == "coop" else "solo"
	gold = int(data.get("gold", 0))
	best_depth = int(data.get("best_depth", 0))
	runs = int(data.get("runs", 0))
	mine_stored = float(data.get("mine_stored", 0.0))
	mine_time = float(data.get("mine_time", 0.0))
	ore_stored = float(data.get("ore_stored", 0.0))
	var m: Variant = data.get("materials", {})
	if typeof(m) == TYPE_DICTIONARY:
		for k: String in m:
			materials[k] = int(m[k])
	var s: Variant = data.get("stash", [])
	if typeof(s) == TYPE_ARRAY:
		for it: Variant in s:
			if typeof(it) == TYPE_DICTIONARY and _valid_item(it):
				stash.append(_fix_item(it))
	_load_levels(data)
	var hs: Variant = data.get("heroes", {})
	if typeof(hs) == TYPE_DICTIONARY:
		for k: String in hs:
			if Skills.CLASSES.has(k) and typeof(hs[k]) == TYPE_DICTIONARY:
				heroes[k] = hs[k]
	hero_cls = str(data.get("hero_cls", ""))
	if not heroes.has(hero_cls):
		hero_cls = ""
	var r: Variant = data.get("run", {})
	if typeof(r) == TYPE_DICTIONARY and r.has("players"):
		run_save = r
	var q: Variant = data.get("quest", {})
	if typeof(q) == TYPE_DICTIONARY and q.has("kind"):
		quest = q
	var qo: Variant = data.get("quest_offers", [])
	if typeof(qo) == TYPE_ARRAY:
		quest_offers = qo
	var sh: Variant = data.get("shop", [])
	if typeof(sh) == TYPE_ARRAY:
		for e: Variant in sh:
			if typeof(e) == TYPE_DICTIONARY and typeof(e.get("item")) == TYPE_DICTIONARY and _valid_item(e["item"]):
				shop.append({"item": _fix_item(e["item"]), "price": int(e.get("price", 50))})
	shop_runs = int(data.get("shop_runs", -1))


# ---------------- Наставник: поручения на забег ----------------

const Roster := preload("res://scripts/boss_roster.gd")
const QUEST_KINDS := {
	"kills": {"text": "Убей %d монстров за один забег", "need": [30, 60]},
	"elites": {"text": "Убей %d элитных монстров за один забег", "need": [2, 4]},
	"bosses": {"text": "Убей %d боссов за один забег", "need": [2, 3]},
	"events": {"text": "Воспользуйся %d событиями на этажах за один забег", "need": [2, 3]},
	"floors": {"text": "Пройди %d этажей за один забег", "need": [4, 8]},
}


## Три поручения на выбор; награда растёт с самым глубоким этажом.
func make_quest_offers() -> void:
	quest_offers = []
	var kinds: Array = QUEST_KINDS.keys()
	kinds.shuffle()
	var depth := maxi(1, best_depth)
	var biome_mats: Array = Roster.BIOME_MATS[Roster.biome_of(depth)]
	for k: String in kinds.slice(0, 3):
		var spec: Dictionary = QUEST_KINDS[k]
		var need := randi_range(spec["need"][0], spec["need"][1])
		var mat: String = biome_mats[0][0]
		quest_offers.append({"kind": k, "need": need, "text": spec["text"] % need,
			"gold": 40 + depth * 6 + need * 3, "mats": {mat: 3 + Roster.biome_of(depth)}, "progress": 0})
	save_game()


func take_quest(i: int) -> void:
	if i < 0 or i >= quest_offers.size():
		return
	quest = quest_offers[i]
	quest["progress"] = 0
	quest_offers = []
	save_game()
	changed.emit()


# ---------------- Торговец ----------------

## Товар обновляется после каждого забега (или за золото — reroll).
func restock_shop(force := false) -> void:
	if not force and shop_runs == runs and not shop.is_empty():
		return
	shop_runs = runs
	shop = []
	var depth := maxi(1, best_depth)
	var h := current_hero()
	var cls := str(h.get("cls", "warrior"))
	var job := str(h.get("job", ""))
	for i in 4:
		var rarity := 2 if randf() < 0.35 else 1
		var it := Items.make(Items.random_base(cls, job), rarity, depth)
		var price := (90 + depth * 10) if rarity == 2 else (35 + depth * 4)
		shop.append({"item": it, "price": price})
	save_game()


func reroll_cost() -> int:
	return 15 + maxi(1, best_depth) * 2


# ---------------- Сохранения-файлы ----------------

## Все сохранения: [{id, kind, saved_at, gold, runs, best, hero: {...}, run_depth}], новые сверху.
func list_slots() -> Array:
	var out: Array = []
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		var d := _read(_path(id))
		if d.is_empty():
			continue
		var hs: Dictionary = d.get("heroes", {}) if typeof(d.get("heroes")) == TYPE_DICTIONARY else {}
		var hero: Variant = hs.get(str(d.get("hero_cls", "")), {})
		var r: Variant = d.get("run", {})
		out.append({"id": id, "kind": "coop" if str(d.get("kind", "solo")) == "coop" else "solo",
			"saved_at": float(d.get("saved_at", 0.0)), "gold": int(d.get("gold", 0)), "runs": int(d.get("runs", 0)),
			"best": int(d.get("best_depth", 0)), "hero": hero if typeof(hero) == TYPE_DICTIONARY else {},
			"run_depth": int(r.get("depth", 0)) if typeof(r) == TYPE_DICTIONARY and r.has("players") else 0})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["saved_at"] > y["saved_at"])
	return out


## Сделать текущим сохранение id (и прочитать его).
func load_slot(id: String) -> void:
	slot = id
	load_game()
	update_mine()
	_last_slot = id
	_save_profile()
	changed.emit()


## Новое пустое сохранение вида kind ("solo"/"coop"). Возвращает его id.
func new_slot(kind: String) -> String:
	var n := 1
	while FileAccess.file_exists(_path("save%d" % n)):
		n += 1
	slot = "save%d" % n
	slot_kind = kind
	_clear()
	update_mine()
	save_game()
	_last_slot = slot
	_save_profile()
	changed.emit()
	return slot


## Удалить файл сохранения (кнопка «Удалить» с подтверждением в меню).
func delete_slot(id: String) -> void:
	if persist:
		DirAccess.remove_absolute(_path(id))
	if id == slot:
		slot = ""
		_clear()
	if id == _last_slot:
		_last_slot = ""
		_save_profile()


## Незаконченный забег закончился (смерть, возвращение в лагерь, новый забег).
func clear_run() -> void:
	if run_save.is_empty():
		return
	run_save = {}
	save_game()


## Папка с сохранениями — открыть в проводнике (только ПК).
func open_save_folder() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	OS.shell_open(ProjectSettings.globalize_path(save_dir))


func _load_profile() -> void:
	var p := _read(PROFILE_PATH)
	_last_slot = str(p.get("last_slot", ""))
	uid = str(p.get("uid", ""))
	var se: Variant = p.get("settings", {})
	if typeof(se) == TYPE_DICTIONARY:
		for k: String in se:
			settings[k] = se[k]


var _no_profile := false


func _save_profile() -> void:
	if not persist or _no_profile:
		return
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"last_slot": _last_slot, "uid": uid, "settings": settings}, "  "))


## Раньше было одно сохранение save.json — переносим его в сохранение «save1» (одиночная игра).
func _migrate_old_save() -> void:
	if not FileAccess.file_exists(OLD_SAVE) or FileAccess.file_exists(_path("save1")):
		return
	var d := _read(OLD_SAVE)
	if d.is_empty():
		return
	var se: Variant = d.get("settings", {})
	if typeof(se) == TYPE_DICTIONARY:
		for k: String in se:
			settings[k] = se[k]
	if not persist:
		_last_slot = "__old"  # --loadsave: только читаем, ничего не переносим
		return
	d.erase("settings")
	d["kind"] = "solo"
	d["saved_at"] = Time.get_unix_time_from_system()
	_write("save1", d)
	DirAccess.remove_absolute("user://save_old.json")
	DirAccess.rename_absolute(OLD_SAVE, "user://save_old.json")  # старый файл — как запасная копия
	_last_slot = "save1"
	_save_profile()


## JSON превращает все числа в дробные — возвращаем целые там, где нужно.
func _fix_item(it: Dictionary) -> Dictionary:
	# Старые сохранения: был один слот «Украшение» — теперь «Кольцо» и «Амулет».
	if it["slot"] == "accessory":
		it["slot"] = Items.BASES[it["base"]]["slot"]
	it["rarity"] = int(it["rarity"])
	it["icon"] = int(it["icon"])
	it["refine"] = int(it.get("refine", 0))
	var st := {}
	for k: String in it["stats"]:
		st[k] = int(it["stats"][k])
	it["stats"] = st
	return it


func _valid_item(it: Dictionary) -> bool:
	return it.has("base") and Items.BASES.has(it["base"]) and it.has("slot") and it.has("stats") and it.has("rarity") and it.has("name") and it.has("icon")


func _load_levels(data: Dictionary) -> void:
	var lv: Variant = data.get("levels", {})
	if typeof(lv) == TYPE_DICTIONARY:
		for k: String in lv:
			if UPGRADES.has(k):
				levels[k] = int(lv[k])
