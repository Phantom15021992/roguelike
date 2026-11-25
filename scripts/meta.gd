extends Node
## Постоянный прогресс (autoload «Meta»): золото лагеря, улучшения построек, шахта, рекорды.
## Сохраняется в user://save.json (на Windows: %APPDATA%\Godot\app_userdata\Roguelike\save.json).
## В тестовых запусках (--autotest, --uitest, --camptest) ничего не сохраняется.

signal changed

const SAVE_PATH := "user://save.json"
const Items := preload("res://scripts/items.gd")

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
	"workshop": {"name": "Мастерская", "max": 3, "cost": [50, 2.0],
		"desc": "Создание предметов из материалов, заточка, склад снаряжения. Уровень: сильнее и чаще редкие предметы, +3% к заточке."},
}

const STASH_MAX := 30

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
var persist := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	persist = not ("--autotest" in args or "--uitest" in args or "--camptest" in args or "--clicktest" in args or "--skilltest" in args or "--cooptest" in args)
	# `--loadsave` — тест на настоящем сохранении: прочитать, но ничего не записывать.
	if persist or "--loadsave" in args:
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
func apply_to_run(st: Node = Run) -> void:
	st.points += level("training")
	st.skill_points += level("library")
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
	if stash.size() >= STASH_MAX:
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


# ---------------- Кооператив: у гостя — лагерь хозяина ----------------

var _own_persist := true
var _is_guest_copy := false


## Хозяин: что показать гостям (постройки, склад, золото лагеря).
func net_dict() -> Dictionary:
	update_mine()
	return {"gold": gold, "levels": levels, "best_depth": best_depth, "runs": runs,
		"materials": materials, "stash": stash, "mine_stored": mine_stored, "ore_stored": ore_stored}


## Гость: временно показывает лагерь хозяина. Своё сохранение не трогается.
func apply_host(d: Dictionary) -> void:
	if not _is_guest_copy:
		_own_persist = persist
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

func save_game() -> void:
	if not persist:
		return
	update_mine()
	var data := {
		"gold": gold, "levels": levels, "best_depth": best_depth, "runs": runs,
		"mine_stored": mine_stored, "ore_stored": ore_stored, "mine_time": mine_time,
		"materials": materials, "stash": stash,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("save.json повреждён, начинаем с нуля")
		return
	gold = int(data.get("gold", 0))
	best_depth = int(data.get("best_depth", 0))
	runs = int(data.get("runs", 0))
	mine_stored = float(data.get("mine_stored", 0.0))
	mine_time = float(data.get("mine_time", 0.0))
	ore_stored = float(data.get("ore_stored", 0.0))
	materials = {}
	var m: Variant = data.get("materials", {})
	if typeof(m) == TYPE_DICTIONARY:
		for k: String in m:
			materials[k] = int(m[k])
	stash = []
	var s: Variant = data.get("stash", [])
	if typeof(s) == TYPE_ARRAY:
		for it: Variant in s:
			if typeof(it) == TYPE_DICTIONARY and _valid_item(it):
				stash.append(_fix_item(it))
	levels = {}
	_load_levels(data)


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
