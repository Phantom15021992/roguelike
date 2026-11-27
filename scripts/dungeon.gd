extends Node2D
## Этаж подземелья: собирает этаж из блоков (data/blocks.txt), расставляет героя, монстров
## и лестницу. Каждый 3-й этаж — отдельная арена с боссом.
##
## Символы карты: '#' стена, '.' пол, 'P' герой, 'S' лестница, 'B' босс,
## монстры: 's' слизень, 'w' дух, 'b' мышь, 'x' скелет, 'm' гриб.

const TILE := 16
const TILES_TEX := preload("res://assets/tiles.png")
# Новая графика (по референсам владельца): пока только первый биом — кристальная пещера.
const CAVE_TEX := preload("res://assets/cave_tiles.png")
# Биомы в новом стиле (пещера): пол+скала 64x128 (пол 4x4 клетки + скала 4x4), украшения 192x16,
# цвет света кристаллов, сумрак, цвета краёв скал и колонн. Остальные биомы — старые плитки.
# Картинки: tools/gen_cave.gd (биом 0) и tools/gen_biomes.gd (2, 3, 4, 8).
const STYLES := {
	# "art" — новый утверждённый стиль (tools/gen_dungeon.gd, assets/dng/*<art>.png, 2 пикселя
	# картинки на пиксель мира): пол и скалы рисует shaders/cave_art.gdshader, украшения 32 px.
	0: {"art": "0", "floor": "res://assets/cave_floor.png", "decor": "res://assets/dng/decor0.png", "light": Color(0.55, 0.85, 0.85),
		"ambient": Color(0.74, 0.74, 0.8), "rock": Color8(15, 14, 29), "edge": Color8(30, 30, 54), "rim": Color8(74, 84, 130), "pillar": Color8(52, 56, 88)},
	2: {"floor": "res://assets/biome_floor_2.png", "decor": "res://assets/biome_decor_2.png", "light": Color(1.0, 0.55, 0.2),
		"ambient": Color(0.42, 0.3, 0.3), "rock": Color8(26, 14, 14), "edge": Color8(56, 30, 26), "rim": Color8(200, 90, 40), "pillar": Color8(70, 46, 42)},
	3: {"floor": "res://assets/biome_floor_3.png", "decor": "res://assets/biome_decor_3.png", "light": Color(0.6, 0.88, 1.0),
		"ambient": Color(0.45, 0.5, 0.66), "rock": Color8(40, 56, 90), "edge": Color8(70, 96, 140), "rim": Color8(220, 236, 252), "pillar": Color8(110, 140, 180)},
	4: {"floor": "res://assets/biome_floor_4.png", "decor": "res://assets/biome_decor_4.png", "light": Color(0.5, 1.0, 0.6),
		"ambient": Color(0.32, 0.4, 0.32), "rock": Color8(16, 26, 16), "edge": Color8(34, 52, 30), "rim": Color8(90, 140, 70), "pillar": Color8(70, 80, 56)},
	8: {"floor": "res://assets/biome_floor_8.png", "decor": "res://assets/biome_decor_8.png", "light": Color(1.0, 0.75, 0.4),
		"ambient": Color(0.42, 0.38, 0.34), "rock": Color8(20, 18, 24), "edge": Color8(50, 46, 52), "rim": Color8(170, 130, 70), "pillar": Color8(110, 100, 96)},
}
const LIGHT_TEX := preload("res://assets/light.png")
const Blocks := preload("res://scripts/blocks.gd")
const Arenas := preload("res://scripts/arenas.gd")
const ANVIL := preload("res://scripts/anvil.gd")
const EXIT_PORTAL := preload("res://scripts/exit_portal.gd")
const FLOOR_EVENT := preload("res://scripts/floor_event.gd")

# Обычный этаж: сетка блоков.
const BLOCK := 15         # размер блока в тайлах
const BLOCK_GRID_W := 5
const BLOCK_GRID_H := 4

# Арена босса: старый генератор, карта 64x36.
const GRID_W := 4
const GRID_H := 3
const CELL_W := 16
const CELL_H := 12
const CORRIDOR_HALF := 1  # коридор шириной 3 тайла

# Координаты тайлов в tiles.png
const FLOOR_VARIANTS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const WALL_TOP := Vector2i(3, 0)
const WALL_FACE := Vector2i(4, 0)
const STAIRS := Vector2i(5, 0)

const SPAWNS := {
	"s": preload("res://scenes/slime.tscn"),
	"w": preload("res://scenes/wisp.tscn"),
	"b": preload("res://scenes/bat.tscn"),
	"x": preload("res://scenes/skeleton.tscn"),
	"m": preload("res://scenes/mushroom.tscn"),
	"i": preload("res://scenes/imp.tscn"),
	"o": preload("res://scenes/golem.tscn"),
	"z": preload("res://scenes/salamander.tscn"),
	# Глубины 10–50
	"f": preload("res://scenes/frost_wisp.tscn"),
	"c": preload("res://scenes/ice_slime.tscn"),
	"t": preload("res://scenes/toad.tscn"),
	"u": preload("res://scenes/lurker.tscn"),
	"h": preload("res://scenes/shade.tscn"),
	"n": preload("res://scenes/necromancer.tscn"),
	"d": preload("res://scenes/demon.tscn"),
	"k": preload("res://scenes/horror.tscn"),
	# Вторая половина биомов (этажи 6–10 каждого биома) — по 3 новых монстра.
	"1": preload("res://scenes/slime_splitter.tscn"),
	"2": preload("res://scenes/vampire_bat.tscn"),
	"3": preload("res://scenes/bomb_shroom.tscn"),
	"4": preload("res://scenes/skeleton_archer.tscn"),
	"5": preload("res://scenes/ghost.tscn"),
	"6": preload("res://scenes/bone_guard.tscn"),
	"7": preload("res://scenes/fire_slime.tscn"),
	"8": preload("res://scenes/fire_wisp.tscn"),
	"9": preload("res://scenes/bomber_imp.tscn"),
	"a": preload("res://scenes/ice_golem.tscn"),
	"e": preload("res://scenes/snow_bat.tscn"),
	"g": preload("res://scenes/frost_shroom.tscn"),
	"j": preload("res://scenes/poison_slime.tscn"),
	"l": preload("res://scenes/gnat.tscn"),
	"p": preload("res://scenes/rot_skeleton.tscn"),
	"q": preload("res://scenes/shadow_slime.tscn"),
	"r": preload("res://scenes/mirror_shade.tscn"),
	"v": preload("res://scenes/phantom_knight.tscn"),
	"y": preload("res://scenes/demon_slime.tscn"),
	"C": preload("res://scenes/hellhound.tscn"),
	"E": preload("res://scenes/soul_eater.tscn"),
	# Этажи 71–100. Буквы D M P S L A B заняты картой блоков.
	"F": preload("res://scenes/drowned.tscn"),
	"G": preload("res://scenes/tentacle.tscn"),
	"H": preload("res://scenes/jellyfish.tscn"),
	"I": preload("res://scenes/whirlpool.tscn"),
	"J": preload("res://scenes/crab.tscn"),
	"K": preload("res://scenes/sea_serpent.tscn"),
	"N": preload("res://scenes/turret.tscn"),
	"O": preload("res://scenes/saw.tscn"),
	"Q": preload("res://scenes/mech_golem.tscn"),
	"R": preload("res://scenes/flamer.tscn"),
	"T": preload("res://scenes/miner.tscn"),
	"U": preload("res://scenes/spider_mech.tscn"),
	"V": preload("res://scenes/reflector.tscn"),
	"W": preload("res://scenes/mirror.tscn"),
	"X": preload("res://scenes/glow_shroom.tscn"),
	"Y": preload("res://scenes/crystal_slime.tscn"),
	"Z": preload("res://scenes/prism.tscn"),
	"0": preload("res://scenes/shard_bat.tscn"),
}
# Биомы по 10 этажей (всего 70): боссы на 3-м, 6-м, 9-м этаже биома, 10-й — логово финального
# босса биома. Кто какой босс — boss_roster.gd.
const Roster := preload("res://scripts/boss_roster.gd")
const MAX_DEPTH := Roster.MAX_DEPTH


## Настройки босса этого этажа (см. boss_roster.gd).
static func boss_for(depth: int) -> Dictionary:
	return Roster.config_for(depth)


static func is_boss_depth(depth: int) -> bool:
	return Roster.is_boss_depth(depth)


# Монстры биомов: [символ, вес]. «monsters» — с 1-го этажа биома, «extra» — добавляются
# с 6-го этажа биома (по 3 новых монстра).
const POOLS := [
	{"from": 1, "name": "Подземелье", "tint": Color(1, 1, 1),
		"monsters": [["s", 6], ["b", 2], ["w", 2], ["m", 1]], "extra": [["1", 2], ["2", 2], ["3", 2]]},
	{"from": 11, "name": "Катакомбы", "tint": Color(0.82, 0.86, 1.0),
		"monsters": [["x", 4], ["b", 2], ["w", 2], ["m", 2], ["s", 1]], "extra": [["4", 2], ["5", 2], ["6", 2]]},
	{"from": 21, "name": "Огненные пещеры", "tint": Color(1.0, 0.8, 0.68),
		"monsters": [["i", 3], ["z", 3], ["o", 2], ["b", 1], ["x", 1]], "extra": [["7", 2], ["8", 2], ["9", 2]]},
	{"from": 31, "name": "Ледяные пещеры", "tint": Color(0.78, 0.9, 1.15),
		"monsters": [["f", 3], ["c", 3], ["b", 2], ["x", 1], ["o", 1]], "extra": [["a", 2], ["e", 2], ["g", 2]]},
	{"from": 41, "name": "Ядовитые топи", "tint": Color(0.78, 1.0, 0.72),
		"monsters": [["t", 3], ["u", 2], ["s", 2], ["m", 2], ["z", 1]], "extra": [["j", 2], ["l", 2], ["p", 2]]},
	{"from": 51, "name": "Теневой лабиринт", "tint": Color(0.75, 0.68, 0.95),
		"monsters": [["h", 3], ["n", 2], ["x", 3], ["w", 1], ["f", 1]], "extra": [["q", 2], ["r", 2], ["v", 2]]},
	{"from": 61, "name": "Бездна", "tint": Color(0.95, 0.62, 0.68),
		"monsters": [["d", 3], ["k", 2], ["i", 2], ["h", 2], ["n", 1]], "extra": [["y", 2], ["C", 2], ["E", 2]]},
	{"from": 71, "name": "Затонувший храм", "tint": Color(0.7, 0.9, 1.0),
		"monsters": [["F", 3], ["G", 2], ["H", 3], ["c", 1], ["t", 1]], "extra": [["I", 2], ["J", 2], ["K", 2]]},
	{"from": 81, "name": "Механическая кузня", "tint": Color(1.0, 0.9, 0.75),
		"monsters": [["N", 3], ["O", 2], ["Q", 2], ["i", 1], ["o", 1]], "extra": [["R", 2], ["T", 2], ["U", 2]]},
	{"from": 91, "name": "Хрустальные пещеры", "tint": Color(1.0, 0.85, 1.1),
		"monsters": [["V", 2], ["W", 3], ["X", 2], ["h", 2], ["r", 1]], "extra": [["Y", 2], ["Z", 2], ["0", 2]]},
]


static func pool_for(depth: int) -> Dictionary:
	var result: Dictionary = POOLS[0]
	for p: Dictionary in POOLS:
		if depth >= p["from"]:
			result = p
	return result


## Монстры этажа: первые 5 этажей биома — основной набор, с 6-го — ещё 3 новых.
static func monsters_for(depth: int) -> Array:
	var p := pool_for(depth)
	var out: Array = p["monsters"].duplicate()
	if depth == 1:
		out = out.filter(func(m: Array) -> bool: return m[0] != "m")  # на самом первом этаже без грибов
	if Roster.local_floor(depth) >= 6:
		out += p["extra"]
	return out


static func _pick_monster(rng: RandomNumberGenerator, monsters: Array) -> String:
	var total := 0
	for m in monsters:
		total += m[1]
	var r := rng.randi_range(1, total)
	for m in monsters:
		r -= m[1]
		if r <= 0:
			return m[0]
	return monsters[0][0]

# Модификатор этажа (реиграбельность): на обычных этажах иногда меняет правила.
const MODIFIERS := {
	"dark": {"name": "Тьма", "desc": "видно только рядом с собой"},
	"gold_rush": {"name": "Золотая лихорадка", "desc": "монстры крепче (+50% HP), золота вдвое больше"},
	"horde": {"name": "Орда", "desc": "монстров в полтора раза больше"},
	"glass": {"name": "Стеклянная пушка", "desc": "и ты, и монстры получаете +40% урона"},
	"bounty": {"name": "Щедрые недра", "desc": "материалов вдвое больше, предметов в полтора раза"},
}
const ELITE_KINDS := {
	"armored": {"name": "Бронированный", "color": Color(0.75, 0.8, 0.9)},
	"swift": {"name": "Быстрый", "color": Color(0.5, 1.0, 0.6)},
	"explosive": {"name": "Взрывной", "color": Color(1.0, 0.5, 0.2)},
	"regen": {"name": "Живучий", "color": Color(1.0, 0.4, 0.5)},
}
var modifier := ""
var trap := {}                 # комната-ловушка: {rect, doors, cells}; {} — нет
var _trap_state := ""          # "" — ждёт, "fight" — заперта, "done" — пройдена
var _trap_monsters: Array = []
var arena_rect := Rect2i()      # пол арены босса (в тайлах), задаёт _generate_boss
var arena_name := ""
var _portal_cell := Vector2i(-1, -1)  # портал домой — в зале перед ареной

@onready var map: TileMapLayer = $Map
@onready var entities: Node2D = $Entities
@onready var player: CharacterBody2D = $Entities/Player

var stairs_pos := Vector2(-9999, -9999)  # нет лестницы, пока не появится
var astar := AStarGrid2D.new()
var rows: Array = []
var is_boss_floor := false
var _gate_cells: Array[Vector2i] = []


func _ready() -> void:
	map.tile_set = _make_tileset()
	if Net.is_guest():
		_ready_guest()
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	is_boss_floor = is_boss_depth(Run.depth)
	if not is_boss_floor and Run.depth >= 2 and rng.randf() < 0.35:
		modifier = MODIFIERS.keys()[rng.randi() % MODIFIERS.size()]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mod="):
			modifier = a.get_slice("=", 1)
	Game.mod = modifier  # монстры читают его при появлении
	if modifier == "dark":
		Game.set_darkness(true)
	if "--autotest" in OS.get_cmdline_user_args():
		print("floor %d seed %d%s" % [Run.depth, rng.seed, " (BOSS)" if is_boss_floor else ""])
	rows = _generate_boss(rng) if is_boss_floor else _generate(rng, Run.depth)
	_build(rows)
	if "--mapdump" in OS.get_cmdline_user_args():
		_dump_map(rows, "res://shots/map_floor%d_%d.png" % [Run.depth, randi() % 1000])
		print("anvil on floor: %s" % ("".join(rows).contains("A")))
	map.modulate = Color.WHITE if _cave_style() else pool_for(Run.depth)["tint"]
	_decorate()
	Game.spawn_guest_heroes()
	Net.scene_loaded()
	Game.save_run.call_deferred()  # начало этажа — продолжить можно отсюда


## Кооп, гость: карта — из присланной хозяином, монстров и предметы пришлёт он же.
func _ready_guest() -> void:
	var d: Dictionary = Net.scene_data
	is_boss_floor = d.get("boss", false)
	modifier = str(d.get("mod", ""))
	Game.mod = modifier
	if modifier == "dark":
		Game.set_darkness(true)
	_gate_cells.clear()
	for c: Vector2i in d.get("gate", []):
		_gate_cells.append(c)
	rows = d["rows"]
	entities.remove_child(player)
	player.queue_free()
	_build(rows, true)
	map.modulate = Color.WHITE if _cave_style() else pool_for(Run.depth)["tint"]
	_decorate()
	Net.scene_loaded()


## Кооп, хозяин: что прислать гостям для этой сцены.
func net_scene() -> Dictionary:
	return {"kind": "dungeon", "rows": rows, "depth": Run.depth, "boss": is_boss_floor, "gate": _gate_cells, "mod": modifier}


# ---------------- Новая графика: кристальная пещера ----------------

## Клетка пола: в пещере — кусок большого бесшовного пола, иначе старая плитка.
## Стена, поставленная по ходу игры (ворота арены, ловушка): в пещере — тёмная скала.
func _wall_cell(cell: Vector2i) -> void:
	_grid_set(cell, true)
	if _cave_style():
		map.set_cell(cell, 1, Vector2i(posmod(cell.x, 4), 4 + posmod(cell.y, 4)))
	else:
		map.set_cell(cell, 0, WALL_FACE)


var _cols := {}              # клетка колонны -> номер колонны
var _col_rects: Array = []   # Rect2i каждой колонны (в клетках)


## Колонны — маленькие отдельные куски стены (до 9 клеток), не касающиеся края карты.
func _find_columns(map_rows: Array) -> void:
	_cols.clear()
	_col_rects.clear()
	if not _cave_style():
		return
	var h := map_rows.size()
	var w: int = (map_rows[0] as String).length()
	var seen := {}
	for y in h:
		for x in w:
			if (map_rows[y] as String)[x] != "#" or seen.has(Vector2i(x, y)):
				continue
			var comp: Array = []
			var stack: Array = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			var edge := false
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				comp.append(c)
				if c.x == 0 or c.y == 0 or c.x == w - 1 or c.y == h - 1:
					edge = true
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n := c + d
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and not seen.has(n) and (map_rows[n.y] as String)[n.x] == "#":
						seen[n] = true
						stack.append(n)
			if edge or comp.size() > 9:
				continue
			var r := Rect2i(comp[0], Vector2i.ONE)
			for c: Vector2i in comp:
				r = r.merge(Rect2i(c, Vector2i.ONE))
			var id := _col_rects.size()
			_col_rects.append(r)
			for c: Vector2i in comp:
				_cols[c] = id


func _floor_cell(cell: Vector2i) -> void:
	_grid_set(cell, false)
	if _cave_style():
		map.set_cell(cell, 1, Vector2i(posmod(cell.x, 4), posmod(cell.y, 4)))
	else:
		map.set_cell(cell, 0, FLOOR_VARIANTS[0])


## Биомы из STYLES — в новом стиле; остальные пока старые.
func _cave_style() -> bool:
	return STYLES.has(Roster.biome_of(Run.depth))


func _style() -> Dictionary:
	return STYLES.get(Roster.biome_of(Run.depth), STYLES[0])


## Биом в новом утверждённом стиле (пол и скалы — шейдером по карте, 2x картинки).
func _art() -> bool:
	return _cave_style() and _style().has("art")


var _grid_img: Image
var _grid_tex: ImageTexture


## Пол и скалы новым стилем: карта этажа — картинка 1 px на клетку (белый — скала), по ней
## шейдер рисует всё на одном прямоугольнике под украшениями. Плитки карты остаются для
## столкновений, но не видны.
func _make_art_floor() -> void:
	var h := rows.size()
	var w: int = (rows[0] as String).length()
	_grid_img = Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var rock := row[x] == "#" and not _cols.has(Vector2i(x, y))
			_grid_img.set_pixel(x, y, Color.WHITE if rock else Color.BLACK)
	_grid_tex = ImageTexture.create_from_image(_grid_img)
	var rect := ColorRect.new()
	rect.name = "CaveArt"
	rect.size = Vector2(w * TILE, h * TILE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cave_art.gdshader")
	var art: String = _style()["art"]
	mat.set_shader_parameter("grid", _grid_tex)
	mat.set_shader_parameter("floor_tex", load("res://assets/dng/floor%s.png" % art))
	mat.set_shader_parameter("rock_tex", load("res://assets/dng/rock%s.png" % art))
	mat.set_shader_parameter("cells", Vector2(w, h))
	rect.material = mat
	add_child(rect)
	move_child(rect, map.get_index() + 1)
	map.self_modulate = Color(1, 1, 1, 0.0)
	if "--showtiles" in OS.get_cmdline_user_args():  # проверка: клетки карты сквозь рисунок
		map.self_modulate.a = 1.0
		rect.modulate.a = 0.5


func _grid_set(cell: Vector2i, rock: bool) -> void:
	if _grid_img == null or cell.x < 0 or cell.y < 0 or cell.x >= _grid_img.get_width() or cell.y >= _grid_img.get_height():
		return
	_grid_img.set_pixel(cell.x, cell.y, Color.WHITE if rock else Color.BLACK)
	_grid_tex.update(_grid_img)


## Колонна новым стилем: готовая картинка по размеру (клетки), низ — нижний край колонны.
func _art_pillar(r: Rect2i, layer: Node2D) -> void:
	var art: String = _style()["art"]
	var w := clampi(r.size.x, 1, 3)
	var h := clampi(r.size.y, 1, 3)
	var node := Node2D.new()
	node.position = Vector2(r.position.x * TILE + r.size.x * TILE / 2.0, (r.position.y + r.size.y) * TILE)
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/dng/pillar%s_%dx%d.png" % [art, w, h])
	sp.centered = false
	sp.scale = Vector2.ONE * 0.5
	sp.offset = Vector2(-sp.texture.get_width() / 2.0, -sp.texture.get_height() + 4)
	node.add_child(sp)
	$Entities.add_child(node)
	if w >= 2 or h >= 2:
		var cp := node.position + Vector2(-1, -15)
		_light(layer, cp, _lc, 0.8 + w * 0.3, 0.6)


var _decor_tex: Texture2D
var _lc := Color(0.4, 0.85, 1.0)   # цвет света кристаллов биома


## Украшения и свет. Расклад зависит только от карты — у гостя в коопе получается тот же.
func _decorate() -> void:
	if not _cave_style():
		return
	# Полумрак пещеры — своя пелена со светлыми пятнами (встроенный свет движка в веб-режиме
	# ложится квадратами по клеткам).
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	_shade = ColorRect.new()
	_shade.size = Vector2(320, 180)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/cave_light.gdshader")
	var st := _style()
	mat.set_shader_parameter("ambient", Vector3((st["ambient"] as Color).r, (st["ambient"] as Color).g, (st["ambient"] as Color).b))
	_decor_tex = load(st["decor"])
	_lc = st["light"]
	_shade.material = mat
	cl.add_child(_shade)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("".join(rows))
	var layer := Node2D.new()
	layer.name = "Decor"
	$Ground.add_child(layer)
	$Ground.move_child(layer, 0)
	if _art():
		_make_art_floor()
	# Неровные края скал — под украшениями, над плитками.
	var edges: Node2D = preload("res://scripts/cave_edges.gd").new()
	edges.name = "CaveEdges"
	# Колонны для краёв — пол (вокруг них нет каменных наплывов), сами колонны — отдельные столбы.
	var open_rows: Array = []
	for y in rows.size():
		var orow: String = rows[y]
		for c: Vector2i in _cols:
			if c.y == y:
				orow[c.x] = "."
		open_rows.append(orow)
	edges.rows = open_rows
	edges.rock = st["rock"]
	edges.rock_edge = st["edge"]
	edges.rim_col = st["rim"]
	if _art():
		edges.free()
	else:
		$Ground.add_child(edges)
		$Ground.move_child(edges, 0)
	for r: Rect2i in _col_rects:
		if _art():
			_art_pillar(r, layer)
			continue
		var pil: Node2D = preload("res://scripts/cave_pillar.gd").new()
		pil.cells = r.size
		pil.seed_v = hash(r.position)
		pil.set_palette(st["pillar"])
		pil.position = Vector2(r.position.x * TILE + r.size.x * TILE / 2.0, (r.position.y + r.size.y) * TILE)
		$Entities.add_child(pil)
		if pil.has_crystals():
			var cp: Vector2 = pil.position + pil.crystal_pos()
			_light(layer, cp, _lc, 1.2 + r.size.x * 0.4, 0.8)
			# Кристаллы верхушки — над пеленой полумрака, чтобы сияли.
			var cs := _decor_sprite(_glow_layer(), int(hash(r.position) % 3), cp + Vector2(0, -2))
			cs.modulate = Color(1.3, 1.4, 1.5)
			cs.scale = Vector2.ONE * (0.8 + r.size.x * 0.2)
			_glow(layer, cp, 0.6 + r.size.x * 0.2, float(hash(r.position) % 100))
	var h := rows.size()
	var w: int = (rows[0] as String).length()
	var lights := 0
	for y in range(1, h - 1):
		var row: String = rows[y]
		for x in range(1, w - 1):
			var ch := row[x]
			var pos := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			if ch == "#":
				if not _cols.has(Vector2i(x, y)):
					_rock_decor(layer, rng, open_rows, x, y, pos)
				continue
			if ch == "S":
				_light(layer, pos, _lc, 2.0, 0.7)
				if _art():
					var stairs := Sprite2D.new()
					stairs.texture = load("res://assets/dng/stairs%s.png" % _style()["art"])
					stairs.scale = Vector2.ONE * 0.5
					stairs.position = pos
					layer.add_child(stairs)
				continue
			var under_wall := (open_rows[y - 1] as String)[x] == "#"
			var r2 := rng.randf()
			if under_wall and r2 < 0.07 and lights < 28:
				var c := _decor_sprite(_glow_layer(), rng.randi_range(0, 2), pos + Vector2(0, -4))
				c.flip_h = rng.randf() < 0.5
				c.modulate = Color(1.3, 1.4, 1.5)
				_glow(layer, pos + Vector2(0, -7), 1.0, rng.randf() * TAU)
				_light(layer, pos + Vector2(0, -6), _lc, 2.6, 1.3)
				lights += 1
			elif under_wall and r2 < 0.13:
				_decor_sprite(layer, 4, pos).modulate = Color(1.3, 1.5, 1.7)
				if lights < 28 and rng.randf() < 0.5:
					_glow(layer, pos, 0.5, rng.randf() * TAU)
					_light(layer, pos, _lc, 1.2, 0.9)
					lights += 1
			elif r2 < 0.05:
				_decor_sprite(layer, 6, pos)
			elif r2 < 0.09:
				_decor_sprite(layer, 7, pos)
			elif r2 < 0.095 and lights < 28:
				_decor_sprite(_glow_layer(), rng.randi_range(0, 2), pos).modulate = Color(1.3, 1.4, 1.5)
				_glow(layer, pos + Vector2(0, -3), 0.9, rng.randf() * TAU)
				_light(layer, pos + Vector2(0, -6), _lc, 2.4, 1.2)
				lights += 1
	set_process(true)


## Фон скалы (где ходить нельзя): у края — сталагмиты, в глубине — валуны, кристаллы в породе, искры.
func _rock_decor(layer: Node2D, rng: RandomNumberGenerator, open_rows: Array, x: int, y: int, pos: Vector2) -> void:
	var depth := 3
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var yy := y + dy
			var xx := x + dx
			if yy < 0 or yy >= open_rows.size() or xx < 0 or xx >= (open_rows[yy] as String).length():
				continue
			if (open_rows[yy] as String)[xx] != "#":
				depth = mini(depth, maxi(absi(dx), absi(dy)))
	var r := rng.randf()
	var jitter := Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
	if depth == 1:
		if r < 0.07:
			_decor_sprite(layer, 8, pos + jitter).flip_h = rng.randf() < 0.5
	elif depth >= 2:
		if r < 0.1:
			_decor_sprite(layer, 10, pos + jitter).flip_h = rng.randf() < 0.5
		elif r < 0.15:
			_decor_sprite(_glow_layer(), 9, pos + jitter).flip_h = rng.randf() < 0.5
			if rng.randf() < 0.5:
				_glow(layer, pos + jitter + Vector2(0, -3), 0.55, rng.randf() * TAU)
				_light(layer, pos, _lc, 0.9, 0.4)
		elif r < 0.25:
			_decor_sprite(layer, 11, pos + jitter)
		elif r < 0.3:
			_decor_sprite(layer, 8, pos + jitter).flip_h = rng.randf() < 0.5


var _halos: Array = []   # [спрайт ореола, фаза] — мягко пульсируют


## Ореол кристалла: мягкое голубое пятно, складывается с картинкой (светится, а не просто «не темнеет»).
func _glow(_layer: Node2D, pos: Vector2, size: float, phase: float) -> void:
	var g := Sprite2D.new()
	g.texture = LIGHT_TEX
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.position = pos
	g.scale = Vector2.ONE * size * 0.7
	g.modulate = Color(_lc.r * 0.9, _lc.g * 0.9, _lc.b * 0.9, 0.55)
	# Над пеленой полумрака — иначе она гасит ореол; под кристаллами.
	_glow_layer().add_child(g)
	_glow_layer().move_child(g, 0)
	_halos.append([g, phase, size])


var _glow_root: Node2D


func _glow_layer() -> Node2D:
	if _glow_root == null:
		var cl := CanvasLayer.new()
		cl.layer = 2
		cl.follow_viewport_enabled = true
		add_child(cl)
		_glow_root = Node2D.new()
		cl.add_child(_glow_root)
	return _glow_root


func _decor_sprite(layer: Node2D, frame: int, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _decor_tex if _decor_tex else load(_style()["decor"])
	s.region_enabled = true
	if _art():
		s.region_rect = Rect2(frame * 32, 0, 32, 32)
		s.scale = Vector2.ONE * 0.5
	else:
		s.region_rect = Rect2(frame * 16, 0, 16, 16)
	s.position = pos
	layer.add_child(s)
	return s


var _shade: ColorRect
var _lights: Array = []   # [позиция, цвет, радиус] — кристаллы, грибы, лестница


func _light(_layer: Node2D, pos: Vector2, color: Color, size: float, energy: float) -> void:
	_lights.append([pos, Color(color.r * energy, color.g * energy, color.b * energy) * 0.8, size * 30.0])


## Каждый кадр: какие источники света на экране — в шейдер (не больше 32).
func _process(_delta: float) -> void:
	if _shade == null:
		return
	var tm := Time.get_ticks_msec() / 1000.0
	for hl: Array in _halos:
		var g: Sprite2D = hl[0]
		var f := 0.5 + 0.5 * sin(tm * 1.6 + float(hl[1]))
		g.modulate.a = 0.35 + 0.3 * f
		g.scale = Vector2.ONE * float(hl[2]) * (0.62 + 0.12 * f)
	# Мир → экран 320x180 (канва растянута на окно, поэтому делим на масштаб окна).
	var k := 320.0 / get_viewport().get_visible_rect().size.x
	var xf := get_viewport().get_canvas_transform()
	var pos := PackedVector2Array()
	var col := PackedColorArray()
	for h in get_tree().get_nodes_in_group("player"):
		pos.append(xf * (h.global_position + Vector2(0, -8)) * k)
		col.append(Color(1.0, 0.92, 0.8, 120.0) if not h.dead else Color(0.5, 0.5, 0.6, 60.0))
	var screen := Rect2(Vector2(-60, -60), Vector2(440, 300))
	for l: Array in _lights:
		if pos.size() >= 32:
			break
		var sp: Vector2 = xf * (l[0] as Vector2) * k
		if screen.has_point(sp):
			pos.append(sp)
			var c: Color = l[1]
			col.append(Color(c.r, c.g, c.b, l[2]))
	var mat := _shade.material as ShaderMaterial
	mat.set_shader_parameter("count", pos.size())
	# Шейдер ждёт ровно 32 элемента.
	while pos.size() < 32:
		pos.append(Vector2.ZERO)
		col.append(Color(0, 0, 0, 1))
	mat.set_shader_parameter("pos", pos)
	var v4 := PackedVector4Array()
	for c: Color in col:
		v4.append(Vector4(c.r, c.g, c.b, c.a))
	mat.set_shader_parameter("col", v4)


# ---------------- Комната-ловушка ----------------

func _physics_process(_delta: float) -> void:
	if trap.is_empty() or _trap_state == "done" or Net.is_guest():
		return
	var r: Array = trap["rect"]
	# Внутренняя часть комнаты (без краёв с проходами) — в пикселях.
	var inner := Rect2(Vector2((r[0] + 1) * TILE, (r[1] + 1) * TILE), Vector2((r[2] - 2) * TILE, (r[3] - 2) * TILE))
	if _trap_state == "":
		for h in get_tree().get_nodes_in_group("player"):
			if not h.dead and inner.has_point(h.global_position):
				_trap_spring(inner)
				return
	elif _trap_state == "fight":
		_trap_monsters = _trap_monsters.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not m.dead)
		if _trap_monsters.is_empty():
			_trap_open()


func _trap_spring(inner: Rect2) -> void:
	_trap_state = "fight"
	var edits: Array = []
	for d: Array in trap["doors"]:
		var c := Vector2i(d[0], d[1])
		_wall_cell(c)
		astar.set_point_solid(c, true)
		edits.append([c.x, c.y, "#", true])
	Net.map_cells(edits)
	# Кто стоит в проходе — внутрь.
	for h in get_tree().get_nodes_in_group("player"):
		var hc := Vector2i(h.global_position / TILE)
		for d: Array in trap["doors"]:
			if hc == Vector2i(d[0], d[1]):
				h.global_position = inner.get_center()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool := monsters_for(Run.depth)
	var cells: Array = trap["cells"].duplicate()
	cells.shuffle()
	var heroes := get_tree().get_nodes_in_group("player")
	var n := rng.randi_range(10, 15)
	for cell: Array in cells:
		if n <= 0:
			break
		var pos := Vector2(cell[0] * TILE + TILE / 2.0, cell[1] * TILE + TILE - 2)
		var near := false
		for h in heroes:
			if h.global_position.distance_to(pos) < 40.0:
				near = true
		if near:
			continue
		var e: Node2D = SPAWNS[_pick_monster(rng, pool)].instantiate()
		e.position = pos
		entities.add_child(e)
		_trap_monsters.append(e)
		Game.burst(pos + Vector2(0, -6), Color(0.9, 0.3, 0.3), 8)
		n -= 1
	Game.banner("Ловушка! Выхода нет — бей всех", 2.5)
	Game.shake(4.0, 0.4)


func _trap_open() -> void:
	_trap_state = "done"
	var edits: Array = []
	for d: Array in trap["doors"]:
		var c := Vector2i(d[0], d[1])
		_floor_cell(c)
		astar.set_point_solid(c, false)
		edits.append([c.x, c.y, ".", false])
	Net.map_cells(edits)
	Game.banner("Ловушка пройдена — награда твоя", 2.5)


func _exit_tree() -> void:
	Game.set_darkness(false)
	Game.mod = ""


## Камера героя (своего — у гостя появляется позже карты): границы этажа.
func setup_camera(cam: Camera2D) -> void:
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = (rows[0] as String).length() * TILE if not rows.is_empty() else 10000
	cam.limit_bottom = rows.size() * TILE
	cam.reset_smoothing()


## Кооп, гость: хозяин изменил карту. cells: [[x, y, тайл, твёрдая?], ...]; лестница — [x, y, "S"].
func apply_cells(cells: Array) -> void:
	for c: Array in cells:
		var cell := Vector2i(c[0], c[1])
		if str(c[2]) == "S":
			map.set_cell(cell, 0, STAIRS)
			stairs_pos = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
			continue
		if c[3]:
			_wall_cell(cell)
		else:
			_floor_cell(cell)
		astar.set_point_solid(cell, c[3])


# ---------------- Арена босса ----------------
# Комната старта слева, коридор, большая арена с четырьмя колоннами (укрытия от плевков).
# Когда герой заходит в арену, проход закрывается; после победы — открывается и
# на месте босса появляется лестница.

## Этаж с боссом тоже из блоков: старт → 2–5 комнат (без монстров) → зал с порталом домой →
## арена из data/arenas.txt (два блока в ширину, у правого края), своя у каждого босса.
func _generate_boss(rng: RandomNumberGenerator) -> Array:
	var w := BLOCK_GRID_W * BLOCK
	var h := BLOCK_GRID_H * BLOCK
	var grid: Array = []
	for y in h:
		var line: Array = []
		line.resize(w)
		line.fill("#")
		grid.append(line)

	# Решение владельца: на этаже с боссом только три части — комната с порталом домой
	# (герой появляется в ней), коридор, арена босса (столбцы 3–4).
	var ay := rng.randi_range(0, BLOCK_GRID_H - 1)
	var room := Vector2i(1, ay)
	var corr := Vector2i(2, ay)
	var parts := [[room, "start", {"E": true}], [corr, "corridor", {"W": true, "E": true}]]
	for part: Array in parts:
		var c: Vector2i = part[0]
		var need: Dictionary = part[2]
		var v := _pick_variant(rng, part[1], need)
		var ox := c.x * BLOCK
		var oy := c.y * BLOCK
		for y in BLOCK:
			for x in BLOCK:
				var ch: String = v["rows"][y][x]
				var out := ch
				match ch:
					"D":
						out = "." if need.has(_door_side(x, y)) else "#"
					"M", "L", "S", "A":
						out = "."  # перед логовом тихо: ни монстров, ни лестницы
				grid[oy + y][ox + x] = out
	# Портал домой — в комнате, ближе к выходу в коридор (не на месте появления героя).
	_portal_cell = _open_cell_in(grid, room * BLOCK + Vector2i(BLOCK / 2 + 3, BLOCK / 2), Vector2i(3, 4))

	# Арена.
	var boss_id := Roster.kind_of(boss_for(Run.depth))
	var arena := Arenas.pick(rng, boss_id)
	arena_name = arena["name"]
	var ax := 3 * BLOCK
	var oy2 := ay * BLOCK
	for y in Arenas.H:
		for x in Arenas.W:
			var ch: String = arena["rows"][y][x]
			grid[oy2 + y][ax + x] = "." if ch == "D" else ch
	arena_rect = Rect2i(ax + 1, oy2 + 1, Arenas.W - 2, Arenas.H - 2)
	# Ворота — клетки входа (левый край арены): закрываются, когда босс проснулся.
	_gate_cells.clear()
	for y in range(Arenas.DOOR_LO, Arenas.DOOR_HI + 1):
		_gate_cells.append(Vector2i(ax, oy2 + y))
	var result: Array = []
	for line in grid:
		result.append("".join(line))
	return result


## Клетка пола поближе к center (в пределах half от него) — по ещё не построенной карте.
func _open_cell_in(grid: Array, center: Vector2i, half: Vector2i) -> Vector2i:
	var best := center
	var best_d := 1 << 30
	for y in range(center.y - half.y, center.y + half.y + 1):
		for x in range(center.x - half.x, center.x + half.x + 1):
			if grid[y][x] == "." and (Vector2i(x, y) - center).length_squared() < best_d:
				best = Vector2i(x, y)
				best_d = (Vector2i(x, y) - center).length_squared()
	return best


## Свободная клетка рядом с cell (по готовой карте поиска пути).
func _open_cell_near(cell: Vector2i) -> Vector2i:
	for r in 6:
		for y in range(cell.y - r, cell.y + r + 1):
			for x in range(cell.x - r, cell.x + r + 1):
				var c := Vector2i(x, y)
				if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
					return c
	return cell


## Точка рядом с pos, где можно стоять (если pos в стене или колонне).
func open_spot(pos: Vector2) -> Vector2:
	if is_open_at(pos):
		return pos
	var c := _open_cell_near(Vector2i(pos / TILE))
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE - 2)


## Можно ли стоять в точке (для боссов: телепорт, прыжки — не в колонну).
func is_open_at(pos: Vector2) -> bool:
	var c := Vector2i(pos / TILE)
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)


func _on_boss_woke() -> void:
	var edits: Array = []
	for c in _gate_cells:
		_wall_cell(c)
		astar.set_point_solid(c, true)
		edits.append([c.x, c.y, "#", true])
	Net.map_cells(edits)
	# Кооп: кто не успел зайти в арену — переносится внутрь, к воротам.
	var arena := Rect2(Vector2(arena_rect.position * TILE), Vector2(arena_rect.size * TILE))
	var inside := Vector2((arena_rect.position.x + 1) * TILE + TILE / 2.0, _center(arena_rect).y * TILE + TILE - 2)
	for h in get_tree().get_nodes_in_group("player"):
		if not arena.has_point(h.global_position):
			h.global_position = inside
	Game.shake(3.0, 0.3)


func _on_boss_died(boss: Node) -> void:
	var edits: Array = []
	for c in _gate_cells:
		_floor_cell(c)
		astar.set_point_solid(c, false)
		edits.append([c.x, c.y, ".", false])
	var cell := Vector2i(boss.global_position / TILE)
	if astar.is_point_solid(cell):
		cell = _open_cell_near(_center(arena_rect))
	# На последнем этаже (70-м) дальше идти некуда — только портал домой.
	var last := Run.depth >= MAX_DEPTH
	if not last:
		map.set_cell(cell, 0, STAIRS)
		stairs_pos = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
		edits.append([cell.x, cell.y, "S", false])
	Net.map_cells(edits)
	# Рядом — портал домой: вернуться в лагерь живым и сохранить снаряжение.
	var portal: Node2D = EXIT_PORTAL.new()
	var pcell := _open_cell_near(Vector2i(arena_rect.position.x + 4, _center(arena_rect).y))
	if pcell == cell:
		pcell = _open_cell_near(pcell + Vector2i(3, 0))
	portal.position = Vector2(pcell * TILE) + Vector2(TILE / 2.0, TILE - 2)
	entities.add_child(portal)
	Game.quest_progress("bosses")
	# Сохранение после каждого босса: следующий забег можно начать со следующего этажа.
	if not last:
		Game.checkpoint.call_deferred(Run.depth + 1)


# ---------------- Генерация из блоков ----------------
# Этаж = сетка ячеек BLOCK x BLOCK тайлов. Блуждание по сетке выбирает 7–10 ячеек и связи
# между ними (иногда с кольцами). В каждую ячейку ставится блок из data/blocks.txt
# (повёрнутый/отражённый), у которого есть проходы ко всем нужным соседям;
# лишние проходы замуровываются. Старт — блок "start", лестница — блок "exit" в самой
# дальней ячейке.

func _generate(rng: RandomNumberGenerator, depth: int) -> Array:
	var w := BLOCK_GRID_W * BLOCK
	var h := BLOCK_GRID_H * BLOCK
	var grid: Array = []
	for y in h:
		var line: Array = []
		line.resize(w)
		line.fill("#")
		grid.append(line)

	# 1. Блуждание по ячейкам.
	var start := Vector2i(rng.randi_range(0, BLOCK_GRID_W - 1), rng.randi_range(0, BLOCK_GRID_H - 1))
	var cells: Array[Vector2i] = [start]
	var edges: Array = []
	var target_count := rng.randi_range(7, 10)
	var cur := start
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var guard := 0
	while cells.size() < target_count and guard < 2000:
		guard += 1
		var nxt: Vector2i = cur + dirs[rng.randi() % 4]
		if nxt.x < 0 or nxt.y < 0 or nxt.x >= BLOCK_GRID_W or nxt.y >= BLOCK_GRID_H:
			continue
		if not cells.has(nxt):
			cells.append(nxt)
			edges.append([cur, nxt])
		cur = nxt
	for a in cells:
		for b in cells:
			if a < b and (a - b).length_squared() == 1 and not _has_edge(edges, a, b) and rng.randf() < 0.2:
				edges.append([a, b])

	# Какие проходы нужны каждой ячейке.
	var need := {}
	for c in cells:
		need[c] = {}
	for e in edges:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var d := b - a
		need[a][_side(d)] = true
		need[b][_side(-d)] = true

	# Самая дальняя ячейка (поиск в ширину) — там лестница.
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for e in edges:
			var n: Variant = e[1] if e[0] == c else (e[0] if e[1] == c else null)
			if n != null and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	var exit_cell := start
	for c in cells:
		if dist[c] > dist[exit_cell]:
			exit_cell = c

	# Кузня с наковальней — на половине этажей, в одной из промежуточных комнат.
	var forge_cell := Vector2i(-1, -1)
	var middle := cells.filter(func(c: Vector2i) -> bool: return c != start and c != exit_cell)
	if not middle.is_empty() and rng.randf() < 0.5:
		forge_cell = middle[rng.randi() % middle.size()]

	# Событие (алтарь, сундук, путник, фонтан) — на 40% обычных этажей, в промежуточной комнате.
	var event_cell := Vector2i(-1, -1)
	var mid2 := middle.filter(func(c: Vector2i) -> bool: return c != forge_cell)
	if depth >= 2 and not mid2.is_empty() and (rng.randf() < 0.4 or "--events" in OS.get_cmdline_user_args()):
		event_cell = mid2[rng.randi() % mid2.size()]
	# Комната-ловушка: приманка (фонтан или сундук) видна, но стоит войти — проходы закрываются
	# и появляется 10–15 монстров. На 25% обычных этажей со 2-го.
	var trap_cell := Vector2i(-1, -1)
	var mid3 := mid2.filter(func(c: Vector2i) -> bool: return c != event_cell)
	if depth >= 2 and not mid3.is_empty() and (rng.randf() < 0.25 or "--trap" in OS.get_cmdline_user_args()):
		trap_cell = mid3[rng.randi() % mid3.size()]
	trap = {}

	# 2. Блоки.
	var monsters: Array = monsters_for(depth)
	for c in cells:
		var tag := "start" if c == start else ("exit" if c == exit_cell else ("forge" if c == forge_cell else ""))
		var v := _pick_variant(rng, tag, need[c])
		var ox := c.x * BLOCK
		var oy := c.y * BLOCK
		var spots: Array[Vector2i] = []
		var floor_cells: Array[Vector2i] = []
		for y in BLOCK:
			for x in BLOCK:
				var ch: String = v["rows"][y][x]
				var out := ch
				match ch:
					"D":
						out = "." if need[c].has(_door_side(x, y)) else "#"
					"M":
						out = "."
						spots.append(Vector2i(ox + x, oy + y))
					"L":
						out = "."
				grid[oy + y][ox + x] = out
				if out == "." and x > 1 and y > 1 and x < BLOCK - 2 and y < BLOCK - 2:
					floor_cells.append(Vector2i(ox + x, oy + y))
		if c == trap_cell and not floor_cells.is_empty():
			var tc := Vector2i(ox + BLOCK / 2, oy + BLOCK / 2)
			var bait: Vector2i = floor_cells[0]
			for fc in floor_cells:
				if (fc - tc).length_squared() < (bait - tc).length_squared():
					bait = fc
			grid[bait.y][bait.x] = "?"
			var doors: Array = []
			for y in BLOCK:
				for x in BLOCK:
					var edge := x == 0 or y == 0 or x == BLOCK - 1 or y == BLOCK - 1
					if edge and grid[oy + y][ox + x] == ".":
						doors.append([ox + x, oy + y])
			trap = {"rect": [ox, oy, BLOCK, BLOCK], "doors": doors, "cells": floor_cells.map(func(v: Vector2i) -> Array: return [v.x, v.y])}
		if c == event_cell and not floor_cells.is_empty():
			var center := Vector2i(ox + BLOCK / 2, oy + BLOCK / 2)
			var best_c: Vector2i = floor_cells[0]
			for fc in floor_cells:
				if (fc - center).length_squared() < (best_c - center).length_squared():
					best_c = fc
			grid[best_c.y][best_c.x] = "!"
		# 3. Монстры: сначала на отмеченные места M, потом — на случайный пол.
		if c == start or c == trap_cell:
			continue  # в ловушке монстры появятся, когда войдёшь
		var count := mini(rng.randi_range(2, 3) + int(depth / 2.0), 6)
		if modifier == "horde":
			count = mini(int(count * 1.5), 9)
		if v["tag"] == "corridor":
			count = mini(count, 2)
		spots.shuffle()
		floor_cells.shuffle()
		for p in spots + floor_cells:
			if count <= 0:
				break
			if grid[p.y][p.x] == ".":
				grid[p.y][p.x] = _pick_monster(rng, monsters)
				count -= 1

	var result: Array = []
	for line in grid:
		result.append("".join(line))
	return result


## Случайный блок с нужным тегом (или любой обычный), повёрнутый так, чтобы были все нужные проходы.
func _pick_variant(rng: RandomNumberGenerator, tag: String, needed: Dictionary) -> Dictionary:
	var pool: Array = Blocks.with_tag(tag) if tag != "" else Blocks.all().filter(
		func(b: Dictionary) -> bool: return b["tag"] == "room" or b["tag"] == "corridor")
	var options := []
	for b: Dictionary in pool:
		for v: Dictionary in b["variants"]:
			var ok := true
			for side: String in needed:
				if not v["doors"].has(side):
					ok = false
					break
			if ok:
				options.append({"rows": v["rows"], "tag": b["tag"], "name": b["name"]})
	if options.is_empty():
		push_error("Нет блока для проходов %s (тег «%s»)" % [needed.keys(), tag])
		return {"rows": Blocks.all()[0]["rows"], "tag": "room", "name": "?"}
	return options[rng.randi() % options.size()]


static func _side(d: Vector2i) -> String:
	if d == Vector2i.RIGHT:
		return "E"
	if d == Vector2i.LEFT:
		return "W"
	if d == Vector2i.UP:
		return "N"
	return "S"


static func _door_side(x: int, y: int) -> String:
	if y == 0:
		return "N"
	if y == BLOCK - 1:
		return "S"
	if x == 0:
		return "W"
	return "E"

func _has_edge(edges: Array, a: Vector2i, b: Vector2i) -> bool:
	for e in edges:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return true
	return false


func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


func _fill(grid: Array, r: Rect2i, ch: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			grid[y][x] = ch


func _carve_h(grid: Array, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2) - CORRIDOR_HALF, maxi(x1, x2) + CORRIDOR_HALF + 1):
		for dy in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
			_set_floor(grid, x, y + dy)


func _carve_v(grid: Array, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2) - CORRIDOR_HALF, maxi(y1, y2) + CORRIDOR_HALF + 1):
		for dx in range(-CORRIDOR_HALF, CORRIDOR_HALF + 1):
			_set_floor(grid, x + dx, y)


func _set_floor(grid: Array, x: int, y: int) -> void:
	# Крайние ряды карты всегда остаются стеной.
	if y > 0 and x > 0 and y < grid.size() - 1 and x < grid[0].size() - 1:
		grid[y][x] = "."


# ---------------- Постройка ----------------

func _build(map_rows: Array, guest := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var h := map_rows.size()
	var w: int = (map_rows[0] as String).length()

	_find_columns(map_rows)
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for y in h:
		var row: String = map_rows[y]
		for x in w:
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "#":
				if _cave_style() and _cols.has(cell):
					# Колонна: под ней обычный пол (без дыр вокруг), твёрдость — у плитки-двойника.
					map.set_cell(cell, 1, Vector2i(posmod(x, 4), posmod(y, 4)), 1)
				elif _cave_style():
					map.set_cell(cell, 1, Vector2i(posmod(x, 4), 4 + posmod(y, 4)))
				else:
					var below_is_floor := y + 1 < h and (map_rows[y + 1] as String)[x] != "#"
					map.set_cell(cell, 0, WALL_FACE if below_is_floor else WALL_TOP)
				astar.set_point_solid(cell, true)
				continue
			if ch == "S":
				map.set_cell(cell, 0, STAIRS)
			else:
				var r := rng.randf()
				var v: Vector2i = FLOOR_VARIANTS[0] if r < 0.7 else (FLOOR_VARIANTS[1] if r < 0.85 else FLOOR_VARIANTS[2])
				if _cave_style():
					_floor_cell(cell)
				else:
					map.set_cell(cell, 0, v)
			var spot := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE - 2)
			if guest:
				if ch == "S":
					stairs_pos = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
				elif ch == "A":
					astar.set_point_solid(cell, true)
				continue
			match ch:
				"P":
					player.position = spot
				"S":
					stairs_pos = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
				"?":
					# Приманка комнаты-ловушки: фонтан или честный сундук.
					var bait_ev: Node2D = FLOOR_EVENT.new()
					bait_ev.kind = "fountain" if rng.randf() < 0.5 else "chest"
					bait_ev.bait = true
					bait_ev.position = spot
					entities.add_child(bait_ev)
				"!":
					var ev: Node2D = FLOOR_EVENT.new()
					ev.kind = FLOOR_EVENT.KINDS[rng.randi() % FLOOR_EVENT.KINDS.size()]
					for a: String in OS.get_cmdline_user_args():
						if a.begins_with("--event="):
							ev.kind = a.get_slice("=", 1)
					ev.position = spot
					entities.add_child(ev)
				"A":
					var anvil: Node2D = ANVIL.new()
					anvil.position = spot
					entities.add_child(anvil)
					astar.set_point_solid(cell, true)
				_:
					if SPAWNS.has(ch) or ch == "B":
						var e: Node2D = Roster.make(boss_for(Run.depth), Run.depth) if ch == "B" else SPAWNS[ch].instantiate()
						# Элитный монстр: с 3-го этажа, шанс растёт с глубиной.
						if ch != "B" and Run.depth >= 3 and (rng.randf() < 0.08 + 0.002 * Run.depth or "--elites" in OS.get_cmdline_user_args()):
							e.elite = true
							e.elite_kind = ELITE_KINDS.keys()[rng.randi() % ELITE_KINDS.size()]
						if ch == "B" and "--weakboss" in OS.get_cmdline_user_args():
							e.hp_mult = 0.08  # тест: быстро пройти логово и проверить лестницу дальше
						e.position = spot
						if ch == "B":
							e.arena = Rect2(Vector2(arena_rect.position * TILE), Vector2(arena_rect.size * TILE))
							e.woke.connect(_on_boss_woke)
							e.died.connect(_on_boss_died)
						entities.add_child(e)

	if guest:
		return
	# Портал у входа в логово: последний шанс вернуться в лагерь с добычей, не рискуя боем.
	if is_boss_floor:
		var portal: Node2D = EXIT_PORTAL.new()
		var pcell := _portal_cell
		portal.position = Vector2(pcell * TILE) + Vector2(TILE / 2.0, TILE - 2)
		entities.add_child(portal)
		astar.set_point_solid(pcell, true)

	setup_camera(player.get_node("Camera"))


## Отладка: сохранить карту этажа картинкой (1 тайл = 4x4 пикселя).
func _dump_map(map_rows: Array, path: String) -> void:
	var colors := {"#": Color8(25, 22, 32), ".": Color8(120, 112, 135), "P": Color.CYAN, "S": Color.YELLOW,
		"s": Color.GREEN, "w": Color.MEDIUM_PURPLE, "b": Color.PLUM, "x": Color.WHITE, "m": Color.RED}
	var h := map_rows.size()
	var w: int = (map_rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, colors.get(map_rows[y][x], Color.ORANGE))
	img.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	img.save_png(ProjectSettings.globalize_path(path))
	print("map saved: " + path)


func is_near_stairs(pos: Vector2) -> bool:
	return pos.distance_to(stairs_pos) < 12.0


## Путь по полу (центры тайлов) от одной точки до другой — для бота и будущих монстров.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := Vector2i(from / TILE)
	var b := Vector2i(to / TILE)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return PackedVector2Array()
	var pts := astar.get_point_path(a, b, true)
	for i in pts.size():
		pts[i] += Vector2(TILE / 2.0, TILE / 2.0)
	return pts


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = CAVE_TEX if _cave_style() else TILES_TEX
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for x in 6:
		src.create_tile(Vector2i(x, 0))

	var half := TILE / 2.0
	# Пещера: большой бесшовный пол и скала (источник 1) — сетка тайлов не видна.
	if _cave_style():
		var big := TileSetAtlasSource.new()
		big.texture = load(_style()["floor"])
		big.texture_region_size = Vector2i(TILE, TILE)
		ts.add_source(big, 1)
		for y in 8:
			for x in 4:
				big.create_tile(Vector2i(x, y))
				var td: TileData
				if y >= 4:  # скала — твёрдая
					td = big.get_tile_data(Vector2i(x, y), 0)
				else:       # двойник пола с твёрдостью — под колоннами
					var alt := big.create_alternative_tile(Vector2i(x, y))
					td = big.get_tile_data(Vector2i(x, y), alt)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for wall in [WALL_TOP, WALL_FACE]:
		var data := src.get_tile_data(wall, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
	return ts
