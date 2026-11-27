extends RefCounted
## Предметы: слоты, базы, редкость, случайные и особые свойства, комплекты, названия.
## Предмет — словарь:
## {base, slot, name, icon, rarity, stats: {...}, refine, set?: id комплекта, starter?: true}

# 8 слотов, как в Ragnarok.
const SLOTS := ["weapon", "offhand", "head", "armor", "cloak", "boots", "ring", "amulet"]
const SLOT_NAMES := {
	"weapon": "Оружие", "offhand": "Вторая рука", "head": "Голова", "armor": "Броня",
	"cloak": "Плащ", "boots": "Обувь", "ring": "Кольцо", "amulet": "Амулет",
}

const RARITY := [
	{"name": "обычный", "color": Color(0.9, 0.9, 0.9), "affixes": 0},
	{"name": "магический", "color": Color(0.45, 0.65, 1.0), "affixes": 1},
	{"name": "редкий", "color": Color(1.0, 0.8, 0.25), "affixes": 2},
	{"name": "комплект", "color": Color(0.4, 0.95, 0.5), "affixes": 2},
]
const SET_RARITY := 3

# gender: 0 — м.р., 1 — ж.р., 2 — ср.р., 3 — мн.ч. (для прилагательных в названии).
# class — только для этого базового класса; job — только для этой профессии;
# two_hand — двуручное: занимает и вторую руку.
const BASES := {
	# --- Оружие мечника ---
	"sword": {"slot": "weapon", "class": "warrior", "name": "Меч", "gender": 0, "icon": 0,
		"stats": {"atk_min": 8, "atk_max": 12}},
	"axe": {"slot": "weapon", "class": "warrior", "name": "Топор", "gender": 0, "icon": 1,
		"stats": {"atk_min": 13, "atk_max": 19, "aspd": -15}},
	"dagger": {"slot": "weapon", "class": ["warrior", "thief"], "name": "Кинжал", "gender": 0, "icon": 2,
		"stats": {"atk_min": 5, "atk_max": 8, "aspd": 25, "crit": 5}},
	"greataxe": {"slot": "weapon", "class": "warrior", "job": "berserker", "two_hand": true,
		"name": "Двуручный топор", "gender": 0, "icon": 24,
		"stats": {"atk_min": 20, "atk_max": 30, "aspd": -20, "crit": 5}},
	"mace": {"slot": "weapon", "class": "warrior", "job": "paladin", "name": "Булава", "gender": 1, "icon": 25,
		"stats": {"atk_min": 11, "atk_max": 15, "stun": 4}},
	# --- Оружие лучника ---
	"bow": {"slot": "weapon", "class": "archer", "name": "Короткий лук", "gender": 0, "icon": 7,
		"stats": {"atk_min": 7, "atk_max": 10, "aspd": 10}},
	"longbow": {"slot": "weapon", "class": "archer", "name": "Длинный лук", "gender": 0, "icon": 8,
		"stats": {"atk_min": 11, "atk_max": 16, "aspd": -10}},
	"hunter_bow": {"slot": "weapon", "class": "archer", "job": "hunter", "name": "Охотничий лук", "gender": 0, "icon": 26,
		"stats": {"atk_min": 10, "atk_max": 14, "aspd": 15, "crit": 3}},
	"crossbow": {"slot": "weapon", "class": "archer", "job": "sniper", "name": "Арбалет", "gender": 0, "icon": 27,
		"stats": {"atk_min": 18, "atk_max": 26, "aspd": -25, "pierce": 1}},
	# --- Оружие мага ---
	"wand": {"slot": "weapon", "class": "mage", "name": "Жезл", "gender": 0, "icon": 9,
		"stats": {"atk_min": 7, "atk_max": 10, "sp": 10, "aspd": 10}},
	"staff": {"slot": "weapon", "class": "mage", "name": "Посох", "gender": 0, "icon": 10,
		"stats": {"atk_min": 11, "atk_max": 15, "sp": 25, "aspd": -10}},
	"element_staff": {"slot": "weapon", "class": "mage", "job": "wizard", "two_hand": true,
		"name": "Посох стихий", "gender": 0, "icon": 28,
		"stats": {"atk_min": 15, "atk_max": 21, "sp": 30, "aspd": -10}},
	"sage_book": {"slot": "weapon", "class": "mage", "job": "professor", "name": "Книга мудреца", "gender": 1, "icon": 29,
		"stats": {"atk_min": 9, "atk_max": 13, "sp": 20, "cast": 15}},
	# --- Оружие вора ---
	"knife": {"slot": "weapon", "class": "thief", "name": "Нож", "gender": 0, "icon": 30,
		"stats": {"atk_min": 6, "atk_max": 9, "aspd": 15, "crit": 3}},
	"stiletto": {"slot": "weapon", "class": "thief", "name": "Стилет", "gender": 0, "icon": 31,
		"stats": {"atk_min": 8, "atk_max": 11, "crit": 8}},
	"cleaver": {"slot": "weapon", "class": "thief", "job": "bandit", "name": "Тесак", "gender": 0, "icon": 32,
		"stats": {"atk_min": 14, "atk_max": 20, "aspd": -5, "stun": 3}},
	"katar": {"slot": "weapon", "class": "thief", "job": "assassin", "name": "Катар", "gender": 0, "icon": 33,
		"stats": {"atk_min": 11, "atk_max": 15, "aspd": 10, "crit": 12}},
	# --- Оружие послушника ---
	"acolyte_rod": {"slot": "weapon", "class": "acolyte", "name": "Посох послушника", "gender": 0, "icon": 34,
		"stats": {"atk_min": 7, "atk_max": 10, "sp": 15}},
	"beads": {"slot": "weapon", "class": "acolyte", "name": "Чётки", "gender": 3, "icon": 35,
		"stats": {"atk_min": 5, "atk_max": 8, "sp": 25, "int": 1, "aspd": 10}},
	"holy_staff": {"slot": "weapon", "class": "acolyte", "job": "priest", "two_hand": true,
		"name": "Посох света", "gender": 0, "icon": 36, "stats": {"atk_min": 12, "atk_max": 16, "sp": 35, "int": 2}},
	"knuckles": {"slot": "weapon", "class": "acolyte", "job": "monk", "name": "Кастеты", "gender": 3, "icon": 37,
		"stats": {"atk_min": 12, "atk_max": 17, "aspd": 15, "str": 1}},
	# --- Вторая рука ---
	"buckler": {"slot": "offhand", "class": ["warrior", "thief", "acolyte"], "name": "Баклер", "gender": 0, "icon": 11,
		"stats": {"hp": 10, "def": 4}},
	"tower_shield": {"slot": "offhand", "class": "warrior", "name": "Башенный щит", "gender": 0, "icon": 12,
		"stats": {"hp": 25, "def": 8, "speed": -5}},
	"quiver": {"slot": "offhand", "class": "archer", "name": "Колчан", "gender": 0, "icon": 13,
		"stats": {"atk": 2, "aspd": 5}},
	"tome": {"slot": "offhand", "class": ["mage", "acolyte"], "name": "Гримуар", "gender": 0, "icon": 14,
		"stats": {"sp": 15, "cast": 8}},
	# --- Голова ---
	"cap": {"slot": "head", "name": "Кожаная шапка", "gender": 1, "icon": 15, "stats": {"hp": 8, "eva": 2}},
	"helm": {"slot": "head", "name": "Железный шлем", "gender": 0, "icon": 16, "stats": {"hp": 15, "def": 3}},
	"circlet": {"slot": "head", "name": "Венец", "gender": 0, "icon": 17, "stats": {"sp": 10, "int": 1}},
	# --- Броня ---
	"leather": {"slot": "armor", "name": "Кожаная куртка", "gender": 1, "icon": 3, "stats": {"hp": 15}},
	"chain": {"slot": "armor", "name": "Кольчуга", "gender": 1, "icon": 4, "stats": {"hp": 35, "speed": -6}},
	# --- Плащ ---
	"cape": {"slot": "cloak", "name": "Плащ", "gender": 0, "icon": 18, "stats": {"eva": 4}},
	"mantle": {"slot": "cloak", "name": "Мантия", "gender": 1, "icon": 19, "stats": {"sp": 10, "def": 2}},
	# --- Обувь ---
	"shoes": {"slot": "boots", "name": "Сапоги", "gender": 3, "icon": 20, "stats": {"speed": 6}},
	"greaves": {"slot": "boots", "name": "Латные сапоги", "gender": 3, "icon": 21, "stats": {"hp": 12, "def": 3, "speed": -2}},
	# --- Кольцо и амулет ---
	"ring": {"slot": "ring", "name": "Кольцо", "gender": 2, "icon": 5, "stats": {"crit": 4}},
	"band": {"slot": "ring", "name": "Перстень", "gender": 0, "icon": 22, "stats": {"str": 1, "atk": 1}},
	"amulet": {"slot": "amulet", "name": "Амулет", "gender": 0, "icon": 6, "stats": {"hp": 10, "atk": 2}},
	"talisman": {"slot": "amulet", "name": "Талисман", "gender": 0, "icon": 23, "stats": {"def": 2, "hp": 8}},
}

# Обычные случайные свойства: [мин, макс].
const AFFIXES := {
	"hp": [8, 20], "atk": [2, 5], "crit": [2, 6], "aspd": [4, 10], "speed": [3, 8], "sp": [8, 20],
	"def": [2, 5], "eva": [2, 5], "cast": [4, 10],
	"str": [1, 3], "agi": [1, 3], "vit": [1, 3], "int": [1, 3], "dex": [1, 3], "luk": [1, 3],
}
# Особые свойства (у редких — одно обязательно): срабатывают в бою.
const SPECIAL := {
	"lifesteal": [2, 5],   # % нанесённого урона лечит
	"burn": [5, 12],       # % шанс поджечь (3 с, 30% удара за всё время)
	"thorns": [10, 25],    # % полученного урона в ближнем бою возвращается обидчику
	"stun": [3, 8],        # % шанс оглушить на 1 с (босса — замедлить)
	"boss": [8, 20],       # % урона боссам
}
const SPECIAL_SUFFIX := {
	"lifesteal": "вампира", "burn": "пламени", "thorns": "шипов", "stun": "грома", "boss": "убийцы",
}

# [м.р., ж.р., ср.р., мн.ч.]
const ADJECTIVES := {
	"hp": ["Крепкий", "Крепкая", "Крепкое", "Крепкие"],
	"atk": ["Яростный", "Яростная", "Яростное", "Яростные"],
	"crit": ["Меткий", "Меткая", "Меткое", "Меткие"],
	"aspd": ["Быстрый", "Быстрая", "Быстрое", "Быстрые"],
	"speed": ["Лёгкий", "Лёгкая", "Лёгкое", "Лёгкие"],
	"sp": ["Мудрый", "Мудрая", "Мудрое", "Мудрые"],
	"def": ["Прочный", "Прочная", "Прочное", "Прочные"],
	"eva": ["Неуловимый", "Неуловимая", "Неуловимое", "Неуловимые"],
	"cast": ["Чародейский", "Чародейская", "Чародейское", "Чародейские"],
	"str": ["Могучий", "Могучая", "Могучее", "Могучие"],
	"agi": ["Проворный", "Проворная", "Проворное", "Проворные"],
	"vit": ["Стойкий", "Стойкая", "Стойкое", "Стойкие"],
	"int": ["Разумный", "Разумная", "Разумное", "Разумные"],
	"dex": ["Зоркий", "Зоркая", "Зоркое", "Зоркие"],
	"luk": ["Счастливый", "Счастливая", "Счастливое", "Счастливые"],
}

# Как показывать свойства (общие для подсказок, склада и окна характеристик).
const STAT_LABELS := {
	"atk": "%+d к урону", "hp": "%+d HP", "sp": "%+d SP", "crit": "%+d%% крит",
	"aspd": "%+d%% скор. атаки", "speed": "%+d%% скор. бега", "def": "%+d%% защиты",
	"eva": "%+d%% уклонения", "cast": "%+d%% скор. каста",
	"str": "%+d Сила", "agi": "%+d Ловкость", "vit": "%+d Выносливость",
	"int": "%+d Интеллект", "dex": "%+d Меткость", "luk": "%+d Удача",
	"lifesteal": "%d%% вампиризм", "burn": "%d%% шанс поджечь", "thorns": "%d%% шипы",
	"stun": "%d%% шанс оглушить", "boss": "%+d%% урона боссам", "pierce": "+%d пробивание стрел",
	"hp_pct": "%+d%% HP", "dmg_pct": "%+d%% урона",
}

# Комплекты: части (базы предметов) и бонусы за число надетых частей.
const SETS := {
	"guardian": {"name": "Страж", "gen": "Стража", "pieces": ["helm", "chain", "tower_shield"],
		"bonus": {2: {"hp_pct": 15}, 3: {"def": 10}}},
	"fury": {"name": "Ярость", "gen": "Ярости", "pieces": ["greataxe", "cape", "greaves"],
		"bonus": {2: {"lifesteal": 4}, 3: {"dmg_pct": 15}}},
	"tracker": {"name": "Следопыт", "gen": "Следопыта", "pieces": ["quiver", "cape", "shoes"],
		"bonus": {2: {"speed": 8}, 3: {"crit": 10, "aspd": 10}}},
	"archmage": {"name": "Архимаг", "gen": "Архимага", "pieces": ["circlet", "mantle", "tome"],
		"bonus": {2: {"sp": 30}, 3: {"cast": 20}}},
}

# Значения, которые растут с глубиной подземелья.
const SCALING_KEYS := ["atk_min", "atk_max", "atk", "hp", "sp"]


static func stat_text(key: String, value: int) -> String:
	return (STAT_LABELS.get(key, key + " %+d") as String) % value


## Может ли герой (класс + профессия) носить предмет / базу.
static func fits_base(base_key: String, cls: String, job: String) -> bool:
	var b: Dictionary = BASES[base_key]
	if b.has("class") and cls != "":
		var c: Variant = b["class"]
		if (c is Array and not (cls in c)) or (c is String and c != cls):
			return false
	if b.has("job") and b["job"] != job:
		return false
	return true


static func fits(item: Dictionary, cls: String, job := "") -> bool:
	return fits_base(item["base"], cls, job)


## Старое имя, оставлено для совместимости.
static func fits_class(item: Dictionary, cls: String) -> bool:
	return fits(item, cls, "")


static func random_base(cls := "", job := "") -> String:
	var keys := []
	for k: String in BASES:
		if fits_base(k, cls, job):
			keys.append(k)
	return keys.pick_random()


## Случайный предмет для героя: обычный / магический / редкий, изредка — часть комплекта.
static func random_item(depth: int, cls := "", job := "") -> Dictionary:
	if randf() < 0.02 + 0.003 * depth:
		var s := random_set_item(depth, cls, job)
		if not s.is_empty():
			return s
	var r := randf()
	var rarity := 0
	if r < 0.07 + 0.01 * depth:
		rarity = 2
	elif r < 0.4:
		rarity = 1
	return make(random_base(cls, job), rarity, depth)


static func make(base_key: String, rarity: int, depth: int) -> Dictionary:
	var base: Dictionary = BASES[base_key]
	var scale := 1.0 + 0.15 * (depth - 1)
	var stats := {}
	for k: String in base["stats"]:
		var v: int = base["stats"][k]
		stats[k] = int(round(v * scale)) if k in SCALING_KEYS else v

	var n: int = RARITY[rarity]["affixes"]
	var pool := AFFIXES.keys()
	pool.shuffle()
	var first_affix := ""
	var special := ""
	for i in n:
		var k: String
		# У редкого второе свойство — всегда особое.
		if rarity == 2 and i == n - 1:
			k = SPECIAL.keys().pick_random()
			special = k
			stats[k] = stats.get(k, 0) + randi_range(SPECIAL[k][0], SPECIAL[k][1])
			continue
		k = pool[i]
		var v := randi_range(AFFIXES[k][0], AFFIXES[k][1])
		if k in SCALING_KEYS:
			v = int(round(v * scale))
		stats[k] = stats.get(k, 0) + v
		if first_affix == "":
			first_affix = k

	var item_name: String = base["name"]
	if first_affix != "":
		var adj: String = ADJECTIVES[first_affix][base["gender"]]
		item_name = adj + " " + item_name.left(1).to_lower() + item_name.substr(1)
	if special != "":
		item_name += " " + SPECIAL_SUFFIX[special]
	return {
		"base": base_key,
		"slot": base["slot"],
		"name": item_name,
		"icon": base["icon"],
		"rarity": rarity,
		"stats": stats,
		"refine": 0,
	}


## Часть комплекта: «Шлем Стража». Пустой словарь, если подходящих частей нет.
static func random_set_item(depth: int, cls := "", job := "") -> Dictionary:
	var options := []
	for sid: String in SETS:
		for b: String in SETS[sid]["pieces"]:
			if fits_base(b, cls, job):
				options.append([sid, b])
	if options.is_empty():
		return {}
	var pick: Array = options.pick_random()
	return make_set_piece(pick[0], pick[1], depth)


static func make_set_piece(set_id: String, base_key: String, depth: int) -> Dictionary:
	var item := make(base_key, 1, depth)
	# Второе обычное свойство вместо прилагательного в названии.
	var pool := AFFIXES.keys()
	pool.shuffle()
	for k: String in pool:
		if not item["stats"].has(k):
			item["stats"][k] = randi_range(AFFIXES[k][0], AFFIXES[k][1])
			break
	item["rarity"] = SET_RARITY
	item["set"] = set_id
	item["name"] = "%s %s" % [BASES[base_key]["name"], SETS[set_id]["gen"]]
	return item


## Иконка предмета для RichTextLabel (items.png, 16x16).
static func icon_bb(item: Dictionary, px := 9) -> String:
	return "[img width=%d height=%d region=%d,0,16,16]res://assets/items.png[/img] " % [px, px, int(item.get("icon", 0)) * 16]


static func color(item: Dictionary) -> Color:
	return RARITY[item["rarity"]]["color"]


## Имя с уровнем заточки: «Яростный меч +3».
static func display_name(item: Dictionary) -> String:
	var r: int = item.get("refine", 0)
	return item["name"] + (" +%d" % r if r > 0 else "")


static func is_two_hand(item: Variant) -> bool:
	return item != null and BASES[item["base"]].get("two_hand", false)
