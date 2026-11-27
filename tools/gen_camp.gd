extends SceneTree
## Лагерь-деревня в изометрии (по референсам владельца: дом-бар как образец перспективы,
## лист домиков — цвета крыш, деревня — мостовая и зелень). Детализация ART = 4 пикселя
## картинки на 1 пиксель мира.
##
## Постройки собираются из настоящих 3D-плоскостей (стены, скаты крыши, фронтоны, карнизы,
## трубы), которые проецируются в изометрию: экран = (X - Y, (X + Y) / 2 - Z). Клетка сетки —
## 64 единицы по X и Y (ромб 128x64 пикселя картинки = 32x16 пикселей мира). Свет сверху-слева:
## левые стены (+Y) освещены, правые (+X) в тени, тень на земле падает вправо.
## Вариант «x» (дверь на правой стене) рисуется с зеркальным светом и отражается.
##
##   godot --headless --path . --script res://tools/gen_camp.gd
## Выход: assets/camp/ — ground.png (вся земля с сеткой участков и лесом), b_<id>_<y|x>.png,
##   p_<имя>.png (мелочи, деревья), glow.png, camp.json (точки привязки, двери, деревья-спрайты).

const LAY := preload("res://scripts/camp_layout.gd")
const ART := 4
const U := 64.0            # клетка в единицах 3D
const LEAF := [Color8(156, 204, 86), Color8(104, 164, 64), Color8(64, 120, 52), Color8(36, 78, 44)]
const LIGHT_Y := Vector3(0.25, 0.9, 1.1)
const SHD_Y := Vector3(0.62, -0.2, 0.0)
const PLASTER := Color8(236, 222, 190)
const TIMBER := Color8(112, 66, 40)
const NONE := Color(0, 0, 0, 0)

var errors := 0
var meta := {"sprites": {}, "trees": []}
var LIGHT := LIGHT_Y.normalized()
var SHD := SHD_Y
var O := Vector2.ZERO
var spts: Array[Vector3] = []
var icons := {}
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


static func tones(c: Color) -> Array:
	return [c.lightened(0.22), c, c.darkened(0.2), c.darkened(0.42)]


static func hh(x: int, y: int, i: int) -> int:
	return hash(Vector3i(x, y, i)) & 1023


func _init() -> void:
	noise.seed = 11
	noise.frequency = 0.004
	noise2.seed = 23
	noise2.frequency = 0.02
	var dir := ProjectSettings.globalize_path("res://assets/camp")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	_icons()
	_glow()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for id: String in ["workshop", "merchant", "mine", "portal", "training", "library", "forge", "infirmary", "treasury", "storage", "exchange", "mentor"]:
		for face: String in ["y", "x"]:
			if id in ["portal", "merchant", "mine"] and face == "x":
				continue
			_building(id, face)
	for name: String in ["fountain", "lamp", "bench", "barrels", "crates", "cart", "bush", "flowers", "sign", "tree", "tree2", "tree3", "ftree", "ftree2"]:
		_prop(name)
	if only != "buildings":
		_ground()
	var f := FileAccess.open("res://assets/camp/camp.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("gen_camp: done, errors=%d" % errors)
	quit(1 if errors else 0)


func _save(img: Image, name: String) -> void:
	var path := "res://assets/camp/%s.png" % name
	if img.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("cannot save " + path)
		errors += 1


func _glow() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_save(img, "glow")


# ===================================================================================
#                             ИЗОМЕТРИЧЕСКИЙ «ДВИЖОК»
# ===================================================================================

func pr(p: Vector3) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5 - p.z) + O


## Цвет с учётом освещённости грани (b: 0.5 тень … 1.15 свет); в тени — холоднее.
static func lit(c: Color, b: float) -> Color:
	var r := c.r * b
	var g := c.g * b
	var bl := c.b * b
	if b < 0.9:
		var k := (0.9 - b) * 0.55
		r *= 1.0 - k * 0.35
		g *= 1.0 - k * 0.15
		bl *= 1.0 + k * 0.25
	elif b > 1.0:
		r += (b - 1.0) * 0.12
		g += (b - 1.0) * 0.08
	return Color(clampf(r, 0, 1), clampf(g, 0, 1), clampf(bl, 0, 1), c.a)


## Плоскость-параллелограмм p0 + s*e1 + t*e2, текстура tex(u, v, L1, L2) в единицах длины рёбер.
func quad(cv: Cv, p0: Vector3, e1: Vector3, e2: Vector3, n: Vector3, tex: Callable, shade := true) -> void:
	var a := pr(p0)
	var b := pr(p0 + e1) - a
	var c := pr(p0 + e2) - a
	var det := b.x * c.y - b.y * c.x
	if absf(det) < 0.5:
		return
	var r := Rect2(a, Vector2.ZERO).expand(a + b).expand(a + c).expand(a + b + c)
	var l1 := e1.length()
	var l2 := e2.length()
	var bright := 0.5 + 0.62 * maxf(0.0, n.normalized().dot(LIGHT)) if shade else 1.0
	for iy in range(int(floor(r.position.y)), int(ceil(r.end.y)) + 1):
		for ix in range(int(floor(r.position.x)), int(ceil(r.end.x)) + 1):
			var dx := ix + 0.5 - a.x
			var dy := iy + 0.5 - a.y
			var s := (dx * c.y - dy * c.x) / det
			var t := (b.x * dy - b.y * dx) / det
			if s < -0.001 or s > 1.001 or t < -0.001 or t > 1.001:
				continue
			var col: Color = tex.call(s * l1, t * l2, l1, l2)
			if col.a <= 0.0:
				continue
			cv.put(ix, iy, lit(col, bright))


## Коробка: видимые грани верх, +Y (лицо), +X (бок).
func box(cv: Cv, p: Vector3, s: Vector3, front: Callable, side: Callable, top: Callable) -> void:
	quad(cv, p + Vector3(0, 0, s.z), Vector3(s.x, 0, 0), Vector3(0, s.y, 0), Vector3(0, 0, 1), top)
	quad(cv, p + Vector3(0, s.y, 0), Vector3(s.x, 0, 0), Vector3(0, 0, s.z), Vector3(0, 1, 0), front)
	quad(cv, p + Vector3(s.x, s.y, 0), Vector3(0, -s.y, 0), Vector3(0, 0, s.z), Vector3(1, 0, 0), side)
	for dx: float in [0.0, s.x]:
		for dy: float in [0.0, s.y]:
			spts.append(p + Vector3(dx, dy, s.z))


func flat(c: Color) -> Callable:
	return func(_u: float, _v: float, _a: float, _b: float) -> Color: return c


## Шар (листва, камни, фрукты) в точке 3D, свет сверху-слева.
func ball3(cv: Cv, p: Vector3, r: float, pal: Array, ry := 1.0, leafy := false, sd := 0, rocky := false) -> void:
	var c := pr(p)
	var lt := Vector3(-0.55, -0.6, 0.58)
	for iy in range(int(c.y - r * ry) - 1, int(c.y + r * ry) + 2):
		for ix in range(int(c.x - r) - 1, int(c.x + r) + 2):
			var nx := (ix + 0.5 - c.x) / r
			var ny := (iy + 0.5 - c.y) / (r * ry)
			var jag := 1.0
			if leafy:
				jag = 1.0 - (hh(ix / 3, iy / 3, sd & 255) % 100) * 0.0018
			var d := nx * nx + ny * ny
			if d > jag:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d))
			var l := lt.x * nx + lt.y * ny + lt.z * nz
			if leafy:
				l += (hh(ix / 3, iy / 3, 21 + sd) % 100 - 50) * 0.006
			if rocky:
				# Грани и трещины: свет «ломается» по шуму.
				l += noise2.get_noise_2d(ix * 2.5 + sd * 31, iy * 2.5) * 0.45
				l = roundf(l * 3.0) / 3.0
			var col: Color = pal[1]
			if l > 0.72:
				col = pal[0]
			elif l < -0.12:
				col = pal[3]
			elif l < 0.3:
				col = pal[2]
			if leafy and d > 0.84 * jag and l < 0.45:
				col = pal[3]
			if rocky and (d > 0.86 or absf(noise.get_noise_2d(ix * 6.0 + sd * 17, iy * 6.0)) < 0.015):
				col = pal[3]
			cv.put(ix, iy, col)


# ---------------------------------- текстуры ----------------------------------

## Черепица/сланец/солома. v — от карниза вверх по скату.
func tex_roof(u: float, v: float, l1: float, _l2: float, col: Color, kind: String, moss: float) -> Color:
	var p := tones(col)
	var rh := 18.0 if kind == "tile" else (13.0 if kind == "slate" else 10.0)
	var rw := 26.0 if kind == "tile" else 18.0
	var row := int(v / rh)
	var ry := fmod(v, rh)
	var c: Color = p[1]
	if kind == "thatch":
		var s := hh(int(u / 2), row, 40) % 7
		c = p[1] if s < 3 else (p[0] if s < 5 else p[2])
		if ry < 3.0 and hh(int(u / 3), row, 41) % 3 != 0:
			c = p[3]
	else:
		var off := (row % 2) * rw * 0.5
		var su := fmod(u + off, rw)
		var id := int((u + off) / rw)
		var var_ := hh(id, row, 42) % 6
		if var_ == 0:
			c = c.lightened(0.08)
		elif var_ == 5:
			c = c.darkened(0.1)
		elif var_ == 3:
			c = c.lerp(Color8(150, 120, 90), 0.12)
		# Нижний край ряда (на него падает тень от верхнего), блик сверху.
		if ry < 3.0:
			c = p[3]
		elif ry < 6.0:
			c = p[2]
		elif ry > rh - 4.0:
			c = c.lightened(0.12)
		if su < 2.0 and ry >= 3.0:
			c = p[2].darkened(0.12)
		elif su > rw - 3.0 and ry >= 3.0:
			c = c.darkened(0.06)
		# Скруглённые нижние углы черепиц.
		if ry < 7.0 and (su < 4.0 or su > rw - 4.0):
			c = p[3]
		if moss > 0.0 and hh(int(u / 5), int(v / 4), 43) < int(moss * 1023.0):
			c = Color8(112, 152, 70) if hh(int(u), int(v), 44) < 600 else Color8(84, 124, 60)
	if v < 4.0:
		c = c.darkened(0.25)
	if u < 4.0 or u > l1 - 4.0:
		c = c.darkened(0.18)
	return c


## Доска карниза / ветровая доска.
func tex_board(u: float, v: float, _l1: float, l2: float, col: Color) -> Color:
	var p := tones(col)
	var c: Color = p[1]
	if v > l2 - 2.0:
		c = p[0]
	elif v < 2.0:
		c = p[3]
	elif hh(int(u / 7), int(v), 45) < 60:
		c = p[2]
	return c


## Дерево (балки, столбы): волокна вдоль u.
func tex_wood(u: float, v: float, l1: float, l2: float, col: Color) -> Color:
	var p := tones(col)
	var c: Color = p[1]
	if hh(int(u / 9), int(v / 2), 46) < 140:
		c = p[2]
	if v < 1.5 or u < 1.5:
		c = p[0]
	elif v > l2 - 2.0 or u > l1 - 2.0:
		c = p[3]
	return c


## Камень кладкой.
func tex_stone(u: float, v: float, col: Color, rh := 18.0) -> Color:
	var p := tones(col)
	var row := int(floor(v / rh))
	var ry := fposmod(v, rh)
	var len_ := 30.0 + (hh(row, 0, 47) % 3) * 6.0
	var off := (row % 2) * len_ * 0.5 + (hh(row, 1, 47) % 7)
	var su := fposmod(u + off, len_)
	var id := int(floor((u + off) / len_))
	var c: Color = p[1]
	var var_ := hh(id, row, 48) % 5
	if var_ == 0:
		c = p[0].darkened(0.06)
	elif var_ == 4:
		c = p[2]
	elif var_ == 2:
		c = c.lerp(Color8(150, 130, 110), 0.15)
	if ry < 2.0 or su < 2.0:
		return col.darkened(0.5)
	if ry > rh - 4.0 or su < 4.5:
		c = c.lightened(0.1)
	elif ry < 4.5 or su > len_ - 3.0:
		c = c.darkened(0.16)
	if hh(int(u / 2), int(v / 2), 49) < 20:
		c = c.darkened(0.1)
	return c


func tex_planks(u: float, v: float, col: Color) -> Color:
	var p := tones(col)
	var i := int(u / 16.0)
	var su := fmod(u, 16.0)
	var c: Color = p[1] if i % 2 == 0 else p[1].darkened(0.06)
	if hh(i, int(v / 40), 50) % 4 == 0:
		c = c.lightened(0.05)
	if su < 2.0:
		c = p[3]
	elif su < 4.0:
		c = p[0].darkened(0.04)
	elif hh(i * 7 + int(su / 3), int(v / 3), 51) < 40:
		c = p[2]
	if fmod(v + i * 37.0, 90.0) < 2.0:
		c = p[3]
	return c


## Штукатурка; кое-где отвалилась — виден кирпич.
func tex_plaster(u: float, v: float, col: Color) -> Color:
	var s := hh(int(u / 3), int(v / 3), 52)
	var c := col
	if s < 70:
		c = col.darkened(0.05)
	elif s > 990:
		c = col.lightened(0.04)
	var n := noise2.get_noise_2d(u * 0.9, v * 0.9 + 300.0)
	if n > 0.55:
		return tex_stone(u, v, Color8(176, 100, 74), 10.0)
	return c


## Стена: материал + балки фахверка + особенности (дверь, окна, вывеска) + затенение.
func tex_wall(u: float, v: float, l1: float, l2: float, spec: Dictionary) -> Color:
	var feats: Array = spec.get("feats", [])
	for f: Dictionary in feats:
		var fc: Color = _feature(f, u, v)
		if fc.a > 0.0:
			return _ao(fc, v, l2, spec)
	return _ao(_material(u, v, l1, l2, spec), v, l2, spec)


func _material(u: float, v: float, l1: float, l2: float, spec: Dictionary) -> Color:
	var mat: String = spec["mat"]
	var col: Color = spec["col"]
	var wood: Color = spec.get("wood", TIMBER)
	if mat == "stone":
		return tex_stone(u, v, col)
	if mat == "planks":
		if v < 14.0:
			return tex_stone(u, v, Color8(128, 122, 116), 7.0)
		return tex_planks(u, v, col)
	if v < 16.0:
		return tex_stone(u, v, Color8(132, 126, 118), 8.0)
	var c := tex_plaster(u, v, col)
	var bw := 10.0
	var wp := tones(wood)
	var floors: int = spec.get("floors", 1)
	var top: float = spec.get("wall_h", l2)
	var beam := false
	if u < bw or u > l1 - bw:
		beam = true
	var stp := l1 / maxf(1.0, roundf(l1 / 64.0))
	if fmod(u + bw * 0.5, stp) < bw:
		beam = true
	if (v >= 16.0 and v < 16.0 + bw) or (v > top - bw and v <= top):
		beam = true
	for fl in range(1, floors):
		var fy := 16.0 + (top - 16.0) * fl / floors
		if absf(v - fy) < bw * 0.5:
			beam = true
	if not beam and v < top:
		var fh := (top - 16.0) / floors
		var fl2 := int((v - 16.0) / fh)
		var vb := 16.0 + fl2 * fh
		var vt := vb + fh
		for side: int in [0, 1]:
			var ua := bw if side == 0 else l1 - bw
			var ub := stp if side == 0 else l1 - stp
			var t := (v - vb) / (vt - vb)
			var ul := lerpf(ua, ub, t)
			if absf(u - ul) < 5.0 and t > 0.05 and t < 0.95:
				beam = true
	if beam:
		c = wp[1]
		if hh(int(u / 4), int(v / 2), 53) < 120:
			c = wp[2]
		if hh(int(u), int(v / 6), 54) < 30:
			c = wp[0]
	return c


func _ao(c: Color, v: float, l2: float, spec: Dictionary) -> Color:
	if v < 10.0:
		c = c.darkened((10.0 - v) * 0.03)
	if spec.get("eave", true) and v > l2 - 22.0:
		c = c.darkened((v - (l2 - 22.0)) / 22.0 * 0.38)
	return c


func _arch_in(u: float, v: float, c: float, w: float, h: float) -> bool:
	if absf(u - c) > w * 0.5 or v < 0.0 or v > h:
		return false
	var top := h - w * 0.5
	if v > top:
		var dx := u - c
		var dy := v - top
		return dx * dx + dy * dy <= w * w * 0.25
	return true


## Дверь, окно, вывеска, знамя на стене (в координатах стены, v снизу вверх).
func _feature(f: Dictionary, u: float, v: float) -> Color:
	match f["t"]:
		"door":
			var c: float = f["u"]
			var w: float = f["w"]
			var h: float = f["h"]
			var arch: bool = f.get("arch", true)
			var outer := _arch_in(u, v, c, w + 14.0, h + 7.0) if arch else (absf(u - c) <= w * 0.5 + 7.0 and v >= 0.0 and v <= h + 7.0)
			if not outer:
				return NONE
			var inner := _arch_in(u, v, c, w, h) if arch else (absf(u - c) <= w * 0.5 and v <= h)
			if not inner:
				var s := hh(int((u - c) / 7.0 + 20), int(v / 9.0), 55)
				return Color8(150, 144, 134) if s % 3 != 0 else Color8(120, 114, 106)
			var p := tones(f.get("col", Color8(120, 72, 44)))
			var du := u - (c - w * 0.5)
			var pc: Color = p[1] if int(du / 12.0) % 2 == 0 else (p[1] as Color).darkened(0.08)
			if fmod(du, 12.0) < 2.0:
				pc = p[3]
			elif fmod(du, 12.0) < 4.0:
				pc = (p[0] as Color).darkened(0.05)
			for bv: float in [h * 0.25, h * 0.62]:
				if absf(v - bv) < 3.0:
					pc = Color8(64, 62, 70) if v < bv + 1 else Color8(120, 118, 128)
			if absf(u - (c + w * 0.3)) < 3.0 and absf(v - h * 0.45) < 3.0:
				pc = Color8(230, 196, 90)
			return pc
		"win":
			var c: float = f["u"]
			var w: float = f["w"]
			var h: float = f["h"]
			var v0: float = f["v"]
			var arch: bool = f.get("arch", false)
			var vv := v - v0
			var du := u - c
			var shut: Color = f.get("shut", NONE)
			if shut.a > 0.0 and vv >= -2.0 and vv <= h + 2.0 and absf(du) > w * 0.5 + 5.0 and absf(du) <= w * 0.5 + 5.0 + w * 0.42:
				var sp := tones(shut)
				var sc: Color = sp[1]
				if fmod(vv + 10.0, 8.0) < 2.0:
					sc = sp[3]
				if absf(absf(du) - (w * 0.5 + 5.0)) < 2.0:
					sc = sp[2]
				return sc
			if f.get("box", true) and vv < -3.0 and vv > -14.0 and absf(du) < w * 0.5 + 6.0:
				if vv > -6.0:
					var fl := hh(int(u / 4), 0, 56)
					if fl % 3 == 0:
						var fc: Array = [Color8(236, 90, 110), Color8(250, 210, 90), Color8(250, 250, 240), Color8(210, 120, 220)]
						return fc[fl % 4]
					return LEAF[1] if fl % 2 == 0 else LEAF[2]
				return Color8(76, 46, 32) if vv < -12.0 else Color8(116, 72, 46)
			var inside := _arch_in(u, vv, c, w, h) if arch else (absf(du) <= w * 0.5 and vv >= 0.0 and vv <= h)
			var frame := _arch_in(u, vv + 5.0, c, w + 10.0, h + 10.0) if arch else (absf(du) <= w * 0.5 + 5.0 and vv >= -5.0 and vv <= h + 5.0)
			if not frame:
				return NONE
			if not inside:
				return Color8(100, 64, 44) if vv > 0.0 else Color8(140, 96, 64)
			var t := clampf(vv / h, 0.0, 1.0)
			var g := Color8(96, 140, 196).lerp(Color8(40, 56, 98), t)
			if fposmod(du + vv * 0.8, 22.0) < 3.0:
				g = Color8(196, 224, 248)
			if f.get("warm", true) and t < 0.45 and hh(int(u / 4), int(v / 4), 57) < 300:
				g = Color8(240, 192, 110)
			if absf(du) < 2.0 or absf(vv - h * 0.5) < 2.0:
				g = Color8(80, 52, 36)
			return g
		"sign":
			var c: float = f["u"]
			var v0: float = f["v"]
			var du := u - c
			var vv := v - v0
			if absf(du) > 26.0 or vv < 0.0 or vv > 44.0:
				return NONE
			if absf(du) > 23.0 or vv < 3.0 or vv > 41.0:
				return Color8(60, 38, 28)
			var ic: Image = icons.get(f["icon"], null)
			if ic:
				var ix := int((du + 20.0) / 40.0 * ic.get_width())
				var iy := int((41.0 - vv) / 38.0 * ic.get_height())
				if ix >= 0 and iy >= 0 and ix < ic.get_width() and iy < ic.get_height():
					var pc := ic.get_pixel(ix, iy)
					if pc.a > 0.5:
						return pc
			var bp := tones(f.get("col", Color8(150, 100, 62)))
			return bp[0] if vv > 37.0 else (bp[1] if hh(int(u / 6), int(v / 2), 58) > 100 else bp[2])
		"banner":
			var c: float = f["u"]
			var v0: float = f["v"]
			var du := u - c
			var vv := v0 - v
			if absf(du) > 12.0 or vv < 0.0 or vv > 64.0:
				return NONE
			if vv > 52.0 and absf(du) * 1.2 < vv - 52.0:
				return NONE
			var bc: Color = f["col"]
			if vv < 4.0:
				return Color8(220, 180, 70)
			if absf(du) > 9.0:
				return bc.darkened(0.25)
			var ic: Image = icons.get(f.get("icon", ""), null)
			if ic and vv > 14.0 and vv < 38.0:
				var ix := int((du + 12.0) / 24.0 * ic.get_width())
				var iy := int((vv - 14.0) / 24.0 * ic.get_height())
				if ix >= 0 and iy >= 0 and ix < ic.get_width() and iy < ic.get_height() and ic.get_pixel(ix, iy).a > 0.5:
					return ic.get_pixel(ix, iy)
			return bc
	return NONE


## Фронтон: пятиугольник под линией крыши (k0 — высота крыши над стеной у края).
func tex_gable(u: float, v: float, l1: float, l2: float, spec: Dictionary) -> Color:
	var half := l1 * 0.5
	var k0: float = spec.get("k0", 0.0)
	var lim := k0 + (l2 - k0) * (1.0 - absf(u - half) / half)
	if v > lim:
		return NONE
	var s := spec.duplicate()
	s["feats"] = spec.get("gfeats", [])
	s["eave"] = false
	s["floors"] = 1
	s["wall_h"] = 9999.0
	var c := tex_wall(u, v + 40.0, l1, l2 + 40.0, s)
	if spec["mat"] == "timber":
		var wp := tones(spec.get("wood", TIMBER))
		var fc := _feature_any(spec.get("gfeats", []), u, v + 40.0)
		if absf(u - half) < 5.0 and fc.a <= 0.0:
			c = wp[1]
		if v < 9.0:
			c = wp[1] if v > 2.0 else wp[3]
	var edge := lim - v
	if edge < 18.0:
		c = c.darkened((18.0 - edge) / 18.0 * 0.45)
	return c


func _feature_any(feats: Array, u: float, v: float) -> Color:
	for f: Dictionary in feats:
		var fc: Color = _feature(f, u, v)
		if fc.a > 0.0:
			return fc
	return NONE


# ---------------------------------- части построек ----------------------------------

func walls(cv: Cv, x0: float, y0: float, w: float, d: float, h: float, front: Dictionary, side: Dictionary) -> void:
	front["wall_h"] = h
	side["wall_h"] = h
	quad(cv, Vector3(x0, y0 + d, 0), Vector3(w, 0, 0), Vector3(0, 0, h), Vector3(0, 1, 0), tex_wall.bind(front))
	quad(cv, Vector3(x0 + w, y0 + d, 0), Vector3(0, -d, 0), Vector3(0, 0, h), Vector3(1, 0, 0), tex_wall.bind(side))
	for dx: float in [0.0, w]:
		for dy: float in [0.0, d]:
			spts.append(Vector3(x0 + dx, y0 + dy, h))
	var wood: Color = front.get("wood", TIMBER)
	if front["mat"] != "stone":
		box(cv, Vector3(x0 + w - 6, y0 + d - 6, 0), Vector3(10, 10, h), tex_wood.bind(wood), tex_wood.bind(wood), flat(wood))


## Крыша, конёк вдоль X (передний скат смотрит на +Y). part: "back" — до стен, "front" — после.
func roof_x(cv: Cv, x0: float, y0: float, w: float, d: float, h: float, o: float, rise: float, col: Color, kind: String, part: String, gable: Dictionary, moss := 0.04) -> void:
	var a := d * 0.5 + o
	var t := 9.0
	var board := Color8(92, 56, 38)
	var rt := tex_roof.bind(col, kind, moss)
	if part == "back":
		quad(cv, Vector3(x0 - o, y0 - o, h), Vector3(w + 2 * o, 0, 0), Vector3(0, a, rise), Vector3(0, -rise, a), rt)
		spts.append(Vector3(x0 - o, y0 + d * 0.5, h + rise))
		spts.append(Vector3(x0 + w + o, y0 + d * 0.5, h + rise))
		return
	gable["k0"] = o * rise / a
	quad(cv, Vector3(x0 + w, y0 + d, h), Vector3(0, -d, 0), Vector3(0, 0, rise), Vector3(1, 0, 0), tex_gable.bind(gable))
	quad(cv, Vector3(x0 - o, y0 + d + o, h), Vector3(w + 2 * o, 0, 0), Vector3(0, -a, rise), Vector3(0, rise, a), rt)
	quad(cv, Vector3(x0 + w + o, y0 + d * 0.5, h + rise - t), Vector3(0, -a, -rise), Vector3(0, 0, t), Vector3(1, 0, 0), tex_board.bind(board))
	quad(cv, Vector3(x0 + w + o, y0 + d + o, h - t), Vector3(0, -a, rise), Vector3(0, 0, t), Vector3(1, 0, 0), tex_board.bind(board))
	quad(cv, Vector3(x0 - o, y0 + d + o, h - t), Vector3(w + 2 * o, 0, 0), Vector3(0, 0, t), Vector3(0, 1, 0), tex_board.bind(board))
	box(cv, Vector3(x0 - o, y0 + d * 0.5 - 5, h + rise - 3), Vector3(w + 2 * o, 10, 7), tex_board.bind(col.darkened(0.3)), tex_board.bind(col.darkened(0.4)), tex_board.bind(col.darkened(0.15)))


## Крыша, конёк вдоль Y (фронтон смотрит на +Y — к зрителю слева).
func roof_y(cv: Cv, x0: float, y0: float, w: float, d: float, h: float, o: float, rise: float, col: Color, kind: String, part: String, gable: Dictionary, moss := 0.04) -> void:
	var a := w * 0.5 + o
	var t := 9.0
	var board := Color8(92, 56, 38)
	var rt := tex_roof.bind(col, kind, moss)
	if part == "back":
		quad(cv, Vector3(x0 - o, y0 - o, h), Vector3(0, d + 2 * o, 0), Vector3(a, 0, rise), Vector3(-rise, 0, a), rt)
		spts.append(Vector3(x0 + w * 0.5, y0 - o, h + rise))
		spts.append(Vector3(x0 + w * 0.5, y0 + d + o, h + rise))
		return
	gable["k0"] = o * rise / a
	quad(cv, Vector3(x0, y0 + d, h), Vector3(w, 0, 0), Vector3(0, 0, rise), Vector3(0, 1, 0), tex_gable.bind(gable))
	quad(cv, Vector3(x0 - o, y0 + d + o, h - t), Vector3(a, 0, rise), Vector3(0, 0, t), Vector3(0, 1, 0), tex_board.bind(board))
	quad(cv, Vector3(x0 + w + o, y0 + d + o, h), Vector3(0, -(d + 2 * o), 0), Vector3(-a, 0, rise), Vector3(rise, 0, a), rt)
	quad(cv, Vector3(x0 + w * 0.5, y0 + d + o, h + rise - t), Vector3(a, 0, -rise), Vector3(0, 0, t), Vector3(0, 1, 0), tex_board.bind(board))
	quad(cv, Vector3(x0 + w + o, y0 + d + o, h - t), Vector3(0, -(d + 2 * o), 0), Vector3(0, 0, t), Vector3(1, 0, 0), tex_board.bind(board))
	box(cv, Vector3(x0 + w * 0.5 - 5, y0 - o, h + rise - 3), Vector3(10, d + 2 * o, 7), tex_board.bind(col.darkened(0.3)), tex_board.bind(col.darkened(0.4)), tex_board.bind(col.darkened(0.15)))


func chimney(cv: Cv, x: float, y: float, z0: float, hgt: float, smoke := true) -> void:
	var st := Color8(150, 138, 126)
	var stx := func(u: float, v: float, _a: float, _b: float) -> Color: return tex_stone(u, v, st, 12.0)
	box(cv, Vector3(x, y, z0), Vector3(26, 26, hgt), stx, stx, flat(Color8(40, 30, 30)))
	box(cv, Vector3(x - 3, y - 3, z0 + hgt), Vector3(32, 32, 6), flat(Color8(110, 104, 98)), flat(Color8(110, 104, 98)), func(u: float, v: float, _a: float, _b: float) -> Color:
		return Color8(30, 22, 22) if u > 6 and u < 26 and v > 6 and v < 26 else Color8(130, 124, 118))
	if smoke:
		var top := pr(Vector3(x + 13, y + 13, z0 + hgt + 6))
		for i in 6:
			var r := 7.0 + i * 2.6
			var p := top + Vector2(i * 7.0 + sin(i * 1.3) * 5.0, -14.0 - i * 15.0)
			cv.ell(p.x, p.y, r, r * 0.85, Color(0.9, 0.9, 0.94, 0.5 - i * 0.07))
			cv.ell(p.x - r * 0.3, p.y - r * 0.3, r * 0.5, r * 0.4, Color(1, 1, 1, 0.3 - i * 0.04))


## Куст на земле.
func bush(cv: Cv, x: float, y: float, r: float, flowers := true, sd := 1) -> void:
	ball3(cv, Vector3(x, y, r * 0.7), r, LEAF, 0.85, true, sd)
	if flowers:
		var c := pr(Vector3(x, y, r * 0.7))
		var cols := [Color8(240, 90, 110), Color8(250, 240, 250), Color8(250, 210, 90)]
		for i in 5:
			var p := c + Vector2((hh(i, sd, 59) % 100 - 50) * r / 60.0, (hh(i, sd, 60) % 100 - 60) * r / 80.0)
			cv.rect(p.x, p.y, 3, 3, cols[(i + sd) % 3])
	spts.append(Vector3(x, y, r * 1.4))


## Крыльцо-ступенька перед дверью.
func porch(cv: Cv, u: float, y: float, w: float) -> void:
	var st := Color8(156, 150, 138)
	var sf := func(uu: float, vv: float, _a: float, _b: float) -> Color: return tex_stone(uu, vv + 4.0, st, 8.0)
	box(cv, Vector3(u - w * 0.5, y, 0), Vector3(w, 16, 8), sf, sf, func(uu: float, vv: float, _a: float, _b: float) -> Color: return tex_stone(uu, vv, st.lightened(0.08), 16.0))


func crate3(cv: Cv, p: Vector3, s: float, fruit := NONE) -> void:
	var wood := Color8(176, 126, 74)
	var t := func(u: float, v: float, l1: float, l2: float) -> Color:
		var c := tex_planks(u, v, wood)
		if u < 4 or u > l1 - 4 or v < 4 or v > l2 - 4:
			c = wood.darkened(0.3)
		return c
	box(cv, p, Vector3(s, s, s * 0.7), t, t, func(u: float, v: float, l1: float, l2: float) -> Color:
		if u < 4 or u > l1 - 4 or v < 4 or v > l2 - 4:
			return wood.darkened(0.1)
		return Color8(60, 40, 30))
	if fruit.a > 0.0:
		for i in 6:
			var q := p + Vector3(8 + (i % 3) * (s - 16) / 2.0, 8 + (i / 3) * (s - 16), s * 0.7 + 4)
			ball3(cv, q, 6, tones(fruit.lightened((i % 2) * 0.1)), 1.0)


func barrel3(cv: Cv, p: Vector3, r: float, hgt: float) -> void:
	var wood := tones(Color8(150, 98, 58))
	var c0 := pr(p)
	for yy in int(hgt):
		var bul := r + 3.0 * sin(PI * yy / hgt)
		for xx in range(int(-bul), int(bul) + 1):
			var t := (xx + bul) / (bul * 2.0)
			var c: Color = wood[0] if t < 0.22 else (wood[1] if t < 0.65 else (wood[2] if t < 0.9 else wood[3]))
			if int(xx + bul) % 10 < 2:
				c = c.darkened(0.25)
			if absf(yy - 6.0) < 2.5 or absf(yy - (hgt - 8.0)) < 2.5:
				c = Color8(70, 70, 82) if t > 0.3 else Color8(130, 130, 140)
			cv.put(int(c0.x + xx), int(c0.y - yy), c)
	cv.ell(c0.x, c0.y - hgt, r, r * 0.5, wood[2])
	cv.ell(c0.x, c0.y - hgt, r - 4, (r - 4) * 0.5, Color8(110, 70, 42))
	spts.append(p + Vector3(0, 0, hgt))


# ===================================================================================
#                                   ПОСТРОЙКИ
# ===================================================================================

func _building(id: String, face: String) -> void:
	var fp := Vector2(192, 192)
	if LAY.FIXED.has(id):
		var s: Vector2 = LAY.FIXED[id]["size"]
		fp = s * U
	var mirror := face == "x"
	LIGHT = (Vector3(LIGHT_Y.y, LIGHT_Y.x, LIGHT_Y.z) if mirror else LIGHT_Y).normalized()
	SHD = Vector3(SHD_Y.y, SHD_Y.x, 0) if mirror else SHD_Y
	var cw := 900
	var ch := 900
	var anchor := Vector2(450, 700)
	var center := Vector3(fp.x / 2.0, fp.y / 2.0, 0)
	O = Vector2.ZERO
	O = anchor - pr(center)
	spts = []
	var cv := Cv.new(cw, ch)
	var door: Vector3 = call("_b_" + id, cv)
	var pts := PackedVector2Array()
	for c: Vector3 in [Vector3(0, 0, 0), Vector3(fp.x, 0, 0), Vector3(fp.x, fp.y, 0), Vector3(0, fp.y, 0)]:
		pts.append(pr(c))
	for p: Vector3 in spts:
		pts.append(pr(Vector3(p.x, p.y, 0) + SHD * p.z))
	var hull := Geometry2D.convex_hull(pts)
	var sh := Cv.new(cw, ch)
	if hull.size() >= 3:
		sh.poly(hull, Color(0.06, 0.05, 0.14, 0.34))
	sh.img.blend_rect(cv.img, Rect2i(0, 0, cw, ch), Vector2i.ZERO)
	var img := sh.img
	var used := img.get_used_rect()
	img = img.get_region(used)
	var a := anchor - Vector2(used.position)
	var dp := (pr(door) - anchor) / ART
	var top := 0.0
	for p: Vector3 in spts:
		top = minf(top, pr(p).y - anchor.y)
	if mirror:
		img.flip_x()
		a.x = img.get_width() - a.x
		dp.x = -dp.x
	var name := "b_%s_%s" % [id, face]
	_save(img, name)
	meta["sprites"][name] = {"anchor": [a.x, a.y], "door": [dp.x, dp.y], "top": top / ART}
	print("building ", name, " ", img.get_size())


## Обычный дом по описанию. Возвращает точку перед дверью.
func _house(cv: Cv, s: Dictionary) -> Vector3:
	var x0: float = s.get("x0", 18.0)
	var y0: float = s.get("y0", 22.0)
	var w: float = s.get("w", 156.0)
	var d: float = s.get("d", 150.0)
	var h: float = s.get("h", 150.0)
	var o: float = s.get("o", 16.0)
	var rise: float = s.get("rise", 110.0)
	var ridge: String = s.get("ridge", "y")
	var roof: Color = s["roof"]
	var kind: String = s.get("kind", "tile")
	var moss: float = s.get("moss", 0.04)
	var front: Dictionary = s["front"]
	var side: Dictionary = s["side"]
	var gable: Dictionary = s.get("gable", {})
	gable["mat"] = front["mat"]
	gable["col"] = front["col"]
	gable["wood"] = front.get("wood", TIMBER)
	var rf: Callable = roof_y if ridge == "y" else roof_x
	rf.call(cv, x0, y0, w, d, h, o, rise, roof, kind, "back", gable, moss)
	if s.has("chimney"):
		var c: Vector2 = s["chimney"]
		chimney(cv, c.x, c.y, h - 10.0, rise + 60.0)
	if s.has("pre"):
		(s["pre"] as Callable).call(cv)
	walls(cv, x0, y0, w, d, h, front, side)
	if s.has("mid"):
		(s["mid"] as Callable).call(cv)
	rf.call(cv, x0, y0, w, d, h, o, rise, roof, kind, "front", gable, moss)
	var du: float = s.get("door_u", w * 0.5)
	porch(cv, x0 + du, y0 + d, 70.0)
	for b: Array in s.get("bushes", []):
		bush(cv, x0 + float(b[0]), y0 + d + 14.0, float(b[1]), true, int(b[0]))
	if s.has("post"):
		(s["post"] as Callable).call(cv)
	return Vector3(x0 + du, y0 + d + 20.0, 0)


func _b_workshop(cv: Cv) -> Vector3:
	var front := {"mat": "timber", "col": PLASTER, "wood": TIMBER, "feats": [
		{"t": "door", "u": 46.0, "w": 52.0, "h": 104.0, "col": Color8(140, 84, 48)},
		{"t": "win", "u": 100.0, "v": 56.0, "w": 30.0, "h": 44.0, "shut": Color8(70, 120, 90)},
		{"t": "sign", "u": 100.0, "v": 106.0, "icon": "gear", "col": Color8(150, 100, 62)}]}
	var side := {"mat": "timber", "col": PLASTER, "wood": TIMBER, "feats": [
		{"t": "win", "u": 30.0, "v": 58.0, "w": 30.0, "h": 40.0},
		{"t": "win", "u": 118.0, "v": 58.0, "w": 30.0, "h": 40.0}]}
	var gable := {"gfeats": [{"t": "win", "u": 63.0, "v": 52.0, "w": 26.0, "h": 34.0, "arch": true, "box": false}]}
	var lean := func(c: Cv) -> void:
		# Навес с верстаком у правой стены.
		var wood := Color8(120, 78, 48)
		box(c, Vector3(146, 62, 0), Vector3(30, 92, 44), func(u: float, v: float, _a: float, _b: float) -> Color: return tex_planks(u, v, wood),
			func(u: float, v: float, _a: float, _b: float) -> Color: return tex_planks(u, v, wood.darkened(0.1)),
			func(u: float, v: float, _a: float, _b: float) -> Color: return tex_wood(v, u, 92, 30, Color8(170, 120, 76)))
		box(c, Vector3(152, 80, 44), Vector3(8, 30, 6), flat(Color8(170, 176, 190)), flat(Color8(130, 136, 150)), flat(Color8(210, 214, 226)))
		box(c, Vector3(156, 124, 44), Vector3(14, 10, 10), flat(Color8(120, 80, 50)), flat(Color8(96, 64, 40)), flat(Color8(150, 104, 66)))
		ball3(c, Vector3(166, 64, 62), 14, tones(Color8(132, 128, 124)), 1.0)
		for p: Vector2 in [Vector2(182, 56), Vector2(182, 160)]:
			box(c, Vector3(p.x, p.y, 0), Vector3(8, 8, 94), tex_wood.bind(TIMBER), tex_wood.bind(TIMBER), flat(TIMBER))
		quad(c, Vector3(196, 170, 92), Vector3(0, -122, 0), Vector3(-52, 0, 30), Vector3(30, 0, 52), func(u: float, v: float, _a: float, _b: float) -> Color:
			var cc := Color8(70, 140, 96) if int(u / 16.0) % 2 == 0 else Color8(236, 228, 200)
			if v < 6.0:
				cc = cc.darkened(0.25)
			return cc)
		spts.append(Vector3(196, 170, 92))
	var post := func(c: Cv) -> void:
		barrel3(c, Vector3(4, 180, 0), 16, 40)
		crate3(c, Vector3(148, 172, 0), 28)
	return _house(cv, {"x0": 18.0, "y0": 24.0, "w": 126.0, "d": 146.0, "h": 150.0, "rise": 96.0, "ridge": "y",
		"roof": Color8(198, 104, 54), "front": front, "side": side, "gable": gable, "chimney": Vector2(34, 70),
		"door_u": 46.0, "mid": lean, "post": post, "moss": 0.05, "bushes": [[90, 15]]})


func _b_merchant(cv: Cv) -> Vector3:
	var wall := Color8(240, 226, 196)
	var front := {"mat": "timber", "col": wall, "wood": Color8(104, 62, 40), "feats": [
		{"t": "door", "u": 132.0, "w": 48.0, "h": 100.0, "col": Color8(70, 120, 96)},
		{"t": "win", "u": 58.0, "v": 34.0, "w": 76.0, "h": 50.0, "box": false},
		{"t": "sign", "u": 58.0, "v": 108.0, "icon": "coin", "col": Color8(150, 100, 62)}]}
	var side := {"mat": "timber", "col": wall, "wood": Color8(104, 62, 40), "feats": [
		{"t": "win", "u": 62.0, "v": 50.0, "w": 30.0, "h": 40.0, "shut": Color8(170, 70, 60)}]}
	var gable := {"gfeats": [{"t": "win", "u": 63.0, "v": 34.0, "w": 22.0, "h": 28.0, "arch": true, "box": false}]}
	var post := func(c: Cv) -> void:
		var awn := func(u: float, v: float, _a: float, l2: float) -> Color:
			var cc := Color8(66, 142, 92) if int(u / 18.0) % 2 == 0 else Color8(240, 234, 210)
			if v > l2 - 6.0:
				cc = cc.darkened(0.15)
			return cc
		quad(c, Vector3(12, 144, 124), Vector3(170, 0, 0), Vector3(0, 40, -28), Vector3(0, 28, 40), awn)
		for i in 10:
			var p := pr(Vector3(20 + i * 17.0, 184, 96))
			c.ell(p.x, p.y, 9, 5, Color8(66, 142, 92) if i % 2 == 0 else Color8(240, 234, 210))
		crate3(c, Vector3(8, 154, 0), 32, Color8(220, 60, 60))
		crate3(c, Vector3(44, 158, 0), 30, Color8(240, 160, 50))
		crate3(c, Vector3(78, 156, 0), 30, Color8(130, 200, 80))
		barrel3(c, Vector3(186, 178, 0), 15, 40)
		spts.append(Vector3(182, 184, 96))
	return _house(cv, {"x0": 10.0, "y0": 18.0, "w": 172.0, "d": 124.0, "h": 140.0, "rise": 90.0, "ridge": "x",
		"roof": Color8(206, 108, 58), "front": front, "side": side, "gable": gable, "chimney": Vector2(140, 34),
		"door_u": 132.0, "post": post, "moss": 0.03})


func _b_portal(cv: Cv) -> Vector3:
	var stone := Color8(150, 146, 168)
	var st := func(u: float, v: float, _a: float, _b: float) -> Color: return tex_stone(u, v, stone, 14.0)
	var st2 := func(u: float, v: float, _a: float, _b: float) -> Color: return tex_stone(u, v, stone.darkened(0.05), 14.0)
	box(cv, Vector3(-10, -6, 0), Vector3(212, 102, 10), st, st2, func(u: float, v: float, _a: float, _b: float) -> Color: return tex_stone(u, v, stone.lightened(0.05), 20.0))
	box(cv, Vector3(8, 10, 10), Vector3(176, 70, 10), st, st2, func(u: float, v: float, _a: float, _b: float) -> Color: return tex_stone(u, v, stone.lightened(0.08), 20.0))
	# Вихрь в проёме.
	var vortex := func(u: float, v: float, _a: float, _b: float) -> Color:
		var cx := 56.0
		var top := 154.0
		var dx := (u - cx) / 56.0
		if v > top:
			var dy := (v - top) / 56.0
			if dx * dx + dy * dy > 1.0:
				return NONE
		var ry := (v - 100.0) / 110.0
		var r := sqrt(dx * dx + ry * ry * 0.7)
		var ang := atan2(ry, dx)
		var sw := sin(ang * 3.0 + r * 10.0)
		var c := Color8(40, 20, 84)
		if sw > 0.6:
			c = Color8(156, 96, 236)
		elif sw > 0.1:
			c = Color8(100, 54, 176)
		elif sw < -0.7:
			c = Color8(80, 160, 236)
		if r < 0.3:
			c = Color8(236, 226, 255) if r < 0.17 else Color8(176, 146, 250)
		return c
	quad(cv, Vector3(40, 46, 20), Vector3(112, 0, 0), Vector3(0, 0, 210), Vector3(0, 1, 0), vortex, false)
	for px: float in [12.0, 152.0]:
		var rune := func(u: float, v: float, _a: float, _b: float) -> Color:
			var c := tex_stone(u, v, stone, 20.0)
			if absf(u - 14.0) < 4.0 and fmod(v, 46.0) > 18.0 and fmod(v, 46.0) < 34.0 and v > 20.0 and v < 200.0:
				c = Color8(120, 236, 255)
			return c
		box(cv, Vector3(px, 30, 20), Vector3(28, 30, 200), rune, st2, flat(stone.lightened(0.1)))
		box(cv, Vector3(px - 6, 24, 220), Vector3(40, 42, 14), st, st2, flat(stone.lightened(0.15)))
	var arch := func(u: float, v: float, _a: float, _b: float) -> Color:
		var dx := u - 90.0
		var dy := v + 160.0 - 234.0
		var d := sqrt(dx * dx + dy * dy)
		if d > 88.0 or d < 56.0 or v + 160.0 < 232.0:
			return NONE
		var a := atan2(dy, dx)
		var seg := int(a / (PI / 9.0))
		var c := Color8(166, 162, 184) if seg % 2 == 0 else Color8(150, 146, 168)
		if absf(fmod(a, PI / 9.0)) < 0.03 or d > 85.0 or d < 58.0:
			c = Color8(96, 92, 112)
		if absf(dx) < 12.0 and dy > 70.0:
			c = Color8(120, 236, 255) if d < 80.0 and d > 66.0 else Color8(180, 176, 196)
		return c
	quad(cv, Vector3(6, 60, 160), Vector3(180, 0, 0), Vector3(0, 0, 170), Vector3(0, 1, 0), arch)
	for px: float in [-4.0, 196.0]:
		var p := pr(Vector3(px, 70, 10))
		cv.poly(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-4, -40), p + Vector2(2, -48), p + Vector2(8, 0)]), Color8(110, 200, 250))
		cv.poly(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(-1, -38), p + Vector2(2, -42), p + Vector2(3, 0)]), Color8(220, 246, 255))
	spts.append(Vector3(96, 60, 300))
	return Vector3(96, 104, 0)


func _b_mine(cv: Cv) -> Vector3:
	var rock := tones(Color8(146, 136, 124))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var rocks: Array[Vector3] = []
	for i in 26:
		var x := rng.randf_range(6, 186)
		var y := rng.randf_range(6, 140)
		var hgt := 150.0 - Vector2(x - 96, (y - 70) * 1.3).length() * 1.2
		rocks.append(Vector3(x, y, maxf(16.0, rng.randf_range(0.4, 1.0) * hgt)))
	rocks.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x + a.y < b.x + b.y)
	for r: Vector3 in rocks:
		if r.y > 120 and r.x > 60 and r.x < 140:
			continue
		var pal := rock.duplicate()
		if r.z > 110:
			pal = [Color8(150, 180, 90), Color8(120, 130, 100), Color8(100, 96, 90), Color8(66, 60, 58)]
		ball3(cv, r, rng.randf_range(24, 40), pal, 0.8, false, int(r.x * 7 + r.y), true)
		spts.append(r + Vector3(0, 0, 20))
	for i in 60:
		var p := pr(Vector3(rng.randf_range(20, 170), rng.randf_range(20, 120), rng.randf_range(20, 120)))
		if cv.img.get_pixel(clampi(int(p.x), 0, cv.w - 1), clampi(int(p.y), 0, cv.h - 1)).a > 0.5 and cv.img.get_pixel(clampi(int(p.x) + 3, 0, cv.w - 1), clampi(int(p.y) + 2, 0, cv.h - 1)).a > 0.5:
			cv.rect(p.x, p.y, 3, 2, Color8(250, 214, 90))
			cv.rect(p.x + 1, p.y, 1, 1, Color8(255, 250, 200))
	var dark := func(_u: float, v: float, _a: float, l2: float) -> Color:
		return Color8(14, 10, 12).lerp(Color8(54, 42, 36), clampf(1.0 - v / l2, 0, 1) * 0.8)
	quad(cv, Vector3(70, 150, 0), Vector3(56, 0, 0), Vector3(0, 0, 100), Vector3(0, 1, 0), dark, false)
	var wood := Color8(130, 86, 52)
	for px: float in [60.0, 126.0]:
		box(cv, Vector3(px, 146, 0), Vector3(12, 14, 106), tex_wood.bind(wood), tex_wood.bind(wood), flat(wood))
	box(cv, Vector3(52, 144, 106), Vector3(94, 18, 14), tex_wood.bind(wood), tex_wood.bind(wood), tex_wood.bind(wood.lightened(0.1)))
	for i in 6:
		box(cv, Vector3(70, 156 + i * 9, 0), Vector3(56, 5, 3), flat(Color8(100, 70, 46)), flat(Color8(80, 56, 38)), flat(Color8(120, 84, 54)))
	for px: float in [80.0, 114.0]:
		box(cv, Vector3(px, 150, 3), Vector3(4, 56, 3), flat(Color8(150, 150, 162)), flat(Color8(110, 110, 122)), flat(Color8(200, 200, 210)))
	for r: Vector3 in [Vector3(30, 160, 20), Vector3(166, 156, 24), Vector3(16, 130, 40), Vector3(180, 128, 36)]:
		ball3(cv, r, 26, rock, 0.8, false, int(r.x * 3 + r.y), true)
	var lp := pr(Vector3(140, 150, 96))
	cv.rect(lp.x, lp.y, 12, 16, Color8(250, 214, 110))
	cv.rect(lp.x + 3, lp.y + 3, 6, 9, Color8(255, 250, 220))
	cv.rect(lp.x - 1, lp.y - 2, 14, 2, Color8(50, 44, 48))
	cv.rect(lp.x - 1, lp.y + 16, 14, 2, Color8(50, 44, 48))
	return Vector3(96, 206, 0)


# --------------- остальные постройки (пока простые, по общему виду) ---------------

func _simple(cv: Cv, mat: String, wall: Color, roof: Color, kind: String, ridge: String, icon: String, extra := {}) -> Vector3:
	var shut: Color = extra.get("shut", NONE)
	var feats: Array = [
		{"t": "door", "u": 78.0, "w": 52.0, "h": 104.0, "col": extra.get("door", Color8(130, 80, 48))},
		{"t": "win", "u": 30.0, "v": 56.0, "w": 30.0, "h": 40.0, "shut": shut},
		{"t": "win", "u": 128.0, "v": 56.0, "w": 30.0, "h": 40.0, "shut": shut},
		{"t": "sign", "u": 78.0, "v": 118.0, "icon": icon}]
	if extra.has("banner"):
		feats.append({"t": "banner", "u": 10.0, "v": 140.0, "col": extra["banner"], "icon": icon})
		feats.append({"t": "banner", "u": 146.0, "v": 140.0, "col": extra["banner"], "icon": icon})
	var sfeats: Array = [
		{"t": "win", "u": 46.0, "v": 58.0, "w": 30.0, "h": 40.0, "shut": shut},
		{"t": "win", "u": 106.0, "v": 58.0, "w": 30.0, "h": 40.0, "shut": shut}]
	var floors: int = extra.get("floors", 1)
	var h := 150.0 if floors == 1 else 230.0
	if floors > 1:
		feats.append({"t": "win", "u": 30.0, "v": 150.0, "w": 30.0, "h": 40.0})
		feats.append({"t": "win", "u": 128.0, "v": 150.0, "w": 30.0, "h": 40.0})
		sfeats.append({"t": "win", "u": 76.0, "v": 150.0, "w": 30.0, "h": 40.0})
	var front := {"mat": mat, "col": wall, "wood": TIMBER, "feats": feats, "floors": floors}
	var side := {"mat": mat, "col": wall, "wood": TIMBER, "feats": sfeats, "floors": floors}
	var s := {"x0": 18.0, "y0": 20.0, "w": 156.0, "d": 152.0, "h": h, "rise": extra.get("rise", 100.0), "ridge": ridge,
		"roof": roof, "kind": kind, "front": front, "side": side, "door_u": 78.0,
		"gable": {"gfeats": [{"t": "win", "u": 78.0, "v": 46.0, "w": 24.0, "h": 30.0, "arch": true, "box": false}]},
		"bushes": [[22, 14], [140, 13]], "moss": extra.get("moss", 0.03)}
	if extra.get("chimney", true):
		s["chimney"] = Vector2(120, 40) if ridge == "x" else Vector2(40, 60)
	if extra.has("post"):
		s["post"] = extra["post"]
	return _house(cv, s)


func _b_library(cv: Cv) -> Vector3:
	return _simple(cv, "timber", Color8(236, 226, 200), Color8(64, 94, 172), "tile", "x", "book", {"floors": 2, "shut": Color8(60, 96, 156)})


func _b_forge(cv: Cv) -> Vector3:
	var post := func(c: Cv) -> void:
		box(c, Vector3(120, 178, 0), Vector3(40, 22, 28), flat(Color8(90, 60, 40)), flat(Color8(70, 46, 32)), flat(Color8(110, 74, 50)))
		box(c, Vector3(124, 180, 28), Vector3(32, 18, 14), flat(Color8(84, 86, 100)), flat(Color8(64, 66, 80)), flat(Color8(140, 144, 160)))
	return _simple(cv, "stone", Color8(140, 134, 128), Color8(150, 66, 50), "tile", "y", "hammer", {"door": Color8(100, 60, 40), "post": post, "moss": 0.06})


func _b_infirmary(cv: Cv) -> Vector3:
	return _simple(cv, "timber", Color8(246, 244, 236), Color8(64, 146, 128), "tile", "x", "cross", {"door": Color8(220, 220, 214), "shut": Color8(80, 150, 110)})


func _b_treasury(cv: Cv) -> Vector3:
	return _simple(cv, "stone", Color8(184, 178, 162), Color8(112, 74, 150), "slate", "x", "coin", {"banner": Color8(110, 70, 150), "door": Color8(96, 60, 44)})


func _b_storage(cv: Cv) -> Vector3:
	return _simple(cv, "planks", Color8(156, 108, 68), Color8(176, 70, 56), "tile", "y", "box", {"moss": 0.05})


func _b_training(cv: Cv) -> Vector3:
	return _simple(cv, "timber", Color8(226, 210, 176), Color8(160, 84, 52), "tile", "y", "sword", {"shut": Color8(150, 60, 56)})


func _b_exchange(cv: Cv) -> Vector3:
	return _simple(cv, "planks", Color8(146, 100, 66), Color8(70, 140, 90), "tile", "x", "scales", {"chimney": false})


func _b_mentor(cv: Cv) -> Vector3:
	return _simple(cv, "timber", Color8(230, 212, 176), Color8(208, 170, 88), "thatch", "y", "star", {"rise": 110.0, "shut": Color8(60, 100, 170)})


# ===================================================================================
#                                    ИКОНКИ
# ===================================================================================

func _icons() -> void:
	for name: String in ["book", "hammer", "cross", "coin", "box", "gear", "scales", "potion", "sword", "star"]:
		var cv := Cv.new(20, 20)
		_icon(cv, 10, 10, name)
		icons[name] = cv.img


func _icon(cv: Cv, cx: int, cy: int, icon: String) -> void:
	var gold := Color8(242, 200, 80)
	var iron := Color8(180, 186, 200)
	match icon:
		"book":
			cv.rect(cx - 7, cy - 6, 14, 12, Color8(70, 90, 170))
			cv.rect(cx - 6, cy - 5, 12, 10, Color8(236, 228, 200))
			cv.rect(cx, cy - 5, 1, 10, Color8(150, 140, 120))
			cv.rect(cx - 5, cy - 3, 4, 1, Color8(150, 140, 120))
			cv.rect(cx + 2, cy - 3, 4, 1, Color8(150, 140, 120))
		"hammer":
			cv.line(Vector2(cx - 5, cy + 6), Vector2(cx + 2, cy - 1), Color8(150, 100, 60), 2)
			cv.rect(cx - 1, cy - 7, 9, 5, iron)
			cv.rect(cx - 1, cy - 7, 9, 1, Color.WHITE)
		"cross":
			cv.rect(cx - 2, cy - 7, 4, 14, Color8(220, 50, 60))
			cv.rect(cx - 7, cy - 2, 14, 4, Color8(220, 50, 60))
		"coin":
			cv.ell(cx, cy, 7, 7, Color8(180, 130, 40))
			cv.ell(cx, cy, 5.5, 5.5, gold)
			cv.rect(cx - 1, cy - 3, 2, 6, Color8(180, 130, 40))
		"box":
			cv.rect(cx - 7, cy - 6, 14, 12, Color8(186, 134, 80))
			cv.rect(cx - 7, cy - 1, 14, 2, Color8(110, 74, 44))
			cv.rect(cx - 1, cy - 6, 2, 12, Color8(110, 74, 44))
		"gear":
			cv.ell(cx, cy, 6, 6, iron)
			for a in 8:
				var v := Vector2.from_angle(a * TAU / 8.0) * 7.0
				cv.rect(cx + v.x - 1.5, cy + v.y - 1.5, 3, 3, iron)
			cv.ell(cx, cy, 2.5, 2.5, Color8(80, 70, 60))
		"scales":
			cv.rect(cx, cy - 7, 1, 12, gold)
			cv.rect(cx - 7, cy - 6, 15, 1, gold)
			cv.ell(cx - 6, cy, 3, 2, gold)
			cv.ell(cx + 7, cy, 3, 2, gold)
			cv.rect(cx - 3, cy + 5, 7, 2, gold)
		"potion":
			cv.ell(cx, cy + 2, 5, 5, Color8(220, 70, 90))
			cv.rect(cx - 1, cy - 7, 3, 4, Color8(200, 220, 230))
			cv.put(cx - 2, cy, Color.WHITE)
		"sword":
			cv.line(Vector2(cx - 6, cy + 6), Vector2(cx + 6, cy - 6), Color8(210, 216, 230), 2)
			cv.line(Vector2(cx - 6, cy + 1), Vector2(cx - 1, cy + 6), Color8(200, 160, 70), 2)
			cv.rect(cx - 8, cy + 6, 3, 3, Color8(140, 90, 50))
		"star":
			for k in 5:
				var a := -PI / 2.0 + k * TAU / 5.0
				cv.line(Vector2(cx, cy), Vector2(cx, cy) + Vector2.from_angle(a) * 8.0, Color8(250, 220, 100), 2)
			cv.ell(cx, cy, 3, 3, Color8(255, 240, 170))


# ===================================================================================
#                                    МЕЛОЧИ
# ===================================================================================

func _prop(name: String) -> void:
	LIGHT = LIGHT_Y.normalized()
	SHD = SHD_Y
	var cw := 420
	var ch := 480
	var anchor := Vector2(210, 400)
	O = anchor
	spts = []
	var cv := Cv.new(cw, ch)
	call("_p_" + name, cv)
	var sh := Cv.new(cw, ch)
	var pts := PackedVector2Array()
	for p: Vector3 in spts:
		pts.append(pr(Vector3(p.x, p.y, 0)))
		pts.append(pr(Vector3(p.x, p.y, 0) + SHD * p.z))
	if pts.size() >= 3:
		var hull := Geometry2D.convex_hull(pts)
		if hull.size() >= 3:
			sh.poly(hull, Color(0.06, 0.05, 0.14, 0.3))
	sh.img.blend_rect(cv.img, Rect2i(0, 0, cw, ch), Vector2i.ZERO)
	var img := sh.img
	var used := img.get_used_rect()
	img = img.get_region(used)
	var a := anchor - Vector2(used.position)
	_save(img, "p_" + name)
	meta["sprites"]["p_" + name] = {"anchor": [a.x, a.y]}


func _p_fountain(cv: Cv) -> void:
	var stone := Color8(176, 170, 160)
	var c := pr(Vector3.ZERO)
	for i in 18:
		cv.ell(c.x, c.y - i, 104, 52, stone.darkened(0.25 - i * 0.008) if i < 17 else stone)
	cv.ell(c.x, c.y - 18, 104, 52, stone.lightened(0.08))
	cv.ell(c.x, c.y - 18, 92, 45, Color8(130, 124, 116))
	cv.ell(c.x, c.y - 16, 88, 43, Color8(66, 134, 192))
	for iy in range(int(c.y - 60), int(c.y + 30)):
		for ix in range(int(c.x - 88), int(c.x + 88)):
			var nx := (ix + 0.5 - c.x) / 88.0
			var ny := (iy + 0.5 - (c.y - 16)) / 43.0
			if nx * nx + ny * ny > 1.0:
				continue
			if sin(ix * 0.16 + iy * 0.5) > 0.92 or hh(ix, iy, 93) < 6:
				cv.put(ix, iy, Color8(176, 224, 246))
			elif ny < -0.6:
				cv.put(ix, iy, Color8(56, 116, 172))
	for yy in 90:
		for xx in range(-12, 13):
			var t := (xx + 12) / 24.0
			cv.put(int(c.x + xx), int(c.y - 20 - yy), stone.lightened(0.12) if t < 0.3 else (stone if t < 0.7 else stone.darkened(0.2)))
	for i in 8:
		cv.ell(c.x, c.y - 108 - i, 38, 18, stone.darkened(0.2 - i * 0.02))
	cv.ell(c.x, c.y - 116, 38, 18, stone.lightened(0.1))
	cv.ell(c.x, c.y - 116, 30, 13, Color8(86, 156, 210))
	for s: int in [-1, 1]:
		for i in 26:
			var t := i / 25.0
			var p := Vector2(c.x + s * (20 + t * 46), c.y - 124 + t * t * 92 - t * 10)
			cv.ell(p.x, p.y, 3.5, 3.5, Color(0.82, 0.94, 1.0, 0.9))
	cv.ell(c.x, c.y - 132, 5, 12, Color(0.86, 0.96, 1.0, 0.9))
	spts.append(Vector3(-60, -60, 30))
	spts.append(Vector3(60, 60, 30))
	spts.append(Vector3(0, 0, 130))


func _p_lamp(cv: Cv) -> void:
	var c := pr(Vector3.ZERO)
	var iron := Color8(46, 44, 56)
	cv.ell(c.x, c.y - 4, 12, 6, iron)
	cv.rect(c.x - 4, c.y - 200, 8, 196, iron)
	cv.rect(c.x - 4, c.y - 200, 2, 196, Color8(100, 100, 118))
	cv.rect(c.x - 4, c.y - 206, 34, 5, iron)
	cv.rect(c.x + 22, c.y - 201, 4, 8, iron)
	cv.rect(c.x + 12, c.y - 194, 24, 30, iron)
	cv.rect(c.x + 15, c.y - 190, 18, 22, Color8(255, 210, 120))
	cv.rect(c.x + 20, c.y - 186, 8, 14, Color8(255, 250, 220))
	cv.rect(c.x + 10, c.y - 198, 28, 5, iron)
	spts.append(Vector3(0, 0, 200))


func _p_bench(cv: Cv) -> void:
	var wood := Color8(150, 100, 62)
	var w := func(u: float, v: float, l1: float, l2: float) -> Color: return tex_wood(u, v, l1, l2, wood)
	box(cv, Vector3(-40, -6, 0), Vector3(6, 6, 22), flat(Color8(60, 56, 64)), flat(Color8(44, 40, 50)), flat(Color8(80, 76, 86)))
	box(cv, Vector3(34, -6, 0), Vector3(6, 6, 22), flat(Color8(60, 56, 64)), flat(Color8(44, 40, 50)), flat(Color8(80, 76, 86)))
	box(cv, Vector3(-44, -12, 22), Vector3(88, 24, 6), w, w, w)
	box(cv, Vector3(-44, -16, 28), Vector3(88, 4, 30), w, w, w)


func _p_barrels(cv: Cv) -> void:
	barrel3(cv, Vector3(-18, -10, 0), 18, 50)
	barrel3(cv, Vector3(18, -4, 0), 18, 50)
	barrel3(cv, Vector3(0, 22, 0), 17, 46)


func _p_crates(cv: Cv) -> void:
	crate3(cv, Vector3(-30, -30, 0), 40)
	crate3(cv, Vector3(14, -22, 0), 34)
	crate3(cv, Vector3(-24, -24, 28), 30)


func _p_cart(cv: Cv) -> void:
	var iron := Color8(100, 96, 108)
	for p: Vector2 in [Vector2(-26, -20), Vector2(22, -20)]:
		var q := pr(Vector3(p.x, p.y, 10))
		cv.ell(q.x, q.y, 11, 11, Color8(48, 44, 52))
	box(cv, Vector3(-36, -20, 10), Vector3(72, 40, 34), flat(iron), flat(iron.darkened(0.2)), flat(Color8(70, 60, 56)))
	for i in 10:
		var oc: Array = [Color8(150, 140, 130), Color8(250, 210, 90), Color8(120, 110, 104)]
		ball3(cv, Vector3(-28 + (i % 5) * 14, -12 + (i / 5) * 18, 48), 9, tones(oc[i % 3]), 0.9)
	for p: Vector2 in [Vector2(-26, 22), Vector2(22, 22)]:
		var q := pr(Vector3(p.x, p.y, 10))
		cv.ell(q.x, q.y, 11, 11, Color8(48, 44, 52))
		cv.ell(q.x, q.y, 4, 4, Color8(140, 136, 146))


func _p_bush(cv: Cv) -> void:
	bush(cv, -18, 0, 22, true, 3)
	bush(cv, 16, 6, 20, true, 4)
	bush(cv, 0, -14, 24, true, 5)


func _p_flowers(cv: Cv) -> void:
	var cols := [Color8(240, 90, 110), Color8(250, 210, 90), Color8(250, 250, 250), Color8(170, 130, 240), Color8(240, 150, 80)]
	for i in 26:
		var p := pr(Vector3((hh(i, 0, 61) % 70) - 35.0, (hh(i, 1, 61) % 70) - 35.0, 0))
		cv.rect(p.x, p.y - 10, 2, 10, LEAF[2])
		cv.rect(p.x - 3, p.y - 6, 3, 2, LEAF[1])
		cv.rect(p.x - 3, p.y - 15, 7, 6, cols[i % cols.size()])
		cv.rect(p.x - 1, p.y - 13, 3, 2, Color8(255, 240, 160))


func _p_sign(cv: Cv) -> void:
	var wood := Color8(150, 100, 62)
	var w := func(u: float, v: float, l1: float, l2: float) -> Color: return tex_wood(u, v, l1, l2, wood)
	box(cv, Vector3(-5, -5, 0), Vector3(10, 10, 150), w, w, w)
	var b1 := func(u: float, v: float, l1: float, l2: float) -> Color:
		if u > l1 - 14.0 and absf(v - l2 * 0.5) > (l1 - u) * 1.2:
			return NONE
		var c := tex_wood(u, v, l1, l2, wood.lightened(0.05))
		if absf(v - l2 * 0.5) < 2.0 and u > 10 and u < 58:
			c = Color8(70, 44, 30)
		return c
	quad(cv, Vector3(-40, 6, 100), Vector3(80, 0, 0), Vector3(0, 0, 34), Vector3(0, 1, 0), b1)
	var b2 := func(u: float, v: float, l1: float, l2: float) -> Color:
		if u < 14.0 and absf(v - l2 * 0.5) > u * 1.1:
			return NONE
		return tex_wood(u, v, l1, l2, wood)
	quad(cv, Vector3(6, 40, 60), Vector3(0, -80, 0), Vector3(0, 0, 30), Vector3(1, 0, 0), b2)
	spts.append(Vector3(0, 0, 140))


## Дерево: ствол + крона из шаров. kind: 0 — круглое, 1 — тёмное лесное, 2 — молодое светлое.
func _tree(cv: Cv, kind: int, sd: int) -> void:
	var bark := tones(Color8(112, 76, 52))
	var c := pr(Vector3.ZERO)
	var ths: Array = [110.0, 90.0, 100.0]
	var rs: Array = [74.0, 68.0, 56.0]
	var th: float = ths[kind]
	var r: float = rs[kind]
	for yy in int(th):
		var half := 10.0 - yy * 0.03
		for xx in range(int(-half), int(half) + 1):
			var t := (xx + half) / (half * 2.0)
			var cc: Color = bark[0] if t < 0.3 else (bark[1] if t < 0.7 else bark[2])
			if hh(xx + 20, yy / 4, 62) < 120:
				cc = bark[3]
			cv.put(int(c.x + xx), int(c.y - yy), cc)
	cv.ell(c.x - 12, c.y - 3, 8, 4, bark[2])
	cv.ell(c.x + 12, c.y - 2, 9, 4, bark[2])
	var pal: Array = LEAF
	if kind == 1:
		pal = [Color8(110, 160, 72), Color8(70, 124, 56), Color8(44, 92, 48), Color8(26, 58, 38)]
	elif kind == 2:
		pal = [Color8(190, 220, 100), Color8(140, 190, 70), Color8(90, 150, 60), Color8(56, 104, 50)]
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var cz := th + r * 0.55
	var balls: Array = [[0.0, 0.0, cz, r]]
	for i in 7:
		var a := rng.randf() * TAU
		var dd := r * rng.randf_range(0.4, 0.68)
		balls.append([cos(a) * dd, sin(a) * dd, cz + rng.randf_range(-0.4, 0.5) * r, r * rng.randf_range(0.42, 0.6)])
	balls.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) + float(a[1]) - float(a[2]) * 0.3 < float(b[0]) + float(b[1]) - float(b[2]) * 0.3)
	for b: Array in balls:
		ball3(cv, Vector3(b[0], b[1], b[2]), b[3], pal, 0.9, true, sd + int(b[3]))
	spts.append(Vector3(0, 0, th + r))
	spts.append(Vector3(r * 0.5, -r * 0.5, th + r * 0.4))
	spts.append(Vector3(-r * 0.5, r * 0.5, th + r * 0.4))


func _p_tree(cv: Cv) -> void:
	_tree(cv, 0, 4242)


func _p_tree2(cv: Cv) -> void:
	_tree(cv, 2, 777)


func _p_tree3(cv: Cv) -> void:
	_tree(cv, 0, 9191)


func _p_ftree(cv: Cv) -> void:
	_tree(cv, 1, 31337)


func _p_ftree2(cv: Cv) -> void:
	_tree(cv, 1, 2718)


# ===================================================================================
#                                    ЗЕМЛЯ
# ===================================================================================

func _ground() -> void:
	var gw := LAY.WIDTH * ART
	var gh := LAY.HEIGHT * ART
	var img := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	# Вид земли с шагом 1/8 клетки (быстрее, чем считать на каждый пиксель).
	var R := 8
	var kn := (LAY.N + 8) * R
	var kinds := PackedByteArray()
	kinds.resize(kn * kn)
	for gj in kn:
		for gi in kn:
			kinds[gj * kn + gi] = LAY.kind_at((gi + 0.5) / R - 4.0, (gj + 0.5) / R - 4.0)
	var grass := [Color8(70, 122, 56), Color8(88, 144, 62), Color8(106, 160, 68), Color8(132, 180, 80)]
	var flowers := [Color8(240, 220, 110), Color8(236, 120, 140), Color8(250, 250, 240), Color8(150, 150, 236), Color8(240, 150, 80)]
	for y in gh:
		for x in gw:
			var cell := LAY.to_cell(Vector2(x / float(ART), y / float(ART)))
			var n := noise.get_noise_2d(x, y)
			var wn := noise2.get_noise_2d(x, y) * 0.12
			var ki := clampi(int((cell.x + wn + 4.0) * R), 0, kn - 1)
			var kj := clampi(int((cell.y - wn + 4.0) * R), 0, kn - 1)
			var k := kinds[kj * kn + ki]
			var gx := cell.x * U
			var gy := cell.y * U
			var c: Color
			match k:
				1:
					c = _paver(gx, gy, n)
					if wn > 0.07 and hh(x / 3, y / 3, 17) < 600:
						c = grass[1 + hh(x, y, 18) % 2]
				4:
					c = _lot(gx, gy, n, x, y)
				5:
					c = Color8(168, 138, 100) if n > -0.1 else Color8(150, 122, 88)
					if hh(x / 3, y / 3, 6) < 30:
						c = Color8(190, 176, 150)
					elif hh(x / 2, y / 2, 7) < 40:
						c = Color8(126, 100, 72)
				3:
					c = _water(cell, x, y)
				2:
					c = Color8(30, 58, 40) if hh(x / 4, y / 4, 8) > 300 else Color8(40, 72, 46)
				_:
					var t := clampi(int((n + 0.6) * 2.6), 0, 2)
					c = grass[t + 1]
					var s := hh(x, y / 4, 11)
					if s < 70:
						c = grass[0]
					elif s > 1006:
						c = grass[3]
					var f := hh(x / 3, y / 3, 12)
					if f < 3 and n < 0.1:
						c = flowers[hh(x / 3, y / 3, 13) % flowers.size()]
			img.set_pixel(x, y, c)
	var cv := Cv.new(1, 1)
	cv.img = img
	cv.w = gw
	cv.h = gh
	_lot_stakes(cv)
	_forest(cv)
	_save(cv.img, "ground")


func _paver(gx: float, gy: float, n: float) -> Color:
	var row := int(floor(gy / 16.0))
	var off := 16.0 if row % 2 == 0 else 0.0
	var lu := fposmod(gx + off, 32.0)
	var lv := fposmod(gy, 16.0)
	var id := int(floor((gx + off) / 32.0))
	var base := Color8(184, 166, 132)
	var v := hh(id, row, 70) % 7
	if v == 0:
		base = Color8(164, 158, 146)
	elif v == 1:
		base = Color8(196, 160, 120)
	elif v == 2:
		base = base.darkened(0.08)
	if n > 0.3:
		base = base.darkened((n - 0.3) * 0.35)
	if lu < 2.0 or lv < 2.0:
		return Color8(116, 102, 82)
	if lv < 4.0 or lu < 4.0:
		return base.lightened(0.1)
	if lv > 13.5 or lu > 29.5:
		return base.darkened(0.16)
	return base


func _lot(gx: float, gy: float, n: float, x: int, y: int) -> Color:
	var c := Color8(150, 118, 84) if n > 0.0 else Color8(138, 108, 78)
	if hh(x / 3, y / 3, 71) < 40:
		c = Color8(176, 156, 126)
	elif hh(x / 2, y / 2, 72) < 50:
		c = Color8(116, 90, 66)
	# Сетка разметки — клетки участка.
	var lu := fposmod(gx, U)
	var lv := fposmod(gy, U)
	if lu < 2.0 or lv < 2.0:
		c = c.lerp(Color8(236, 220, 180), 0.45)
	var i := LAY.in_lot(gx / U, gy / U)
	if i >= 0:
		var a: Vector2 = LAY.LOTS[i]["at"]
		var du := minf(gx - a.x * U, (a.x + LAY.LOT_SIZE) * U - gx)
		var dv := minf(gy - a.y * U, (a.y + LAY.LOT_SIZE) * U - gy)
		if minf(du, dv) < 5.0 and minf(du, dv) > 1.5:
			c = Color8(230, 208, 150)
	return c


## Колышки по углам участков.
func _lot_stakes(cv: Cv) -> void:
	for l: Dictionary in LAY.LOTS:
		var a: Vector2 = l["at"]
		for cc: Vector2 in [a, a + Vector2(LAY.LOT_SIZE, 0), a + Vector2(LAY.LOT_SIZE, LAY.LOT_SIZE), a + Vector2(0, LAY.LOT_SIZE)]:
			var p := LAY.to_screen(cc) * ART
			cv.rect(p.x - 3, p.y - 26, 6, 26, Color8(150, 100, 60))
			cv.rect(p.x - 3, p.y - 26, 2, 26, Color8(190, 140, 90))
			cv.rect(p.x - 4, p.y - 28, 8, 4, Color8(200, 60, 50))


func _water(cell: Vector2, x: int, y: int) -> Color:
	var d := cell.distance_to(LAY.POND) / LAY.POND_R
	if d > 0.86:
		var s := hh(x / 6, y / 4, 14)
		return Color8(156, 150, 138) if s < 500 else Color8(122, 118, 108)
	var c := Color8(52, 114, 172) if d < 0.55 else Color8(70, 140, 196)
	if d > 0.76:
		c = Color8(100, 172, 212)
	if sin(x * 0.09 + sin(y * 0.15) * 2.0 + y * 0.3) > 0.94:
		c = Color8(156, 210, 238)
	if hh(x, y, 15) < 3:
		c = Color8(232, 246, 255)
	for lp: Vector2 in [Vector2(4.6, 20.8), Vector2(5.9, 21.9), Vector2(5.4, 20.3)]:
		if cell.distance_to(lp) < 0.22:
			c = Color8(84, 154, 74) if hh(x, y, 16) < 920 else Color8(240, 160, 190)
	return c


## Лес: деревья по краям. Дальние — в картинку земли, ближние (у переднего края) — спрайтами.
func _forest(g: Cv) -> void:
	var trees := {}
	for nm: String in ["ftree", "ftree2", "tree3"]:
		trees[nm] = Image.load_from_file(ProjectSettings.globalize_path("res://assets/camp/p_%s.png" % nm))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var spots: Array = []
	var stp := 26.0
	for gy in range(-2, int(LAY.HEIGHT / (stp * 0.5)) + 4):
		for gx in range(-2, int(LAY.WIDTH / stp) + 3):
			var p := Vector2(gx * stp + (stp * 0.5 if gy % 2 == 1 else 0.0) + rng.randf_range(-7, 7), gy * stp * 0.5 + rng.randf_range(-4, 4))
			var cell := LAY.to_cell(p)
			if LAY.kind_at(cell.x, cell.y) != LAY.FOREST:
				continue
			spots.append([p, cell])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	var names: Array = ["ftree", "ftree2", "ftree", "tree3"]
	for s: Array in spots:
		var p: Vector2 = s[0]
		var cell: Vector2 = s[1]
		var nm: String = names[rng.randi() % 4]
		var front := (cell.x >= LAY.INNER1 - 0.2 or cell.y >= LAY.INNER1 - 0.2) and cell.x < LAY.INNER1 + 2.6 and cell.y < LAY.INNER1 + 2.6
		# Перед шахтой (она у самого леса) деревья — в картинку земли, иначе закроют вход.
		if cell.y < 8.0 and cell.x < LAY.INNER1 + 3.0:
			front = false
		if front:
			meta["trees"].append([p.x, p.y, nm])
			continue
		var img: Image = trees[nm]
		var an: Array = meta["sprites"]["p_" + nm]["anchor"]
		var pos := Vector2i(int(p.x * ART - float(an[0])), int(p.y * ART - float(an[1])))
		g.img.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), pos)
