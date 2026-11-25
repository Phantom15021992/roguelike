extends Node2D
## Этаж подземелья: собирает этаж из блоков (data/blocks.txt), расставляет героя, монстров
## и лестницу. Каждый 3-й этаж — отдельная арена с боссом.
##
## Символы карты: '#' стена, '.' пол, 'P' герой, 'S' лестница, 'B' босс,
## монстры: 's' слизень, 'w' дух, 'b' мышь, 'x' скелет, 'm' гриб.

const TILE := 16
const TILES_TEX := preload("res://assets/tiles.png")
const Blocks := preload("res://scripts/blocks.gd")
const ANVIL := preload("res://scripts/anvil.gd")
const EXIT_PORTAL := preload("res://scripts/exit_portal.gd")

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
}
# Боссы по очереди: 3-й этаж — Король слизней, 6-й — Повелитель костей, 9-й — снова король...
const BOSSES := [
	preload("res://scenes/boss_slime.tscn"),
	preload("res://scenes/bone_lord.tscn"),
	preload("res://scenes/ember_titan.tscn"),
]

# Наборы монстров по глубине: [символ, вес]. Этажи 4+ — Катакомбы.
const POOLS := [
	{"from": 1, "name": "", "tint": Color(1, 1, 1), "monsters": [["s", 6], ["b", 2], ["w", 2]]},
	{"from": 2, "name": "", "tint": Color(1, 1, 1), "monsters": [["s", 5], ["b", 2], ["w", 2], ["m", 1]]},
	{"from": 4, "name": "Катакомбы", "tint": Color(0.82, 0.86, 1.0), "monsters": [["x", 4], ["b", 2], ["w", 2], ["m", 2], ["s", 1]]},
	{"from": 7, "name": "Огненные пещеры", "tint": Color(1.0, 0.8, 0.68), "monsters": [["i", 3], ["z", 3], ["o", 2], ["b", 1], ["x", 1]]},
]


static func pool_for(depth: int) -> Dictionary:
	var result: Dictionary = POOLS[0]
	for p: Dictionary in POOLS:
		if depth >= p["from"]:
			result = p
	return result


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

const BOSS_EVERY := 3  # каждый 3-й этаж — арена с боссом
# Арена босса (в тайлах) и комната старта перед ней.
const BOSS_START := Rect2i(4, 14, 10, 8)
const BOSS_ARENA := Rect2i(26, 9, 24, 16)

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
	is_boss_floor = Run.depth % BOSS_EVERY == 0
	if "--autotest" in OS.get_cmdline_user_args():
		print("floor %d seed %d%s" % [Run.depth, rng.seed, " (BOSS)" if is_boss_floor else ""])
	rows = _generate_boss() if is_boss_floor else _generate(rng, Run.depth)
	_build(rows)
	if "--mapdump" in OS.get_cmdline_user_args():
		_dump_map(rows, "res://shots/map_floor%d_%d.png" % [Run.depth, randi() % 1000])
		print("anvil on floor: %s" % ("".join(rows).contains("A")))
	map.modulate = pool_for(Run.depth)["tint"]
	Game.spawn_guest_heroes()
	Net.scene_loaded()


## Кооп, гость: карта — из присланной хозяином, монстров и предметы пришлёт он же.
func _ready_guest() -> void:
	var d: Dictionary = Net.scene_data
	is_boss_floor = d.get("boss", false)
	_gate_cells.clear()
	for c: Vector2i in d.get("gate", []):
		_gate_cells.append(c)
	rows = d["rows"]
	entities.remove_child(player)
	player.queue_free()
	_build(rows, true)
	map.modulate = pool_for(Run.depth)["tint"]
	Net.scene_loaded()


## Кооп, хозяин: что прислать гостям для этой сцены.
func net_scene() -> Dictionary:
	return {"kind": "dungeon", "rows": rows, "depth": Run.depth, "boss": is_boss_floor, "gate": _gate_cells}


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
		map.set_cell(cell, 0, WALL_FACE if c[3] else FLOOR_VARIANTS[0])
		astar.set_point_solid(cell, c[3])


# ---------------- Арена босса ----------------
# Комната старта слева, коридор, большая арена с четырьмя колоннами (укрытия от плевков).
# Когда герой заходит в арену, проход закрывается; после победы — открывается и
# на месте босса появляется лестница.

func _generate_boss() -> Array:
	var w := GRID_W * CELL_W
	var h := GRID_H * CELL_H
	var grid: Array = []
	for y in h:
		var line: Array = []
		line.resize(w)
		line.fill("#")
		grid.append(line)
	_fill(grid, BOSS_START, ".")
	_fill(grid, BOSS_ARENA, ".")
	var a := _center(BOSS_START)
	var b := _center(BOSS_ARENA)
	_carve_h(grid, a.x, b.x, b.y)
	for pos in [Vector2i(4, 3), Vector2i(18, 3), Vector2i(4, 11), Vector2i(18, 11)]:
		_fill(grid, Rect2i(BOSS_ARENA.position + pos, Vector2i(2, 2)), "#")
	grid[a.y][a.x] = "P"
	grid[b.y][b.x] = "B"
	# Ворота — клетки коридора сразу перед ареной.
	_gate_cells.clear()
	for y in range(b.y - CORRIDOR_HALF, b.y + CORRIDOR_HALF + 1):
		_gate_cells.append(Vector2i(BOSS_ARENA.position.x - 1, y))
	var result: Array = []
	for line in grid:
		result.append("".join(line))
	return result


func _on_boss_woke() -> void:
	var edits: Array = []
	for c in _gate_cells:
		map.set_cell(c, 0, WALL_FACE)
		astar.set_point_solid(c, true)
		edits.append([c.x, c.y, "#", true])
	Net.map_cells(edits)
	# Кооп: кто не успел зайти в арену — переносится внутрь, к воротам.
	var arena := Rect2(Vector2(BOSS_ARENA.position * TILE), Vector2(BOSS_ARENA.size * TILE))
	var inside := Vector2((BOSS_ARENA.position.x + 1) * TILE + TILE / 2.0, _center(BOSS_ARENA).y * TILE + TILE - 2)
	for h in get_tree().get_nodes_in_group("player"):
		if not arena.has_point(h.global_position):
			h.global_position = inside
	Game.shake(3.0, 0.3)


func _on_boss_died(boss: Node) -> void:
	var edits: Array = []
	for c in _gate_cells:
		map.set_cell(c, 0, FLOOR_VARIANTS[0])
		astar.set_point_solid(c, false)
		edits.append([c.x, c.y, ".", false])
	var cell := Vector2i(boss.global_position / TILE)
	if astar.is_point_solid(cell):
		cell = Vector2i(_center(BOSS_ARENA))
	map.set_cell(cell, 0, STAIRS)
	stairs_pos = Vector2(cell * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
	edits.append([cell.x, cell.y, "S", false])
	Net.map_cells(edits)
	# Рядом — портал домой: вернуться в лагерь живым и сохранить снаряжение.
	var portal: Node2D = EXIT_PORTAL.new()
	var pcell := Vector2i(BOSS_ARENA.position.x + 5, _center(BOSS_ARENA).y)
	if pcell == cell:
		pcell.x += 3
	portal.position = Vector2(pcell * TILE) + Vector2(TILE / 2.0, TILE - 2)
	entities.add_child(portal)
	Game.banner("Лестница вниз — или портал домой", 3.0)


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

	# 2. Блоки.
	var monsters: Array = pool_for(depth)["monsters"]
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
		# 3. Монстры: сначала на отмеченные места M, потом — на случайный пол.
		if c == start:
			continue
		var count := mini(rng.randi_range(2, 3) + int(depth / 2.0), 6)
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
				var below_is_floor := y + 1 < h and (map_rows[y + 1] as String)[x] != "#"
				map.set_cell(cell, 0, WALL_FACE if below_is_floor else WALL_TOP)
				astar.set_point_solid(cell, true)
				continue
			if ch == "S":
				map.set_cell(cell, 0, STAIRS)
			else:
				var r := rng.randf()
				var v: Vector2i = FLOOR_VARIANTS[0] if r < 0.7 else (FLOOR_VARIANTS[1] if r < 0.85 else FLOOR_VARIANTS[2])
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
				"A":
					var anvil: Node2D = ANVIL.new()
					anvil.position = spot
					entities.add_child(anvil)
					astar.set_point_solid(cell, true)
				_:
					if SPAWNS.has(ch) or ch == "B":
						var scene: PackedScene = BOSSES[(Run.depth / BOSS_EVERY - 1) % BOSSES.size()] if ch == "B" else SPAWNS[ch]
						var e: Node2D = scene.instantiate()
						e.position = spot
						if ch == "B":
							e.arena = Rect2(Vector2(BOSS_ARENA.position * TILE), Vector2(BOSS_ARENA.size * TILE))
							e.woke.connect(_on_boss_woke)
							e.died.connect(_on_boss_died)
						entities.add_child(e)

	if guest:
		return
	# Портал у входа в логово: последний шанс вернуться в лагерь с добычей, не рискуя боем.
	if is_boss_floor:
		var portal: Node2D = EXIT_PORTAL.new()
		var pcell := BOSS_START.position + Vector2i(2, 3)
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
	src.texture = TILES_TEX
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for x in 6:
		src.create_tile(Vector2i(x, 0))

	var half := TILE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for wall in [WALL_TOP, WALL_FACE]:
		var data := src.get_tile_data(wall, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
	return ts
