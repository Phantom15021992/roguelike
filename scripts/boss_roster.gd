extends RefCounted
## Боссы по биомам. Биом — 10 этажей: боссы на 3-м, 6-м и 9-м этажах биома, 10-й — логово
## финального босса биома (4 фазы; со 2-й фазы призывает мини-копии трёх боссов этого биома).
##
## Боссов всего 4 «вида» (скрипта): король-слизень (прыжки), повелитель костей (копья, щит
## с кристаллами), владыка пламени (метеоры, лава, лучи) и финальный (4 фазы). Каждый босс
## биома — вид с настройками: имя, цвет, размер, темп, сила ударов, холод снарядов, здоровье,
## добыча, кого призывает.

const BIOME_FLOORS := 10
const MAX_DEPTH := 70
const BOSS_FLOORS := [3, 6, 9, 10]   # этажи биома с боссом (10-й — финальный)

const SLIME := "res://scenes/boss_slime.tscn"
const BONE := "res://scenes/bone_lord.tscn"
const EMBER := "res://scenes/ember_titan.tscn"
const FINAL := "res://scenes/final_boss.tscn"

# Материалы-добыча биома: [обычные..., редкий].
const BIOME_MATS := [
	[["gel", 5], ["dust", 3], ["spore", 2], ["crown", 1]],
	[["bone", 6], ["ore", 3], ["phylactery", 1]],
	[["sulfur", 4], ["obsidian", 3], ["scale", 3], ["ember_heart", 1]],
	[["ice", 6], ["ore", 3], ["frost_heart", 1]],
	[["venom", 6], ["spore", 3], ["swamp_pearl", 1]],
	[["soul", 6], ["bone", 3], ["shadow_gem", 1]],
	[["horn", 6], ["sulfur", 3], ["abyss_eye", 1]],
]

const ROSTER := [
	# 1–10 Подземелье
	[
		{"scene": SLIME, "name": "Король слизней"},
		{"scene": BONE, "name": "Повелитель костей"},
		{"scene": EMBER, "name": "Владыка пламени"},
		{"scene": FINAL, "name": "Древний страж", "tint": Color(0.8, 0.85, 1.0), "minion": "res://scenes/slime.tscn"},
	],
	# 11–20 Катакомбы
	[
		{"scene": SLIME, "name": "Чумной король слизней", "tint": Color(0.75, 0.9, 0.6), "tempo": 1.05},
		{"scene": BONE, "name": "Лич", "tint": Color(0.6, 0.95, 0.75), "tempo": 1.1},
		{"scene": EMBER, "name": "Костяной колосс", "tint": Color(0.95, 0.92, 0.78), "minion": "res://scenes/skeleton.tscn"},
		{"scene": FINAL, "name": "Король мёртвых", "tint": Color(0.7, 0.75, 0.95), "minion": "res://scenes/skeleton.tscn"},
	],
	# 21–30 Огненные пещеры
	[
		{"scene": SLIME, "name": "Магмовый слизень", "tint": Color(1.4, 0.6, 0.3), "tempo": 1.1},
		{"scene": BONE, "name": "Огненный жрец", "tint": Color(1.4, 0.7, 0.4), "tempo": 1.1},
		{"scene": EMBER, "name": "Владыка пламени", "tempo": 1.1},
		{"scene": FINAL, "name": "Повелитель вулкана", "tint": Color(1.35, 0.5, 0.3), "minion": "res://scenes/imp.tscn"},
	],
	# 31–40 Ледяные пещеры: снаряды замедляют
	[
		{"scene": SLIME, "name": "Ледяной король слизней", "tint": Color(0.7, 0.95, 1.4), "tempo": 1.15, "chill": 1.5},
		{"scene": BONE, "name": "Ледяная королева", "tint": Color(0.7, 0.95, 1.4), "tempo": 1.15, "chill": 1.5},
		{"scene": EMBER, "name": "Морозный исполин", "tint": Color(0.6, 0.85, 1.4), "tempo": 1.15, "minion": "res://scenes/frost_wisp.tscn"},
		{"scene": FINAL, "name": "Король вечной зимы", "tint": Color(0.75, 0.9, 1.5), "chill": 1.5, "minion": "res://scenes/ice_slime.tscn"},
	],
	# 41–50 Ядовитые топи
	[
		{"scene": SLIME, "name": "Королева топей", "tint": Color(0.7, 1.25, 0.6), "tempo": 1.2, "chill": 1.0},
		{"scene": BONE, "name": "Болотная ведьма", "tint": Color(0.6, 1.2, 0.5), "tempo": 1.2},
		{"scene": EMBER, "name": "Гнилой титан", "tint": Color(0.6, 1.0, 0.4), "tempo": 1.2, "minion": "res://scenes/toad.tscn"},
		{"scene": FINAL, "name": "Мать топей", "tint": Color(0.55, 1.15, 0.5), "minion": "res://scenes/lurker.tscn"},
	],
	# 51–60 Теневой лабиринт
	[
		{"scene": SLIME, "name": "Теневой король слизней", "tint": Color(0.6, 0.5, 0.95), "tempo": 1.25},
		{"scene": BONE, "name": "Теневой жнец", "tint": Color(0.55, 0.45, 0.9), "tempo": 1.3},
		{"scene": EMBER, "name": "Пожиратель света", "tint": Color(0.5, 0.45, 0.8), "tempo": 1.25, "minion": "res://scenes/shade.tscn"},
		{"scene": FINAL, "name": "Князь теней", "tint": Color(0.5, 0.4, 0.85), "minion": "res://scenes/necromancer.tscn"},
	],
	# 61–70 Бездна
	[
		{"scene": SLIME, "name": "Демонический слизень", "tint": Color(1.4, 0.45, 0.45), "tempo": 1.3},
		{"scene": BONE, "name": "Архидемон", "tint": Color(1.3, 0.4, 0.6), "tempo": 1.35},
		{"scene": EMBER, "name": "Князь бездны", "tint": Color(1.2, 0.4, 0.9), "tempo": 1.35, "minion": "res://scenes/demon.tscn"},
		{"scene": FINAL, "name": "Повелитель бездны", "tint": Color(0.9, 0.35, 1.1), "size": 1.3, "minion": "res://scenes/horror.tscn"},
	],
]


## Номер биома (0..6) и этаж внутри биома (1..10).
static func biome_of(depth: int) -> int:
	return clampi((depth - 1) / BIOME_FLOORS, 0, ROSTER.size() - 1)


static func local_floor(depth: int) -> int:
	return (depth - 1) % BIOME_FLOORS + 1


static func is_boss_depth(depth: int) -> bool:
	return local_floor(depth) in BOSS_FLOORS


## Настройки босса этого этажа ({} — этаж без босса).
static func config_for(depth: int) -> Dictionary:
	var i := BOSS_FLOORS.find(local_floor(depth))
	if i < 0:
		return {}
	return ROSTER[biome_of(depth)][i]


## Финальный этаж биома (10-й, 20-й, ...).
static func is_final_depth(depth: int) -> bool:
	return local_floor(depth) == BIOME_FLOORS


## Вид босса (имя скрипта: boss_slime, bone_lord, ember_titan, final_boss) — для выбора арены.
static func kind_of(cfg: Dictionary) -> String:
	return (cfg["scene"] as String).get_file().get_basename()


## Создать босса по настройкам (ещё не добавлен в сцену). as_mini — мини-копия для финального.
static func make(cfg: Dictionary, depth: int, as_mini := false) -> Node2D:
	var e: Node2D = (load(cfg["scene"]) as PackedScene).instantiate()
	e.BOSS_NAME = cfg["name"]
	e.tempo = float(cfg.get("tempo", 1.0))
	e.shot_chill = float(cfg.get("chill", 0.0))
	e.tint = cfg.get("tint", Color(1, 1, 1, 1))
	e.size = float(cfg.get("size", 1.0))
	e.power = float(cfg.get("power", 1.0))
	e.hp_mult = float(cfg.get("hp", 1.0))
	if cfg.has("minion") and "minion_scene" in e:
		e.minion_scene = load(cfg["minion"])
	var mats: Array = BIOME_MATS[biome_of(depth)].duplicate(true)
	if (cfg["scene"] as String) == FINAL:
		for m: Array in mats:
			m[1] = int(m[1]) * 2  # финальный — двойная добыча
	e.loot_mats = mats
	if as_mini:
		e.is_mini = true
		e.size = e.size * 0.6
		e.hp_mult = 0.2
		e.power = 0.6
		e.BOSS_NAME = cfg["name"] + " (копия)"
	return e
