extends "res://tools/pixstyle.gd"
## Рисунки подземелья в утверждённом стиле (правила — .claude/skills/pixel-style): пол плитами,
## скалы, кристаллы, грибы-трутовики, корни, лестница, колонна и монстры первого биома.
## Всё в пикселях картинки (2 пикселя картинки = 1 пиксель мира).
## Используют: tools/sample_dungeon.gd (картинка-образец).

# Палитры (приглушённые, 4–5 тонов одного оттенка).
const SLAB := [Color8(156, 154, 166), Color8(132, 130, 146), Color8(110, 108, 126), Color8(88, 86, 104), Color8(68, 66, 84)]
const SEAM := Color8(54, 50, 66)
const ROCKD := [Color8(132, 122, 138), Color8(100, 92, 110), Color8(78, 70, 90), Color8(58, 52, 70), Color8(40, 34, 50)]
const CREV := Color8(24, 18, 30)
const CRYS := [Color8(214, 244, 236), Color8(150, 214, 206), Color8(96, 168, 170), Color8(62, 118, 132), Color8(44, 80, 100)]
const FUNG := [Color8(236, 182, 110), Color8(210, 140, 80), Color8(170, 100, 62), Color8(122, 68, 50)]
const ROOT := [Color8(150, 112, 84), Color8(116, 84, 64), Color8(84, 60, 50)]
const BONE := [Color8(236, 228, 206), Color8(206, 196, 172), Color8(164, 152, 132)]

# Монстры.
const SLIME_G := [Color8(190, 220, 126), Color8(146, 192, 96), Color8(104, 158, 78), Color8(72, 122, 66), Color8(48, 86, 56)]
const SLIME_S := [Color8(220, 220, 120), Color8(186, 196, 86), Color8(144, 160, 66), Color8(106, 122, 56), Color8(74, 86, 48)]
const BAT_B := [Color8(150, 128, 150), Color8(118, 98, 124), Color8(90, 74, 100), Color8(66, 54, 78), Color8(46, 38, 58)]
const BAT_W := [Color8(132, 108, 128), Color8(104, 84, 106), Color8(80, 64, 86), Color8(58, 46, 66), Color8(42, 34, 50)]
const VAMP_B := [Color8(170, 104, 104), Color8(140, 78, 84), Color8(110, 58, 68), Color8(80, 42, 54), Color8(56, 30, 42)]
const VAMP_W := [Color8(150, 90, 94), Color8(120, 66, 76), Color8(92, 48, 62), Color8(68, 36, 50), Color8(48, 26, 38)]
const WISP := [Color8(230, 236, 250), Color8(184, 196, 236), Color8(140, 152, 214), Color8(104, 112, 180), Color8(76, 80, 140)]
const CAP_P := [Color8(196, 156, 206), Color8(164, 118, 180), Color8(132, 88, 152), Color8(100, 64, 122), Color8(70, 46, 92)]
const CAP_R := [Color8(232, 132, 108), Color8(204, 96, 80), Color8(166, 68, 62), Color8(124, 48, 50), Color8(88, 36, 42)]
const STEM := [Color8(242, 232, 210), Color8(220, 206, 180), Color8(190, 174, 150), Color8(150, 134, 116)]
const EYE := Color8(40, 30, 40)


# ===================================================================================
#                                  ОСНОВА ДЛЯ ДЕТАЛЕЙ
# ===================================================================================

## Набор пикселей с контуром заданного цвета по силуэту.
func blit(pix: Dictionary, oc: Color = OUT) -> void:
	for k: Vector2i in pix:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not pix.has(k + d):
				put(k.x + d.x, k.y + d.y, oc)
	for k: Vector2i in pix:
		put(k.x, k.y, pix[k])


## Тон шара: свет сверху-слева, тень снизу-справа ступенями (5 тонов), светлая кромка сверху,
## тёмная полоса по низу — как у пучков листвы.
func ball_tone(dx: float, dy: float, r: float, pal: Array) -> Color:
	var d := sqrt(dx * dx + dy * dy)
	var g := dy * 0.85 + dx * 0.45
	var ti := 2
	if g < -0.55:
		ti = 0
	elif g < -0.15:
		ti = 1
	elif g < 0.3:
		ti = 2
	elif g < 0.65:
		ti = 3
	else:
		ti = 4
	var rim := (1.0 - d) * r
	if rim < 1.3 and dy < -0.25:
		ti = mini(ti, 1)
	elif rim < 1.8 and dy > 0.35:
		ti = 4
	return pal[ti]


## Эллипс-шар в набор пикселей. cut — нижняя граница (плоское дно), -1 — без среза.
func ball(pix: Dictionary, cx: float, cy: float, rx: float, ry: float, pal: Array, cut := 1e9) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		if y >= cut:
			continue
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var c := ball_tone(dx, dy, minf(rx, ry), pal)
			if y >= cut - 2 and cut < 1e8:
				c = pal[4]
			pix[Vector2i(x, y)] = c


## Многоугольник одним тоном с кромками: свет по верху-левому краю, тень по нижнему-правому.
func poly(pix: Dictionary, pts: PackedVector2Array, pal: Array, base := 1) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	var inside := {}
	for y in range(int(r.position.y) - 1, int(r.end.y) + 2):
		for x in range(int(r.position.x) - 1, int(r.end.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				inside[Vector2i(x, y)] = true
	for k: Vector2i in inside:
		var c: Color = pal[base]
		if not inside.has(k + Vector2i(0, -1)) or not inside.has(k + Vector2i(-1, 0)):
			c = pal[maxi(base - 1, 0)]
		if not inside.has(k + Vector2i(0, 1)) or not inside.has(k + Vector2i(1, 0)):
			c = pal[mini(base + 2, pal.size() - 1)]
		elif not inside.has(k + Vector2i(0, 2)) or not inside.has(k + Vector2i(2, 0)):
			c = pal[mini(base + 1, pal.size() - 1)]
		pix[k] = c


func glow(cx: float, cy: float, r: float, c: Color, a := 0.22) -> void:
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			var d := Vector2(x + 0.5 - cx, (y + 0.5 - cy) * 1.25).length() / r
			if d < 1.0:
				# Ступенчато, без гладкого градиента.
				var k := 0.35 if d > 0.7 else (0.7 if d > 0.4 else 1.0)
				put(x, y, Color(c.r, c.g, c.b, a * k))


# ===================================================================================
#                                     ПОЛ И СКАЛЫ
# ===================================================================================

## Плиты пола: камни-многоугольники (ячейки вороного 18 px), у каждой свой оттенок, свет по
## верхне-левой кромке, тень по нижне-правой, тёмные швы с редким мхом, трещины.
# Повтор узора (для бесшовных плиток игры): N ячеек на период, 0 — без повтора.
var SLAB_G := 18.0
var SLAB_N := 0
var ROCK_G := 24.0
var ROCK_N := 0


func _wrap(c: int, n: int) -> int:
	return posmod(c, n) if n > 0 else c


func slab(x: int, y: int) -> Color:
	var g := SLAB_G
	var gx := int(floor(x / float(g)))
	var gy := int(floor(y / float(g)))
	var p := Vector2(x + 0.5, y + 0.5)
	var d1 := 1e9
	var d2 := 1e9
	var near := Vector2.ZERO
	var nid := Vector2i.ZERO
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var cx := gx + ox
			var cy := gy + oy
			var hx := _wrap(cx, SLAB_N)
			var hy := _wrap(cy, SLAB_N)
			var sp := Vector2(cx * g + 3 + hh(hx, hy, 41) % int(g - 6), cy * g + 3 + hh(hx, hy, 42) % int(g - 6))
			var d := Vector2(p.x - sp.x, (p.y - sp.y) * 1.2).length()
			if d < d1:
				d2 = d1
				d1 = d
				near = sp
				nid = Vector2i(hx, hy)
			elif d < d2:
				d2 = d
	var edge := d2 - d1
	if edge < 1.6:
		return MOSS[2].darkened(0.3) if hh(x / 2, y / 2, 44) % 9 == 0 else SEAM
	var v := hh(nid.x, nid.y, 43) % 7
	var c: Color = SLAB[1]
	if v == 0:
		c = SLAB[0].darkened(0.05)
	elif v == 1 or v == 2:
		c = SLAB[2]
	elif v == 3:
		c = SLAB[1].lerp(Color8(150, 136, 120), 0.22)
	elif v == 4:
		c = SLAB[1].lerp(Color8(120, 136, 146), 0.2)
	var dir := (p - near).normalized()
	if edge < 3.2:
		var lit := dir.dot(Vector2(-0.7, -0.7))
		if lit > 0.25:
			c = c.lightened(0.16)
		elif lit < -0.25:
			c = c.darkened(0.22)
	else:
		# Трещина в редких плитах.
		if hh(nid.x, nid.y, 45) % 11 == 0:
			var a := float(hh(nid.x, nid.y, 46) % 100) * 0.0314
			var q := p - near
			var along := q.dot(Vector2(cos(a), sin(a)))
			var across := q.dot(Vector2(-sin(a), cos(a))) + 1.2 * sin(along * 0.6)
			if absf(across) < 0.6 and absf(along) < 6.0:
				return SEAM
			if across > 0.6 and across < 1.6 and absf(along) < 6.0:
				return c.lightened(0.1)
		if hh(x, y, 47) < 24:
			c = c.darkened(0.08)
		elif hh(x, y, 48) < 12:
			c = c.lightened(0.06)
	return c


## Верх скалы: груда округлых глыб разного размера (вороной 24 px), у каждой глыбы купол —
## светлый верх-лево, тёмный низ-право, светлая кромка сверху, тёмная полоса снизу; между
## глыбами — широкие чёрные щели (по ним скала не похожа на плиты пола).
func rock_top(x: int, y: int) -> Color:
	var g := ROCK_G
	var gx := int(floor(x / float(g)))
	var gy := int(floor(y / float(g)))
	var p := Vector2(x + 0.5, y + 0.5)
	var d1 := 1e9
	var d2 := 1e9
	var near := Vector2.ZERO
	var nid := Vector2i.ZERO
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var cx := gx + ox
			var cy := gy + oy
			var hx := _wrap(cx, ROCK_N)
			var hy := _wrap(cy, ROCK_N)
			var sp := Vector2(cx * g + 3 + hh(hx, hy, 51) % int(g - 6), cy * g + 3 + hh(hx, hy, 52) % int(g - 6))
			# Глыбы разного веса — одни крупнее соседей.
			var wgt := 1.0 + float(hh(hx, hy, 57) % 5) * 0.12
			var d := Vector2(p.x - sp.x, (p.y - sp.y) * 1.2).length() / wgt
			if d < d1:
				d2 = d1
				d1 = d
				near = sp
				nid = Vector2i(hx, hy)
			elif d < d2:
				d2 = d
	var edge := d2 - d1
	if edge < 2.4:
		return CREV
	var rad := maxf(d1 + edge * 0.5, 1.0)
	var q := (p - near) / rad
	var g2 := q.y * 0.8 + q.x * 0.5
	var ti := 2
	if g2 < -0.42:
		ti = 0
	elif g2 < -0.08:
		ti = 1
	elif g2 < 0.3:
		ti = 2
	elif g2 < 0.58:
		ti = 3
	else:
		ti = 4
	if edge < 4.2:
		if q.y > 0.15 or q.x > 0.45:
			ti = 4                               # тёмный низ-право у щели
		elif q.y < -0.2 or q.x < -0.4:
			ti = mini(ti, 0 if edge > 3.2 else 1)   # светлая кромка верх-лево
	if hh(nid.x, nid.y, 53) % 4 == 0:
		ti = mini(ti + 1, 4)
	var c: Color = ROCKD[ti]
	# Мох на верхушках некоторых глыб.
	if hh(nid.x, nid.y, 54) % 5 == 0 and q.y < -0.1 and edge > 4.2:
		var mn := nz.get_noise_2d(x * 2.0, y * 2.0)
		if mn > -0.05:
			c = MOSS[2] if mn < 0.2 else MOSS[1].darkened(0.12)
	elif hh(x, y, 55) < 26:
		c = c.darkened(0.1)
	elif hh(x, y, 58) < 10 and ti <= 1:
		c = c.lightened(0.1)
	return c


## Передняя грань скалы (невысокий обрыв над полом): вертикальные грани неравной ширины,
## у каждой светлый левый край и тёмный правый, ниже — темнее; под кромкой верха — тень,
## по низу — тёмная линия.
func rock_face(x: int, y: int, depth: int, total: int) -> Color:
	# Сверху — светлая кромка-губа, под ней тень, по низу — тёмная линия.
	if depth == 0:
		return ROCKD[0]
	if depth == 1:
		return ROCKD[1]
	if depth <= 3:
		return ROCKD[4]
	if depth >= total - 1:
		return OUT
	var t := float(depth) / total
	var sx := x + depth * 0.25
	var col := int(floor(sx / 13.0))
	var off := float(hh(col, 0, 59) % 5) - 2.0
	var lx := sx - (col * 13.0 + off)
	if lx < 0.0:
		col -= 1
		lx += 13.0
	var ti := 1 + hh(col, 0, 56) % 2
	if t > 0.6:
		ti += 1
	if lx < 1.0:
		return CREV.lightened(0.12)
	if lx < 2.5:
		ti = maxi(ti - 1, 0)
	elif lx > 10.5:
		ti = mini(ti + 1, 4)
	if hh(x, y, 60) < 24:
		ti = mini(ti + 1, 4)
	return ROCKD[clampi(ti, 0, 4)]


# ===================================================================================
#                                   УКРАШЕНИЯ ПОЛА
# ===================================================================================

## Друза кристаллов: острые призмы — левая грань светлая, правая в тени, ребро между ними,
## блик у вершины; мягкий ореол.
func crystals(cx: int, base: int, s: float, sd: int, halo := true) -> void:
	if halo:
		glow(cx, base - s * 0.8, s * 2.0, CRYS[1], 0.14)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var list: Array = []
	var n := 3 + sd % 3
	for i in n:
		var off := (i - (n - 1) * 0.5) * s * 0.45 + rng.randf_range(-1.5, 1.5)
		var h := s * (1.6 if absf(off) < s * 0.3 else rng.randf_range(0.8, 1.2))
		var lean := off * 0.35 + rng.randf_range(-1.0, 1.0)
		var w := s * rng.randf_range(0.32, 0.42)
		list.append([off, h, lean, w])
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	ground_shadow(cx + int(s * 0.5), base, int(s * 1.1), 3, 0.3)
	for e: Array in list:
		var bx: float = cx + float(e[0])
		var h: float = e[1]
		var tip := Vector2(bx + float(e[2]), base - h)
		var w: float = e[3]
		var pl := PackedVector2Array([Vector2(bx - w, base), Vector2(bx - w, base - h * 0.62), tip, Vector2(bx + w, base - h * 0.62), Vector2(bx + w, base)])
		var pix := {}
		var r := Rect2(pl[0], Vector2.ZERO)
		for q in pl:
			r = r.expand(q)
		for y in range(int(r.position.y) - 1, int(r.end.y) + 1):
			for x in range(int(r.position.x) - 1, int(r.end.x) + 1):
				var pp := Vector2(x + 0.5, y + 0.5)
				if not Geometry2D.is_point_in_polygon(pp, pl):
					continue
				var ridge := bx + (tip.x - bx) * clampf((base - pp.y) / h, 0.0, 1.0)
				var c: Color = CRYS[1] if pp.x < ridge else CRYS[3]
				if absf(pp.x - ridge) < 0.8:
					c = CRYS[0] if pp.x < ridge else CRYS[2]
				if pp.x < bx - w + 1.2:
					c = CRYS[0]
				if pp.y > base - 2.0:
					c = CRYS[4] if pp.x > ridge else CRYS[3]
				if pp.y < tip.y + 3.0 and pp.x < ridge:
					c = CRYS[0]
				pix[Vector2i(x, y)] = c
		blit(pix, CRYS[4].darkened(0.5))


## Грибы-трутовики на камне: полукруглые шляпки ярусом, светлая кромка, тень под шляпкой.
func tinder(cx: int, cy: int, n: int) -> void:
	for i in n:
		var x := cx + (i % 2) * 7 - 3
		var y := cy + i * 6
		var pix := {}
		ball(pix, x, y, 6.5 - i * 0.6, 3.2, [FUNG[0], FUNG[0], FUNG[1], FUNG[2], FUNG[3]], y + 1)
		blit(pix)
		for k in range(-5 + i, 6 - i):
			put(x + k, y + 1, FUNG[3].darkened(0.3))


## Маленькие светящиеся грибочки (ножка + шляпка).
func shrooms(cx: int, base: int, sd: int) -> void:
	glow(cx, base - 6, 12, Color8(170, 200, 230), 0.16)
	for i in 3:
		var x: int = cx + [-5, 0, 5][i]
		var h: int = [6, 9, 5][i] + sd % 2
		var pix := {}
		for y in range(base - h, base):
			pix[Vector2i(x, y)] = STEM[1]
			pix[Vector2i(x + 1, y)] = STEM[2]
		blit(pix)
		var cap := {}
		ball(cap, x + 0.5, base - h, 3.0 + (1 if i == 1 else 0), 2.0, [Color8(220, 238, 246), Color8(170, 210, 230), Color8(130, 176, 206), Color8(96, 138, 176), Color8(72, 104, 140)], base - h + 2)
		blit(cap)


## Корень, выползающий из скалы: изогнутая ветка с отростками.
func root(x0: int, y0: int, n: int, dx: float, sd: int) -> void:
	var pix := {}
	var p := Vector2(x0, y0)
	var ang := atan2(1.0, dx)
	for i in n:
		ang += sin(i * 0.4 + sd) * 0.12
		p += Vector2(cos(ang), sin(ang)) * 1.0
		var w := 2.5 * (1.0 - float(i) / n) + 0.6
		for yy in range(-int(w), int(w) + 1):
			for xx in range(-int(w), int(w) + 1):
				if xx * xx + yy * yy <= w * w:
					var k := Vector2i(int(p.x) + xx, int(p.y) + yy)
					pix[k] = ROOT[0] if (yy < 0 or xx < 0) and absf(yy) >= w - 1 else ROOT[1]
		if i > 4 and i % 9 == 4:
			var b := p
			for j in 6:
				b += Vector2(cos(ang + 0.9), sin(ang + 0.9))
				pix[Vector2i(int(b.x), int(b.y))] = ROOT[1]
	for k: Vector2i in pix.keys():
		if not pix.has(k + Vector2i(0, 1)) or not pix.has(k + Vector2i(1, 0)):
			pix[k] = ROOT[2]
	blit(pix)


## Камешки на полу.
func pebble(cx: int, cy: int, s: int, sd: int) -> void:
	var pix := {}
	ball(pix, cx, cy, s, s * 0.7, [SLAB[0], SLAB[1], SLAB[2], SLAB[3], SLAB[4]])
	ground_shadow(cx + 2, cy + int(s * 0.5), s, 2, 0.28)
	blit(pix)


## Череп и кости.
func bones(cx: int, cy: int) -> void:
	ground_shadow(cx + 4, cy + 4, 10, 3, 0.25)
	var b := {}
	for i in 12:
		b[Vector2i(cx - 10 + i, cy + 3 - i / 4)] = BONE[1]
		b[Vector2i(cx - 10 + i, cy + 4 - i / 4)] = BONE[2]
	for e: Vector2i in [Vector2i(-11, 3), Vector2i(-11, 5), Vector2i(2, 0), Vector2i(2, 2)]:
		b[Vector2i(cx + e.x, cy + e.y)] = BONE[1]
	blit(b)
	var s := {}
	ball(s, cx + 6, cy - 1, 5, 4.5, [BONE[0], BONE[0], BONE[1], BONE[2], BONE[2]])
	for x in range(cx + 3, cx + 10):
		s[Vector2i(x, cy + 3)] = BONE[1]
		s[Vector2i(x, cy + 4)] = BONE[2]
	blit(s)
	for e: Vector2i in [Vector2i(4, -1), Vector2i(5, -1), Vector2i(4, 0), Vector2i(8, -1), Vector2i(8, 0), Vector2i(9, -1)]:
		put(cx + e.x, cy + e.y, CREV)
	put(cx + 6, cy + 2, CREV)


## Лестница вниз: проём в полу, ступени спускаются к зрителю — у каждой ступени светлая
## кромка, проступь и тёмный подступёнок; чем ниже, тем темнее, внизу темнота. Левая стенка
## проёма на свету, правая в тени; по краю — обкладка из камней разной длины.
func stairs(x: int, y: int, w: int, h: int) -> void:
	var pal := [SLAB[0], SLAB[1], SLAB[3]]
	ground_shadow(x + w / 2 + 6, y + h + 2, w / 2 + 8, 4, 0.25)
	# Обкладка: сверху длинные плиты, по бокам — короткие камни.
	var lens := [14, 10, 16, 12, 9, 15]
	var px := x - 6
	var i := 0
	while px < x + w + 6:
		var l: int = mini(lens[i % lens.size()], x + w + 6 - px)
		bar(px, y - 7, l - 1, 6, pal)
		px += l
		i += 1
	var py := y
	i = 0
	while py < y + h:
		var l: int = mini([11, 8, 13][i % 3], y + h - py)
		bar(x - 7, py, 5, l - 1, pal)
		bar(x + w + 2, py, 5, l - 1, [SLAB[1], SLAB[2], SLAB[4]])
		py += l
		i += 1
	rect(x - 1, y - 1, w + 2, h + 1, OUT)
	rect(x, y, w, h, CREV)
	var n := 5
	var sh := 7
	for k in n:
		var t := float(k) / n                  # 0 — верхняя ступень (у пола)
		var sy := y + k * sh
		if sy + sh > y + h:
			break
		var dk := t * 0.6
		rect(x, sy, w, 4, SLAB[1].darkened(dk))          # проступь
		rect(x, sy, w, 1, SLAB[0].darkened(dk))          # светлая кромка
		rect(x, sy + 4, w, 3, SLAB[3].darkened(dk + 0.1))  # подступёнок
		rect(x, sy + 6, w, 1, SLAB[4].darkened(dk + 0.25))
		# Стенки проёма.
		rect(x, sy, 3, sh, SLAB[2].darkened(dk))
		rect(x, sy, 1, sh, SLAB[1].darkened(dk))
		rect(x + w - 3, sy, 3, sh, SLAB[4].darkened(dk + 0.1))
	# Тень от верхней кромки проёма.
	for xx in w:
		tint(x + xx, y, 0.4)
		tint(x + xx, y + 1, 0.25)


## Колонна-скала — кусок той же скалы, что стены: верх из глыб с мхом, передняя грань с
## гранями, тень вправо; на верхушке друза кристаллов.
func pillar(cx: int, base: int, r: int, hgt: int, cap := 8, crys := true) -> void:
	# Скальный выступ — угловатая глыба как камни лагеря (crag): верхняя грань с мхом,
	# передняя на свету, правый бок в тени, трещины, контур; кристаллы на вершине.
	var w := r * 2 + 6
	var h := hgt + cap * 2
	ground_shadow(cx + r / 2 + 4, base - 2, r + 6, 5, 0.32)
	crag(cx, base - h / 2, w, h, r * 13 + cap)
	if crys:
		crystals(cx - 3, base - h + int(h * 0.3), 6.0, 4, true)


## Угловатая глыба (перенесено из camp_art._rock, палитра скал подземелья).
func crag(cx: int, cy: int, w: int, h: int, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var pts := PackedVector2Array()
	for i in 7:
		var ang := -PI / 2.0 + i * TAU / 7.0 + rng.randf_range(-0.25, 0.25)
		var rr := rng.randf_range(0.82, 1.0)
		var p := Vector2(cx + cos(ang) * w * 0.5 * rr, cy + sin(ang) * h * 0.5 * rr)
		if p.y > cy + h * 0.3:
			p.y = cy + h * 0.5
		pts.append(p)
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	var top_y := cy - h * 0.12
	var split_x := cx + w * 0.16
	var pix := {}
	for py in range(int(r.position.y) - 1, int(r.end.y) + 2):
		for px in range(int(r.position.x) - 1, int(r.end.x) + 2):
			if not Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), pts):
				continue
			var jag := 2.0 * sin(px * 0.45 + sd) + float(hh(px / 3, 0, sd) % 3)
			var ty := top_y + jag
			var sxl := split_x + (py - cy) * 0.35
			var c: Color
			if py < ty:
				c = ROCKD[0]
				# Мох — цельные шапки по шуму, светлый верх и тёмный край.
				var mn := nz.get_noise_2d(px * 2.2 + sd, py * 2.2)
				if mn > 0.05 and py < ty - 1:
					c = MOSS[0] if mn > 0.2 else MOSS[1]
				elif mn > -0.02 and py < ty - 1:
					c = MOSS[2]
			elif py < ty + 1.5:
				c = ROCKD[3]                         # тень под ребром верхней грани
			elif px > sxl:
				c = ROCKD[2] if px < sxl + 1.5 or hh(px / 3, py / 3, sd + 2) > 200 else ROCKD[3]
				if px < sxl + 1.0:
					c = ROCKD[4]                     # ребро между гранями
			else:
				c = ROCKD[1]
				if px < r.position.x + 3:
					c = ROCKD[0]                     # освещённая левая кромка
			if py > r.end.y - 3:
				c = ROCKD[3]
			# Трещины — редкие короткие линии.
			if py > ty + 4 and absf(px - (cx - w * 0.2 + (py - ty) * 0.5 + (sd % 7))) < 0.6 and py < ty + 12:
				c = ROCKD[4]
			pix[Vector2i(px, py)] = c
	blit(pix)

## Тёмный холст для крупного вида монстров и пол под ними.
func floor_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			put(x, y, slab(x, y))


# ===================================================================================
#                                       МОНСТРЫ
#  Кадр 48x48 пикселей картинки (24 мира). Рисуются от середины основания (cx, base).
#  dir: 0 — вниз (к нам), 1 — вбок вправо (влево — зеркалом), 2 — вверх (спиной).
# ===================================================================================

func monster(kind: String, cx: int, base: int, dir: int, fr: int) -> void:
	match kind:
		"slime":
			slime(cx, base, dir, fr, SLIME_G, false)
		"slime_splitter":
			slime(cx, base, dir, fr, SLIME_S, true)
		"bat":
			bat(cx, base, dir, fr, BAT_B, BAT_W, Color8(236, 206, 110), false)
		"vampire_bat":
			bat(cx, base, dir, fr, VAMP_B, VAMP_W, Color8(240, 96, 80), true)
		"wisp":
			wisp(cx, base, dir, fr)
		"mushroom":
			mushroom(cx, base, dir, fr, CAP_P, Color8(226, 206, 236), false)
		"bomb_shroom":
			mushroom(cx, base, dir, fr, CAP_R, Color8(246, 238, 222), true)

const MONSTERS := {"slime": 3, "slime_splitter": 3, "bat": 2, "vampire_bat": 2, "wisp": 2, "mushroom": 2, "bomb_shroom": 2}


func eye(x: int, y: int, h: int, c: Color = EYE, glint := true) -> void:
	for i in h:
		put(x, y + i, c)
		put(x + 1, y + i, c)
	if glint:
		put(x, y, Color8(250, 246, 236))


## Слизень: прозрачный купол — светлая кромка сверху, внутри пузырьки, тёмное дно с бликом
## от пола; блик-окно сверху-слева; глаза. fr: 0 покой, 1 приплюснут, 2 прыжок.
func slime(cx: int, base: int, dir: int, fr: int, pal: Array, split: bool) -> void:
	var rx: float = [16.0, 18.0, 13.0][fr]
	var ry: float = [14.0, 11.0, 16.0][fr]
	var lift := 6 if fr == 2 else 0
	if fr != 2:
		ground_shadow(cx + 3, base - 1, int(rx) + 2, 3, 0.32)
	else:
		ground_shadow(cx + 3, base - 1, int(rx) - 3, 2, 0.22)
	var bottom := base - lift
	var cy := bottom - ry * 0.85
	var pix := {}
	ball(pix, cx, cy, rx, ry, pal, bottom)
	# Пузырьки внутри (светлый верх пузырька, тёмный низ).
	for b: Vector3 in [Vector3(-6, 4, 2.0), Vector3(7, 2, 1.5), Vector3(2, 7, 1.2)]:
		var bx := cx + int(b.x * rx / 16.0)
		var by := int(cy + b.y)
		for yy in range(-2, 3):
			for xx in range(-2, 3):
				if xx * xx + yy * yy <= b.z * b.z + 0.5:
					var k := Vector2i(bx + xx, by + yy)
					if pix.has(k):
						pix[k] = (pal[0] as Color) if yy < 0 else (pal[1] as Color)
	if split:
		# Шов посередине: слизень вот-вот разделится; два ядра.
		for y in range(int(cy - ry) + 3, bottom - 2):
			var k := Vector2i(cx + int(sin(y * 0.5) * 1.2), y)
			if pix.has(k):
				pix[k] = pal[4]
				if pix.has(k + Vector2i(1, 0)):
					pix[k + Vector2i(1, 0)] = pal[0]
		for s: int in [-1, 1]:
			for yy in range(-2, 3):
				for xx in range(-2, 3):
					if xx * xx + yy * yy <= 4:
						var k := Vector2i(cx + s * 7 + xx, int(cy) + 3 + yy)
						if pix.has(k):
							pix[k] = Color8(236, 150, 90) if yy < 1 else Color8(190, 100, 70)
	# Блик-окно.
	var hx := cx - int(rx * 0.45)
	var hy := int(cy - ry * 0.5)
	for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(4, -1)]:
		var q := Vector2i(hx, hy) + k
		if pix.has(q):
			pix[q] = Color8(246, 250, 232)
	blit(pix, (pal[4] as Color).darkened(0.45))
	if dir == 2:
		return
	var ex := cx + (3 if dir == 1 else 0)
	var ey := int(cy) - 2
	if dir == 0:
		eye(ex - 6, ey, 4)
		eye(ex + 4, ey, 4)
		if fr != 2:
			put(ex - 1, ey + 6, EYE)
			put(ex, ey + 7, EYE)
			put(ex + 1, ey + 6, EYE)
	else:
		eye(ex + 1, ey, 4)
		eye(ex + 7, ey, 4)


## Мышь: тело-шар с ушами, крылья-перепонки с пальцами (кромка крыла светлая, перепонка
## между пальцами провисает, у тела темнее), глаза светятся. fr: 0 крылья вверх, 1 вниз.
func bat(cx: int, base: int, dir: int, fr: int, body: Array, wing: Array, eyec: Color, fangs: bool) -> void:
	var cy := base - 22 - (2 if fr == 0 else 0)
	ground_shadow(cx + 4, base - 2, 10, 3, 0.22)
	for s: int in [-1, 1]:
		var tip := Vector2(cx + s * 22, cy - (12 if fr == 0 else -8))
		var elbow := Vector2(cx + s * 12, cy - (10 if fr == 0 else 2))
		var pts := PackedVector2Array()
		pts.append(Vector2(cx + s * 4, cy - 4))
		pts.append(elbow)
		pts.append(tip)
		# Провисающая перепонка: три фестона между пальцами.
		var root_p := Vector2(cx + s * 5, cy + 5)
		for i in range(1, 4):
			var f := float(i) / 3.0
			var a := tip.lerp(root_p, f - 1.0 / 6.0) + Vector2(0, 5 if fr == 0 else 3)
			pts.append(a)
			pts.append(tip.lerp(root_p, f))
		if s < 0:
			pts.reverse()
		var pal: Array = wing
		if dir == 1 and s < 0:
			pal = [wing[2], wing[3], wing[3], wing[4], wing[4]]
		var pix := {}
		poly(pix, pts, pal, 2)
		# Пальцы — светлые косточки от локтя к фестонам.
		for i in range(0, 3):
			var f := float(i) / 3.0
			var to := tip.lerp(root_p, f)
			for t in 12:
				var q := elbow.lerp(to, t / 12.0)
				var k := Vector2i(int(q.x), int(q.y))
				if pix.has(k):
					pix[k] = pal[1]
		for t in 14:
			var q := Vector2(cx + s * 4, cy - 4).lerp(elbow, t / 14.0)
			pix[Vector2i(int(q.x), int(q.y))] = pal[0]
			q = elbow.lerp(tip, t / 14.0)
			pix[Vector2i(int(q.x), int(q.y))] = pal[0]
		blit(pix)
	# Уши.
	for s: int in [-1, 1]:
		var e := {}
		poly(e, PackedVector2Array([Vector2(cx + s * 2, cy - 6), Vector2(cx + s * 7, cy - 15), Vector2(cx + s * 9, cy - 4)]), body, 1)
		blit(e)
	var b := {}
	ball(b, cx, cy, 9, 8.5, body)
	# Пушистая грудка — светлые штрихи.
	if dir == 0:
		for i in 5:
			b[Vector2i(cx - 2 + i, cy + 3 + i % 2)] = body[1]
	blit(b)
	if dir == 2:
		return
	var ex := cx + (4 if dir == 1 else 0)
	if dir == 0:
		eye(ex - 5, cy - 2, 3, eyec, false)
		eye(ex + 3, cy - 2, 3, eyec, false)
		put(ex - 5, cy - 2, Color8(255, 250, 220))
		put(ex + 3, cy - 2, Color8(255, 250, 220))
	else:
		eye(ex + 2, cy - 2, 3, eyec, false)
		put(ex + 2, cy - 2, Color8(255, 250, 220))
	if fangs:
		var fx := ex - 2 if dir == 0 else ex + 3
		for f: int in ([0, 3] if dir == 0 else [0]):
			put(fx + f, cy + 3, BONE[0])
			put(fx + f, cy + 4, BONE[1])


## Дух: светящийся сгусток — голова-шар, хвост-язык пламени книзу, язычки сверху; ядро светлее,
## мягкий ореол. fr: 0/1 — хвост качается.
func wisp(cx: int, base: int, dir: int, fr: int) -> void:
	var cy := base - 26
	glow(cx, cy, 22, WISP[1], 0.2)
	ground_shadow(cx + 4, base - 2, 8, 2, 0.2)
	var sw := 2 if fr == 1 else -2
	var tail := {}
	poly(tail, PackedVector2Array([Vector2(cx - 9, cy + 2), Vector2(cx + 9, cy + 2), Vector2(cx + 5 + sw, cy + 12),
		Vector2(cx + 1 - sw, cy + 17), Vector2(cx + sw * 2, cy + 22), Vector2(cx - 3 - sw, cy + 15), Vector2(cx - 7 + sw, cy + 10)]), WISP, 2)
	blit(tail, (WISP[4] as Color).darkened(0.45))
	var flames := {}
	for i in 3:
		var fx := cx - 6 + i * 6
		var fh: int = [8, 13, 9][i] + (2 if (i + fr) % 2 == 0 else 0)
		poly(flames, PackedVector2Array([Vector2(fx - 4, cy - 4), Vector2(fx + (1 if fr == 0 else -1), cy - 4 - fh), Vector2(fx + 4, cy - 4)]), WISP, 1)
	blit(flames, (WISP[4] as Color).darkened(0.45))
	var head := {}
	ball(head, cx, cy, 11, 10, WISP)
	# Светлое ядро.
	for yy in range(-4, 5):
		for xx in range(-5, 5):
			if xx * xx + yy * yy * 1.4 <= 18:
				head[Vector2i(cx - 1 + xx, cy + 1 + yy)] = WISP[0] if xx * xx + yy * yy < 8 else WISP[1]
	blit(head, (WISP[4] as Color).darkened(0.45))
	if dir == 2:
		return
	var ex := cx + (4 if dir == 1 else 0)
	var ec := Color8(54, 50, 104)
	if dir == 0:
		eye(ex - 5, cy - 2, 5, ec)
		eye(ex + 3, cy - 2, 5, ec)
		put(ex - 1, cy + 5, ec)
		put(ex, cy + 5, ec)
	else:
		eye(ex + 3, cy - 2, 5, ec)


## Гриб: шляпка-купол (светлая кромка, тень на нижнем крае и тёмная полоска пластинок под ней —
## чёткий переход «шляпка → низ»), пятна со своим светом/тенью, ножка с лицом.
## fr: 0 покой, 1 выброс спор (шляпка приседает, облачка). bomb — фитиль с искрой.
func mushroom(cx: int, base: int, dir: int, fr: int, cap: Array, spot: Color, bomb: bool) -> void:
	ground_shadow(cx + 4, base - 2, 14, 3, 0.3)
	var sq := 2 if fr == 1 else 0
	var st := {}
	for y in range(base - 18, base):
		var t := float(y - (base - 18)) / 18.0
		var hw := 6 + int(t * 2.0)
		for x in range(cx - hw, cx + hw + 1):
			var u := float(x - cx) / hw
			st[Vector2i(x, y)] = STEM[0] if u < -0.5 else (STEM[1] if u < 0.35 else (STEM[2] if u < 0.75 else STEM[3]))
			if y >= base - 2:
				st[Vector2i(x, y)] = STEM[3]
	blit(st)
	if dir != 2:
		var fx := cx + (3 if dir == 1 else 0)
		if dir == 0:
			eye(fx - 4, base - 12, 3)
			eye(fx + 2, base - 12, 3)
		else:
			eye(fx + 2, base - 12, 3)
		if fr == 1:
			rect(fx - 1, base - 6, 3, 2, EYE)
		else:
			put(fx, base - 6, EYE)
			put(fx + 1, base - 6, EYE)
	var cy := base - 22 + sq
	var gills := {}
	for x in range(cx - 15, cx + 16):
		var yy := cy + 6 + int(2.0 * (1.0 - pow((x - cx) / 15.0, 2.0)))
		gills[Vector2i(x, yy)] = cap[4]
		gills[Vector2i(x, yy - 1)] = STEM[3] if posmod(x, 2) == 0 else cap[4]
	blit(gills)
	var c := {}
	ball(c, cx, cy, 17 + sq * 0.5, 11 - sq * 0.5, cap, cy + 7)
	# Кромка шляпки снизу — тень, по ней видно, где кончается купол.
	for x in range(cx - 16, cx + 17):
		var k := Vector2i(x, cy + 6)
		if c.has(k):
			c[k] = cap[4]
	# Пятна: свет сверху-слева, тень снизу-справа.
	for v: Vector3 in [Vector3(-9, -3, 3), Vector3(1, -7, 2.5), Vector3(9, -2, 3), Vector3(-2, 2, 2), Vector3(-13, 2, 1.5), Vector3(13, 3, 1.5)]:
		if dir == 2 and v.y > 0:
			continue
		for yy in range(-3, 4):
			for xx in range(-3, 4):
				if xx * xx + yy * yy * 1.3 <= v.z * v.z:
					var k := Vector2i(cx + int(v.x) + xx, cy + int(v.y) + yy)
					if c.has(k):
						c[k] = spot if (yy < 1 and xx < 1) else spot.darkened(0.18)
	blit(c)
	if bomb:
		# Фитиль и искра.
		var top := Vector2(cx + 1, cy - 11)
		for t in 8:
			var q := top + Vector2(t * 0.6, -t)
			put(int(q.x), int(q.y), Color8(96, 70, 50))
			put(int(q.x) + 1, int(q.y), Color8(66, 46, 40))
		var sp := top + Vector2(5, -9)
		glow(sp.x, sp.y, 7 + fr * 2, Color8(255, 200, 100), 0.35)
		for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1)]:
			put(int(sp.x) + k.x, int(sp.y) + k.y, Color8(255, 236, 150) if k == Vector2i.ZERO else Color8(246, 164, 70))
		if fr == 1:
			for k: Vector2i in [Vector2i(-3, -3), Vector2i(3, -2), Vector2i(2, 3)]:
				put(int(sp.x) + k.x, int(sp.y) + k.y, Color8(255, 220, 120))
	elif fr == 1:
		for v: Vector2 in [Vector2(-20, -8), Vector2(19, -10), Vector2(-16, 4), Vector2(17, 6), Vector2(0, -20)]:
			var pf := {}
			ball(pf, cx + v.x, cy + v.y, 3.2, 2.6, [Color8(236, 222, 246), Color8(214, 194, 230), Color8(190, 166, 212), Color8(164, 140, 192), Color8(140, 116, 170)])
			blit(pf, Color8(120, 96, 140))
