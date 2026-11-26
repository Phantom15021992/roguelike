extends Node2D
## Неровные края скал в пещере: поверх стыков «скала — пол» рисуются рваные каменные кромки,
## чтобы контур скал не шёл ровно по клеткам. Чисто картинка (без столкновений); расклад
## зависит только от карты — у гостей в коопе такой же.
##   — бока и верх скальной массы: выступ на 2–6 px в сторону пола + светлая кромка;
##   — подножие обрыва: неровная тень и камешки;
##   — верх обрыва: наплывы тёмной породы на светлую кромку;
##   — внутренние углы пола: скругление.

const TILE := 16
const ROCK := Color8(15, 14, 29)
const ROCK_EDGE := Color8(30, 30, 54)
const RIM := Color8(74, 84, 130)
const SHADOW := Color8(12, 11, 24, 170)
const PEBBLE := Color8(70, 76, 112)

var rows: Array = []


func _is_wall(x: int, y: int) -> bool:
	if y < 0 or y >= rows.size():
		return true
	var r: String = rows[y]
	return x < 0 or x >= r.length() or r[x] == "#"


## Детерминированный «шум» 0..1 по клетке и номеру.
func _n(x: int, y: int, i: int) -> float:
	var h := hash(Vector3i(x, y, i))
	return float(h & 1023) / 1023.0


func _draw() -> void:
	for y in rows.size():
		for x in (rows[y] as String).length():
			if _is_wall(x, y):
				_wall_edges(x, y)
			else:
				_floor_corners(x, y)


func _wall_edges(x: int, y: int) -> void:
	var ox := x * TILE
	var oy := y * TILE
	var face := not _is_wall(x, y + 1)   # обрыв: под скалой пол
	# Бок скалы слева/справа (пол рядом): выступ в сторону пола.
	if not _is_wall(x - 1, y):
		_lip(Vector2(ox, oy), Vector2(ox, oy + TILE), Vector2(-1, 0), x, y, 0, not face)
	if not _is_wall(x + 1, y):
		_lip(Vector2(ox + TILE, oy), Vector2(ox + TILE, oy + TILE), Vector2(1, 0), x, y, 1, not face)
	# Верх скалы, над которым пол (задняя кромка массива).
	if not _is_wall(x, y - 1):
		_lip(Vector2(ox, oy), Vector2(ox + TILE, oy), Vector2(0, -1), x, y, 2, true)
	if face:
		# Подножие обрыва: неровная тень на полу и камешки.
		var pts := PackedVector2Array([Vector2(ox, oy + TILE)])
		for k in 5:
			pts.append(Vector2(ox + k * 4, oy + TILE + 1 + int(_n(x, y, 10 + k) * 4.0)))
		pts.append(Vector2(ox + TILE, oy + TILE))
		draw_colored_polygon(pts, SHADOW)
		if _n(x, y, 20) < 0.45:
			var px := ox + 2 + int(_n(x, y, 21) * 11.0)
			draw_rect(Rect2(px, oy + TILE + 1, 2, 2), PEBBLE)
			draw_rect(Rect2(px, oy + TILE + 3, 2, 1), SHADOW)
		# Верх обрыва: рваная кромка тёмной породы, наползающая на стенку (если сверху скала).
		if _is_wall(x, y - 1):
			_lip(Vector2(ox, oy), Vector2(ox + TILE, oy), Vector2(0, 1), x, y, 3, true, 1.0, 3.0)


## Рваный выступ скалы вдоль ребра a→b в сторону out (наружу, на пол).
func _lip(a: Vector2, b: Vector2, out: Vector2, x: int, y: int, side: int, rim: bool, dmin := 2.0, drange := 4.0) -> void:
	var pts := PackedVector2Array()
	var steps := 4
	var edge: Array = []
	for k in steps + 1:
		var t := float(k) / steps
		var p := a.lerp(b, t)
		# Концы ребра — без выступа (стыкуются с соседями), середина — 2..6 px.
		var depth := 0.0 if k == 0 or k == steps else dmin + _n(x, y, side * 10 + k) * drange
		edge.append(p + out * round(depth))
	pts.append(a)
	for p: Vector2 in edge:
		pts.append(p)
	pts.append(b)
	draw_colored_polygon(pts, ROCK)
	# Чуть светлее у самого края — объём выступа.
	for k in range(1, edge.size()):
		draw_line(edge[k - 1], edge[k], ROCK_EDGE, 2.0)
	if rim:
		for k in range(1, edge.size()):
			draw_line(edge[k - 1], edge[k], RIM, 1.0)


## Внутренний угол пола (скала с двух соседних сторон) — скругление.
func _floor_corners(x: int, y: int) -> void:
	var ox := x * TILE
	var oy := y * TILE
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var dx: int = c[0]
		var dy: int = c[1]
		if _is_wall(x + dx, y) and _is_wall(x, y + dy):
			var cx := ox + (0 if dx < 0 else TILE)
			var cy := oy + (0 if dy < 0 else TILE)
			var r := 5.0 + _n(x, y, 60 + dx + dy * 2) * 3.0
			draw_colored_polygon(_corner(cx, cy, dx, dy, r), ROCK)


## Угол между двумя стенами: область между вершиной угла и дугой радиуса r (выпуклая к полу).
func _corner(cx: float, cy: float, dx: int, dy: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(cx, cy)])
	# Центр дуги — внутри пола на расстоянии r по обеим осям.
	var centre := Vector2(cx - dx * r, cy - dy * r)
	for k in 9:
		var a := float(k) / 8.0 * PI / 2.0
		# Точки дуги от стены по X до стены по Y, обращённые к углу.
		pts.append(centre + Vector2(dx * r * cos(a), dy * r * sin(a)))
	return pts
