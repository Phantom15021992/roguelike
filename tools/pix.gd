extends RefCounted
## Набор кисточек для пиксель-арта монстров (используют tools/gen_monsters.gd и gen_bosses.gd).
## Рисуем в кадр img размером fs x fs; координаты — в «единицах 24-пиксельного кадра»,
## умножаются на k (для боссов 48 px k = 2: формы те же, но крупнее и глаже).
## Стиль по референсам владельца: чиби, объём тремя-четырьмя тонами (свет сверху-слева),
## тёмная обводка, светящиеся глаза.

const OUT := Color8(20, 14, 28)

var img: Image
var fs := 24
var k := 1.0


func begin(size: int) -> void:
	fs = size
	k = size / 24.0
	img = Image.create(fs, fs, false, Image.FORMAT_RGBA8)


## Палитра из одного цвета: [свет, основной, тень, глубокая тень].
static func pal(c: Color) -> Array:
	return [c.lightened(0.32), c, c.darkened(0.32), c.darkened(0.58)]


func px(x: float, y: float, c: Color) -> void:
	var ix := int(floor(x * k))
	var iy := int(floor(y * k))
	var n := maxi(1, int(round(k)))
	for dy in n:
		for dx in n:
			_put(ix + dx, iy + dy, c)


## Пиксель в настоящих координатах кадра (для тонких деталей у боссов).
func _put(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < fs and y < fs:
		if c.a >= 1.0:
			img.set_pixel(x, y, c)
		elif c.a > 0.0:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	for iy in range(int(floor(y * k)), int(ceil((y + h) * k))):
		for ix in range(int(floor(x * k)), int(ceil((x + w) * k))):
			_put(ix, iy, c)


func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var x0 := int(floor((cx - rx) * k)) - 1
	var x1 := int(ceil((cx + rx) * k)) + 1
	var y0 := int(floor((cy - ry) * k)) - 1
	var y1 := int(ceil((cy + ry) * k)) + 1
	for iy in range(y0, y1):
		for ix in range(x0, x1):
			var nx := ((ix + 0.5) / k - cx) / rx
			var ny := ((iy + 0.5) / k - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				_put(ix, iy, c)


## Объёмный шар: свет сверху-слева, 4 тона.
func ball(cx: float, cy: float, rx: float, ry: float, p: Array, glossy := false) -> void:
	var x0 := int(floor((cx - rx) * k)) - 1
	var x1 := int(ceil((cx + rx) * k)) + 1
	var y0 := int(floor((cy - ry) * k)) - 1
	var y1 := int(ceil((cy + ry) * k)) + 1
	for iy in range(y0, y1):
		for ix in range(x0, x1):
			var nx := ((ix + 0.5) / k - cx) / rx
			var ny := ((iy + 0.5) / k - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var nz := sqrt(1.0 - d)
			var l := -0.5 * nx - 0.62 * ny + 0.6 * nz
			var c: Color = p[1]
			if l > 0.78:
				c = p[0]
			elif l < -0.05:
				c = p[3]
			elif l < 0.32:
				c = p[2]
			_put(ix, iy, c)
	if glossy:
		ell(cx - rx * 0.38, cy - ry * 0.45, maxf(0.8, rx * 0.22), maxf(0.6, ry * 0.15), (p[0] as Color).lightened(0.5))


## Заливка многоугольника.
func poly(pts: PackedVector2Array, c: Color) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var sp := PackedVector2Array()
	for p in pts:
		sp.append(p * k)
	for iy in range(int(floor(r.position.y * k)) - 1, int(ceil(r.end.y * k)) + 1):
		for ix in range(int(floor(r.position.x * k)) - 1, int(ceil(r.end.x * k)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(ix + 0.5, iy + 0.5), sp):
				_put(ix, iy, c)


## Многоугольник с объёмом: сверху-слева светлее, снизу-справа темнее.
func spoly(pts: PackedVector2Array, p: Array) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	var sp := PackedVector2Array()
	for q in pts:
		sp.append(q * k)
	var w := maxf(1.0, r.size.x)
	var h := maxf(1.0, r.size.y)
	for iy in range(int(floor(r.position.y * k)) - 1, int(ceil(r.end.y * k)) + 1):
		for ix in range(int(floor(r.position.x * k)) - 1, int(ceil(r.end.x * k)) + 1):
			if not Geometry2D.is_point_in_polygon(Vector2(ix + 0.5, iy + 0.5), sp):
				continue
			var t := (((ix + 0.5) / k - r.position.x) / w) * 0.45 + (((iy + 0.5) / k - r.position.y) / h) * 0.55
			var c: Color = p[0] if t < 0.22 else (p[1] if t < 0.6 else (p[2] if t < 0.85 else p[3]))
			_put(ix, iy, c)


func line(a: Vector2, b: Vector2, c: Color, w := 1.0) -> void:
	var n := int(ceil(a.distance_to(b) * k * 1.5)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if w <= 1.0:
			_put(int(floor(p.x * k)), int(floor(p.y * k)), c)
		else:
			ell(p.x, p.y, w * 0.5, w * 0.5, c)


## Глаза: вниз — два, вбок — один ближе к краю, вверх — нет. style: "dot" (точка со светом),
## "glow" (светящиеся), "cute" (большие тёмные с бликом).
func eyes(cx: float, cy: float, gap: float, dir: int, c: Color, style := "glow") -> void:
	if dir == 2:
		return
	var xs: Array = [cx - gap, cx + gap] if dir == 0 else [cx + gap * 1.3]
	for x: float in xs:
		match style:
			"cute":
				rect(x - 1, cy - 1, 2, 3, c)
				px(x - 1, cy - 1, Color.WHITE)
			"dot":
				rect(x - 0.5, cy - 0.5, 1, 1, c)
			_:
				rect(x - 1, cy - 0.5, 2, 1.5, c)
				px(x - 1 + (1 if dir == 1 else 0), cy - 0.5, c.lightened(0.6))


## Тёмная обводка вокруг всех непрозрачных пикселей.
func outline(col := OUT) -> void:
	var add: Array = []
	for y in fs:
		for x in fs:
			if img.get_pixel(x, y).a > 0.1:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < fs and q.y < fs and img.get_pixel(q.x, q.y).a > 0.5:
					add.append(Vector2i(x, y))
					break
	for p: Vector2i in add:
		img.set_pixelv(p, col)


## Отражение кадра по горизонтали (для «вбок» нарисованного влево и т.п.).
func flip() -> void:
	img.flip_x()
