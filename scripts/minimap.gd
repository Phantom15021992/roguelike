extends Control
## Карта этажа с туманом войны. Открывается по мере исследования (герой видит REVEAL клеток вокруг).
## Маленькая — в правом верхнем углу (участок вокруг героя), большая — по клавише M, весь этаж.
## Метки: герой, лестница, наковальня, порталы, босс — только там, где уже побывал.

const REVEAL := 6              # радиус обзора в клетках
const MINI_SIZE := Vector2(60, 40)
const MINI_POS := Vector2(256, 24)
const BIG_SCALE := 2.0         # базовых пикселей на клетку на большой карте
const FLOOR_C := Color(0.55, 0.52, 0.62, 0.92)
const WALL_C := Color(0.18, 0.16, 0.24, 0.92)
const STAIRS_C := Color(1.0, 0.85, 0.3)
const BOSS_C := Color(1.0, 0.3, 0.3)

var big := false
var _dungeon: Node
var _w := 0
var _h := 0
var _explored := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _last_cell := Vector2i(-999, -999)
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mode(false)


func _set_mode(is_big: bool) -> void:
	big = is_big
	if big:
		position = Vector2.ZERO
		size = Vector2(320, 180)
	else:
		position = MINI_POS
		size = MINI_SIZE
	queue_redraw()


func toggle() -> void:
	_set_mode(not big)


func _init_map() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.get("rows") == null or (scene.rows as Array).is_empty():
		return false
	_dungeon = scene
	_h = scene.rows.size()
	_w = (scene.rows[0] as String).length()
	_explored.resize(_w * _h)
	_explored.fill(0)
	_img = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	return true


func _process(delta: float) -> void:
	_t += delta
	if _dungeon == null or not is_instance_valid(_dungeon):
		if not _init_map():
			visible = false
			return
	visible = true
	var p: Node2D = Game.local_hero()
	if p == null:
		return
	var cell := Vector2i(p.global_position / 16.0)
	if cell != _last_cell:
		_last_cell = cell
		_reveal(cell)
	queue_redraw()


## Открыть клетки вокруг героя: пол и стены, граничащие с полом.
func _reveal(center: Vector2i) -> void:
	var changed := false
	for dy in range(-REVEAL - 1, REVEAL + 2):
		for dx in range(-REVEAL - 1, REVEAL + 2):
			var c := center + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
				continue
			if Vector2(dx, dy).length() > REVEAL + 0.5:
				continue
			var i := c.y * _w + c.x
			if _explored[i] == 1:
				continue
			_explored[i] = 1
			changed = true
			var ch: String = _dungeon.rows[c.y][c.x]
			if ch != "#":
				_img.set_pixelv(c, FLOOR_C)
			elif _touches_floor(c):
				_img.set_pixelv(c, WALL_C)
	if changed:
		_tex.update(_img)


func _touches_floor(c: Vector2i) -> bool:
	for o in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var n: Vector2i = c + o
		if n.x >= 0 and n.y >= 0 and n.x < _w and n.y < _h and _dungeon.rows[n.y][n.x] != "#":
			return true
	return false


func is_explored(world_pos: Vector2) -> bool:
	var c := Vector2i(world_pos / 16.0)
	if c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return false
	return _explored[c.y * _w + c.x] == 1


func _draw() -> void:
	if _tex == null or _last_cell.x < -100:
		return
	if big:
		_draw_big()
	else:
		_draw_mini()


func _draw_mini() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.08, 0.75))
	# Участок карты вокруг героя, 1 клетка = 1 базовый пиксель.
	var src := Rect2(Vector2(_last_cell) - size / 2.0, size)
	var clipped := src.intersection(Rect2(0, 0, _w, _h))
	if clipped.size.x > 0 and clipped.size.y > 0:
		draw_texture_rect_region(_tex, Rect2(clipped.position - src.position, clipped.size), clipped)
	_draw_markers(func(world: Vector2) -> Vector2: return world / 16.0 - src.position, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.45, 0.6), false, 1.0)


func _draw_big() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.05, 0.95))
	var map_size := Vector2(_w, _h) * BIG_SCALE
	var origin := ((size - map_size) / 2.0).round()
	draw_texture_rect(_tex, Rect2(origin, map_size), false)
	draw_rect(Rect2(origin - Vector2(1, 1), map_size + Vector2(2, 2)), Color(0.5, 0.45, 0.6), false, 1.0)
	_draw_markers(func(world: Vector2) -> Vector2: return origin + world / 16.0 * BIG_SCALE, BIG_SCALE)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(origin.x, origin.y - 3), "Карта этажа %d" % Run.depth, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
	# Легенда: цветной квадратик + подпись.
	var x := origin.x
	var y := origin.y + map_size.y + 8
	var legend := [["M — закрыть", Color(0, 0, 0, 0)], ["ты", Color(0.4, 1.0, 1.0)], ["лестница", STAIRS_C],
		["наковальня", Color(1.0, 0.55, 0.2)], ["портал", Color(0.75, 0.5, 1.0)], ["босс", BOSS_C]]
	for e in legend:
		var c: Color = e[1]
		if c.a > 0.0:
			draw_rect(Rect2(x, y - 4, 3, 3), c)
			x += 5
		draw_string(font, Vector2(x, y), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.75, 0.72, 0.8))
		x += font.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x + 8


## Метки. to_map переводит мировые координаты в координаты рисования.
func _draw_markers(to_map: Callable, s: float) -> void:
	var r := maxf(1.0, s)
	# Лестница.
	if _dungeon.get("stairs_pos") != null and is_explored(_dungeon.stairs_pos):
		_dot(to_map.call(_dungeon.stairs_pos), r + 0.5, STAIRS_C)
	# Наковальни и порталы.
	for n in get_tree().get_nodes_in_group("interactables"):
		if n.has_method("map_color") and is_explored(n.global_position):
			_dot(to_map.call(n.global_position), r + 0.5, n.map_color())
	# Босс.
	for b in get_tree().get_nodes_in_group("boss"):
		if not b.dead and is_explored(b.global_position):
			_dot(to_map.call(b.global_position), r + 1.0, BOSS_C)
	# Герой — мигает.
	var p: Node2D = Game.local_hero()
	if p:
		var blink := 0.6 + 0.4 * sin(_t * 8.0)
		_dot(to_map.call(p.global_position), r + 0.5, Color(0.4, 1.0, 1.0, blink))


func _dot(pos: Vector2, radius: float, color: Color) -> void:
	if pos.x < -2 or pos.y < -2 or pos.x > size.x + 2 or pos.y > size.y + 2:
		return
	draw_rect(Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color)
