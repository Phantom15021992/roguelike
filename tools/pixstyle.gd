extends SceneTree
## Кисти утверждённого стиля графики (владелец утвердил 2026-11-27; правила — .claude/skills/pixel-style).
## Генератор картинки наследуется:  extends "res://tools/pixstyle.gd"  и в _init вызывает setup().
##
## Всё рисуется «пиксель в пиксель» в координатах сцены: put(x, y) сдвигает на (OX, OY) — запас
## холста слева и сверху, так что сцену можно рисовать и в отрицательных координатах.
## Правила: у каждой детали тёмный контур OUT; свет 1–2 px сверху-слева, тень 1–2 px снизу-справа
## (bar, _blit_outlined); тени на землю — вправо (ground_shadow, shadow); палитры приглушённые.
##
## Что есть:
##   основа:  setup, save, grass, put, tint, rect, bar, shadow, ground_shadow, _blit_outlined, _line, hh
##   крыши:   _shingles (черепица рядами в многоугольнике), _slope (скат-параллелограмм с маской),
##            _board (ветровая доска), _chimney / _chimney_slope (низ под 45° по скату) / _flashing, _vent
##   стены:   _plaster (штукатурка с кирпичами), _brick, _window, _awning, _door (ниша, арка),
##            _sign_board (вывеска с текстом), _hanging_sign
##   мелочи:  _keg / _keg_side (бочки-цилиндры), _crate (ящик с фруктами), _bottles, _easel
##   зелень:  _tree (oak / birch / fruit / autumn / pine), _pine, _bush (green / flower / berry / dark),
##            _draw_clumps (пучки листвы — основа крон и кустов)

var OX := 0          # запас холста слева
var OY := 0          # запас холста сверху
var W := 64
var H := 64
var img: Image
var RP: Array = ROOF   # палитра черепицы для _shingles/_slope (меняется у разных построек)
var nz := FastNoiseLite.new()


## Холст: ширина/высота сцены и запасы слева/сверху.
func setup(w: int, h: int, ox := 0, oy := 0) -> void:
	OX = ox
	OY = oy
	W = w + ox
	H = h + oy
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	nz.seed = 5
	nz.frequency = 0.05


## Сохранить в shots/<name>.png и увеличенную копию <name>_x<scale>.png.
func save(name: String, scale := 4) -> void:
	var out := ProjectSettings.globalize_path("res://shots/")
	img.save_png(out + name + ".png")
	if scale > 1:
		var big := img.duplicate()
		big.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
		big.save_png(out + name + "_x%d.png" % scale)


## Спокойная трава: пятна тона по шуму, редкие травинки и цветочки.
func grass(x0: int, y0: int, x1: int, y1: int, flowers := true) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			var n := nz.get_noise_2d(x, y * 1.3)
			var c: Color = GRASS[1]
			if n > 0.25:
				c = GRASS[1].lerp(GRASS[0], 0.35)
			elif n < -0.3:
				c = GRASS[1].lerp(GRASS[2], 0.6)
			var tuft := hh(x / 2, y / 3, 20)
			if tuft < 26:
				c = GRASS[0] if posmod(y, 3) == 0 else GRASS[2]
			if flowers and hh(x / 2, y / 2, 22) < 2:
				c = [Color8(236, 214, 120), Color8(232, 140, 150), Color8(240, 236, 226)][hh(x, y, 23) % 3]
			put(x, y, c)


# Палитра (снята с референса и приглушена).
const OUT := Color8(52, 32, 40)

const ROOF := [Color8(214, 150, 98), Color8(184, 110, 72), Color8(148, 82, 60), Color8(110, 58, 50), Color8(82, 44, 44)]

const WOOD := [Color8(196, 136, 88), Color8(156, 98, 62), Color8(120, 72, 50), Color8(88, 52, 42)]

const PLAST := [Color8(240, 230, 206), Color8(222, 208, 180), Color8(196, 180, 154), Color8(166, 148, 126)]

const STONE := [Color8(170, 166, 156), Color8(140, 138, 130), Color8(112, 110, 106), Color8(84, 82, 82)]

const MOSS := [Color8(150, 172, 92), Color8(112, 140, 72), Color8(82, 108, 60)]

const GLASS := [Color8(132, 140, 172), Color8(74, 74, 108), Color8(50, 46, 76)]

const IRON := [Color8(170, 170, 184), Color8(120, 120, 136), Color8(80, 80, 96)]

const AWN_R := [Color8(196, 104, 84), Color8(160, 78, 66), Color8(122, 58, 54)]

const AWN_W := [Color8(242, 232, 210), Color8(218, 204, 180), Color8(186, 170, 150)]

const GROUND := [Color8(156, 158, 140), Color8(132, 134, 120), Color8(108, 110, 100), Color8(84, 86, 80)]

const SIGN_TXT := Color8(244, 232, 206)

const LEAVES := [Color8(172, 198, 104), Color8(126, 164, 80), Color8(88, 128, 64), Color8(58, 92, 54)]

const LEAF_OUT := Color8(38, 58, 42)

const BARK := [Color8(150, 104, 72), Color8(112, 76, 56), Color8(80, 54, 44)]

const GRASS := [Color8(134, 166, 92), Color8(110, 146, 76), Color8(88, 124, 64), Color8(68, 100, 54)]

## Осветлить (k < 0) или затемнить уже нарисованный пиксель.
func tint(x0: int, y: int, k: float) -> void:
	var x := x0 + OX
	var py := y + OY
	if x >= 0 and py >= 0 and x < W and py < H:
		var c := img.get_pixel(x, py)
		if c.a > 0.0:
			img.set_pixel(x, py, c.darkened(k) if k > 0.0 else c.lightened(-k))

func put(x0: int, y0: int, c: Color) -> void:
	var x := x0 + OX
	var y := y0 + OY
	if x >= 0 and y >= 0 and x < W and y < H:
		if c.a >= 1.0:
			img.set_pixel(x, y, c)
		elif c.a > 0.0:
			var d := img.get_pixel(x, y)
			img.set_pixel(x, y, c if d.a <= 0.0 else d.blend(c))

func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in h:
		for xx in w:
			put(x + xx, y + yy, c)

func hh(x: int, y: int, i: int) -> int:
	return hash(Vector3i(x, y, i)) & 1023

## Объёмный брусок: контур, свет сверху/слева, тень снизу/справа (2 px).
func bar(x: int, y: int, w: int, h: int, p: Array, outline := true) -> void:
	if outline:
		rect(x - 1, y - 1, w + 2, h + 2, OUT)
	rect(x, y, w, h, p[1])
	if h >= 3:
		rect(x, y, w, 1, p[0])
	if w >= 3:
		rect(x, y, 1, h, p[0])
	if h >= 4:
		rect(x, y + h - 2, w, 2, p[2])
	elif h >= 2:
		rect(x, y + h - 1, w, 1, p[2])
	if w >= 4:
		rect(x + w - 1, y, 1, h, p[2])
	# Волокна дерева — редкие тёмные чёрточки.
	if p == WOOD and w > 6:
		for i in range(2, w - 2, 5):
			if hh(x + i, y, 1) % 3 == 0 and h > 4:
				rect(x + i, y + 2 + hh(i, y, 2) % maxi(1, h - 4), 2, 1, p[2])

## Неровная тень (полупрозрачная) — для теней на стене и земле.
func shadow(x: int, y: int, w: int, h: int, a := 0.28) -> void:
	for yy in h:
		for xx in w:
			var px := x + xx + OX
			var py := y + yy + OY
			if px >= 0 and py >= 0 and px < W and py < H and img.get_pixel(px, py).a > 0.5:
				put(x + xx, y + yy, Color(0.16, 0.08, 0.16, a))


# ------------------------------- земля и двор -------------------------------

## Черепица в многоугольнике: ряды 6 px, черепицы 8 px со сдвигом; свет — верх ряда,
## тень — 2 px внизу (на неё ложится следующий ряд), левая половина крыши светлее.
func _shingles(poly: PackedVector2Array, row0: int, moss := 0.06, dark := 0.0) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for y in range(int(r.position.y), int(r.end.y) + 1):
		for x in range(int(r.position.x), int(r.end.x) + 1):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				continue
			# Черепица 11 px шириной, ряд 6 px; у каждой — фаска: свет сверху и слева,
			# тень снизу (2 px — тень от верхнего ряда) и справа, скруглённые нижние углы.
			var row := (y - row0) / 6
			var ry := posmod(y - row0, 6)
			var off := (row % 2) * 5 + (hh(row, 0, 15) % 3)
			var sx := posmod(x + off, 11)
			var id := (x + off) / 11
			var c: Color = RP[1]
			var v := hh(id, row, 6) % 6
			if v == 0:
				c = RP[0].darkened(0.06)
			elif v == 5:
				c = RP[2].lightened(0.05)
			if ry == 0:
				c = RP[0]
			elif ry == 1 and sx > 0 and sx < 10:
				c = c.lightened(0.05)
			if sx == 1 and ry < 4:
				c = RP[0]
			elif sx == 10 and ry < 4:
				c = RP[2]
			if ry == 4:
				c = RP[2]
			elif ry == 5:
				c = RP[3]
			# Шов между черепицами — только в нижней части ряда (черепица лежит внахлёст).
			if sx == 0 and ry >= 2:
				c = RP[3] if ry < 5 else RP[4]
			elif sx == 0:
				c = RP[0].darkened(0.04)
			if ry >= 4 and (sx == 10 or sx == 1):
				c = RP[4]
			if hh(x / 3, y / 3, 7) < int(moss * 1023.0) and ry < 4:
				c = MOSS[1] if hh(x, y, 8) % 2 == 0 else MOSS[0]
			put(x, y, c.darkened(dark) if dark > 0.0 else c)
	# Контур крыши.
	for i in poly.size():
		_line(poly[i], poly[(i + 1) % poly.size()], OUT)

func _line(a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1, n))
		put(int(round(p.x)), int(round(p.y)), c)

## Скат крыши-параллелограмм: p0 — угол у карниза спереди, e1 — от карниза к коньку,
## e2 — вглубь (вверх по экрану). Черепица рядами вдоль карниза.
func _slope(p0: Vector2, e1: Vector2, e2: Vector2, dark: float, mask := PackedVector2Array()) -> void:
	var det := e1.x * e2.y - e1.y * e2.x
	var r := Rect2(p0, Vector2.ZERO).expand(p0 + e1).expand(p0 + e2).expand(p0 + e1 + e2)
	var l1 := e1.length()
	var l2 := e2.length()
	for iy in range(int(r.position.y) - 1, int(r.end.y) + 2):
		for ix in range(int(r.position.x) - 1, int(r.end.x) + 2):
			var dx := ix + 0.5 - p0.x
			var dy := iy + 0.5 - p0.y
			var sv := (dx * e2.y - dy * e2.x) / det
			var tv := (e1.x * dy - e1.y * dx) / det
			if sv < 0.0 or sv > 1.0 or tv < 0.0 or tv > 1.0:
				continue
			if mask.size() > 0 and not Geometry2D.is_point_in_polygon(Vector2(ix + 0.5, iy + 0.5), mask):
				continue
			var su := sv * l1
			var tt := tv * l2
			var row := int(su / 6.5)
			var ru := fmod(su, 6.5)
			var off := (row % 2) * 4.5
			var tk := fposmod(tt + off, 9.0)
			var id := int((tt + off) / 9.0)
			var c: Color = RP[1]
			var v := hh(id, row, 24) % 6
			if v == 0:
				c = RP[0].darkened(0.05)
			elif v == 5:
				c = RP[2].lightened(0.05)
			if ru < 1.5:
				c = RP[0]
			elif ru > 5.0:
				c = RP[3]
			elif ru > 4.0:
				c = RP[2]
			if tk < 1.0 and ru <= 4.0:
				c = RP[3]
			elif tk < 2.0 and ru <= 4.0:
				c = c.lightened(0.05)
			if hh(ix / 3, iy / 3, 25) < 50 and ru < 4.0:
				c = MOSS[1] if hh(ix, iy, 26) % 2 == 0 else MOSS[0]
			put(ix, iy, c.darkened(dark) if dark > 0.0 else c)

## Толстая доска вдоль линии a→b (ветровая доска фронтона): 3 px свет/середина/тень + контур.
func _board(a: Vector2, b: Vector2) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1, n))
		var x := int(round(p.x))
		var y := int(round(p.y))
		put(x, y - 1, OUT)
		put(x, y, WOOD[0])
		put(x, y + 1, WOOD[1])
		put(x, y + 2, WOOD[2])
		put(x, y + 3, OUT)

func _chimney(x: int, y: int) -> void:
	var w := 14
	var h := 24
	rect(x - 1, y - 1, w + 2, h + 2, OUT)
	for yy in h:
		for xx in w:
			var row := yy / 4
			var sx := (xx + (row % 2) * 3) % 7
			var c: Color = STONE[1]
			if yy % 4 == 0 or sx == 0:
				c = STONE[3]
			elif yy % 4 == 1 or sx == 1:
				c = STONE[0]
			if xx >= w - 2:
				c = c.darkened(0.18)
			put(x + xx, y + yy, c)
	bar(x - 2, y - 4, w + 4, 4, STONE)
	rect(x + 2, y - 3, w - 4, 2, Color8(40, 30, 34))
	# Дым.
	for i in 4:
		var cx := x + 7 + i * 3
		var cy := y - 10 - i * 8
		var r := 3 + i
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if xx * xx + yy * yy <= r * r:
					put(cx + xx, cy + yy, Color(0.9, 0.9, 0.92, 0.45 - i * 0.08))
	# Тень трубы на крыше.
	shadow(x + w + 1, y + 10, 4, h - 8, 0.3)

## Кладка трубы: кирпичики 7x4 со светом сверху-слева и швами.
func _brick(xx: int, yy: int, base: Color) -> Color:
	var row := yy / 4
	var sx := posmod(xx + (row % 2) * 3, 7)
	var c := base
	if posmod(yy, 4) == 0 or sx == 0:
		c = base.darkened(0.42)
	elif posmod(yy, 4) == 1 or sx == 1:
		c = base.lightened(0.16)
	return c

## Труба на правом скате: низ срезан под 45° по скату (справа длиннее), по срезу — жестяной
## фартук и тень на черепице. h — высота трубы у левого края.
func _chimney_slope(x: int, y: int, h: int) -> void:
	var w := 14
	# Тень трубы на скат справа.
	for k in 5:
		for yy in range(y + 6 + k, y + h + w + k):
			put(x + w + 1 + k, yy, Color(0.16, 0.08, 0.16, 0.28 - k * 0.04))
	# Кладка, низ каждого столбца — по линии ската.
	for xx in w:
		var hb := h + xx
		for yy in hb:
			var c := _brick(xx, yy, STONE[1])
			if xx >= w - 2:
				c = c.darkened(0.18)
			put(x + xx, y + yy, c)
	for yy in range(y - 1, y + h + 1):
		put(x - 1, yy, OUT)
	for yy in range(y - 1, y + h + w + 1):
		put(x + w, yy, OUT)
	# Фартук по срезу: 2 px света и тени, контур снизу; тень на черепице под ним.
	for xx in range(-2, w + 2):
		var by := y + h + xx
		put(x + xx, by - 2, IRON[0])
		put(x + xx, by - 1, IRON[1])
		put(x + xx, by, IRON[2])
		put(x + xx, by + 1, OUT)
		tint(x + xx, by + 2, 0.3)
		tint(x + xx, by + 3, 0.15)
	# Шапка и дым.
	bar(x - 2, y - 4, w + 4, 4, STONE)
	rect(x + 2, y - 3, w - 4, 2, Color8(40, 30, 34))
	for i in 4:
		var cx := x + 7 + i * 3
		var cy := y - 10 - i * 8
		var r := 3 + i
		for yy in range(-r, r + 1):
			for xx in range(-r, r + 1):
				if xx * xx + yy * yy <= r * r:
					put(cx + xx, cy + yy, Color(0.9, 0.9, 0.92, 0.45 - i * 0.08))

## Тень-эллипс на земле (вправо от предмета).
func ground_shadow(cx: int, base: int, rx: int, ry: int, a := 0.3) -> void:
	for yy in range(-ry, ry + 1):
		for xx in range(-rx, rx + 1):
			if float(xx * xx) / (rx * rx) + float(yy * yy) / (ry * ry) <= 1.0:
				put(cx + xx, base + yy, Color(0.16, 0.08, 0.16, a))

## Бочка стоя. Объём по горизонтали — 5 тонов дерева (блик на трети слева, рефлекс по
## правому краю), клёпки шириной 3 px со швами и волокнами, бочка пузатая (силуэт выгнут),
## обручи: светлая кромка, блик, тёмный низ, заклёпка; сверху обод из торцов клёпок и
## утопленная крышка из досок (обод бросает на неё тень); вода — с бликом и рябью.
const KEG := [Color8(220, 168, 110), Color8(190, 134, 84), Color8(156, 102, 64), Color8(122, 76, 50), Color8(88, 54, 42)]

const HOOP := [Color8(214, 214, 222), Color8(170, 170, 184), Color8(120, 120, 136), Color8(78, 76, 92)]

func _keg_tone(t: float) -> int:
	# t — положение поперёк бочки 0..1 (слева направо).
	if t < 0.08:
		return 2
	if t < 0.18:
		return 1
	if t < 0.34:
		return 0
	if t < 0.6:
		return 1
	if t < 0.8:
		return 2
	if t < 0.93:
		return 3
	return 2   # рефлекс у самого края

## Нарисовать набор пикселей и обвести его контуром по силуэту.
func _blit_outlined(pix: Dictionary) -> void:
	for k: Vector2i in pix:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not pix.has(k + d):
				put(k.x + d.x, k.y + d.y, OUT)
	for k: Vector2i in pix:
		put(k.x, k.y, pix[k])

## Бочка стоя — цилиндр: верх-эллипс (обод из торцов клёпок, утопленная крышка), по переднему
## краю верха — яркая кромка, сразу под ней — тень под ободом: чёткий переход «верх → бок».
## Бок пузатый, клёпки сужаются к краям, обручи и низ изогнуты по дуге.
func _keg(cx: int, base: int, w: int, h: int, water := false) -> void:
	ground_shadow(cx + w / 2, base, w * 3 / 4 + 1, 3, 0.34)
	var r := w / 2.0
	var ry := 4.0
	var yb := float(base) - ry
	var yt := yb - h
	var pix := {}
	for py in range(int(yt - ry) - 2, base + 2):
		for px in range(int(cx - r) - 3, int(cx + r) + 3):
			var fx := px + 0.5 - cx
			var fy := py + 0.5
			# Радиус бока с пузом.
			var k := clampf((fy - yt) / (yb - yt), 0.0, 1.0)
			var rr := r + 1.6 * sin(PI * k)
			# Верх.
			var dxt := fx / r
			if absf(dxt) <= 1.0:
				var arc_t := ry * sqrt(1.0 - dxt * dxt)
				if fy >= yt - arc_t and fy <= yt + arc_t:
					var dyt := (fy - yt) / ry
					var d := dxt * dxt + dyt * dyt
					var c: Color
					if fy > yt + arc_t - 1.2 and dyt > 0.0:
						c = KEG[0].lightened(0.18)          # передняя кромка обода — свет
					elif d > 0.5:
						c = KEG[0] if dyt < 0.2 else KEG[1]   # обод: торцы клёпок
						if posmod(int(floor(fx)), 3) == 0:
							c = c.darkened(0.2)
					elif water:
						c = Color8(66, 100, 140) if dyt < 0.0 else Color8(92, 132, 168)
						if (absf(dyt) < 0.25 and posmod(px, 4) == 1) or (int(floor(fx)) == -2 and dyt < 0.0 and dyt > -0.5):
							c = Color8(214, 232, 242)
					else:
						c = KEG[2] if posmod(py, 3) != 0 else KEG[3]   # доски крышки
						if dyt < -0.2 or dxt < -0.45:
							c = KEG[3]                                  # тень от обода внутри
						if int(floor(fx)) == 1 and absf(dyt) < 0.3:
							c = KEG[4]
					pix[Vector2i(px, py)] = c
					continue
			# Бок.
			var dx := fx / rr
			if absf(dx) > 1.0:
				continue
			var arc := ry * sqrt(1.0 - dx * dx)
			var y0 := yt + arc
			var y1 := yb + arc
			if fy <= y0 or fy > y1:
				continue
			var t := (dx + 1.0) * 0.5
			var ti := _keg_tone(t)
			var v := fy - y0
			if v < 2.0:
				ti = mini(ti + 2, 4)        # тень под ободом
			elif y1 - fy < 1.5:
				ti = mini(ti + 1, 4)
			var c: Color = KEG[ti]
			# Клёпки: шаг по углу — у краёв уже.
			var ang := asin(clampf(dx, -1.0, 1.0)) / PI * 9.0
			if fposmod(ang + 0.5, 1.0) < 0.14 and v >= 2.0:
				c = KEG[mini(ti + 1, 4)]
			elif hh(int(ang * 3.0), int(fy) / 2, 40) < 60 and v >= 2.0:
				c = KEG[mini(ti + 1, 4)]
			# Обручи по дуге.
			for hk: float in [3.0, float(h) - 4.0]:
				if v >= hk and v < hk + 1.0:
					c = HOOP[0] if t > 0.2 and t < 0.33 else (HOOP[1] if t < 0.72 else HOOP[2])
				elif v >= hk + 1.0 and v < hk + 2.0:
					c = HOOP[3]
				elif v >= hk + 2.0 and v < hk + 3.0:
					c = c.darkened(0.15)
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)

## Бочка лёжа — тот же цилиндр вдоль x: днище-эллипс слева (обод, утопленные доски), по его
## правой кромке — свет, сразу за ней — тень; бок светлый сверху, обручи изогнуты.
func _keg_side(x: int, base: int, length: int, r: int) -> void:
	ground_shadow(x + length / 2 + 4, base + 1, length * 2 / 3 + 2, 3, 0.34)
	var ex := 3.5
	var cy := float(base) - r - 1.0
	var xl := float(x) + ex
	var xr := xl + length
	var pix := {}
	for py in range(int(cy - r) - 3, int(cy + r) + 3):
		for px in range(x - 1, int(xr + ex) + 2):
			var fx := px + 0.5
			var fy := py + 0.5 - cy
			var k := clampf((fx - xl) / length, 0.0, 1.0)
			var rr := r + 1.3 * sin(PI * k)
			var dye := fy / r
			if absf(dye) <= 1.0:
				var arc_e := ex * sqrt(1.0 - dye * dye)
				if fx >= xl - arc_e and fx <= xl + arc_e:
					var dxe := (fx - xl) / ex
					var d := dxe * dxe + dye * dye
					var c: Color
					if fx > xl + arc_e - 1.2 and dxe > 0.0:
						c = KEG[0].lightened(0.18)
					elif d > 0.5:
						c = KEG[1] if dye < 0.2 else KEG[2]
						if posmod(int(floor(fy)), 3) == 0:
							c = c.darkened(0.2)
					else:
						c = KEG[2] if posmod(int(floor(fy)), 3) != 0 else KEG[3]
						if dye < -0.3:
							c = KEG[3]
					pix[Vector2i(px, py)] = c
					continue
			var dy := fy / rr
			if absf(dy) > 1.0:
				continue
			var arc := ex * sqrt(1.0 - dy * dy)
			var x0 := xl + arc
			var x1 := xr + arc
			if fx <= x0 or fx > x1:
				continue
			var t := (dy + 1.0) * 0.5
			var ti := _keg_tone(t)
			var u := fx - x0
			if u < 2.0:
				ti = mini(ti + 2, 4)
			elif x1 - fx < 1.5:
				ti = mini(ti + 1, 4)
			var c: Color = KEG[ti]
			var ang := asin(clampf(dy, -1.0, 1.0)) / PI * 7.0
			if fposmod(ang + 0.5, 1.0) < 0.16 and u >= 2.0:
				c = KEG[mini(ti + 1, 4)]
			for hk: float in [3.0, float(length) - 5.0]:
				if u >= hk and u < hk + 1.0:
					c = HOOP[0] if t > 0.2 and t < 0.33 else (HOOP[1] if t < 0.72 else HOOP[2])
				elif u >= hk + 1.0 and u < hk + 2.0:
					c = HOOP[3]
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)
	put(int(xl + length * 0.5), int(cy - r) - 1, KEG[4])

const LEAF_BIRCH := [Color8(222, 232, 132), Color8(182, 210, 98), Color8(136, 174, 76), Color8(94, 132, 62), Color8(60, 92, 52)]

const LEAF_AUTUMN := [Color8(246, 202, 108), Color8(226, 154, 72), Color8(190, 108, 56), Color8(142, 72, 48), Color8(94, 48, 42)]

const LEAF_PINE := [Color8(118, 170, 108), Color8(78, 136, 92), Color8(54, 104, 78), Color8(36, 78, 62), Color8(24, 54, 48)]

const BARK_BIRCH := [Color8(244, 240, 228), Color8(214, 208, 196), Color8(166, 160, 152)]

const LEAF5 := [Color8(198, 222, 112), Color8(150, 192, 80), Color8(100, 154, 62), Color8(62, 112, 58), Color8(38, 72, 50)]

## Дерево. Ствол — толстый, изогнутый, кора полосами (свет слева, тень справа), корни, ветки
## уходят в крону, под кроной ствол в тени. Крона — пучки листвы ярусами: у каждого пучка
## свой свет сверху-слева и тень снизу-справа, край из кончиков листьев, мазки листьев внутри;
## передний пучок отбрасывает тень на задние. Контур — по силуэту. Тень на траву вправо.
func _tree(cx: int, base: int, s: int, sd: int, kind := "oak") -> void:
	if kind == "pine":
		_pine(cx, base, s, sd)
		return
	var pal: Array = LEAF5
	var bark: Array = BARK
	if kind == "birch":
		pal = LEAF_BIRCH
		bark = BARK_BIRCH
	elif kind == "autumn":
		pal = LEAF_AUTUMN
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	ground_shadow(cx + s / 2 + 4, base, s + 8, s / 3 + 3, 0.34)
	var pix := {}
	# Ствол.
	var th := int(s * 1.25)
	if kind == "birch":
		th = int(s * 1.7)
	for yy in th + 1:
		var k := float(yy) / th
		var bend := sin(k * 2.4 + sd) * 2.0
		var half := 4.5 - k * 1.5 + (2.0 if yy < 3 else 0.0)
		if kind == "birch":
			half -= 1.5
		for xx in range(int(floor(-half)), int(ceil(half)) + 1):
			var t := (xx + half) / (half * 2.0)
			var c: Color = bark[1]
			if t < 0.28:
				c = bark[0]
			elif t > 0.72:
				c = bark[2]
			if hh(xx + 31, int((yy + sd) / 3.0), 60) < 180:
				c = (c as Color).darkened(0.14)
			if kind == "birch" and posmod(yy + (hh(yy / 5, 0, 63 + sd) % 3), 5) == 0 and xx >= int(floor(-half)) + 1 and xx <= hh(yy, 1, 64) % 3 - 1:
				c = Color8(54, 46, 50)            # чёрные чёрточки бересты
			if k > 0.6:
				c = (c as Color).darkened(0.25)   # тень от кроны
			pix[Vector2i(cx + xx + int(round(bend)), base - yy)] = c
	# Корни.
	for side: int in [-1, 1]:
		for i in 6:
			var rx := cx + side * (4 + i)
			var ry := base - 2 + i / 2
			pix[Vector2i(rx, ry)] = bark[0] if side < 0 else bark[2]
			pix[Vector2i(rx, ry - 1)] = bark[1] if side < 0 else bark[2]
	# Ветки в крону.
	var top := base - th
	for side: int in [-1, 1]:
		for i in 9:
			var bx := cx + side * (2 + i)
			var by := top + 6 - i
			pix[Vector2i(bx, by)] = bark[1]
			pix[Vector2i(bx, by + 1)] = bark[2]
	_blit_outlined(pix)
	# Крона: пучки ярусами (задние — выше и темнее).
	var cy := top - s / 3
	var clumps: Array = []
	clumps.append([0, -s * 0.35, s * 0.55, 1])
	for i in 3:
		var ang := PI + 0.35 + i * 1.2 + rng.randf_range(-0.2, 0.2)
		clumps.append([cos(ang) * s * 0.6, -s * 0.2 + sin(ang) * s * 0.25, s * rng.randf_range(0.42, 0.5), 1])
	for i in 4:
		var px := lerpf(-s * 0.75, s * 0.75, i / 3.0) + rng.randf_range(-3, 3)
		clumps.append([px, s * 0.12 + (i % 2) * 4 - 2 + rng.randf_range(-1, 2), s * rng.randf_range(0.36, 0.44), 0])
	for i in 3:
		var px := lerpf(-s * 0.45, s * 0.45, i / 2.0) + rng.randf_range(-2, 2)
		clumps.append([px, s * 0.44 + rng.randf_range(-1, 2), s * rng.randf_range(0.32, 0.4), 0])
	if kind == "birch":
		for c2: Array in clumps:
			c2[0] = float(c2[0]) * 0.7
			c2[1] = float(c2[1]) * 1.25 - s * 0.15
			c2[2] = float(c2[2]) * 0.85
	var leaves := _draw_clumps(clumps, cx, cy, pal, sd, rng)
	if kind == "fruit":
		# Яблоки в освещённой части кроны: 2x2, блик и тень.
		var keys := leaves.keys()
		var n := 0
		for i in 400:
			var k: Vector2i = keys[rng.randi() % keys.size()]
			if leaves[k] != pal[1] and leaves[k] != pal[2]:
				continue
			if not (leaves.has(k + Vector2i(1, 1)) and leaves.has(k + Vector2i(-1, -1))):
				continue
			put(k.x, k.y, Color8(236, 96, 80))
			put(k.x + 1, k.y, Color8(196, 52, 50))
			put(k.x, k.y + 1, Color8(196, 52, 50))
			put(k.x + 1, k.y + 1, Color8(140, 36, 42))
			n += 1
			if n >= 9:
				break

## Пучки листвы (общие для деревьев и кустов): тон сверху вниз, кромки, тень на соседние,
## мазки листьев, контур по силуэту. Возвращает пиксели листвы.
func _draw_clumps(clumps: Array, cx: int, cy: int, pal: Array, sd: int, rng: RandomNumberGenerator) -> Dictionary:
	var leaves := {}
	for cl: Array in clumps:
		var ccx: float = cx + float(cl[0])
		var ccy: float = cy + float(cl[1])
		var rr: float = cl[2]
		var back: bool = int(cl[3]) == 1
		var spikes := 7 + int(rr / 3)
		var ph := rng.randf() * TAU
		# Тень от этого пучка на уже нарисованные (вниз-вправо, по краю).
		for yy in range(int(ccy - rr) - 2, int(ccy + rr) + 4):
			for xx in range(int(ccx - rr) - 2, int(ccx + rr) + 4):
				var k := Vector2i(xx, yy)
				if not leaves.has(k):
					continue
				var d := Vector2(xx + 0.5 - ccx - 1.5, yy + 0.5 - ccy - 2.0).length()
				if d < rr + 2.0:
					leaves[k] = (leaves[k] as Color).darkened(0.32)
		for yy in range(int(ccy - rr) - 3, int(ccy + rr) + 3):
			for xx in range(int(ccx - rr) - 3, int(ccx + rr) + 3):
				var dx := xx + 0.5 - ccx
				var dy := yy + 0.5 - ccy
				var ang := atan2(dy, dx)
				var edge := rr * (1.0 + 0.2 * pow(absf(sin(ang * spikes * 0.5 + ph)), 3.0)) + (hh(xx, yy, 61 + sd) % 100) * 0.01
				var d := sqrt(dx * dx + dy * dy)
				if d > edge:
					continue
				# Тон сверху вниз (свет сверху-слева): у каждого пучка светлый верх и тёмный низ.
				var g := (dy + dx * 0.35) / edge
				var ti := 2
				if g < -0.5:
					ti = 0
				elif g < -0.12:
					ti = 1
				elif g < 0.28:
					ti = 2
				elif g < 0.6:
					ti = 3
				else:
					ti = 4
				# Кромки пучка: светлая по всему верху, тёмная полоса по всему низу — так
				# пучки ярусов отделяются друг от друга.
				var rim := edge - d
				if rim < 1.4 and dy < -rr * 0.2:
					ti = 0 if dx < rr * 0.3 else 1
				elif rim < 2.6 and dy > rr * 0.15:
					ti = 4
				elif rim < 2.2 and dx > rr * 0.45:
					ti = maxi(ti, 3)        # правый бок пучка темнее — граница с соседом
				elif rim < 1.4 and dx < -rr * 0.5:
					ti = mini(ti, 1)        # левый бок — светлая кромка
				if back:
					ti = mini(ti + 1, 4)
				# Мазки листьев: короткие косые штрихи светлее/темнее.
				var stroke := posmod(xx * 2 + yy * 3 + sd, 7)
				if stroke == 0 and hh(xx / 2, yy / 2, 62) < 520:
					ti = clampi(ti - 1 if g < 0.0 else ti + 1, 0, 4)
				leaves[Vector2i(xx, yy)] = pal[ti]
	# Контур кроны по силуэту.
	for k: Vector2i in leaves:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not leaves.has(k + d):
				put(k.x + d.x, k.y + d.y, (pal[4] as Color).darkened(0.35))
	for k: Vector2i in leaves:
		put(k.x, k.y, leaves[k])
	return leaves

## Ель: короткий ствол, ярусы-треугольники с зубчатым низом; у каждого яруса свет сверху-слева,
## тёмная полоса по низу (на неё падает следующий ярус), контур по силуэту.
func _pine(cx: int, base: int, s: int, sd: int) -> void:
	ground_shadow(cx + s / 2 + 2, base, s, s / 3 + 2, 0.34)
	var pix := {}
	for yy in 8:
		for xx in range(-2, 3):
			pix[Vector2i(cx + xx, base - yy)] = BARK[0] if xx < 0 else (BARK[1] if xx == 0 else BARK[2])
	_blit_outlined(pix)
	var leaves := {}
	var tiers := 4
	var tier_h := int(s * 0.74)
	for t in tiers:
		var bottom := base - 6 - t * int(tier_h * 0.62)
		var half_w := s * (0.95 - t * 0.2)
		var topy := bottom - tier_h
		for yy in range(topy, bottom + 3):
			var k := float(yy - topy) / tier_h
			var hw := half_w * clampf(k, 0.0, 1.0)
			for xx in range(int(-hw) - 2, int(hw) + 3):
				# Зубчатый низ яруса.
				var tooth := 2.5 * absf(sin((xx + sd) * 0.9))
				if yy > bottom + tooth - 2.0:
					continue
				if absf(xx) > hw + (hh(xx, yy, 70 + sd) % 3) - 1:
					continue
				var g := k + xx / maxf(1.0, half_w) * 0.25
				var ti := 2
				if g < 0.3:
					ti = 0
				elif g < 0.55:
					ti = 1
				elif g < 0.8:
					ti = 2
				else:
					ti = 3
				if yy > bottom + tooth - 4.0:
					ti = 4
				if xx > hw * 0.55:
					ti = maxi(ti, 3)
				if posmod(xx * 3 + yy * 2 + sd, 9) == 0 and ti > 0:
					ti -= 1
				leaves[Vector2i(cx + xx, yy)] = LEAF_PINE[ti]
	for k: Vector2i in leaves:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not leaves.has(k + d):
				put(k.x + d.x, k.y + d.y, Color8(20, 40, 38))
	for k: Vector2i in leaves:
		put(k.x, k.y, leaves[k])

## Куст: низкие пучки листвы (тот же приём, что у кроны), обычный / цветущий / с ягодами.
func _bush(cx: int, base: int, s: int, sd: int, kind := "green") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	ground_shadow(cx + s / 2, base, s + 4, 3, 0.34)
	var clumps: Array = []
	var n := 3 + int(s / 8)
	for i in n:
		var px := lerpf(-s * 0.6, s * 0.6, float(i) / maxf(1, n - 1)) + rng.randf_range(-1.5, 1.5)
		clumps.append([px, -s * 0.15 + rng.randf_range(-2, 1), s * rng.randf_range(0.36, 0.46), 1])
	for i in n - 1:
		var px := lerpf(-s * 0.45, s * 0.45, float(i) / maxf(1, n - 2)) + rng.randf_range(-1.5, 1.5)
		clumps.append([px, s * 0.12, s * rng.randf_range(0.34, 0.42), 0])
	var pal: Array = LEAF5 if kind != "dark" else LEAF_PINE
	var leaves := _draw_clumps(clumps, cx, base - int(s * 0.45), pal, sd, rng)
	if kind == "flower" or kind == "berry":
		var keys := leaves.keys()
		var cnt := 0
		for i in 300:
			var k: Vector2i = keys[rng.randi() % keys.size()]
			if not (leaves.has(k + Vector2i(1, 1)) and leaves.has(k + Vector2i(-1, -1))):
				continue
			if kind == "flower":
				var fc: Color = [Color8(246, 170, 190), Color8(250, 246, 236), Color8(244, 210, 110)][cnt % 3]
				put(k.x, k.y - 1, fc)
				put(k.x - 1, k.y, fc)
				put(k.x + 1, k.y, fc.darkened(0.15))
				put(k.x, k.y + 1, fc.darkened(0.25))
				put(k.x, k.y, Color8(250, 220, 120))
			else:
				put(k.x, k.y, Color8(110, 120, 210))
				put(k.x + 1, k.y, Color8(70, 70, 150))
				put(k.x, k.y + 1, Color8(70, 70, 150))
				put(k.x, k.y - 1, Color8(190, 200, 250))
			cnt += 1
			if cnt >= 10:
				break

## Стык трубы с черепицей: жестяной фартук (свет сверху, тень снизу) и тень на скате под ним.
func _flashing(x: int, base: int, w: int) -> void:
	for xx in range(-2, w + 2):
		put(x + xx, base - 2, IRON[0])
		put(x + xx, base - 1, IRON[1])
		put(x + xx, base, IRON[2])
		put(x + xx, base + 1, OUT)
		tint(x + xx, base + 2, 0.3)
		tint(x + xx, base + 3, 0.15)
	put(x - 3, base - 1, OUT)
	put(x - 3, base, OUT)
	put(x + w + 2, base - 1, OUT)
	put(x + w + 2, base, OUT)

## Решётка-вентиляция на крыше: каждая планка — 2 px (свет и тень), как в референсе.
func _vent(x: int, y: int) -> void:
	rect(x - 1, y - 1, 20, 17, OUT)
	rect(x, y, 18, 15, Color8(46, 36, 52))
	for i in 4:
		var yy := y + 1 + i * 4
		rect(x + 1, yy, 16, 1, IRON[0])
		rect(x + 1, yy + 1, 16, 1, IRON[2])
	rect(x, y, 1, 15, IRON[1])
	rect(x + 17, y, 1, 15, IRON[2])
	shadow(x + 18, y + 2, 2, 14, 0.3)


# ------------------------------- стены -------------------------------

func _plaster(x: int, y: int, w: int, h: int) -> void:
	for yy in h:
		for xx in w:
			var c: Color = PLAST[1]
			var s := hh((x + xx) / 2, (y + yy) / 2, 9)
			if s < 80:
				c = PLAST[2]
			elif s > 980:
				c = PLAST[0]
			put(x + xx, y + yy, c)
	# Пятно отвалившейся штукатурки — кирпичики.
	for k in 2:
		var bx := x + 6 + hh(k, x, 10) % maxi(1, w - 20)
		var by := y + 8 + hh(k, y, 10) % maxi(1, h - 20)
		rect(bx - 1, by - 1, 12, 8, PLAST[3])
		for r in 2:
			for c in 2:
				bar(bx + c * 5 + r * 2, by + r * 3, 4, 2, [Color8(200, 128, 100), Color8(170, 96, 78), Color8(130, 70, 60)], false)

## Окно: рама, стекло с бликами, переплёт, подоконник с тенью. goods — витрина с бутылочками
## (у торговца), box — ящик с цветами под окном.
func _window(x: int, y: int, w: int, h: int, goods := true, box := false) -> void:
	rect(x - 3, y - 3, w + 6, h + 6, OUT)
	bar(x - 2, y - 2, w + 4, h + 4, WOOD, false)
	rect(x, y, w, h, GLASS[1])
	for yy in h:
		for xx in w:
			if yy < 3:
				put(x + xx, y + yy, GLASS[2])
			elif (xx + yy) % 13 == 0 or (xx + yy) % 13 == 1:
				put(x + xx, y + yy, GLASS[0])
	# Товар за стеклом: бутылочки.
	for i in (6 if goods else 0):
		var bx := x + 4 + i * 8
		if bx + 4 > x + w:
			break
		var col: Color = [Color8(176, 84, 84), Color8(96, 140, 110), Color8(196, 160, 84)][i % 3]
		rect(bx, y + h - 11, 4, 9, col)
		put(bx, y + h - 11, col.lightened(0.3))
		rect(bx + 1, y + h - 14, 2, 3, Color8(200, 190, 170))
	for k in ([w / 3, 2 * w / 3] if goods else [w / 2 - 1]):
		rect(x + k, y, 2, h, WOOD[2])
		put(x + k, y, WOOD[1])
	rect(x, y + h / 2, w, 1, WOOD[2])
	if not goods:
		# Тёплый свет внутри — нижняя часть стекла.
		for yy in range(h / 2 + 1, h):
			for xx in w:
				if (xx + yy) % 13 > 1 and yy > h / 2 + 1:
					put(x + xx, y + yy, Color8(206, 168, 108) if xx < w / 2 else Color8(180, 144, 96))
	bar(x - 4, y + h + 2, w + 8, 3, WOOD)
	shadow(x - 3, y + h + 6, w + 6, 2, 0.3)
	if box:
		bar(x - 2, y + h + 5, w + 4, 4, WOOD)
		for i in range(0, w + 2, 3):
			put(x - 1 + i, y + h + 4, LEAF5[1] if i % 2 == 0 else LEAF5[2])
			if hh(x + i, y, 94) % 3 == 0:
				put(x - 1 + i, y + h + 3, [Color8(244, 150, 170), Color8(250, 240, 230), Color8(244, 210, 110)][hh(i, y, 95) % 3])

func _awning(x: int, y: int, w: int) -> void:
	# Полосатый навес: наклон, полосы 2 тона + тень, фестоны снизу, тень на стене.
	var h := 13
	for yy in h:
		var lx := x - yy / 3
		var rx := x + w + yy / 3
		for xx in range(lx, rx):
			var stripe := ((xx - x + yy / 3) / 6) % 2 == 0
			var p: Array = AWN_R if stripe else AWN_W
			var c: Color = p[1]
			if yy < 2:
				c = p[0]
			elif yy > h - 3:
				c = p[2]
			put(xx, y + yy, c)
		put(lx - 1, y + yy, OUT)
		put(rx, y + yy, OUT)
	rect(x, y - 1, w, 1, OUT)
	# Фестоны.
	var bx := x - h / 3
	var bw := w + 2 * (h / 3)
	for i in range(0, bw, 6):
		var stripe := (i / 6) % 2 == 0
		var p: Array = AWN_R if stripe else AWN_W
		rect(bx + i + 1, y + h, 4, 2, p[2])
		rect(bx + i + 2, y + h + 2, 2, 1, p[2])
		put(bx + i, y + h, OUT)
		put(bx + i + 1, y + h + 2, OUT)
		put(bx + i + 4, y + h + 2, OUT)
		put(bx + i + 2, y + h + 3, OUT)
		put(bx + i + 3, y + h + 3, OUT)
	rect(bx, y + h, bw, 1, OUT)
	shadow(x - 2, y + h + 4, w + 4, 5, 0.3)
	# Кронштейны.
	for sx: int in [x + 2, x + w - 4]:
		bar(sx, y + h, 2, 8, IRON)


# ------------------------------- фронтон-крыло с дверью -------------------------------

const DOOR := [Color8(150, 168, 130), Color8(116, 136, 102), Color8(88, 106, 82), Color8(60, 72, 60)]

## Дверь в нише: арка из клиновидных камней (у каждого свет сверху-слева, тень снизу-справа,
## швы), замковый камень; ниша — тень под аркой и на левом откосе, правый откос на свету;
## полотно из досок с фасками, тень от арки сверху, железные полосы с заклёпками и петлями,
## кольцо-ручка, каменный порог.
func _door(cx: int, base: int, w: int, h: int) -> void:
	var x0 := cx - w / 2
	var y0 := base - h
	var r := w / 2.0
	var acx := x0 + r          # центр арки
	var acy := y0 + r
	var ring := 5.0            # толщина каменной арки
	var dep := 3               # глубина ниши (откосы)
	var pix := {}
	for py in range(y0 - int(ring) - 1, base):
		for px in range(x0 - int(ring) - 1, x0 + w + int(ring) + 1):
			var fx := px + 0.5
			var fy := py + 0.5
			var in_arch_zone := fy < acy
			var d := Vector2(fx - acx, fy - acy).length() if in_arch_zone else absf(fx - acx)
			var inside := d <= r
			var outer := d <= r + ring
			if not outer:
				continue
			var c: Color
			if not inside:
				# Камни обрамления.
				if in_arch_zone:
					var ang := atan2(fy - acy, fx - acx)      # -PI..0 (верх)
					var seg := int(floor((ang + PI) / (PI / 7.0)))
					var local := fposmod((ang + PI) / (PI / 7.0), 1.0)
					var rad := (d - r) / ring
					c = STONE[1] if seg % 2 == 0 else STONE[1].lightened(0.06)
					if seg == 3:
						c = STONE[0]                         # замковый камень
					if local < 0.12 or rad > 0.86:
						c = STONE[3]                         # швы и внешний край
					elif rad < 0.2:
						c = STONE[2]                         # внутренняя кромка — в тени
					elif local < 0.3 and rad > 0.3:
						c = (c as Color).lightened(0.1)
				else:
					var row := int(floor((fy - acy) / 6.0))
					var lv := fposmod(fy - acy, 6.0)
					var side_w := 5.0 if row % 2 == 0 else 3.5
					var u := (x0 - fx) if fx < acx else (fx - x0 - w)
					c = STONE[1] if row % 2 == 0 else STONE[1].darkened(0.05)
					if lv < 1.0 or u > side_w + 0.5:
						c = STONE[3]
					elif lv < 2.0:
						c = STONE[0]
					elif lv > 4.8 or (fx > acx and u > side_w - 1.0):
						c = STONE[2]
					if u > ring - 0.5:
						continue
				pix[Vector2i(px, py)] = c
				continue
			# Ниша.
			var uu := fx - x0
			var top_edge := r - d if in_arch_zone else 99.0
			if in_arch_zone and top_edge < dep:
				c = STONE[3].darkened(0.25)                  # свод ниши — глубокая тень
			elif uu < dep:
				c = STONE[3]                                 # левый откос в тени
			elif uu > w - dep + 1:
				c = STONE[0]                                 # правый откос на свету
			else:
				# Полотно двери: доски 4 px с фасками.
				var pu := int(floor(uu - dep)) 
				var pl := posmod(pu, 4)
				var ti := 1
				if pl == 0:
					ti = 3
				elif pl == 1:
					ti = 0
				elif pl == 3:
					ti = 2
				if hh(int(floor((uu - dep) / 4.0)), int(fy) / 3, 70) < 90 and pl == 2:
					ti = 2
				c = DOOR[ti]
				# Тень от арки и свода сверху.
				var sh := (top_edge - dep) if in_arch_zone else (fy - acy + r - dep)
				if sh < 3.0:
					c = DOOR[mini(ti + 1, 3)].darkened(0.12)
				# Железные полосы с петлями и заклёпками.
				for bv: int in [y0 + int(h * 0.36), base - 10]:
					if py == bv:
						c = HOOP[1] if uu < w * 0.4 else HOOP[2]
						if posmod(int(uu), 4) == 2:
							c = HOOP[0]
					elif py == bv + 1:
						c = HOOP[3]
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)
	# Концы петель слева — стрелкой, заклёпки.
	for bv: int in [y0 + int(h * 0.36), base - 10]:
		put(x0 + dep, bv - 1, HOOP[1])
		put(x0 + dep, bv + 2, HOOP[3])
		for k in range(x0 + dep + 3, x0 + w - 3, 4):
			put(k, bv, HOOP[0])
			put(k, bv + 1, OUT)
	# Кольцо-ручка.
	var hx := x0 + w - 6
	var hy := y0 + int(h * 0.55)
	for yy in range(-3, 4):
		for xx in range(-3, 4):
			var d := Vector2(xx, yy).length()
			if d > 2.2 and d < 3.3:
				put(hx + xx, hy + yy, HOOP[0] if (xx + yy) < -1 else (HOOP[1] if (xx + yy) < 2 else HOOP[3]))
	put(hx, hy - 4, HOOP[2])
	put(hx, hy - 3, OUT)
	# Порог.
	bar(x0 - 4, base, w + 8, 3, STONE)
	shadow(x0 - 3, base + 3, w + 6, 1, 0.3)

## Вывеска «ЛАВКА» на фронтоне — как «BAR» у референса: доска со светлой кромкой, светлые буквы.
func _sign_board(x: int, y: int, w: int, text := "ЛАВКА") -> void:
	var h := 14
	rect(x - 1, y - 1, w + 2, h + 2, OUT)
	for yy in h:
		for xx in w:
			var c: Color = WOOD[1]
			if hh(x + xx, (y + yy) / 2, 12) < 160:
				c = WOOD[2]
			elif hh(x + xx, y + yy, 13) < 60:
				c = WOOD[0]
			put(x + xx, y + yy, c)
	rect(x, y, w, 1, WOOD[0].lightened(0.15))
	rect(x, y + 1, 1, h - 1, WOOD[0])
	rect(x, y + h - 1, w, 1, WOOD[3])
	rect(x + w - 1, y, 1, h, WOOD[3])
	var glyphs := GLYPHS
	var gx := x + (w - text.length() * 8 + 3) / 2
	for ci in text.length():
		var ch := text[ci]
		if not glyphs.has(ch):
			gx += 8
			continue
		var g: Array = glyphs[ch]
		for gy in 7:
			var row: String = g[gy]
			for i in 5:
				if row[i] == "#":
					put(gx + i, y + 4 + gy, WOOD[3])
					put(gx + i - 1, y + 3 + gy, SIGN_TXT)
		gx += 8
	# Крепления-кронштейны.
	bar(x + 4, y + h, 2, 4, IRON)
	bar(x + w - 6, y + h, 2, 4, IRON)
	shadow(x + 2, y + h + 1, w, 3, 0.3)
	# Мох на углу доски (как в референсе).
	put(x - 1, y - 2, MOSS[0])
	put(x, y - 2, MOSS[1])
	put(x - 1, y - 1, MOSS[1])
	put(x - 2, y - 1, MOSS[2])

## Буквы 5x7 для вывесок (заглавные, кириллица).
const GLYPHS := {
	"А": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"Б": ["#####", "#....", "#....", "####.", "#...#", "#...#", "####."],
	"В": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"Г": ["#####", "#....", "#....", "#....", "#....", "#....", "#...."],
	"Д": ["..##.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"],
	"Е": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"Ж": ["#.#.#", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "#.#.#"],
	"З": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
	"И": ["#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
	"Й": [".#.#.", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
	"К": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"Л": ["..###", "..#.#", "..#.#", "..#.#", ".#..#", ".#..#", "#...#"],
	"М": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"Н": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"О": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"П": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#"],
	"Р": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"С": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"Т": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"У": ["#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
	"Ф": ["..#..", ".###.", "#.#.#", "#.#.#", ".###.", "..#..", "..#.."],
	"Х": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Ц": ["#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#####", "....#"],
	"Ч": ["#...#", "#...#", "#...#", ".####", "....#", "....#", "....#"],
	"Ш": ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"],
	"Ы": ["#...#", "#...#", "#...#", "###.#", "#..##", "#..##", "###.#"],
	"Ь": ["#....", "#....", "#....", "####.", "#...#", "#...#", "####."],
	"Э": [".###.", "#...#", "....#", ".####", "....#", "#...#", ".###."],
	"Ю": ["#..#.", "#.#.#", "#.#.#", "###.#", "#.#.#", "#.#.#", "#..#."],
	"Я": [".####", "#...#", "#...#", ".####", "..#.#", ".#..#", "#...#"],
}


## Подвесная вывеска с монетой на кронштейне.
func _hanging_sign(x: int, y: int) -> void:
	bar(x - 2, y - 2, 18, 2, IRON)
	put(x + 14, y - 1, IRON[2])
	put(x + 2, y, IRON[1])
	put(x + 12, y, IRON[1])
	rect(x, y + 2, 16, 14, OUT)
	bar(x + 1, y + 3, 14, 12, WOOD, false)
	# Монета.
	for yy in range(-4, 5):
		for xx in range(-4, 5):
			if xx * xx + yy * yy <= 17:
				var c := Color8(222, 178, 82)
				if xx + yy < -3:
					c = Color8(250, 222, 140)
				elif xx + yy > 3:
					c = Color8(170, 124, 52)
				put(x + 8 + xx, y + 9 + yy, c)
	rect(x + 7, y + 7, 2, 5, Color8(170, 124, 52))


# ------------------------------- мелочи -------------------------------

const CRATE := [Color8(224, 178, 120), Color8(196, 146, 92), Color8(160, 112, 70), Color8(124, 82, 54), Color8(90, 58, 44)]

## Ящик-коробка, вид сверху-спереди: верх — обод из досок (дальний край и левый на свету),
## внутри тёмная полость с горкой фруктов; передняя кромка — свет, сразу под ней тень (чёткий
## переход «верх → стенка»); стенка из двух досок со швами, угловые планки с гвоздями, справа темнее.
func _crate(x: int, y: int, s: int, fruit: Color) -> void:
	var fh := 10
	var td := 6
	ground_shadow(x + s / 2 + 4, y + fh, s * 3 / 4, 3, 0.34)
	var pix := {}
	for yy in range(y - td, y):
		for xx in range(x, x + s):
			var inner := xx > x and xx < x + s - 1 and yy > y - td and yy < y
			var c: Color
			if not inner:
				c = CRATE[0] if (yy == y - td or xx == x) else CRATE[2]
			else:
				c = CRATE[4] if yy < y - td + 2 or xx < x + 2 else CRATE[3]
			pix[Vector2i(xx, yy)] = c
	for yy in range(y, y + fh):
		for xx in range(x, x + s):
			var v := yy - y
			var u := xx - x
			var t := float(u) / s
			var ti := 1
			if t > 0.68:
				ti = 2
			if t > 0.9:
				ti = 3
			var c: Color = CRATE[ti]
			var bv := posmod(v - 1, 5)
			if v == 0:
				c = CRATE[0].lightened(0.14)
			elif v == 1:
				c = CRATE[3]
			elif bv == 0:
				c = CRATE[4]
			elif bv == 1:
				c = (CRATE[ti] as Color).lightened(0.07)
			elif bv == 4:
				c = CRATE[mini(ti + 1, 4)]
			elif hh(xx, yy, 50) < 90:
				c = CRATE[mini(ti + 1, 4)]
			if (u <= 2 or u >= s - 3) and v >= 1:
				var pu := u if u <= 2 else u - (s - 3)
				c = [CRATE[0], CRATE[1], CRATE[2]][pu]
				if u >= s - 3:
					c = c.darkened(0.16)
				if pu == 1 and (v == 3 or v == fh - 2):
					c = OUT
			pix[Vector2i(xx, yy)] = c
	_blit_outlined(pix)
	# Горка фруктов: задний ряд, потом передний — каждый фрукт 5x5: блик, тень, тёмный край.
	var shape := [".###.", "#####", "#####", "#####", ".###."]
	var spots: Array = []
	for i in 2:
		spots.append(Vector2i(x + 3 + i * 5, y - td - 2))
	for i in 3:
		spots.append(Vector2i(x + 1 + i * 4, y - 5))
	for sp: Vector2i in spots:
		for fy in 5:
			var row: String = shape[fy]
			for fx in 5:
				if row[fx] != "#":
					continue
				var c := fruit
				if (fx == 1 and fy <= 2) or (fx == 2 and fy == 1):
					c = fruit.lightened(0.32)
				elif fx + fy >= 6:
					c = fruit.darkened(0.42)
				elif fx + fy >= 5:
					c = fruit.darkened(0.22)
				put(sp.x + fx, sp.y + fy, c)
		put(sp.x + 2, sp.y - 1, Color8(92, 120, 60))
		put(sp.x + 3, sp.y - 1, Color8(70, 96, 52))
	# Передняя кромка поверх низа фруктов.
	for xx in range(x, x + s):
		put(xx, y, CRATE[0].lightened(0.14))
		put(xx, y + 1, CRATE[3])
	put(x - 1, y, OUT)
	put(x + s, y, OUT)

func _bottles(x: int, base: int) -> void:
	for i in 2:
		var bx := x + i * 5
		rect(bx - 1, base - 11, 6, 11, OUT)
		rect(bx, base - 10, 4, 9, Color8(196, 150, 110))
		rect(bx, base - 10, 1, 9, Color8(236, 200, 160))
		rect(bx + 3, base - 10, 1, 9, Color8(150, 108, 80))
		rect(bx + 1, base - 14, 2, 4, Color8(170, 126, 92))
		put(bx + 1, base - 15, OUT)
		put(bx + 2, base - 15, OUT)

## Грифельная доска-стойка с ценой.
func _easel(x: int, base: int) -> void:
	for s: int in [0, 13]:
		for i in 20:
			put(x + s + (i / 8 if s == 0 else -i / 8), base - i, WOOD[1])
			put(x + s + 1 + (i / 8 if s == 0 else -i / 8), base - i, WOOD[2])
	rect(x - 1, base - 22, 17, 14, OUT)
	rect(x, base - 21, 15, 12, Color8(56, 60, 70))
	rect(x, base - 21, 15, 1, Color8(90, 94, 104))
	rect(x + 3, base - 18, 6, 1, Color8(210, 210, 200))
	rect(x + 3, base - 15, 9, 1, Color8(210, 210, 200))
	rect(x + 3, base - 12, 4, 1, Color8(222, 190, 96))
	bar(x - 1, base - 23, 17, 2, WOOD)
