extends RefCounted
## Крафт: материалы, рецепты, заточка (как в Ragnarok: +1…+10).
##
## Материалы выпадают с монстров (у каждого вида свой), руду даёт шахта лагеря,
## редкие материалы — с боссов (с ними создание гарантирует редкий предмет).
## Заточка: каждый уровень +10% ко всем положительным свойствам предмета.
## До +4 всегда успешно, дальше шанс падает; неудача — уровень заточки −1.

const Items := preload("res://scripts/items.gd")

const MATERIALS := {
	"gel": {"name": "Слизь", "icon": 0},
	"dust": {"name": "Эфирная пыль", "icon": 1},
	"wing": {"name": "Перепонка", "icon": 2},
	"bone": {"name": "Кость", "icon": 3},
	"spore": {"name": "Споры", "icon": 4},
	"ore": {"name": "Руда", "icon": 5},
	"crown": {"name": "Корона слизней", "icon": 6, "rare": true},
	"phylactery": {"name": "Филактерия", "icon": 7, "rare": true},
	"sulfur": {"name": "Сера", "icon": 8},
	"obsidian": {"name": "Обсидиан", "icon": 9},
	"scale": {"name": "Чешуя", "icon": 10},
	"ember_heart": {"name": "Сердце пламени", "icon": 11, "rare": true},
	# Глубины (10–50). Иконки пока перекрашенные старые (tint).
	"ice": {"name": "Лёд", "icon": 1, "tint": Color(0.6, 0.9, 1.4)},
	"venom": {"name": "Яд", "icon": 4, "tint": Color(0.6, 1.3, 0.4)},
	"soul": {"name": "Душа", "icon": 1, "tint": Color(0.8, 0.6, 1.4)},
	"horn": {"name": "Рог", "icon": 3, "tint": Color(1.3, 0.55, 0.45)},
	"frost_heart": {"name": "Сердце льда", "icon": 11, "rare": true, "tint": Color(0.55, 0.9, 1.5)},
	"swamp_pearl": {"name": "Болотная жемчужина", "icon": 6, "rare": true, "tint": Color(0.7, 1.3, 0.6)},
	"shadow_gem": {"name": "Теневой камень", "icon": 7, "rare": true, "tint": Color(0.75, 0.5, 1.4)},
	"abyss_eye": {"name": "Око бездны", "icon": 11, "rare": true, "tint": Color(1.4, 0.4, 0.8)},
	# Этажи 71–100
	"coral": {"name": "Коралл", "icon": 4, "tint": Color(1.4, 0.7, 0.7)},
	"gear": {"name": "Шестерня", "icon": 5, "tint": Color(1.2, 1.0, 0.7)},
	"crystal": {"name": "Кристалл", "icon": 1, "tint": Color(1.3, 0.8, 1.4)},
	"kraken_ink": {"name": "Чернила кракена", "icon": 6, "rare": true, "tint": Color(0.4, 0.6, 1.2)},
	"machine_core": {"name": "Ядро машины", "icon": 11, "rare": true, "tint": Color(1.3, 1.1, 0.5)},
	"prism": {"name": "Призма", "icon": 7, "rare": true, "tint": Color(1.4, 0.9, 1.5)},
}

# Обычные материалы (не редкие) — ими платят за заточку.
const COMMON := ["gel", "dust", "wing", "bone", "spore", "ore", "sulfur", "obsidian", "scale", "ice", "venom", "soul", "horn", "coral", "gear", "crystal"]
# Редкие (с боссов): при создании гарантируют редкий предмет.
const RARE := ["crown", "phylactery", "ember_heart", "frost_heart", "swamp_pearl", "shadow_gem", "abyss_eye", "kraken_ink", "machine_core", "prism"]

# Рецепты: база предмета → материалы и золото.
const RECIPES := {
	"sword": {"mats": {"ore": 3, "bone": 2}, "gold": 30},
	"axe": {"mats": {"ore": 5, "bone": 2}, "gold": 40},
	"dagger": {"mats": {"ore": 2, "wing": 3}, "gold": 30},
	"bow": {"mats": {"bone": 3, "wing": 3}, "gold": 30},
	"longbow": {"mats": {"bone": 5, "wing": 3}, "gold": 40},
	"wand": {"mats": {"dust": 3, "gel": 2}, "gold": 30},
	"staff": {"mats": {"dust": 5, "spore": 2}, "gold": 40},
	"leather": {"mats": {"gel": 4, "wing": 2}, "gold": 25},
	"chain": {"mats": {"ore": 6, "bone": 2}, "gold": 45},
	"ring": {"mats": {"dust": 3, "ore": 1}, "gold": 30},
	"amulet": {"mats": {"spore": 3, "dust": 2}, "gold": 30},
	# Вторая рука
	"buckler": {"mats": {"ore": 2, "bone": 2}, "gold": 25},
	"tower_shield": {"mats": {"ore": 6, "obsidian": 2}, "gold": 50},
	"quiver": {"mats": {"wing": 3, "bone": 2}, "gold": 25},
	"tome": {"mats": {"dust": 4, "spore": 2}, "gold": 30},
	# Голова, плащ, обувь, украшения
	"cap": {"mats": {"gel": 3, "wing": 1}, "gold": 20},
	"helm": {"mats": {"ore": 4}, "gold": 30},
	"circlet": {"mats": {"dust": 3, "ore": 2}, "gold": 35},
	"cape": {"mats": {"wing": 4, "gel": 2}, "gold": 25},
	"mantle": {"mats": {"dust": 3, "spore": 3}, "gold": 30},
	"shoes": {"mats": {"gel": 2, "scale": 2}, "gold": 25},
	"greaves": {"mats": {"ore": 4, "obsidian": 1}, "gold": 35},
	"band": {"mats": {"ore": 2, "sulfur": 2}, "gold": 35},
	"talisman": {"mats": {"bone": 3, "obsidian": 1}, "gold": 35},
	# Оружие профессий — из материалов глубоких этажей
	"greataxe": {"mats": {"obsidian": 4, "ore": 4}, "gold": 70},
	"mace": {"mats": {"ore": 4, "bone": 3}, "gold": 55},
	"hunter_bow": {"mats": {"scale": 3, "wing": 3}, "gold": 55},
	"crossbow": {"mats": {"ore": 4, "obsidian": 2, "bone": 2}, "gold": 70},
	"element_staff": {"mats": {"sulfur": 4, "dust": 3}, "gold": 70},
	"sage_book": {"mats": {"spore": 3, "dust": 3, "sulfur": 2}, "gold": 60},
	# Вор и послушник
	"knife": {"mats": {"ore": 2, "wing": 2}, "gold": 25},
	"stiletto": {"mats": {"ore": 3, "bone": 2}, "gold": 35},
	"cleaver": {"mats": {"ore": 4, "obsidian": 2}, "gold": 60},
	"katar": {"mats": {"obsidian": 3, "scale": 2}, "gold": 65},
	"acolyte_rod": {"mats": {"bone": 2, "dust": 3}, "gold": 25},
	"beads": {"mats": {"bone": 3, "spore": 2}, "gold": 35},
	"holy_staff": {"mats": {"dust": 4, "sulfur": 3}, "gold": 70},
	"knuckles": {"mats": {"ore": 4, "scale": 2}, "gold": 60},
}

# Закалка (мастерская): любой рецепт можно сделать с материалом глубины — предмет получается
# силы той глубины и с особым свойством закалки. Порядок — как биомы подземелья.
# adj — прилагательное к названию по роду (м/ж/с), bonus — добавка к свойствам.
const TIERS := {
	"fire": {"name": "Огненная", "mat": "sulfur", "count": 3, "depth": 21,
		"adj": ["Огненный", "Огненная", "Огненное"], "bonus": {"burn": 6},
		"desc": "сила 21-го этажа, +6% поджога"},
	"ice": {"name": "Ледяная", "mat": "ice", "count": 4, "depth": 31,
		"adj": ["Ледяной", "Ледяная", "Ледяное"], "bonus": {"def": 4, "hp": 15},
		"desc": "сила 31-го этажа, +4% защиты, +15 HP"},
	"venom": {"name": "Ядовитая", "mat": "venom", "count": 4, "depth": 41,
		"adj": ["Ядовитый", "Ядовитая", "Ядовитое"], "bonus": {"thorns": 15},
		"desc": "сила 41-го этажа, +15% шипов"},
	"soul": {"name": "Призрачная", "mat": "soul", "count": 5, "depth": 51,
		"adj": ["Призрачный", "Призрачная", "Призрачное"], "bonus": {"lifesteal": 3, "sp": 20},
		"desc": "сила 51-го этажа, +3% вампиризма, +20 SP"},
	"horn": {"name": "Демоническая", "mat": "horn", "count": 5, "depth": 61,
		"adj": ["Демонический", "Демоническая", "Демоническое"], "bonus": {"boss": 12, "crit": 5},
		"desc": "сила 61-го этажа, +12% урона боссам, +5% крита"},
	"coral": {"name": "Коралловая", "mat": "coral", "count": 5, "depth": 71,
		"adj": ["Коралловый", "Коралловая", "Коралловое"], "bonus": {"eva": 5, "hp": 25},
		"desc": "сила 71-го этажа, +5% уклонения, +25 HP"},
	"gear": {"name": "Механическая", "mat": "gear", "count": 6, "depth": 81,
		"adj": ["Механический", "Механическая", "Механическое"], "bonus": {"aspd": 8, "def": 3},
		"desc": "сила 81-го этажа, +8% скорости атаки, +3% защиты"},
	"crystal": {"name": "Хрустальная", "mat": "crystal", "count": 6, "depth": 91,
		"adj": ["Хрустальный", "Хрустальная", "Хрустальное"], "bonus": {"crit": 8, "cast": 10},
		"desc": "сила 91-го этажа, +8% крита, +10% скорости каста"},
}

const REFINE_MAX := 10
const REFINE_STEP := 0.10
# Шанс успеха при заточке ДО уровня N (индекс = текущий уровень): +1..+4 — 100%.
const REFINE_CHANCE := [100, 100, 100, 100, 80, 65, 50, 35, 25, 15]


static func mat_name(id: String) -> String:
	return MATERIALS[id]["name"]


# ---------------- Заточка ----------------

static func refine_level(item: Dictionary) -> int:
	return item.get("refine", 0)


## Свойства предмета с учётом заточки (положительные значения растут на 10% за уровень).
static func effective_stats(item: Dictionary) -> Dictionary:
	var r := refine_level(item)
	var out := {}
	for k: String in item["stats"]:
		var v: int = item["stats"][k]
		out[k] = int(round(v * (1.0 + REFINE_STEP * r))) if v > 0 and r > 0 else v
	return out


## Шанс успеха (%) с учётом бонуса (Удача в подземелье, мастерская в лагере).
static func refine_chance(item: Dictionary, bonus: float) -> int:
	var lvl := refine_level(item)
	if lvl >= REFINE_MAX:
		return 0
	return clampi(int(REFINE_CHANCE[lvl] + bonus), 0, 100)


## Цена заточки: золото и любые обычные материалы.
static func refine_cost(item: Dictionary) -> Dictionary:
	var lvl := refine_level(item)
	return {"gold": 15 * (lvl + 1), "mats": lvl + 1}


## Хватает ли ресурсов. mats — словарь материалов (забега или лагеря).
static func can_pay_refine(item: Dictionary, gold: int, mats: Dictionary) -> bool:
	var c := refine_cost(item)
	return refine_level(item) < REFINE_MAX and gold >= c["gold"] and common_count(mats) >= c["mats"]


static func common_count(mats: Dictionary) -> int:
	var n := 0
	for id in COMMON:
		n += mats.get(id, 0)
	return n


## Списать N обычных материалов — начиная с тех, которых больше всего.
static func take_common(mats: Dictionary, n: int) -> void:
	while n > 0:
		var best := ""
		for id in COMMON:
			if mats.get(id, 0) > 0 and (best == "" or mats[id] > mats[best]):
				best = id
		if best == "":
			return
		mats[best] -= 1
		n -= 1


## Попытка заточки. Возвращает true при успехе. Ресурсы списывает вызывающий.
static func try_refine(item: Dictionary, bonus: float) -> bool:
	var ok := randf() * 100.0 < refine_chance(item, bonus)
	if ok:
		item["refine"] = refine_level(item) + 1
	elif refine_level(item) > 0:
		item["refine"] = refine_level(item) - 1
	return ok


# ---------------- Создание ----------------

static func can_craft(base: String, gold: int, mats: Dictionary) -> bool:
	var r: Dictionary = RECIPES[base]
	if gold < r["gold"]:
		return false
	for id: String in r["mats"]:
		if mats.get(id, 0) < r["mats"][id]:
			return false
	return true


## Создать предмет. rare_mat — id редкого материала ("" — без него): гарантирует редкий.
## workshop_level повышает шанс хорошей редкости и силу предмета.
static func craft(base: String, workshop_level: int, rare_mat := "", tier := "") -> Dictionary:
	var rarity := 0
	var r := randf()
	if rare_mat != "" or r < 0.08 + 0.06 * workshop_level:
		rarity = 2
	elif r < 0.45:
		rarity = 1
	var depth := 1 + workshop_level
	if tier != "":
		depth = int(TIERS[tier]["depth"]) + workshop_level
	var item := Items.make(base, rarity, depth)
	item["crafted"] = true
	if tier != "":
		var t: Dictionary = TIERS[tier]
		item["tier"] = tier
		for k: String in t["bonus"]:
			item["stats"][k] = int(item["stats"].get(k, 0)) + int(t["bonus"][k])
		var adj: String = t["adj"][Items.BASES[base]["gender"]]
		var nm: String = item["name"]
		item["name"] = adj + " " + nm.left(1).to_lower() + nm.substr(1)
	return item


## Цена рецепта с закалкой: обычный рецепт + материал глубин, золото ×2.
static func tier_cost(base: String, tier: String) -> Dictionary:
	var r: Dictionary = RECIPES[base]
	var mats: Dictionary = r["mats"].duplicate()
	var gold: int = r["gold"]
	if tier != "":
		var t: Dictionary = TIERS[tier]
		mats[t["mat"]] = mats.get(t["mat"], 0) + int(t["count"])
		gold *= 2
	return {"mats": mats, "gold": gold}


static func can_craft_cost(cost: Dictionary, gold: int, mats: Dictionary) -> bool:
	if gold < cost["gold"]:
		return false
	for id: String in cost["mats"]:
		if mats.get(id, 0) < cost["mats"][id]:
			return false
	return true


## Разобрать предмет: вернуть примерно половину материалов рецепта (минимум 1).
static func salvage(item: Dictionary) -> Dictionary:
	var out := {}
	var recipe: Dictionary = RECIPES.get(item["base"], {"mats": {"ore": 2}})
	for id: String in recipe["mats"]:
		out[id] = maxi(1, int(recipe["mats"][id] / 2.0 + refine_level(item) * 0.5))
	# Закалённый предмет возвращает и часть материала глубин.
	var tier: String = item.get("tier", "")
	if TIERS.has(tier):
		var m: String = TIERS[tier]["mat"]
		out[m] = out.get(m, 0) + maxi(1, int(TIERS[tier]["count"]) / 2)
	return out


static func recipe_text(base: String, tier := "") -> String:
	var r: Dictionary = tier_cost(base, tier)
	var parts: PackedStringArray = []
	for id: String in r["mats"]:
		parts.append("%s ×%d" % [mat_name(id), r["mats"][id]])
	parts.append("%d зол." % r["gold"])
	return ", ".join(parts)
