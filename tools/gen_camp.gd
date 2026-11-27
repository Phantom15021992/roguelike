extends SceneTree
## Графика лагеря-деревни в стиле референсов владельца (уютная деревня: фахверк, черепица,
## мостовая, сочная зелень, густой лес по краям). Детализация двойная: 2 пикселя картинки
## на 1 пиксель мира (в игре спрайты уменьшены вдвое).
##
##   godot --headless --path . --script res://tools/gen_camp.gd
## Выход (assets/camp/): ground.png — вся земля лагеря с лесом и тенями;
##   b_<постройка>.png — постройки (низ картинки = линия основания + PAD), x_<постройка>.png — леса
##   (стройка, когда постройка не построена); p_<мелочь>.png — фонтан, фонари, бочки, деревья…;
##   glow.png — мягкое пятно света.

const LAY := preload("res://scripts/camp_layout.gd")
const PAD := 6            # пикселей картинки под линией основания (ступеньки, тень)
const CELL := 32          # клетка в пикселях картинки
const OUT := Color8(40, 26, 30)

var errors := 0
var shadow_mask := PackedByteArray()
var GW := 0
var GH := 0
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()


class Cv:
	var img: Image
	var w := 0
	var h := 0

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	func put(x: int, y: int, c: Color) -> void:
		if x < 0 or y < 0 or x >= w or y >= h:
			return
		if c.a >= 0.999:
			img.set_pixel(x, y, c)
		elif c.a > 0.0:
			var d := img.get_pixel(x, y)
			if d.a <= 0.0:
				img.set_pixel(x, y, c)
			else:
				img.set_pixel(x, y, d.blend(c))

	func at(x: int, y: int) -> Color:
		if x < 0 or y < 0 or x >= w or y >= h:
			return Color(0, 0, 0, 0)
		return img.get_pixel(x, y)

	func rect(x: float, y: float, rw: float, rh: float, c: Color) -> void:
		for iy in range(int(floor(y)), int(ceil(y + rh))):
			for ix in range(int(floor(x)), int(ceil(x + rw))):
				put(ix, iy, c)

	func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		for iy in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 1):
			for ix in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 1):
				var nx := (ix + 0.5 - cx) / rx
				var ny := (iy + 0.5 - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					put(ix, iy, c)

	func poly(pts: PackedVector2Array, c: Color) -> void:
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		for iy in range(int(floor(r.position.y)) - 1, int(ceil(r.end.y)) + 1):
			for ix in range(int(floor(r.position.x)) - 1, int(ceil(r.end.x)) + 1):
				if Geometry2D.is_point_in_polygon(Vector2(ix + 0.5, iy + 0.5), pts):
					put(ix, iy, c)

	func line(a: Vector2, b: Vector2, c: Color, t := 1) -> void:
		var n := int(ceil(a.distance_to(b))) + 1
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			for dy in t:
				for dx in t:
					put(int(floor(p.x)) + dx, int(floor(p.y)) + dy, c)

	## Затемнить (или осветлить при k < 0) уже нарисованное.
	func shade(x: int, y: int, k: float) -> void:
		var d := at(x, y)
		if d.a <= 0.0:
			return
		img.set_pixel(x, y, d.darkened(k) if k > 0.0 else d.lightened(-k))

	## Тёмная обводка вокруг непрозрачного.
	func outline(col: Color) -> void:
		var add: Array[Vector2i] = []
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > 0.3:
					continue
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixel(q.x, q.y).a > 0.9:
						add.append(Vector2i(x, y))
						break
		for p: Vector2i in add:
			img.set_pixelv(p, col)


static func tones(c: Color) -> Array:
	return [c.lightened(0.22), c, c.darkened(0.2), c.darkened(0.42)]


static func hh(x: int, y: int, i: int) -> int:
	return hash(Vector3i(x, y, i)) & 1023


func _init() -> void:
	noise.seed = 11
	noise.frequency = 0.012
	noise2.seed = 23
	noise2.frequency = 0.05
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/camp"))
	GW = LAY.W * CELL
	GH = LAY.H * CELL
	shadow_mask.resize(GW * GH)
	_glow()
	var arts := {}
	for id: String in LAY.BUILDINGS:
		var cv: Cv = call("_b_" + id)
		_save(cv.img, "res://assets/camp/b_%s.png" % id)
		arts[id] = cv
		if id in ["training", "library", "forge", "infirmary", "treasury", "mine", "storage", "workshop"]:
			_save(_scaffold(cv).img, "res://assets/camp/x_%s.png" % id)
		var at: Vector2 = LAY.BUILDINGS[id]["at"]
		_cast(cv, at * CELL)
	var props := {}
	for name: String in ["fountain", "lamp", "bench", "dummy", "target", "anvil", "barrels", "crates", "hay", "cart", "pot", "sign", "tree", "bush", "flowers"]:
		var cv: Cv = call("_p_" + name)
		_save(cv.img, "res://assets/camp/p_%s.png" % name)
		props[name] = cv
	for p: Array in LAY.PROPS:
		if p[0] in ["flowers", "pot"]:
			continue
		_cast(props[p[0]], (p[1] as Vector2) * CELL)
	_ground()
	print("gen_camp: done, errors=%d" % errors)
	quit(1 if errors else 0)


func _save(img: Image, path: String) -> void:
	if img.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("cannot save " + path)
		errors += 1
	else:
		print("saved ", path)


## Тень от картинки на землю: свет сверху-слева, тень ложится вправо-вверх (за постройку и вбок).
func _cast(cv: Cv, base: Vector2) -> void:
	var by := cv.h - PAD
	for y in by:
		for x in cv.w:
			if cv.img.get_pixel(x, y).a < 0.5:
				continue
			var hgt := float(by - y)
			var gx := int(base.x - cv.w / 2.0 + x + hgt * 0.55)
			var gy := int(base.y - hgt * 0.32)
			for dy in 2:
				for dx in 2:
					var qx := gx + dx
					var qy := gy + dy
					if qx >= 0 and qy >= 0 and qx < GW and qy < GH:
						shadow_mask[qy * GW + qx] = 1


func _glow() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_save(img, "res://assets/camp/glow.png")


# ===================================================================================
#                                    ЗЕМЛЯ
# ===================================================================================

## Бесшовная плитка мостовой (вороной на торе): камни, швы, свет сверху-слева.
func _cobble_tile(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var pts: Array[Vector2] = []
	var cols: Array[Color] = []
	var step := 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var base := Color8(178, 162, 130)
	for gy in size / step:
		for gx in size / step:
			pts.append(Vector2(gx * step + (step / 2.0 if gy % 2 == 1 else 0.0) + rng.randf_range(-2, 2), gy * step + rng.randf_range(-1.5, 1.5) + step / 2.0))
			var v := rng.randf()
			var c := base.darkened(rng.randf_range(-0.04, 0.1))
			if v < 0.18:
				c = Color8(160, 154, 140).darkened(rng.randf_range(0.0, 0.12))
			elif v < 0.3:
				c = Color8(186, 150, 112).darkened(rng.randf_range(0.0, 0.1))
			cols.append(c)
	var mortar := Color8(132, 118, 96)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var i1 := 0
			var n1 := Vector2.ZERO
			for i in pts.size():
				for ox: float in [-size, 0.0, size]:
					for oy: float in [-size, 0.0, size]:
						var q: Vector2 = pts[i] + Vector2(ox, oy)
						if absf(q.x - p.x) > 14 or absf(q.y - p.y) > 14:
							continue
						var d := p.distance_to(q)
						if d < d1:
							d2 = d1
							d1 = d
							i1 = i
							n1 = q
						elif d < d2:
							d2 = d
			var edge := (d2 - d1) * 0.5
			var c: Color = cols[i1]
			var dir := (p - n1).normalized()
			if edge < 0.9:
				c = mortar
			elif edge < 2.0:
				var lit := dir.dot(Vector2(-0.7, -0.7))
				if lit > 0.3:
					c = c.lightened(0.08)
				elif lit < -0.3:
					c = c.darkened(0.12)
			elif hh(x, y, 3) < 40:
				c = c.darkened(0.08)
			img.set_pixel(x, y, c)
	return img


func _ground() -> void:
	var cob := _cobble_tile(126)
	var g := Cv.new(GW, GH)
	var grass := [Color8(74, 126, 58), Color8(92, 148, 64), Color8(112, 166, 72), Color8(136, 184, 82)]
	var dirt := [Color8(132, 104, 74), Color8(150, 120, 86), Color8(168, 138, 100)]
	var flowers := [Color8(240, 220, 110), Color8(236, 120, 140), Color8(250, 250, 240), Color8(150, 150, 236), Color8(240, 150, 80)]
	for y in GH:
		for x in GW:
			var n := noise.get_noise_2d(x, y)
			var wx := noise2.get_noise_2d(x, y) * 0.22
			var wy := noise2.get_noise_2d(x + 999, y) * 0.22
			var fx := x / float(CELL) + wx
			var fy := y / float(CELL) + wy
			var k := LAY.kind_at(fx, fy)
			var c: Color
			match k:
				LAY.STONE:
					c = cob.get_pixel(x % 126, y % 126)
					if n > 0.35:
						c = c.darkened((n - 0.35) * 0.3)
					# Вытоптанные места с травой посреди мостовой.
					var wn := noise2.get_noise_2d(x * 0.35 + 500, y * 0.35)
					if wn > 0.42 and hh(x / 2, y / 2, 17) < 700:
						c = grass[1 + hh(x, y, 18) % 2]
					elif wn > 0.34 and hh(x / 2, y / 2, 19) < 260:
						c = grass[0]
					# Трава пробивается у краёв мостовой.
					var k2 := LAY.kind_at(fx + 0.12, fy + 0.12)
					var k3 := LAY.kind_at(fx - 0.12, fy - 0.12)
					if (k2 == LAY.GRASS or k3 == LAY.GRASS) and hh(x / 2, y / 2, 4) < 420:
						c = grass[1 + hh(x, y, 5) % 2]
					elif hh(x / 3, y / 3, 9) < 6:
						c = grass[0]
				LAY.DIRT:
					var t := clampi(int((n + 0.5) * 3.0), 0, 2)
					c = dirt[t]
					if hh(x, y, 6) < 14:
						c = Color8(110, 86, 62)
					elif hh(x / 2, y / 2, 7) < 10:
						c = Color8(186, 168, 140)
				LAY.WATER:
					c = _water(x, y)
				LAY.FOREST:
					c = Color8(30, 56, 38) if hh(x / 2, y / 2, 8) > 200 else Color8(38, 70, 44)
				_:
					var t := clampi(int((n + 0.6) * 2.6), 0, 2)
					c = grass[t + 1] if hh(x / 2, y, 10) < 900 else grass[t]
					# Травинки: короткие штрихи.
					var s := hh(x, y / 3, 11)
					if s < 60:
						c = grass[0]
					elif s > 1000:
						c = grass[3]
					# Цветочки.
					var f := hh(x / 2, y / 2, 12)
					if f < 3 and n < 0.1:
						c = flowers[hh(x / 2, y / 2, 13) % flowers.size()]
			if shadow_mask[y * GW + x] == 1:
				c = Color(c.r * 0.66, c.g * 0.68, c.b * 0.8)
			g.img.set_pixel(x, y, c)
	_forest(g)
	_save(g.img, "res://assets/camp/ground.png")


func _water(x: int, y: int) -> Color:
	var fx := x / float(CELL)
	var fy := y / float(CELL)
	var d := Vector2((fx - LAY.POND.x) / LAY.POND_R.x, (fy - LAY.POND.y) / LAY.POND_R.y).length()
	if d > 0.86:
		# Берег: светлые камни и мокрый песок.
		var s := hh(x / 4, y / 3, 14)
		return Color8(150, 146, 134) if s < 500 else Color8(120, 116, 106)
	var c := Color8(56, 118, 176) if d < 0.6 else Color8(72, 140, 196)
	if d > 0.78:
		c = Color8(98, 170, 210)
	var r := sin(x * 0.18 + sin(y * 0.3) * 2.0 + y * 0.55)
	if r > 0.93:
		c = Color8(150, 206, 236)
	if hh(x, y, 15) < 3:
		c = Color8(230, 246, 255)
	# Кувшинки.
	for lp: Vector2 in [Vector2(36.6, 16.4), Vector2(39.4, 17.9), Vector2(37.7, 18.4)]:
		if Vector2(fx, fy).distance_to(lp) < 0.24:
			c = Color8(80, 150, 70) if hh(x, y, 16) < 900 else Color8(240, 160, 190)
	return c


## Густой лес по краям: кроны деревьев одна за другой (сверху вниз).
func _forest(g: Cv) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var spots: Array[Vector2] = []
	var step := 30
	for gy in range(-1, GH / step + 2):
		for gx in range(-1, GW / step + 2):
			var p := Vector2(gx * step + rng.randf_range(-9, 9) + (step / 2.0 if gy % 2 == 1 else 0.0), gy * step + rng.randf_range(-8, 8))
			var c := LAY.kind_at(p.x / CELL, (p.y - 6) / CELL)
			if c == LAY.FOREST:
				spots.append(p)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for p: Vector2 in spots:
		var big := 20.0 + rng.randf() * 8.0
		_canopy(g, p.x, p.y - big * 0.4, big, rng.randi(), true)


# ===================================================================================
#                                  КИСТОЧКИ
# ===================================================================================

const LEAF := [Color8(150, 196, 84), Color8(104, 160, 64), Color8(66, 118, 50), Color8(40, 80, 40)]


## Крона из нескольких шаров листвы.
func _canopy(cv: Cv, cx: float, cy: float, r: float, seed_: int, dark := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var balls: Array = []
	balls.append([cx, cy, r])
	for i in 5:
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(0.45, 0.7)
		balls.append([cx + cos(a) * d, cy + sin(a) * d * 0.8, r * rng.randf_range(0.45, 0.62)])
	balls.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) + float(a[2]) * 0.3 < float(b[1]) + float(b[2]) * 0.3)
	var pal: Array = LEAF.duplicate()
	if dark:
		pal = [LEAF[1].darkened(0.08), LEAF[2], LEAF[3], Color8(26, 52, 32)]
	for b: Array in balls:
		_leaf_ball(cv, b[0], b[1], b[2], pal, seed_)


func _leaf_ball(cv: Cv, cx: float, cy: float, r: float, pal: Array, s: int) -> void:
	for iy in range(int(cy - r) - 1, int(cy + r) + 2):
		for ix in range(int(cx - r) - 1, int(cx + r) + 2):
			var nx := (ix + 0.5 - cx) / r
			var ny := (iy + 0.5 - cy) / r
			# Неровный край — лиственные зубчики.
			var jag := 1.0 - (hh(ix / 2, iy / 2, s & 255) % 100) * 0.0016
			var d := nx * nx + ny * ny
			if d > jag:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d))
			var l := -0.5 * nx - 0.65 * ny + 0.55 * nz
			# Листья: пятнышки 2x2 сдвигают тон.
			l += (hh(ix / 2, iy / 2, 21) % 100 - 50) * 0.006
			var c: Color = pal[1]
			if l > 0.72:
				c = pal[0]
			elif l < -0.1:
				c = pal[3]
			elif l < 0.3:
				c = pal[2]
			if d > 0.86 * jag and l < 0.5:
				c = pal[3]
			cv.put(ix, iy, c)


## Камни-кирпичи: ряды высотой rh, ширина камней разная.
func _stones(cv: Cv, x0: int, y0: int, w: int, h: int, col: Color, rh := 7, seed_ := 1) -> void:
	var p := tones(col)
	var mortar: Color = col.darkened(0.45)
	for y in h:
		var row := y / rh
		var ry := y % rh
		for x in w:
			var off := (row * 7 + seed_ * 3) % 13
			var sx := (x + off)
			# ширина камня 10–16
			var idx := sx / 12
			var within := sx % 12
			var c: Color = p[1]
			var v := hh(idx, row, seed_) % 4
			if v == 0:
				c = p[0].darkened(0.08)
			elif v == 3:
				c = p[2]
			if ry == rh - 1 or within == 0:
				c = mortar
			elif ry == 0:
				c = c.lightened(0.12)
			elif ry == rh - 2 or within == 11:
				c = c.darkened(0.14)
			cv.put(x0 + x, y0 + y, c)


## Стена с фахверком: штукатурка + деревянные балки.
func _timber(cv: Cv, x0: int, y0: int, w: int, h: int, plaster: Color, wood: Color, floors := 1) -> void:
	for y in h:
		for x in w:
			var c := plaster
			var s := hh(x / 2, y / 2, 30)
			if s < 60:
				c = plaster.darkened(0.06)
			elif s > 1000:
				c = plaster.lightened(0.05)
			cv.put(x0 + x, y0 + y, c)
	# Потрескавшаяся штукатурка — кирпичи проглядывают.
	var rng := RandomNumberGenerator.new()
	rng.seed = x0 * 7 + y0
	for i in 2:
		var bx := x0 + rng.randi_range(10, w - 24)
		var by := y0 + rng.randi_range(8, h - 18)
		for yy in 8:
			for xx in 12:
				if absf(xx - 6) + absf(yy - 4) * 1.4 < 7:
					var c := Color8(170, 96, 72) if (yy % 4 != 3 and (xx + (yy / 4) * 3) % 6 != 0) else Color8(120, 70, 56)
					cv.put(bx + xx, by + yy, c)
	var wp := tones(wood)
	var beam := func(bx: int, by: int, bw: int, bh: int) -> void:
		cv.rect(bx, by, bw, bh, wp[1])
		cv.rect(bx, by, bw, 1, wp[0])
		cv.rect(bx, by + bh - 1, bw, 1, wp[3])
	var bvert := func(bx: int, by: int, bw: int, bh: int) -> void:
		cv.rect(bx, by, bw, bh, wp[1])
		cv.rect(bx, by, 1, bh, wp[0])
		cv.rect(bx + bw - 1, by, 1, bh, wp[3])
	beam.call(x0, y0, w, 5)
	beam.call(x0, y0 + h - 5, w, 5)
	var fh := h / floors
	for f in range(1, floors):
		beam.call(x0, y0 + f * fh - 2, w, 5)
	var posts := maxi(2, w / 40 + 1)
	for i in posts + 1:
		var px := x0 + int(float(w - 6) * i / posts)
		bvert.call(px, y0, 6, h)
	# Раскосы в крайних пролётах.
	for f in floors:
		var top := y0 + f * fh + 4
		var bot := y0 + (f + 1) * fh - 4
		var pw := (w - 6) / posts
		cv.line(Vector2(x0 + 6, bot), Vector2(x0 + pw, top), wp[2], 3)
		cv.line(Vector2(x0 + w - 6, bot), Vector2(x0 + w - pw, top), wp[2], 3)


## Стена из досок.
func _planks(cv: Cv, x0: int, y0: int, w: int, h: int, wood: Color) -> void:
	var p := tones(wood)
	for y in h:
		for x in w:
			var i := x / 7
			var c: Color = p[1] if i % 2 == 0 else p[1].darkened(0.07)
			if x % 7 == 0:
				c = p[3]
			elif x % 7 == 1:
				c = p[0].darkened(0.05)
			if hh(i, y / 3, 31) < 12:
				c = p[2]
			cv.put(x0 + x, y0 + y, c)


## Каменное основание внизу стены.
func _footing(cv: Cv, x0: int, base: int, w: int, col := Color8(126, 122, 116)) -> void:
	_stones(cv, x0 - 2, base - 8, w + 4, 8, col, 4, 9)


## Крыша скатом к зрителю (вальмовая): ряды черепицы, светлый левый край, тёмный правый.
## kind: tile | slate | thatch. Возвращает y низа крыши (свес).
func _roof(cv: Cv, x0: int, y0: int, w: int, h: int, col: Color, inset: int, kind := "tile", moss := 0.0) -> void:
	var p := tones(col)
	var rw := 9 if kind == "tile" else 7
	var rh := 7 if kind != "thatch" else 5
	for y in h:
		var t := float(y) / h
		var l := x0 + inset * (1.0 - t)
		var r := x0 + w - inset * (1.0 - t)
		for x in range(int(ceil(l)), int(floor(r))):
			var c: Color = p[1]
			var row := y / rh
			var ry := y % rh
			if kind == "thatch":
				var s := hh(x, row, 40) % 7
				c = p[1] if s < 3 else (p[0] if s < 5 else p[2])
				if ry == rh - 1 and hh(x / 2, row, 41) % 3 != 0:
					c = p[3]
			else:
				var off := (row % 2) * (rw / 2)
				var sx := (x - x0 + off) % rw
				var id := (x - x0 + off) / rw
				var v := hh(id, row, 42) % 5
				if v == 0:
					c = c.lightened(0.07)
				elif v == 4:
					c = c.darkened(0.08)
				if ry == 0:
					c = c.lightened(0.14)
				if ry >= rh - 2:
					c = p[2]
				if ry == rh - 1:
					c = p[3]
				if sx == 0 and ry < rh - 1:
					c = p[2].darkened(0.1)
				if ry >= rh - 2 and (sx == 0 or sx == rw - 1):
					c = p[3]
				if moss > 0.0 and hh(x / 3, y / 3, 43) < int(moss * 1023.0):
					c = Color8(108, 150, 70) if hh(x, y, 44) < 600 else Color8(84, 124, 60)
			# Свет слева.
			var g := float(x - x0) / w - 0.5
			if g > 0.0:
				c = c.darkened(g * 0.22)
			else:
				c = c.lightened(-g * 0.1)
			var dl := x - l
			var dr := r - x
			if dl < 3.5:
				c = p[0] if dl < 2.0 else c.lightened(0.12)
			elif dr < 3.5:
				c = p[3] if dr < 2.0 else c.darkened(0.15)
			cv.put(x, y0 + y, c)
	# Конёк.
	cv.rect(x0 + inset - 2, y0 - 3, w - inset * 2 + 4, 4, p[2])
	cv.rect(x0 + inset - 2, y0 - 3, w - inset * 2 + 4, 1, p[0])
	for i in range(0, w - inset * 2 + 4, 6):
		cv.put(x0 + inset - 2 + i, y0, p[3])
	# Свес и доска-карниз.
	cv.rect(x0, y0 + h, w, 3, Color8(70, 44, 34))
	cv.rect(x0, y0 + h, w, 1, Color8(110, 72, 52))


## Тень от свеса на стене.
func _eave_shadow(cv: Cv, x0: int, y: int, w: int, depth := 6) -> void:
	for yy in depth:
		for x in w:
			cv.shade(x0 + x, y + yy, 0.28 * (1.0 - float(yy) / depth) + 0.06)


## Слуховое окно-фронтон на скате крыши.
func _gable(cv: Cv, cx: int, base: int, gw: int, gh: int, roof: Color, wall: Color, wood: Color, round_win := false) -> void:
	var half := gw / 2
	# Стена фронтона.
	for y in gh:
		var span := int(half * float(y) / gh)
		for x in range(-span, span + 1):
			var c := wall if hh(x / 2, y / 2, 50) > 60 else wall.darkened(0.06)
			cv.put(cx + x, base - gh + y, c)
	var wp := tones(wood)
	cv.rect(cx - half, base - 4, gw, 4, wp[1])
	cv.rect(cx - 2, base - gh + 6, 4, gh - 8, wp[2])
	# Окошко.
	if round_win:
		cv.ell(cx, base - gh * 0.45, 7, 7, wp[3])
		cv.ell(cx, base - gh * 0.45, 5, 5, Color8(70, 96, 150))
		cv.put(cx - 2, int(base - gh * 0.45) - 2, Color8(200, 226, 250))
		cv.put(cx - 1, int(base - gh * 0.45) - 3, Color8(200, 226, 250))
	else:
		_window(cv, cx - 8, base - gh / 2 - 8, 16, 16, wood, false)
	# Скаты фронтона.
	var rp := tones(roof)
	for i in gh + 6:
		var y := base - gh - 5 + i
		var xo := int(half * float(i - 5) / gh) + 1
		for t in 7:
			var c: Color = rp[1] if (i + t) % 6 != 0 else rp[3]
			if t == 0:
				c = rp[0]
			if t == 6:
				c = rp[3]
			cv.put(cx - xo - t + 3, y, c.lightened(0.05))
			cv.put(cx + xo + t - 3, y, c.darkened(0.12))
	cv.rect(cx - 3, base - gh - 7, 6, 4, rp[2])


func _window(cv: Cv, x: int, y: int, ww: int, wh: int, wood: Color, box := true, shutters := Color(0, 0, 0, 0), arch := false) -> void:
	var wp := tones(wood)
	cv.rect(x - 2, y - 2, ww + 4, wh + 4, wp[3])
	cv.rect(x - 1, y - 1, ww + 2, wh + 2, wp[1])
	for yy in wh:
		for xx in ww:
			if arch and yy < ww / 2:
				var dx := xx - ww / 2.0 + 0.5
				var dy := ww / 2.0 - yy
				if dx * dx + dy * dy > (ww / 2.0) * (ww / 2.0):
					cv.put(x + xx, y + yy, wp[1])
					continue
			var t := float(yy) / wh
			var c := Color8(46, 62, 104).lerp(Color8(96, 140, 190), t * 0.8)
			if (xx + yy) % 11 < 2 and xx + yy < ww:
				c = Color8(190, 220, 245)
			# Тёплый свет внутри.
			if yy > wh * 0.55 and hh(xx / 3, yy / 3, x) < 200:
				c = Color8(236, 190, 110)
			cv.put(x + xx, y + yy, c)
	cv.rect(x + ww / 2 - 1, y, 2, wh, wp[2])
	cv.rect(x, y + wh / 2 - 1, ww, 2, wp[2])
	cv.rect(x - 3, y - 3, ww + 6, 2, wp[0])
	if shutters.a > 0.0:
		var sp := tones(shutters)
		for s: int in [-1, 1]:
			var sx := x - 9 if s < 0 else x + ww + 3
			cv.rect(sx, y - 1, 6, wh + 2, sp[1])
			cv.rect(sx, y - 1, 6, 1, sp[0])
			for k in range(2, wh, 4):
				cv.rect(sx + 1, y + k, 4, 1, sp[3])
	if box:
		_flowerbox(cv, x - 3, y + wh + 2, ww + 6)


func _flowerbox(cv: Cv, x: int, y: int, w: int) -> void:
	cv.rect(x, y, w, 5, Color8(110, 70, 46))
	cv.rect(x, y, w, 1, Color8(150, 100, 64))
	cv.rect(x, y + 4, w, 1, Color8(70, 44, 32))
	var cols := [Color8(236, 96, 110), Color8(250, 210, 90), Color8(250, 250, 240), Color8(220, 120, 210)]
	for i in range(1, w - 1, 3):
		var lh := 2 + hh(i, y, 60) % 3
		cv.rect(x + i, y - lh, 2, lh, LEAF[1] if i % 2 == 0 else LEAF[2])
		if hh(i, x, 61) % 3 == 0:
			cv.rect(x + i, y - lh - 2, 2, 2, cols[hh(i, y, 62) % cols.size()])
	# Плющ свисает.
	for i in range(2, w - 2, 7):
		var l := 2 + hh(i, x, 63) % 5
		for k in l:
			cv.put(x + i + (k % 2), y + 5 + k, LEAF[2] if k % 3 != 0 else LEAF[1])


func _door(cv: Cv, cx: int, base: int, dw: int, dh: int, wood: Color, arch := true, studs := false) -> void:
	var wp := tones(wood)
	var x0 := cx - dw / 2
	var y0 := base - dh
	# Проём и рамка.
	for yy in dh + 3:
		for xx in dw + 6:
			var px := x0 - 3 + xx
			var py := y0 - 3 + yy
			if arch and yy < dw / 2 + 3:
				var dx := xx - (dw + 6) / 2.0 + 0.5
				var dy := (dw + 6) / 2.0 - yy
				if dx * dx + dy * dy > ((dw + 6) / 2.0) * ((dw + 6) / 2.0):
					continue
			cv.put(px, py, Color8(110, 104, 96) if (xx + yy) % 5 != 0 else Color8(86, 80, 74))
	for yy in dh:
		for xx in dw:
			if arch and yy < dw / 2:
				var dx := xx - dw / 2.0 + 0.5
				var dy := dw / 2.0 - yy
				if dx * dx + dy * dy > (dw / 2.0) * (dw / 2.0):
					continue
			var c: Color = wp[1] if (xx / 5) % 2 == 0 else wp[1].darkened(0.08)
			if xx % 5 == 0:
				c = wp[3]
			elif xx % 5 == 1:
				c = wp[0].darkened(0.08)
			cv.put(x0 + xx, y0 + yy, c)
	# Железные полосы и ручка.
	for by: int in [y0 + dh / 3, y0 + dh * 2 / 3 + 2]:
		cv.rect(x0 + 1, by, dw - 2, 2, Color8(60, 58, 64))
		cv.rect(x0 + 1, by, dw - 2, 1, Color8(110, 108, 118))
		if studs:
			for sx in range(x0 + 3, x0 + dw - 2, 5):
				cv.put(sx, by + 1, Color8(200, 190, 140))
	cv.rect(x0 + dw - 7, y0 + dh / 2, 3, 3, Color8(220, 190, 90))
	cv.put(x0 + dw - 7, y0 + dh / 2, Color8(255, 240, 170))
	# Ступенька.
	cv.rect(x0 - 4, base, dw + 8, 3, Color8(150, 144, 132))
	cv.rect(x0 - 4, base, dw + 8, 1, Color8(190, 184, 170))
	cv.rect(x0 - 4, base + 3, dw + 8, 1, Color8(90, 84, 78))


func _chimney(cv: Cv, x: int, y: int, w: int, h: int, smoke := true) -> void:
	_stones(cv, x, y, w, h, Color8(140, 128, 118), 5, 3)
	for yy in h:
		cv.shade(x + w - 1, y + yy, 0.3)
		cv.shade(x + w - 2, y + yy, 0.2)
	cv.rect(x - 2, y - 3, w + 4, 4, Color8(96, 88, 84))
	cv.rect(x - 2, y - 3, w + 4, 1, Color8(150, 142, 134))
	cv.rect(x + 2, y - 2, w - 4, 2, Color8(30, 24, 24))
	if smoke:
		for i in 5:
			var sx := x + w / 2.0 + i * 3.0 + sin(i * 1.3) * 3.0
			var sy := y - 8.0 - i * 7.0
			var r := 3.0 + i * 1.1
			cv.ell(sx, sy, r, r * 0.85, Color(0.92, 0.92, 0.95, 0.55 - i * 0.08))
			cv.ell(sx - r * 0.3, sy - r * 0.3, r * 0.5, r * 0.4, Color(1, 1, 1, 0.35 - i * 0.05))


## Вывеска на кронштейне: доска с картинкой.
func _sign(cv: Cv, x: int, y: int, icon: String, board := Color8(140, 94, 58), right := true) -> void:
	var dir := 1 if right else -1
	cv.rect(x if right else x - 16, y, 16, 2, Color8(50, 44, 48))
	cv.put(x + dir * 2, y + 2, Color8(50, 44, 48))
	var bx := x + dir * 3 if right else x - 19
	cv.line(Vector2(bx + 2, y + 2), Vector2(bx + 2, y + 5), Color8(70, 66, 70))
	cv.line(Vector2(bx + 14, y + 2), Vector2(bx + 14, y + 5), Color8(70, 66, 70))
	var bp := tones(board)
	cv.rect(bx - 1, y + 5, 18, 16, bp[3])
	cv.rect(bx, y + 6, 16, 14, bp[1])
	cv.rect(bx, y + 6, 16, 1, bp[0])
	_icon(cv, bx + 8, y + 13, icon)


func _icon(cv: Cv, cx: int, cy: int, icon: String) -> void:
	var gold := Color8(242, 200, 80)
	var iron := Color8(170, 176, 190)
	match icon:
		"book":
			cv.rect(cx - 5, cy - 4, 10, 8, Color8(70, 90, 170))
			cv.rect(cx - 4, cy - 3, 8, 6, Color8(236, 228, 200))
			cv.rect(cx, cy - 3, 1, 6, Color8(150, 140, 120))
		"hammer":
			cv.line(Vector2(cx - 3, cy + 4), Vector2(cx + 2, cy - 1), Color8(150, 100, 60), 2)
			cv.rect(cx, cy - 5, 6, 4, iron)
			cv.rect(cx, cy - 5, 6, 1, Color.WHITE)
		"cross":
			cv.rect(cx - 1, cy - 5, 3, 10, Color8(220, 50, 60))
			cv.rect(cx - 4, cy - 2, 9, 3, Color8(220, 50, 60))
		"coin":
			cv.ell(cx, cy, 5, 5, Color8(180, 130, 40))
			cv.ell(cx, cy, 4, 4, gold)
			cv.rect(cx - 1, cy - 2, 2, 4, Color8(180, 130, 40))
		"box":
			cv.rect(cx - 5, cy - 4, 10, 8, Color8(170, 120, 70))
			cv.rect(cx - 5, cy - 1, 10, 1, Color8(110, 74, 44))
			cv.rect(cx - 1, cy - 4, 1, 8, Color8(110, 74, 44))
		"gear":
			cv.ell(cx, cy, 5, 5, iron)
			for a in 8:
				var v := Vector2.from_angle(a * TAU / 8.0) * 5.5
				cv.rect(cx + v.x - 1, cy + v.y - 1, 2, 2, iron)
			cv.ell(cx, cy, 2, 2, Color8(80, 70, 60))
		"scales":
			cv.rect(cx, cy - 5, 1, 9, gold)
			cv.rect(cx - 5, cy - 4, 11, 1, gold)
			cv.ell(cx - 4, cy, 2.5, 1.5, gold)
			cv.ell(cx + 5, cy, 2.5, 1.5, gold)
			cv.rect(cx - 2, cy + 4, 5, 1, gold)
		"potion":
			cv.ell(cx, cy + 1, 4, 4, Color8(220, 70, 90))
			cv.rect(cx - 1, cy - 5, 3, 3, Color8(200, 220, 230))
			cv.put(cx - 2, cy - 1, Color.WHITE)


## Человечек-NPC (чиби, двойная детализация): roles — merchant | mentor | smith.
func _npc(cv: Cv, cx: int, base: int, robe: Color, hair: Color, role: String) -> void:
	var rp := tones(robe)
	# Тело.
	cv.poly(PackedVector2Array([Vector2(cx - 8, base), Vector2(cx + 8, base), Vector2(cx + 6, base - 18), Vector2(cx - 6, base - 18)]), rp[1])
	cv.rect(cx - 8, base - 2, 16, 2, rp[2])
	cv.rect(cx + 3, base - 18, 3, 16, rp[2])
	cv.rect(cx - 6, base - 18, 2, 14, rp[0])
	# Руки.
	cv.rect(cx - 9, base - 15, 3, 8, rp[2])
	cv.rect(cx + 6, base - 15, 3, 8, rp[2])
	cv.rect(cx - 9, base - 8, 3, 2, Color8(240, 196, 160))
	cv.rect(cx + 6, base - 8, 3, 2, Color8(240, 196, 160))
	# Голова.
	cv.ell(cx, base - 25, 8, 8, Color8(244, 204, 168))
	cv.rect(cx - 4, base - 25, 2, 3, Color8(40, 30, 36))
	cv.rect(cx + 2, base - 25, 2, 3, Color8(40, 30, 36))
	cv.put(cx - 4, base - 25, Color.WHITE)
	cv.put(cx + 2, base - 25, Color.WHITE)
	cv.rect(cx - 6, base - 21, 2, 1, Color8(240, 150, 140))
	cv.rect(cx + 4, base - 21, 2, 1, Color8(240, 150, 140))
	var hp := tones(hair)
	match role:
		"mentor":
			# Седая борода, капюшон, посох.
			cv.ell(cx, base - 18, 6, 6, Color8(226, 226, 230))
			cv.ell(cx, base - 17, 4, 4, Color8(250, 250, 250))
			cv.poly(PackedVector2Array([Vector2(cx - 10, base - 22), Vector2(cx, base - 38), Vector2(cx + 10, base - 22), Vector2(cx + 7, base - 28), Vector2(cx - 7, base - 28)]), rp[1])
			cv.rect(cx - 9, base - 30, 18, 4, rp[2])
			cv.rect(cx - 7, base - 30, 14, 1, rp[0])
			cv.rect(cx + 11, base - 40, 2, 40, Color8(120, 80, 50))
			cv.ell(cx + 12, base - 42, 3, 3, Color8(120, 220, 255))
			cv.put(cx + 11, base - 43, Color.WHITE)
		"merchant":
			cv.rect(cx - 8, base - 33, 16, 6, hp[1])
			cv.rect(cx - 8, base - 33, 16, 2, hp[0])
			cv.rect(cx - 9, base - 29, 4, 7, hp[2])
			cv.rect(cx + 5, base - 29, 4, 7, hp[2])
			# Шляпа.
			cv.rect(cx - 11, base - 33, 22, 3, Color8(110, 60, 44))
			cv.rect(cx - 7, base - 40, 14, 7, Color8(140, 76, 52))
			cv.rect(cx - 7, base - 36, 14, 2, Color8(230, 190, 80))
			cv.rect(cx - 5, base - 20, 10, 2, hp[2])
		_:
			cv.rect(cx - 8, base - 33, 16, 6, hp[1])
			cv.rect(cx - 8, base - 33, 16, 2, hp[0])


## Тень у основания картинки.
func _base_shadow(cv: Cv, cx: float, base: int, rx: float) -> void:
	cv.ell(cx, base + 1, rx, 4, Color(0.1, 0.08, 0.12, 0.35))


# ===================================================================================
#                                   ПОСТРОЙКИ
# ===================================================================================

## Дом: стена, крыша, основание. Возвращает холст и полезные величины.
func _house(cw: int, ch: int, body: int, wall_h: int, roof_h: int, inset: int, roof: Color, roof_kind: String, moss: float) -> Dictionary:
	var cv := Cv.new(cw, ch)
	var base := ch - PAD
	var x0 := (cw - body) / 2
	var wall_top := base - wall_h
	var roof_top := wall_top - roof_h
	_base_shadow(cv, cw / 2.0, base, body / 2.0 + 6)
	return {"cv": cv, "base": base, "x0": x0, "wall_top": wall_top, "roof_top": roof_top, "body": body,
		"roof": roof, "kind": roof_kind, "moss": moss, "inset": inset, "roof_h": roof_h}


func _put_roof(d: Dictionary, over := 8) -> void:
	var cv: Cv = d["cv"]
	_roof(cv, int(d["x0"]) - over, int(d["roof_top"]), int(d["body"]) + over * 2, int(d["roof_h"]), d["roof"], int(d["inset"]), d["kind"], d["moss"])


func _b_library() -> Cv:
	var d := _house(212, 216, 176, 100, 80, 20, Color8(66, 96, 168), "tile", 0.03)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	var wood := Color8(90, 56, 40)
	_chimney(cv, x0 + 22, int(d["roof_top"]) - 14, 14, 40)
	_timber(cv, x0, wt, 176, 100, Color8(232, 220, 192), wood, 2)
	_footing(cv, x0, base, 176)
	_put_roof(d)
	_eave_shadow(cv, x0, wt + 3, 176)
	_gable(cv, 106, wt + 2, 56, 40, Color8(66, 96, 168), Color8(232, 220, 192), wood, true)
	_door(cv, 106, base - 2, 26, 42, Color8(120, 70, 44), true)
	for wx: int in [x0 + 18, x0 + 50, x0 + 112, x0 + 144]:
		_window(cv, wx, base - 42, 16, 20, wood, true, Color8(60, 96, 150))
	for wx: int in [x0 + 20, x0 + 80, x0 + 140]:
		_window(cv, wx, wt + 16, 16, 22, wood, true, Color(0, 0, 0, 0), true)
	_sign(cv, x0 + 128, base - 70, "book", Color8(70, 100, 170))
	# Стопка книг и лампа у двери.
	for i in 3:
		cv.rect(80 + i, base - 6 - i * 3, 12, 3, [Color8(170, 60, 60), Color8(60, 120, 90), Color8(200, 160, 70)][i])
	return cv


func _b_forge() -> Cv:
	var d := _house(212, 196, 176, 66, 76, 16, Color8(150, 68, 52), "tile", 0.06)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	_stones(cv, x0, wt, 176, 66, Color8(132, 128, 124), 8, 2)
	_footing(cv, x0, base, 176, Color8(100, 96, 92))
	_put_roof(d)
	_chimney(cv, x0 + 128, int(d["roof_top"]) - 30, 22, 62)
	_eave_shadow(cv, x0, wt + 3, 176, 8)
	_door(cv, 106 - 28, base - 2, 26, 40, Color8(110, 64, 40), false, true)
	# Горн: открытая арка с огнём.
	var fx := x0 + 112
	var fy := base - 40
	for yy in 38:
		for xx in 44:
			var dx := xx - 21.5
			var dy := 22.0 - yy
			if yy < 22 and dx * dx + dy * dy > 22.0 * 22.0:
				continue
			cv.put(fx + xx, fy + yy, Color8(80, 74, 70) if (xx + yy * 3) % 7 != 0 else Color8(60, 56, 54))
	for yy in 32:
		for xx in 36:
			var dx := xx - 17.5
			var dy := 18.0 - yy
			if yy < 18 and dx * dx + dy * dy > 18.0 * 18.0:
				continue
			var t := float(yy) / 32.0
			var c := Color8(60, 24, 20).lerp(Color8(255, 150, 50), t)
			var fl := sin(xx * 0.7) * 3.0 + sin(xx * 1.9) * 2.0
			if yy > 18 - fl:
				c = Color8(255, 196, 80) if yy > 24 else Color8(240, 120, 40)
			if yy > 27 and hh(xx, yy, 70) < 500:
				c = Color8(255, 240, 170)
			cv.put(fx + 4 + xx, fy + 6 + yy, c)
	_sign(cv, x0 + 70, wt + 12, "hammer", Color8(110, 74, 50))
	_window(cv, x0 + 14, base - 40, 16, 18, Color8(90, 56, 40), false)
	# Ведро с водой, клещи.
	cv.ell(x0 + 104, base - 4, 7, 5, Color8(110, 70, 44))
	cv.ell(x0 + 104, base - 7, 6, 2, Color8(90, 150, 200))
	return cv


func _b_infirmary() -> Cv:
	var d := _house(180, 184, 148, 66, 72, 16, Color8(70, 142, 124), "tile", 0.02)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	var wood := Color8(116, 80, 58)
	_timber(cv, x0, wt, 148, 66, Color8(240, 238, 230), wood, 1)
	_footing(cv, x0, base, 148)
	_put_roof(d)
	_eave_shadow(cv, x0, wt + 3, 148)
	_gable(cv, 90, wt + 2, 50, 36, Color8(70, 142, 124), Color8(240, 238, 230), wood, false)
	# Красный крест на фронтоне вместо окна.
	cv.rect(86, wt - 26, 8, 20, Color8(250, 250, 250))
	cv.rect(80, wt - 20, 20, 8, Color8(250, 250, 250))
	cv.rect(88, wt - 24, 4, 16, Color8(214, 50, 60))
	cv.rect(82, wt - 18, 16, 4, Color8(214, 50, 60))
	_door(cv, 90, base - 2, 26, 40, Color8(200, 200, 196), true)
	for wx: int in [x0 + 18, x0 + 114]:
		_window(cv, wx, base - 46, 16, 22, wood, true, Color8(80, 150, 110))
	_sign(cv, x0 + 102, wt + 6, "potion", Color8(230, 226, 214))
	# Грядка с травами.
	for i in 6:
		cv.rect(x0 + 40 + i * 3, base - 5 - hh(i, 1, 71) % 4, 2, 5, LEAF[1 + i % 2])
	return cv


func _b_treasury() -> Cv:
	var d := _house(180, 196, 152, 80, 74, 18, Color8(110, 74, 146), "slate", 0.0)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	_stones(cv, x0, wt, 152, 80, Color8(176, 170, 156), 8, 5)
	_footing(cv, x0, base, 152, Color8(130, 124, 116))
	# Колонны по углам.
	for px: int in [x0 - 2, x0 + 140]:
		cv.rect(px, wt, 14, 80, Color8(200, 196, 184))
		cv.rect(px, wt, 3, 80, Color8(230, 226, 214))
		cv.rect(px + 11, wt, 3, 80, Color8(150, 144, 134))
	_put_roof(d)
	cv.rect(x0 - 8, wt, 168, 3, Color8(220, 180, 70))
	_eave_shadow(cv, x0, wt + 3, 152)
	_door(cv, 90, base - 2, 30, 46, Color8(96, 60, 44), true, true)
	cv.ell(90, base - 52, 5, 5, Color8(220, 180, 70))
	cv.ell(90, base - 52, 3, 3, Color8(110, 220, 255))
	# Знамёна.
	for bx: int in [x0 + 26, x0 + 112]:
		cv.rect(bx, wt + 8, 14, 3, Color8(220, 180, 70))
		cv.poly(PackedVector2Array([Vector2(bx + 1, wt + 11), Vector2(bx + 13, wt + 11), Vector2(bx + 13, wt + 50), Vector2(bx + 7, wt + 44), Vector2(bx + 1, wt + 50)]), Color8(110, 70, 150))
		cv.rect(bx + 1, wt + 11, 2, 36, Color8(140, 98, 180))
		_icon(cv, bx + 7, wt + 26, "coin")
	# Окна-бойницы с решёткой.
	for wx: int in [x0 + 52, x0 + 94]:
		cv.rect(wx, wt + 14, 8, 14, Color8(40, 36, 50))
		for k in 3:
			cv.rect(wx + 1 + k * 3, wt + 14, 1, 14, Color8(150, 150, 160))
	# Сундук с золотом у входа.
	cv.rect(x0 + 112, base - 12, 18, 12, Color8(130, 80, 46))
	cv.rect(x0 + 112, base - 12, 18, 3, Color8(220, 180, 70))
	cv.ell(x0 + 121, base - 13, 7, 2, Color8(250, 210, 90))
	return cv


func _b_storage() -> Cv:
	var d := _house(196, 186, 164, 68, 72, 12, Color8(168, 72, 56), "tile", 0.05)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	_planks(cv, x0, wt, 164, 68, Color8(150, 104, 66))
	_footing(cv, x0, base, 164)
	_put_roof(d)
	_eave_shadow(cv, x0, wt + 3, 164, 8)
	_gable(cv, 98, wt + 2, 46, 32, Color8(168, 72, 56), Color8(150, 104, 66), Color8(90, 56, 40), false)
	# Двустворчатые ворота амбара с косыми перекладинами.
	var gx := 98 - 22
	var gy := base - 48
	cv.rect(gx - 3, gy - 3, 50, 51, Color8(80, 50, 36))
	for s in 2:
		var ox := gx + s * 22
		_planks(cv, ox, gy, 22, 46, Color8(120, 74, 46))
		cv.rect(ox, gy, 22, 3, Color8(90, 56, 38))
		cv.rect(ox, gy + 43, 22, 3, Color8(90, 56, 38))
		cv.line(Vector2(ox + 1, gy + 42), Vector2(ox + 20, gy + 3), Color8(90, 56, 38), 3)
	cv.rect(gx + 21, gy, 2, 46, Color8(50, 32, 24))
	# Ящики и мешки у стены.
	for i in 2:
		var bx := x0 + 10 + i * 16
		cv.rect(bx, base - 16 - i * 0, 14, 14, Color8(170, 122, 72))
		cv.rect(bx, base - 16, 14, 2, Color8(200, 156, 100))
		cv.line(Vector2(bx, base - 16), Vector2(bx + 13, base - 3), Color8(120, 80, 50), 1)
	cv.ell(x0 + 140, base - 8, 8, 8, Color8(210, 190, 140))
	cv.ell(x0 + 150, base - 7, 7, 7, Color8(196, 176, 126))
	cv.rect(x0 + 138, base - 16, 4, 2, Color8(150, 120, 80))
	_sign(cv, x0 + 128, wt + 10, "box", Color8(130, 84, 52))
	return cv


func _b_workshop() -> Cv:
	var d := _house(212, 186, 168, 66, 70, 14, Color8(206, 112, 60), "tile", 0.04)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	var wood := Color8(86, 54, 38)
	_timber(cv, x0, wt, 168, 66, Color8(216, 198, 162), wood, 1)
	_footing(cv, x0, base, 168)
	_put_roof(d)
	_chimney(cv, x0 + 30, int(d["roof_top"]) - 16, 12, 36)
	_eave_shadow(cv, x0, wt + 3, 168)
	_door(cv, 106 + 20, base - 2, 26, 40, Color8(130, 82, 50), true)
	_window(cv, x0 + 140, base - 46, 16, 22, wood, true, Color8(150, 90, 60))
	# Навес над верстаком слева.
	var ax := x0 + 4
	var ay := wt + 10
	for yy in 14:
		for xx in 64:
			var stripe := ((xx + yy / 2) / 8) % 2 == 0
			var c := Color8(70, 130, 90) if stripe else Color8(230, 220, 190)
			if yy > 10:
				c = c.darkened(0.2)
			cv.put(ax + xx, ay + yy, c)
	for i in 8:
		cv.ell(ax + 4 + i * 8, ay + 14, 4, 2, Color8(70, 130, 90) if i % 2 == 0 else Color8(230, 220, 190))
	cv.rect(ax + 2, ay + 14, 2, 36, wood)
	cv.rect(ax + 60, ay + 14, 2, 36, wood)
	# Верстак с инструментами.
	cv.rect(ax + 6, base - 18, 52, 5, Color8(150, 100, 60))
	cv.rect(ax + 6, base - 18, 52, 1, Color8(190, 140, 90))
	cv.rect(ax + 8, base - 13, 3, 13, wood)
	cv.rect(ax + 53, base - 13, 3, 13, wood)
	cv.rect(ax + 14, base - 22, 12, 3, Color8(170, 176, 190))
	cv.rect(ax + 30, base - 24, 2, 6, Color8(150, 100, 60))
	cv.rect(ax + 28, base - 26, 6, 3, Color8(170, 176, 190))
	cv.ell(ax + 46, base - 21, 4, 3, Color8(200, 160, 70))
	# Точильный круг.
	cv.ell(ax + 32, base - 8, 7, 7, Color8(120, 116, 112))
	cv.ell(ax + 32, base - 8, 3, 3, Color8(160, 156, 150))
	_sign(cv, x0 + 72, wt + 8, "gear", Color8(120, 80, 52))
	return cv


func _b_mentor() -> Cv:
	var d := _house(164, 168, 124, 56, 62, 16, Color8(204, 168, 86), "thatch", 0.0)
	var cv: Cv = d["cv"]
	var x0: int = d["x0"]
	var base: int = d["base"]
	var wt: int = d["wall_top"]
	var wood := Color8(96, 62, 44)
	_timber(cv, x0, wt, 124, 56, Color8(226, 206, 170), wood, 1)
	_footing(cv, x0, base, 124)
	_put_roof(d, 10)
	_eave_shadow(cv, x0, wt + 3, 124)
	_door(cv, 82 - 20, base - 2, 24, 38, Color8(110, 70, 46), true)
	_window(cv, x0 + 74, base - 42, 16, 18, wood, true, Color8(150, 70, 60))
	# Вымпел и фонарь.
	cv.rect(x0 + 104, wt - 30, 2, 36, wood)
	cv.poly(PackedVector2Array([Vector2(x0 + 106, wt - 30), Vector2(x0 + 124, wt - 25), Vector2(x0 + 106, wt - 20)]), Color8(60, 110, 190))
	cv.rect(x0 + 40, wt + 6, 6, 8, Color8(240, 200, 100))
	cv.rect(x0 + 40, wt + 5, 6, 1, Color8(50, 44, 48))
	_npc(cv, x0 + 108, base + 2, Color8(70, 100, 170), Color8(220, 220, 224), "mentor")
	return cv


func _b_merchant() -> Cv:
	var cv := Cv.new(148, 124)
	var base := 124 - PAD
	_base_shadow(cv, 74, base, 66)
	var wood := Color8(110, 70, 46)
	var wp := tones(wood)
	# Задняя стенка-полка.
	cv.rect(18, base - 70, 112, 40, Color8(90, 58, 40))
	for sy: int in [base - 58, base - 44]:
		cv.rect(20, sy, 108, 3, wp[0])
		for i in 13:
			var c: Color = [Color8(220, 70, 80), Color8(80, 170, 220), Color8(120, 200, 100), Color8(230, 190, 80)][hh(i, sy, 80) % 4]
			cv.rect(24 + i * 8, sy - 7, 5, 7, c)
			cv.rect(25 + i * 8, sy - 9, 3, 2, Color8(220, 220, 220))
	_npc(cv, 74, base - 24, Color8(150, 60, 60), Color8(120, 74, 44), "merchant")
	# Прилавок.
	_planks(cv, 12, base - 26, 124, 26, Color8(160, 110, 66))
	cv.rect(10, base - 28, 128, 4, wp[1])
	cv.rect(10, base - 28, 128, 1, wp[0])
	# Товары на прилавке: фрукты и зелья.
	for i in 6:
		cv.ell(22 + i * 5, base - 31, 3, 3, Color8(220, 60, 60) if i % 2 == 0 else Color8(240, 150, 50))
	for i in 4:
		cv.ell(104 + i * 6, base - 32, 3, 4, [Color8(110, 220, 120), Color8(120, 140, 240), Color8(240, 90, 140), Color8(250, 220, 90)][i])
		cv.rect(103 + i * 6, base - 38, 2, 3, Color8(200, 190, 170))
	# Столбы и полосатый навес.
	cv.rect(12, base - 92, 4, 66, wp[2])
	cv.rect(132, base - 92, 4, 66, wp[2])
	for yy in 20:
		for xx in 140:
			var stripe := (xx / 10) % 2 == 0
			var c := Color8(200, 60, 56) if stripe else Color8(244, 232, 210)
			if yy < 3:
				c = c.lightened(0.15)
			elif yy > 15:
				c = c.darkened(0.12)
			cv.put(4 + xx, base - 104 + yy, c)
	for i in 14:
		cv.ell(9 + i * 10, base - 84, 5, 3, Color8(200, 60, 56) if i % 2 == 0 else Color8(244, 232, 210))
	for xx in 140:
		cv.shade(4 + xx, base - 105, -0.2)
	# Ящики по бокам.
	cv.rect(0, base - 14, 14, 14, Color8(170, 122, 72))
	cv.rect(0, base - 14, 14, 2, Color8(200, 156, 100))
	cv.rect(134, base - 12, 14, 12, Color8(170, 122, 72))
	cv.rect(134, base - 12, 14, 2, Color8(200, 156, 100))
	for i in 4:
		cv.ell(137 + (i % 2) * 6, base - 15 - (i / 2) * 3, 3, 3, Color8(120, 190, 70))
	return cv


func _b_exchange() -> Cv:
	var cv := Cv.new(132, 116)
	var base := 116 - PAD
	_base_shadow(cv, 66, base, 58)
	var wood := Color8(100, 66, 46)
	var wp := tones(wood)
	_planks(cv, 18, base - 64, 96, 40, Color8(120, 80, 54))
	_planks(cv, 12, base - 24, 108, 24, Color8(150, 104, 66))
	cv.rect(10, base - 27, 112, 4, wp[1])
	cv.rect(10, base - 27, 112, 1, wp[0])
	# Большие весы на прилавке.
	var gold := Color8(230, 190, 80)
	cv.rect(65, base - 58, 3, 31, gold)
	cv.rect(44, base - 56, 45, 3, gold)
	for s: int in [46, 86]:
		cv.line(Vector2(s, base - 53), Vector2(s - 6, base - 40), gold)
		cv.line(Vector2(s, base - 53), Vector2(s + 6, base - 40), gold)
		cv.ell(s, base - 39, 8, 3, Color8(200, 160, 60))
	cv.ell(40, base - 42, 3, 3, Color8(110, 220, 255))
	cv.ell(46, base - 43, 3, 3, Color8(220, 90, 220))
	cv.ell(86, base - 42, 4, 3, Color8(140, 130, 120))
	cv.rect(58, base - 30, 18, 3, Color8(110, 74, 50))
	# Мешочки с материалами.
	for i in 3:
		cv.ell(22 + i * 10, base - 31, 5, 5, [Color8(200, 180, 130), Color8(170, 140, 200), Color8(130, 190, 140)][i])
	for i in 3:
		cv.ell(96 + i * 8, base - 31, 4, 4, [Color8(250, 210, 90), Color8(220, 80, 70), Color8(120, 200, 240)][i])
	cv.rect(12, base - 86, 4, 62, wp[2])
	cv.rect(116, base - 86, 4, 62, wp[2])
	for yy in 18:
		for xx in 124:
			var c := Color8(60, 140, 90) if (xx / 10) % 2 == 0 else Color8(236, 230, 206)
			if yy > 14:
				c = c.darkened(0.12)
			cv.put(4 + xx, base - 98 + yy, c)
	for i in 13:
		cv.ell(9 + i * 10, base - 80, 5, 3, Color8(60, 140, 90) if i % 2 == 0 else Color8(236, 230, 206))
	_sign(cv, 120, base - 76, "scales", Color8(120, 80, 54))
	return cv


func _b_training() -> Cv:
	var cv := Cv.new(148, 122)
	var base := 122 - PAD
	_base_shadow(cv, 74, base, 60)
	var wood := Color8(120, 78, 50)
	var wp := tones(wood)
	# Стойки с оружием.
	for r in 2:
		var rx := 26 + r * 52
		cv.rect(rx, base - 40, 44, 4, wp[1])
		cv.rect(rx, base - 14, 44, 4, wp[1])
		cv.rect(rx, base - 40, 3, 40, wp[2])
		cv.rect(rx + 41, base - 40, 3, 40, wp[2])
		for i in 5:
			var wx := rx + 6 + i * 8
			var kind := (i + r) % 3
			if kind == 0:   # меч
				cv.rect(wx, base - 52, 3, 36, Color8(200, 206, 220))
				cv.rect(wx, base - 52, 1, 36, Color.WHITE)
				cv.rect(wx - 2, base - 18, 7, 2, Color8(150, 110, 60))
			elif kind == 1:  # копьё
				cv.rect(wx + 1, base - 60, 2, 50, Color8(140, 96, 60))
				cv.poly(PackedVector2Array([Vector2(wx - 1, base - 58), Vector2(wx + 2, base - 66), Vector2(wx + 5, base - 58)]), Color8(200, 206, 220))
			else:            # щит
				cv.ell(wx + 2, base - 26, 6, 8, Color8(170, 60, 60))
				cv.ell(wx + 2, base - 26, 3, 4, Color8(230, 190, 80))
	# Навес на столбах.
	for px: int in [16, 128]:
		cv.rect(px, base - 72, 5, 72, wp[1])
		cv.rect(px, base - 72, 1, 72, wp[0])
		cv.rect(px + 4, base - 72, 1, 72, wp[3])
	_roof(cv, 6, base - 108, 136, 34, Color8(150, 84, 56), 10, "tile", 0.08)
	_eave_shadow(cv, 16, base - 71, 117, 5)
	# Флажок.
	cv.rect(72, base - 122, 2, 18, Color8(60, 50, 50))
	cv.poly(PackedVector2Array([Vector2(74, base - 122), Vector2(88, base - 118), Vector2(74, base - 113)]), Color8(210, 60, 60))
	return cv


func _b_mine() -> Cv:
	var cv := Cv.new(196, 164)
	var base := 164 - PAD
	_base_shadow(cv, 98, base, 92)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var rock := [Color8(170, 160, 146), Color8(136, 126, 114), Color8(104, 96, 88), Color8(70, 64, 60)]
	var blobs: Array = []
	for i in 22:
		var bx := rng.randf_range(14, 182)
		var hgt := 120.0 - absf(bx - 98) * 0.9
		var by := base - rng.randf_range(10, maxf(12.0, hgt))
		blobs.append([bx, by, rng.randf_range(14, 26)])
	blobs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	for b: Array in blobs:
		var cx: float = b[0]
		var cy: float = b[1]
		var r: float = b[2]
		for iy in range(int(cy - r * 0.8), int(cy + r * 0.8) + 1):
			for ix in range(int(cx - r), int(cx + r) + 1):
				if iy > base:
					continue
				var nx := (ix + 0.5 - cx) / r
				var ny := (iy + 0.5 - cy) / (r * 0.8)
				var dd := nx * nx + ny * ny
				if dd > 1.0:
					continue
				var l := -0.55 * nx - 0.7 * ny + 0.4 * sqrt(1.0 - dd)
				var c: Color = rock[1]
				if l > 0.6:
					c = rock[0]
				elif l < -0.15:
					c = rock[3]
				elif l < 0.25:
					c = rock[2]
				if hh(ix / 2, iy / 2, 90) < 30 and l > 0.0:
					c = Color8(250, 210, 90)   # золотые жилки
				if ny < -0.6 and hh(ix / 3, iy / 2, 91) < 400:
					c = LEAF[1] if l > 0.4 else LEAF[2]   # мох сверху
				cv.put(ix, iy, c)
	# Вход: деревянная крепь и темнота.
	var ex := 98
	for yy in 50:
		for xx in 40:
			var t := float(yy) / 50.0
			cv.put(ex - 20 + xx, base - 50 + yy, Color8(16, 12, 14).lerp(Color8(50, 40, 36), t * t))
	var wood := Color8(130, 86, 52)
	var wp := tones(wood)
	for px: int in [ex - 26, ex + 20]:
		cv.rect(px, base - 54, 6, 54, wp[1])
		cv.rect(px, base - 54, 1, 54, wp[0])
		cv.rect(px + 5, base - 54, 1, 54, wp[3])
	cv.rect(ex - 30, base - 60, 60, 7, wp[1])
	cv.rect(ex - 30, base - 60, 60, 1, wp[0])
	cv.rect(ex - 30, base - 54, 60, 1, wp[3])
	# Рельсы.
	for i in 6:
		var y := base - 30 + i * 6
		cv.rect(ex - 12 - i, y, 24 + i * 2, 2, Color8(110, 76, 50))
	cv.line(Vector2(ex - 8, base - 34), Vector2(ex - 14, base), Color8(150, 150, 160), 2)
	cv.line(Vector2(ex + 7, base - 34), Vector2(ex + 13, base), Color8(150, 150, 160), 2)
	# Фонарь.
	cv.rect(ex + 26, base - 50, 7, 9, Color8(250, 210, 110))
	cv.rect(ex + 26, base - 51, 7, 1, Color8(50, 44, 48))
	cv.rect(ex + 26, base - 41, 7, 1, Color8(50, 44, 48))
	cv.rect(ex + 28, base - 48, 3, 5, Color8(255, 250, 220))
	# Табличка.
	cv.rect(ex - 12, base - 72, 24, 10, Color8(150, 104, 66))
	cv.rect(ex - 12, base - 72, 24, 1, Color8(190, 140, 90))
	_icon(cv, ex, base - 67, "coin")
	return cv


func _b_portal() -> Cv:
	var cv := Cv.new(132, 160)
	var base := 160 - PAD
	var cx := 66
	_base_shadow(cv, cx, base, 60)
	# Ступени.
	_stones(cv, cx - 60, base - 8, 120, 8, Color8(140, 136, 150), 4, 7)
	_stones(cv, cx - 52, base - 15, 104, 7, Color8(150, 146, 160), 7, 8)
	cv.rect(cx - 60, base - 8, 120, 1, Color8(190, 186, 200))
	cv.rect(cx - 52, base - 15, 104, 1, Color8(200, 196, 210))
	# Вихрь в проёме.
	var oy := base - 60.0
	var orx := 30.0
	var ory := 46.0
	for iy in range(int(oy - ory), base - 14):
		for ix in range(int(cx - orx), int(cx + orx)):
			var dx := (ix + 0.5 - cx) / orx
			var dy := (iy + 0.5 - oy) / ory
			if iy < oy and dx * dx + dy * dy > 1.0:
				continue
			if absf(dx) > 1.0:
				continue
			var r := sqrt(dx * dx + dy * dy * 0.6)
			var a := atan2(dy, dx)
			var s := sin(a * 3.0 + r * 9.0)
			var c := Color8(40, 20, 80)
			if s > 0.6:
				c = Color8(150, 90, 230)
			elif s > 0.1:
				c = Color8(96, 50, 170)
			elif s < -0.7:
				c = Color8(70, 150, 230)
			if r < 0.28:
				c = Color8(230, 220, 255) if r < 0.16 else Color8(170, 140, 250)
			cv.put(ix, iy, c)
	# Колонны.
	for s: int in [-1, 1]:
		var px := cx + s * 38 - 8
		_stones(cv, px, base - 104, 16, 90, Color8(150, 146, 166), 9, 4 + s)
		cv.rect(px, base - 104, 2, 90, Color8(196, 192, 214))
		cv.rect(px + 14, base - 104, 2, 90, Color8(96, 92, 112))
		# Светящиеся руны.
		for k in 4:
			var ry := base - 92 + k * 18
			cv.rect(px + 6, ry, 4, 2, Color8(110, 230, 255))
			cv.rect(px + 7, ry + 2, 2, 5, Color8(110, 230, 255))
			cv.put(px + 7, ry, Color.WHITE)
		cv.rect(px - 3, base - 108, 22, 6, Color8(170, 166, 186))
		cv.rect(px - 3, base - 24, 22, 8, Color8(130, 126, 146))
	# Арка.
	for iy in range(base - 150, base - 100):
		for ix in range(cx - 50, cx + 50):
			var dx := ix + 0.5 - cx
			var dy := (iy + 0.5 - (base - 104)) * 1.15
			var dd := sqrt(dx * dx + dy * dy)
			if dd > 48.0 or dd < 31.0 or iy > base - 103:
				continue
			var a := atan2(dy, dx)
			var seg := int((a + PI) / (PI / 9.0))
			var c := Color8(160, 156, 176) if seg % 2 == 0 else Color8(146, 142, 162)
			if dd > 46.0 or absf(fmod(a + PI, PI / 9.0)) < 0.04:
				c = Color8(90, 86, 106)
			elif dd < 33.0:
				c = Color8(110, 106, 126)
			elif dx < 0 and dd > 43.0:
				c = c.lightened(0.15)
			cv.put(ix, iy, c)
	# Камень-ключ с кристаллом.
	cv.poly(PackedVector2Array([Vector2(cx - 9, base - 152), Vector2(cx + 9, base - 152), Vector2(cx + 6, base - 134), Vector2(cx - 6, base - 134)]), Color8(176, 172, 192))
	cv.poly(PackedVector2Array([Vector2(cx, base - 150), Vector2(cx + 4, base - 143), Vector2(cx, base - 136), Vector2(cx - 4, base - 143)]), Color8(110, 230, 255))
	cv.put(cx - 1, base - 146, Color.WHITE)
	# Кристаллы у подножия.
	for s: int in [-1, 1]:
		var bx := cx + s * 56
		cv.poly(PackedVector2Array([Vector2(bx - 4, base - 4), Vector2(bx - 2, base - 22), Vector2(bx + 2, base - 26), Vector2(bx + 4, base - 4)]), Color8(110, 200, 250))
		cv.poly(PackedVector2Array([Vector2(bx - 2, base - 4), Vector2(bx - 1, base - 20), Vector2(bx + 1, base - 22), Vector2(bx + 1, base - 4)]), Color8(210, 245, 255))
	# Плющ на арке.
	for i in 12:
		var a := PI + i * PI / 11.0
		var p := Vector2(cx + cos(a) * 44, base - 104 + sin(a) * 38)
		if hh(i, 3, 92) % 3 != 0:
			cv.ell(p.x, p.y, 3, 2, LEAF[1 + i % 2])
	return cv


## Строительные леса поверх недостроенной постройки (тот же размер).
func _scaffold(src: Cv) -> Cv:
	var cv := Cv.new(src.w, src.h)
	var base := src.h - PAD
	var used := src.img.get_used_rect()
	var x0 := used.position.x + 6
	var x1 := used.end.x - 6
	var top := used.position.y + 14
	var wood := Color8(176, 130, 78)
	var dark := Color8(110, 76, 44)
	var n := maxi(2, (x1 - x0) / 46)
	for i in n + 1:
		var px := x0 + (x1 - x0) * i / n
		cv.rect(px - 2, top, 4, base - top, wood)
		cv.rect(px + 1, top, 1, base - top, dark)
	for f in 3:
		var y := base - 14 - f * (base - top - 14) / 3
		cv.rect(x0 - 4, y, x1 - x0 + 8, 5, Color8(196, 150, 96))
		cv.rect(x0 - 4, y + 4, x1 - x0 + 8, 1, dark)
	for i in n:
		var a := x0 + (x1 - x0) * i / n
		var b := x0 + (x1 - x0) * (i + 1) / n
		cv.line(Vector2(a, base - 14), Vector2(b, base - 14 - (base - top - 14) / 3), dark, 2)
	# Доски крест-накрест на двери и табличка «строится».
	var cx := src.w / 2
	cv.line(Vector2(cx - 14, base - 36), Vector2(cx + 14, base - 6), wood, 3)
	cv.line(Vector2(cx + 14, base - 36), Vector2(cx - 14, base - 6), wood, 3)
	return cv


# ===================================================================================
#                                    МЕЛОЧИ
# ===================================================================================

func _p_fountain() -> Cv:
	var cv := Cv.new(112, 90)
	var base := 90 - PAD
	var cx := 56.0
	_base_shadow(cv, cx, base, 52)
	var stone := Color8(170, 164, 154)
	# Чаша: внешний край.
	cv.ell(cx, base - 16, 52, 18, Color8(120, 114, 106))
	cv.ell(cx, base - 18, 52, 18, stone)
	cv.ell(cx, base - 19, 46, 14, Color8(130, 124, 116))
	cv.ell(cx, base - 18, 44, 13, Color8(70, 140, 196))
	for iy in range(base - 31, base - 5):
		for ix in range(int(cx - 44), int(cx + 44)):
			var nx := (ix + 0.5 - cx) / 44.0
			var ny := (iy + 0.5 - (base - 18)) / 13.0
			if nx * nx + ny * ny > 1.0:
				continue
			if sin(ix * 0.3 + iy * 0.9) > 0.9 or hh(ix, iy, 93) < 8:
				cv.put(ix, iy, Color8(170, 220, 245))
	# Боковина чаши (видна спереди).
	for ix in range(int(cx - 52), int(cx + 52)):
		var nx := (ix + 0.5 - cx) / 52.0
		var yb := base - 18 + int(18.0 * sqrt(maxf(0.0, 1.0 - nx * nx)))
		for yy in 10:
			var c := stone.darkened(0.1 + float(yy) / 30.0)
			if (ix + yy * 2) % 12 == 0:
				c = Color8(110, 104, 96)
			cv.put(ix, yb + yy - 9, c)
		cv.put(ix, yb - 10, stone.lightened(0.15))
	# Столб и верхняя чаша.
	cv.rect(cx - 5, base - 52, 10, 34, Color8(176, 170, 160))
	cv.rect(cx - 5, base - 52, 3, 34, Color8(206, 200, 190))
	cv.rect(cx + 3, base - 52, 2, 34, Color8(130, 124, 116))
	cv.ell(cx, base - 52, 16, 5, Color8(150, 144, 136))
	cv.ell(cx, base - 54, 16, 5, stone)
	cv.ell(cx, base - 54, 12, 3, Color8(90, 160, 210))
	# Струи.
	for s: int in [-1, 1]:
		for i in 14:
			var t := i / 13.0
			var p := Vector2(cx + s * (8 + t * 16), base - 60 + t * t * 34 - t * 4)
			cv.ell(p.x, p.y, 1.5, 1.5, Color(0.8, 0.93, 1.0, 0.9))
	cv.ell(cx, base - 62, 3, 6, Color(0.85, 0.95, 1.0, 0.9))
	return cv


func _p_lamp() -> Cv:
	var cv := Cv.new(24, 70)
	var base := 70 - PAD
	_base_shadow(cv, 12, base, 7)
	var iron := Color8(48, 46, 58)
	cv.rect(8, base - 4, 8, 4, iron)
	cv.rect(10, base - 52, 4, 50, iron)
	cv.rect(10, base - 52, 1, 50, Color8(96, 96, 112))
	cv.rect(12, base - 54, 8, 2, iron)
	cv.rect(17, base - 52, 2, 3, iron)
	# Фонарь.
	cv.rect(14, base - 49, 9, 11, iron)
	cv.rect(15, base - 48, 7, 9, Color8(255, 214, 120))
	cv.rect(17, base - 46, 3, 5, Color8(255, 250, 220))
	cv.rect(13, base - 51, 11, 2, iron)
	return cv


func _p_bench() -> Cv:
	var cv := Cv.new(48, 30)
	var base := 30 - PAD
	_base_shadow(cv, 24, base, 22)
	var wood := tones(Color8(150, 100, 62))
	cv.rect(4, base - 22, 40, 4, wood[1])
	cv.rect(4, base - 22, 40, 1, wood[0])
	cv.rect(4, base - 16, 40, 2, wood[2])
	cv.rect(2, base - 12, 44, 5, wood[1])
	cv.rect(2, base - 12, 44, 1, wood[0])
	for x: int in [5, 40]:
		cv.rect(x, base - 8, 3, 8, Color8(60, 56, 64))
	return cv


func _p_dummy() -> Cv:
	var cv := Cv.new(30, 54)
	var base := 54 - PAD
	_base_shadow(cv, 15, base, 9)
	var wood := Color8(120, 80, 50)
	cv.rect(14, base - 44, 3, 44, wood)
	cv.rect(3, base - 34, 24, 3, wood)
	var straw := tones(Color8(214, 178, 96))
	cv.ell(15, base - 26, 8, 11, straw[1])
	cv.ell(13, base - 29, 4, 6, straw[0])
	for i in 6:
		cv.rect(9 + i * 2, base - 18, 1, 4, straw[2])
	cv.rect(8, base - 26, 15, 2, Color8(150, 60, 50))
	cv.ell(15, base - 41, 6, 6, Color8(220, 200, 160))
	cv.rect(12, base - 42, 2, 2, Color8(60, 40, 40))
	cv.rect(17, base - 42, 2, 2, Color8(60, 40, 40))
	cv.line(Vector2(12, base - 38), Vector2(18, base - 38), Color8(150, 110, 80))
	return cv


func _p_target() -> Cv:
	var cv := Cv.new(32, 42)
	var base := 42 - PAD
	_base_shadow(cv, 16, base, 10)
	cv.line(Vector2(8, base), Vector2(14, base - 24), Color8(120, 80, 50), 2)
	cv.line(Vector2(24, base), Vector2(18, base - 24), Color8(120, 80, 50), 2)
	cv.ell(16, base - 22, 13, 13, Color8(230, 210, 160))
	cv.ell(16, base - 22, 10, 10, Color8(200, 60, 56))
	cv.ell(16, base - 22, 7, 7, Color8(240, 230, 200))
	cv.ell(16, base - 22, 4, 4, Color8(200, 60, 56))
	cv.ell(16, base - 22, 1.5, 1.5, Color8(250, 210, 80))
	cv.line(Vector2(19, base - 24), Vector2(27, base - 30), Color8(140, 100, 60))
	cv.rect(26, base - 32, 3, 3, Color8(240, 240, 240))
	return cv


func _p_anvil() -> Cv:
	var cv := Cv.new(36, 30)
	var base := 30 - PAD
	_base_shadow(cv, 18, base, 14)
	cv.rect(8, base - 10, 20, 10, Color8(120, 80, 50))
	cv.rect(8, base - 10, 20, 2, Color8(160, 110, 70))
	var iron := tones(Color8(84, 86, 100))
	cv.rect(12, base - 16, 12, 6, iron[2])
	cv.poly(PackedVector2Array([Vector2(2, base - 22), Vector2(30, base - 22), Vector2(34, base - 19), Vector2(26, base - 16), Vector2(8, base - 16)]), iron[1])
	cv.rect(4, base - 22, 26, 2, iron[0])
	cv.rect(20, base - 26, 10, 3, Color8(170, 176, 190))
	return cv


func _barrel(cv: Cv, cx: int, base: int, r: int, h: int) -> void:
	var wood := tones(Color8(146, 96, 56))
	for yy in h:
		var bulge := r + int(2.0 * sin(PI * yy / h))
		for xx in range(-bulge, bulge + 1):
			var t := float(xx + bulge) / (bulge * 2.0)
			var c: Color = wood[0] if t < 0.25 else (wood[1] if t < 0.7 else wood[2])
			if (xx + bulge) % 5 == 0:
				c = wood[3]
			cv.put(cx + xx, base - h + yy, c)
	for by: int in [base - h + 3, base - 4]:
		cv.rect(cx - r - 2, by, r * 2 + 5, 2, Color8(70, 70, 80))
	cv.ell(cx, base - h, r, 3, wood[2])
	cv.ell(cx, base - h, r - 2, 2, Color8(110, 70, 40))


func _p_barrels() -> Cv:
	var cv := Cv.new(44, 40)
	var base := 40 - PAD
	_base_shadow(cv, 22, base, 20)
	_barrel(cv, 13, base, 8, 22)
	_barrel(cv, 30, base, 8, 22)
	_barrel(cv, 22, base - 18, 7, 16)
	return cv


func _crate(cv: Cv, x: int, y: int, s: int) -> void:
	var w := tones(Color8(176, 126, 74))
	cv.rect(x, y, s, s, w[1])
	cv.rect(x, y, s, 2, w[0])
	cv.rect(x, y + s - 2, s, 2, w[2])
	cv.rect(x, y, 2, s, w[2])
	cv.rect(x + s - 2, y, 2, s, w[2])
	cv.line(Vector2(x + 2, y + s - 3), Vector2(x + s - 3, y + 2), w[2], 2)


func _p_crates() -> Cv:
	var cv := Cv.new(44, 42)
	var base := 42 - PAD
	_base_shadow(cv, 22, base, 20)
	_crate(cv, 4, base - 18, 18)
	_crate(cv, 22, base - 16, 16)
	_crate(cv, 10, base - 34, 16)
	return cv


func _p_hay() -> Cv:
	var cv := Cv.new(40, 30)
	var base := 30 - PAD
	_base_shadow(cv, 20, base, 18)
	var s := tones(Color8(222, 186, 96))
	for b in 2:
		var x := 3 + b * 17
		for yy in 16:
			for xx in 17:
				var c: Color = s[1] if hh(xx, yy / 2, 94 + b) % 3 != 0 else s[0]
				if yy > 12:
					c = s[2]
				cv.put(x + xx, base - 16 + yy, c)
		cv.rect(x, base - 12, 17, 1, Color8(150, 100, 60))
	for yy in 12:
		for xx in 18:
			cv.put(12 + xx, base - 26 + yy, s[1] if hh(xx, yy / 2, 96) % 3 != 0 else s[0])
	return cv


func _p_cart() -> Cv:
	var cv := Cv.new(44, 36)
	var base := 36 - PAD
	_base_shadow(cv, 22, base, 20)
	var iron := tones(Color8(96, 92, 100))
	cv.poly(PackedVector2Array([Vector2(4, base - 24), Vector2(40, base - 24), Vector2(36, base - 8), Vector2(8, base - 8)]), iron[1])
	cv.rect(4, base - 24, 36, 2, iron[0])
	cv.rect(8, base - 16, 28, 2, iron[2])
	for i in 7:
		cv.ell(10 + i * 4, base - 26, 4, 3, [Color8(150, 140, 130), Color8(250, 210, 90), Color8(120, 110, 104)][i % 3])
	for x: int in [12, 32]:
		cv.ell(x, base - 5, 5, 5, Color8(50, 46, 52))
		cv.ell(x, base - 5, 2, 2, Color8(140, 136, 140))
	return cv


func _p_pot() -> Cv:
	var cv := Cv.new(18, 24)
	var base := 24 - PAD
	cv.poly(PackedVector2Array([Vector2(3, base - 10), Vector2(15, base - 10), Vector2(13, base), Vector2(5, base)]), Color8(190, 104, 70))
	cv.rect(2, base - 11, 14, 2, Color8(214, 130, 90))
	for i in 5:
		cv.rect(4 + i * 2, base - 15 - (i % 2) * 2, 2, 5, LEAF[1 + i % 2])
	for i in 3:
		cv.rect(4 + i * 4, base - 17 - (i % 2) * 2, 3, 3, [Color8(240, 90, 110), Color8(250, 210, 90), Color8(240, 240, 250)][i])
	return cv


func _p_sign() -> Cv:
	var cv := Cv.new(34, 50)
	var base := 50 - PAD
	_base_shadow(cv, 17, base, 6)
	var wood := tones(Color8(150, 100, 60))
	cv.rect(15, base - 40, 4, 40, wood[1])
	cv.rect(15, base - 40, 1, 40, wood[0])
	cv.poly(PackedVector2Array([Vector2(4, base - 38), Vector2(26, base - 38), Vector2(32, base - 33), Vector2(26, base - 28), Vector2(4, base - 28)]), wood[1])
	cv.rect(4, base - 38, 22, 1, wood[0])
	cv.poly(PackedVector2Array([Vector2(30, base - 24), Vector2(8, base - 24), Vector2(2, base - 19), Vector2(8, base - 14), Vector2(30, base - 14)]), wood[2])
	for i in 4:
		cv.rect(8 + i * 4, base - 34, 3, 1, wood[3])
		cv.rect(12 + i * 4, base - 20, 3, 1, wood[3])
	return cv


func _p_tree() -> Cv:
	var cv := Cv.new(80, 100)
	var base := 100 - PAD
	_base_shadow(cv, 40, base, 16)
	var bark := tones(Color8(110, 74, 50))
	cv.poly(PackedVector2Array([Vector2(33, base), Vector2(47, base), Vector2(44, base - 34), Vector2(36, base - 34)]), bark[1])
	cv.rect(36, base - 34, 3, 34, bark[0])
	cv.rect(42, base - 34, 3, 34, bark[2])
	cv.rect(30, base - 3, 6, 3, bark[2])
	cv.rect(44, base - 3, 7, 3, bark[2])
	_canopy(cv, 40, base - 58, 30, 4242)
	return cv


func _p_bush() -> Cv:
	var cv := Cv.new(40, 32)
	var base := 32 - PAD
	_base_shadow(cv, 20, base, 16)
	_leaf_ball(cv, 13, base - 10, 10, LEAF, 5)
	_leaf_ball(cv, 27, base - 10, 10, LEAF, 6)
	_leaf_ball(cv, 20, base - 15, 11, LEAF, 7)
	for i in 4:
		cv.rect(10 + i * 7, base - 16 + (i % 2) * 6, 2, 2, [Color8(240, 90, 110), Color8(250, 240, 250)][i % 2])
	return cv


func _p_flowers() -> Cv:
	var cv := Cv.new(34, 18)
	var base := 18 - PAD
	var cols := [Color8(240, 90, 110), Color8(250, 210, 90), Color8(250, 250, 250), Color8(170, 130, 240)]
	for i in 11:
		var x := 2 + (i * 7) % 30
		var y := base - 2 - (i * 5) % 9
		cv.rect(x, y, 1, 4, LEAF[2])
		cv.rect(x - 1, y + 2, 1, 1, LEAF[1])
		cv.rect(x - 1, y - 2, 3, 3, cols[i % cols.size()])
		cv.put(x, y - 1, Color8(255, 240, 160))
	return cv
