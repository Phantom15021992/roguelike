extends "res://tools/pixstyle.gd"
## Графика лагеря в утверждённом стиле (общая для превью tools/camp_preview.gd и генератора
## спрайтов игры tools/gen_camp.gd): земля, конструктор домов, постройки, портал, шахта, мелочи.
## Правила стиля — .claude/skills/pixel-style. Плотность: клетка 16 px мира = 32 px картинки.

const LAY := preload("res://scripts/camp_layout.gd")

const C := 32   # клетка в пикселях картинки

const R_TERRA := [Color8(214, 150, 98), Color8(184, 110, 72), Color8(148, 82, 60), Color8(110, 58, 50), Color8(82, 44, 44)]

const R_BLUE := [Color8(150, 170, 206), Color8(112, 134, 180), Color8(84, 102, 148), Color8(62, 74, 116), Color8(44, 52, 86)]

const R_GREEN := [Color8(168, 196, 128), Color8(124, 160, 96), Color8(92, 126, 76), Color8(66, 94, 62), Color8(46, 66, 50)]

const R_DRED := [Color8(196, 118, 96), Color8(160, 84, 70), Color8(126, 62, 56), Color8(96, 46, 46), Color8(70, 34, 38)]

const R_PURPLE := [Color8(176, 150, 196), Color8(138, 112, 164), Color8(106, 84, 132), Color8(80, 62, 104), Color8(56, 44, 76)]

const R_STRAW := [Color8(232, 204, 130), Color8(206, 170, 98), Color8(170, 134, 74), Color8(132, 100, 58), Color8(96, 72, 48)]

const R_BROWN := [Color8(196, 150, 110), Color8(164, 116, 82), Color8(128, 88, 64), Color8(96, 64, 50), Color8(70, 46, 40)]

const ROCK := [Color8(218, 218, 194), Color8(186, 188, 164), Color8(150, 154, 134), Color8(112, 116, 102), Color8(80, 84, 76)]

const WATER := [Color8(132, 188, 214), Color8(94, 154, 192), Color8(70, 124, 170), Color8(52, 94, 140)]

var last_door := Vector2.ZERO   # дверь последней нарисованной постройки (координаты холста)

## Сдвиг начала координат (рисуем постройку в её местных координатах).
func at(x: int, y: int) -> void:
	OX = x
	OY = y

func _ground() -> void:
	var kinds := PackedByteArray()
	kinds.resize(W * H)
	for y in H:
		for x in W:
			var wn := nz.get_noise_2d(x * 2.0, y * 2.0) * 0.18
			var k := LAY.kind_at(x / float(C) + wn, y / float(C) - wn)
			if k == LAY.PATH:
				k = LAY.GRASS        # у построенной шахты вместо утоптанной земли — трава
			var c := Color(0, 0, 0, 0)
			if k == LAY.STONE:
				c = _paver(x, y)
			elif k == LAY.WATER:
				c = _water(x, y)
			elif k == LAY.PATH:
				c = Color8(170, 142, 104) if hh(x / 3, y / 2, 80) > 160 else Color8(150, 122, 88)
				if hh(x, y, 81) < 20:
					c = Color8(196, 182, 152)
			elif k == LAY.FOREST:
				c = GRASS[2].darkened(0.25) if hh(x / 3, y / 3, 82) > 300 else GRASS[3].darkened(0.2)
			kinds[y * W + x] = k
			if c.a > 0.0:
				put(x, y, c)
	grass_where(kinds)
	# Кромка мостовой: тёмная линия там, где она граничит с травой, и пучки травы на швах.
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if kinds[y * W + x] != LAY.STONE:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var kk: int = kinds[(y + d.y) * W + x + d.x]
				if kk == LAY.GRASS or kk == LAY.FOREST:
					put(x, y, GROUND[3])
					break

func grass_where(kinds: PackedByteArray) -> void:
	for y in H:
		for x in W:
			if kinds[y * W + x] != LAY.GRASS:
				continue
			var n := nz.get_noise_2d(x, y * 1.3)
			var c: Color = GRASS[1]
			if n > 0.25:
				c = GRASS[1].lerp(GRASS[0], 0.35)
			elif n < -0.3:
				c = GRASS[1].lerp(GRASS[2], 0.6)
			if hh(x / 2, y / 3, 20) < 26:
				c = GRASS[0] if posmod(y, 3) == 0 else GRASS[2]
			if hh(x / 2, y / 2, 22) < 2:
				c = [Color8(236, 214, 120), Color8(232, 140, 150), Color8(240, 236, 226)][hh(x, y, 23) % 3]
			put(x, y, c)

## Мостовая из плит 18x9 со светом сверху-слева и тенью снизу-справа, мох в швах.
func _paver(x: int, y: int) -> Color:
	var row := y / 9
	var off := (row % 2) * 9
	var sx := posmod(x + off, 18)
	var sy := y % 9
	var c: Color = GROUND[1]
	var v := hh((x + off) / 18, row, 3) % 4
	if v == 0:
		c = GROUND[0].darkened(0.05)
	elif v == 3:
		c = GROUND[2]
	if sy == 0 or sx == 0:
		c = GROUND[3]
		if hh(x, y, 4) % 5 == 0:
			c = MOSS[2]
	elif sy == 1 or sx == 1:
		c = GROUND[0]
	elif sy == 8 or sx == 17:
		c = GROUND[2]
	return c

func _water(x: int, y: int) -> Color:
	var cx := LAY.POND.x * C
	var cy := LAY.POND.y * C
	var d := Vector2((x - cx) / (LAY.POND_R.x * C), (y - cy) / (LAY.POND_R.y * C)).length()
	if d > 0.88:
		# Берег: камни с контуром, светлым верхом и тенью.
		var s := hh(x / 7, y / 5, 83)
		var c: Color = STONE[1] if s % 3 != 0 else STONE[2]
		if posmod(x, 7) == 0 or posmod(y, 5) == 0:
			c = STONE[3]
		elif posmod(y, 5) == 1:
			c = STONE[0]
		return c
	var c: Color = WATER[1] if d < 0.6 else WATER[0].lerp(WATER[1], 0.5)
	if d < 0.35:
		c = WATER[2]
	if y < cy - LAY.POND_R.y * C * 0.55 and d > 0.7:
		c = WATER[3]                       # тень от дальнего берега
	if sin(x * 0.22 + sin(y * 0.3) * 2.0 + y * 0.5) > 0.95:
		c = WATER[0].lightened(0.25)
	if hh(x, y, 84) < 3:
		c = Color8(236, 246, 250)
	for lp: Vector2 in [Vector2(37.3, 16.7), Vector2(39.3, 17.8), Vector2(38.2, 18.2)]:
		var q := Vector2(x / float(C) - lp.x, (y / float(C) - lp.y) * 1.6)
		if q.length() < 0.26:
			c = Color8(112, 168, 82) if q.y > -0.08 else Color8(150, 196, 100)
			if q.length() > 0.22:
				c = Color8(54, 90, 52)
	return c


# ===================================================================================
#                                    ПОСТРОЙКИ
# ===================================================================================

## Стена: фахверк (штукатурка + балки), камень или доски. top/base — местные y.
func wall(x0: int, top: int, w: int, base: int, mat: String) -> void:
	var h := base - top
	if mat == "stone":
		for yy in h:
			for xx in w:
				var row := yy / 7
				var len_ := 12 + (row % 3) * 2
				var off := (row % 2) * 6
				var sx := posmod(xx + off, len_)
				var sy := yy % 7
				var c: Color = STONE[1] if hh((xx + off) / len_, row, 90) % 3 != 0 else STONE[1].darkened(0.07)
				if sy == 0 or sx == 0:
					c = STONE[3]
				elif sy == 1 or sx == 1:
					c = STONE[0]
				elif sy == 6 or sx == len_ - 1:
					c = STONE[2]
				put(x0 + xx, top + yy, c)
	elif mat == "planks":
		for yy in h:
			for xx in w:
				var pl := xx % 6
				var c: Color = WOOD[1] if (xx / 6) % 2 == 0 else WOOD[1].darkened(0.05)
				if pl == 0:
					c = WOOD[3]
				elif pl == 1:
					c = WOOD[0]
				elif pl == 5:
					c = WOOD[2]
				elif hh(x0 + xx, (top + yy) / 4, 91) < 60:
					c = WOOD[2]
				put(x0 + xx, top + yy, c)
	else:
		_plaster(x0, top, w, h)
	# Цоколь.
	for yy in 8:
		for xx in range(x0, x0 + w):
			var c: Color = STONE[1]
			var sx := (xx + (yy / 4) * 4) % 10
			if yy % 4 == 0 or sx == 0:
				c = STONE[3]
			elif yy % 4 == 1 or sx == 1:
				c = STONE[0]
			put(xx, base - 8 + yy, c)
	rect(x0 - 1, base - 9, w + 2, 1, OUT)
	if mat == "timber":
		bar(x0, top, w, 4, WOOD)
		bar(x0, base - 13, w, 4, WOOD)
		var n := maxi(2, w / 36)
		for i in n + 1:
			var px := x0 + int(float(w - 5) * i / n)
			bar(px, top + 4, 5, base - 13 - top - 4, WOOD)
			shadow(px + 5, top + 4, 1, base - 17 - top, 0.22)
		shadow(x0, top + 4, w, 1, 0.25)
	elif mat == "planks":
		bar(x0, top, w, 3, WOOD)
	shadow(x0, top, w, 3, 0.3)

## Дом: основной блок (крыша вдоль фасада, виден один скат) и/или крыло с фронтоном к зрителю
## (видны оба ската); край основной крыши срезан по диагонали поверх ската крыла.
## s: main {x, w, h, rh, mat}, wing {x, w, h, gh, back, mat}, door [cx, w, h], wins [[x, y, w, h]],
##    sign [x, y, w, text], chimney [x, y, h] (на правом скате крыла) или mchim [x, y] (на основной).
func house(s: Dictionary) -> void:
	var main: Dictionary = s.get("main", {})
	var wing: Dictionary = s.get("wing", {})
	var right_x := 0
	var shadow_top := 0
	if not wing.is_empty():
		right_x = int(wing["x"]) + int(wing["w"])
		shadow_top = -int(wing["h"]) - int(wing["gh"]) + 16
	else:
		right_x = int(main["x"]) + int(main["w"])
		shadow_top = -int(main["h"]) - int(main["rh"]) + 20
	# Тень справа от дома — от линии стены, полосой.
	for y in range(shadow_top, 0):
		var w := 16 if y > shadow_top + 13 else clampi(y - shadow_top + 3, 0, 16)
		for x in range(right_x, right_x + 8 + w):
			put(x, y, Color(0.16, 0.08, 0.16, 0.3))
	if s.has("mchim"):
		var mc: Array = s["mchim"]
		_chimney(int(mc[0]), int(mc[1]))
	if not wing.is_empty():
		_wing_roof_p(wing)
		if s.has("chimney"):
			var ch: Array = s["chimney"]
			_chimney_slope(int(ch[0]), int(ch[1]), int(ch[2]))
	if not main.is_empty():
		wall(int(main["x"]), -int(main["h"]), int(main["w"]), 0, main.get("mat", "timber"))
		_main_roof_p(main, wing)
	if s.has("before_wing"):
		(s["before_wing"] as Callable).call()
	if not wing.is_empty():
		_gable_p(wing)
	var lx := int(main["x"]) if not main.is_empty() else int(wing["x"])
	rect(lx - 1, 0, right_x - lx + 2, 1, OUT)
	for wnd: Array in s.get("wins", []):
		_window(int(wnd[0]), int(wnd[1]), int(wnd[2]), int(wnd[3]), false, true)
	if s.has("door"):
		var d: Array = s["door"]
		_door(int(d[0]), 0, int(d[1]), int(d[2]))
		last_door = Vector2(OX + int(d[0]), OY)
	if s.has("sign"):
		var sg: Array = s["sign"]
		_sign_board(int(sg[0]), int(sg[1]), int(sg[2]), str(sg[3]))
	if s.has("after"):
		(s["after"] as Callable).call()

func _main_roof_p(m: Dictionary, wing: Dictionary) -> void:
	var x0: int = m["x"]
	var x1: int = x0 + int(m["w"])
	var eave := -int(m["h"]) - 3
	var ridge := eave - int(m["rh"])
	var poly := PackedVector2Array()
	if not wing.is_empty():
		var lx := int(wing["x"]) - 7
		poly = PackedVector2Array([Vector2(x0 - 6, ridge), Vector2(lx + 25, ridge), Vector2(lx, ridge + 25), Vector2(lx, eave), Vector2(x0 - 6, eave)])
	else:
		poly = PackedVector2Array([Vector2(x0 - 6, ridge), Vector2(x1 + 6, ridge), Vector2(x1 + 6, eave), Vector2(x0 - 6, eave)])
	_shingles(poly, ridge, 0.07)
	for y in range(ridge, eave):
		for k in 12:
			tint(x0 - 5 + k, y, -(0.12 - k * 0.01))
	var rx1 := (int(wing["x"]) - 7 + 26) if not wing.is_empty() else x1 + 7
	bar(x0 - 7, ridge - 3, rx1 - x0 + 7, 4, RP)
	shadow(x0 - 6, ridge + 2, rx1 - x0 + 4, 1, 0.3)
	if not wing.is_empty():
		var lx := int(wing["x"]) - 7
		for i in 26:
			var p := Vector2(lx + 26, ridge + 1).lerp(Vector2(lx + 1, ridge + 26), float(i) / 25.0)
			var x := int(round(p.x))
			var y := int(round(p.y))
			put(x - 1, y, WOOD[0])
			put(x, y, WOOD[1])
			put(x + 1, y, WOOD[2])
			put(x + 2, y, OUT)
			tint(x + 3, y, 0.25)
			tint(x + 4, y, 0.15)
	else:
		bar(x1 + 3, ridge - 3, 4, eave - ridge + 6, WOOD)
	bar(x0 - 9, ridge - 3, 4, eave - ridge + 6, WOOD)
	var ex1 := (int(wing["x"]) - 6) if not wing.is_empty() else x1 + 7
	bar(x0 - 8, eave - 1, ex1 - x0 + 8, 4, WOOD)
	shadow(x0 - 4, eave + 4, ex1 - x0 + 2, 3, 0.35)

func _wing_roof_p(wg: Dictionary) -> void:
	var x0: int = wg["x"]
	var x1: int = x0 + int(wg["w"])
	var top := -int(wg["h"])
	var cx := (x0 + x1) / 2.0
	var l := Vector2(x0 - 7, top)
	var a := Vector2(cx, top - int(wg["gh"]) - 4)
	var r := Vector2(x1 + 7, top)
	var back := Vector2(0, -int(wg.get("back", 77)))
	var t := a + back
	var v := l + back
	var rv := r + back
	_slope(l, a - l, back, 0.0)
	_slope(r, a - r, back, 0.26)
	for y in range(int(v.y), int(l.y) + 1):
		put(int(l.x) - 1, y, OUT)
		put(int(l.x), y, WOOD[0])
		put(int(l.x) + 1, y, WOOD[1])
	for pair: Array in [[v, t, true], [rv, t, false]]:
		var p0: Vector2 = pair[0]
		var p1: Vector2 = pair[1]
		var lit: bool = pair[2]
		var m := int(maxf(absf(p1.x - p0.x), absf(p1.y - p0.y)))
		for i in m + 1:
			var p := p0.lerp(p1, float(i) / m)
			put(int(round(p.x)) + (-1 if lit else 1), int(round(p.y)), OUT)
			put(int(round(p.x)), int(round(p.y)), RP[0] if lit else RP[3])
	for y in range(int(rv.y), int(r.y) + 1):
		put(int(r.x) + 1, y, OUT)
		put(int(r.x), y, WOOD[2])
		put(int(r.x) - 1, y, WOOD[1])
	for y in range(int(t.y), int(a.y) + 1):
		put(int(a.x) - 2, y, OUT)
		put(int(a.x) - 1, y, RP[0])
		put(int(a.x), y, RP[1])
		put(int(a.x) + 1, y, RP[3])
		put(int(a.x) + 2, y, OUT)
	for k in range(-1, 2):
		put(int(t.x) + k, int(t.y) - 1, OUT)
	_board(l, a)
	_board(a, r)
	rect(int(a.x) - 2, int(a.y) - 7, 4, 6, OUT)
	rect(int(a.x) - 1, int(a.y) - 6, 2, 4, WOOD[1])
	put(int(a.x) - 1, int(a.y) - 6, WOOD[0])

func _gable_p(wg: Dictionary) -> void:
	var x0: int = wg["x"]
	var x1: int = x0 + int(wg["w"])
	var top := -int(wg["h"])
	var cx := (x0 + x1) / 2
	var mat: String = wg.get("mat", "timber")
	wall(x0, top, x1 - x0, 0, mat)
	var apex := top - int(wg["gh"])
	for y in range(apex, top):
		var half := int(float(y - apex) / float(top - apex) * (x1 - x0 + 10) / 2.0)
		for xx in range(cx - half, cx + half):
			var c: Color = PLAST[1] if hh(xx / 2, y / 2, 11) >= 80 else PLAST[2]
			if mat == "planks":
				c = WOOD[1] if xx % 6 > 1 else (WOOD[3] if xx % 6 == 0 else WOOD[0])
			elif mat == "stone":
				c = STONE[1] if (y % 7 != 0 and posmod(xx + (y / 7) * 6, 12) != 0) else STONE[3]
			put(xx, y, c)
	for y in range(apex + 4, top):
		var half := int(float(y - apex) / float(top - apex) * (x1 - x0 + 10) / 2.0)
		tint(cx - half + 1, y, 0.25)
		tint(cx - half + 2, y, 0.15)
		tint(cx + half - 2, y, 0.25)
		tint(cx + half - 3, y, 0.15)
	var gw: String = wg.get("gwin", "rect")
	var wy := apex + int((top - apex) * 0.45)
	if gw == "rect":
		rect(cx - 7, wy - 3, 14, 15, OUT)
		bar(cx - 6, wy - 2, 12, 13, WOOD, false)
		rect(cx - 4, wy, 8, 9, GLASS[1])
		rect(cx - 4, wy, 8, 2, GLASS[2])
		put(cx - 3, wy + 3, GLASS[0])
		put(cx - 2, wy + 2, GLASS[0])
		rect(cx - 1, wy, 2, 9, WOOD[2])
		bar(cx - 8, wy + 12, 16, 2, WOOD)
	elif gw == "round":
		for yy in range(-6, 7):
			for xx in range(-6, 7):
				var d := xx * xx + yy * yy
				if d <= 36:
					var c: Color = OUT
					if d <= 25:
						c = WOOD[1] if xx + yy < 0 else WOOD[2]
					if d <= 12:
						c = GLASS[1] if yy > -1 else GLASS[2]
					if d <= 12 and (xx == 0 or yy == 0):
						c = WOOD[2]
					put(cx + xx, wy + 4 + yy, c)
	elif gw == "cross":
		rect(cx - 8, wy - 1, 16, 16, OUT)
		rect(cx - 7, wy, 14, 14, PLAST[0])
		rect(cx - 2, wy + 2, 4, 10, Color8(196, 64, 60))
		rect(cx - 5, wy + 5, 10, 4, Color8(196, 64, 60))
		rect(cx - 2, wy + 2, 1, 10, Color8(232, 110, 100))
	elif gw == "loft":
		rect(cx - 9, wy - 3, 18, 18, OUT)
		bar(cx - 8, wy - 2, 16, 16, WOOD, false)
		rect(cx - 6, wy, 12, 12, Color8(58, 40, 36))
		for k in 4:
			rect(cx - 5 + k * 3, wy + 8 + (k % 2), 3, 4 - (k % 2), R_STRAW[1 + k % 2])
	bar(x0 - 2, top - 4, x1 - x0 + 4, 4, WOOD)
	shadow(x0, top, x1 - x0, 2, 0.25)
	if mat == "timber":
		bar(x0, top, 5, -9 - top, WOOD)
		bar(x1 - 5, top, 5, -9 - top, WOOD)
		shadow(x0 + 5, top + 2, 1, -12 - top, 0.22)

## Плющ с карниза.
func ivy(xs: Array, y: int) -> void:
	for x: int in xs:
		var l := 4 + hh(x, y, 14) % 9
		for i in l:
			var xx := x + (i / 3) % 2
			put(xx, y + i, MOSS[1] if i % 3 != 2 else MOSS[2])
			if i % 3 == 0:
				put(xx + 1, y + i, MOSS[0])
				put(xx - 1, y + 1 + i, MOSS[2])


# ------------------------------- постройки -------------------------------

func _b_merchant(sx: int, sy: int) -> void:
	at(sx - 106, sy)
	RP = R_TERRA
	house({"main": {"x": 12, "w": 116, "h": 78, "rh": 64, "mat": "timber"},
		"wing": {"x": 128, "w": 68, "h": 76, "gh": 42, "back": 77, "mat": "timber"},
		"chimney": [175, -174, 16], "door": [162, 22, 46], "sign": [140, -76, 46, "ЛАВКА"],
		"before_wing": func() -> void:
			_vent(70, -124)
			_window(40, -48, 52, 28)
			_awning(30, -64, 72)
			ivy([16, 22, 60, 118], -63),
		"after": func() -> void:
			_hanging_sign(196, -56)
			_crate(30, -4, 16, Color8(196, 70, 66))
			_crate(48, -2, 16, Color8(222, 150, 66))
			_crate(66, -4, 16, Color8(130, 170, 80))
			_easel(118, 10)})

func _b_library(sx: int, sy: int) -> void:
	at(sx - 70, sy)
	RP = R_BLUE
	house({"wing": {"x": 10, "w": 120, "h": 104, "gh": 50, "back": 64, "mat": "timber", "gwin": "round"},
		"chimney": [100, -222, 14], "door": [70, 22, 46],
		"wins": [[22, -50, 20, 26], [98, -50, 20, 26], [22, -92, 20, 22], [98, -92, 20, 22]],
		"sign": [48, -68, 44, "КНИГИ"],
		"after": func() -> void:
			ivy([14, 126], -103)
			_bush(-6, 4, 11, 31, "flower")
			_bush(146, 4, 11, 32, "green")})

func _b_training(sx: int, sy: int) -> void:
	at(sx - 80, sy)
	RP = R_BROWN
	house({"main": {"x": 20, "w": 120, "h": 64, "rh": 44, "mat": "planks"},
		"door": [80, 30, 44], "sign": [60, -62, 40, "ПЛАЦ"],
		"after": func() -> void:
			_dummy(-6, 6)
			_dummy(166, 8)
			_rack(104, 10)})

func _b_forge(sx: int, sy: int) -> void:
	at(sx - 96, sy)
	RP = R_DRED
	house({"main": {"x": 12, "w": 104, "h": 70, "rh": 50, "mat": "stone"},
		"wing": {"x": 116, "w": 64, "h": 70, "gh": 38, "back": 60, "mat": "stone", "gwin": "rect"},
		"mchim": [30, -137], "door": [148, 22, 46], "sign": [127, -68, 42, "КУЗНЯ"],
		"before_wing": func() -> void:
			_furnace(60, -6),
		"after": func() -> void:
			_anvil(70, 14)
			_keg(-6, 6, 14, 18, true)})

func _b_infirmary(sx: int, sy: int) -> void:
	at(sx - 64, sy)
	RP = R_GREEN
	house({"wing": {"x": 8, "w": 112, "h": 82, "gh": 46, "back": 60, "mat": "timber", "gwin": "cross"},
		"door": [64, 22, 46], "wins": [[20, -52, 20, 24], [88, -52, 20, 24]],
		"sign": [36, -80, 56, "ЛАЗАРЕТ"],
		"after": func() -> void:
			_bush(-8, 4, 10, 41, "flower")
			_bush(136, 4, 10, 42, "flower")})

func _b_mentor(sx: int, sy: int) -> void:
	at(sx - 56, sy)
	RP = R_STRAW
	house({"wing": {"x": 8, "w": 96, "h": 66, "gh": 40, "back": 56, "mat": "timber", "gwin": "round"},
		"door": [40, 22, 46], "wins": [[66, -48, 20, 22]],
		"sign": [20, -64, 72, "НАСТАВНИК"],
		"after": func() -> void:
			_lamp(116, 4)
			_bush(-10, 4, 9, 51, "berry")})

func _b_exchange(sx: int, sy: int) -> void:
	at(sx - 70, sy)
	RP = R_GREEN
	house({"main": {"x": 16, "w": 110, "h": 66, "rh": 46, "mat": "planks"},
		"door": [94, 22, 46], "sign": [50, -64, 40, "ОБМЕН"],
		"after": func() -> void:
			_awning(24, -52, 46)
			_crate(26, -4, 14, Color8(130, 170, 210))
			_crate(42, -2, 14, Color8(210, 196, 120))
			_keg(140, 6, 14, 18)})

func _b_treasury(sx: int, sy: int) -> void:
	at(sx - 92, sy)
	RP = R_PURPLE
	house({"main": {"x": 14, "w": 100, "h": 80, "rh": 50, "mat": "stone"},
		"wing": {"x": 114, "w": 64, "h": 80, "gh": 38, "back": 60, "mat": "stone", "gwin": "round"},
		"door": [146, 22, 46], "wins": [[34, -54, 16, 24], [80, -54, 16, 24]],
		"sign": [125, -76, 42, "КАЗНА"],
		"after": func() -> void:
			_chest(54, 12)})

func _b_storage(sx: int, sy: int) -> void:
	at(sx - 76, sy)
	RP = R_DRED
	house({"wing": {"x": 10, "w": 132, "h": 78, "gh": 52, "back": 64, "mat": "planks", "gwin": "loft"},
		"door": [76, 34, 54], "sign": [56, -76, 40, "СКЛАД"],
		"after": func() -> void:
			_crate(-12, -2, 16, Color8(196, 70, 66))
			_keg(156, 6, 14, 18)
			_keg(170, 10, 14, 18)})

func _b_workshop(sx: int, sy: int) -> void:
	at(sx - 92, sy)
	RP = R_TERRA.map(func(c: Color) -> Color: return c.darkened(0.08))
	house({"main": {"x": 14, "w": 104, "h": 74, "rh": 54, "mat": "timber"},
		"wing": {"x": 118, "w": 62, "h": 72, "gh": 38, "back": 64, "mat": "timber", "gwin": "rect"},
		"chimney": [160, -166, 14], "door": [149, 22, 46], "wins": [[34, -50, 22, 24]],
		"sign": [24, -72, 84, "МАСТЕРСКАЯ"],
		"after": func() -> void:
			_bench(70, 10)
			_grindstone(-6, 8)})

func _b_portal(sx: int, sy: int) -> void:
	at(sx, sy)
	last_door = Vector2(sx, sy)
	_portal()

func _b_mine(sx: int, sy: int) -> void:
	at(sx, sy)
	last_door = Vector2(sx + 6, sy)
	_mine()


# ===================================================================================
#                                 ОСОБЫЕ ПОСТРОЙКИ
# ===================================================================================

## Портал: каменные ступени, две колонны из блоков с рунами, арка из клиновидных камней,
## фиолетовый вихрь, кристаллы по бокам.
func _portal() -> void:
	ground_shadow(30, 0, 70, 6, 0.3)
	bar(-62, -8, 124, 8, STONE)
	bar(-54, -16, 108, 8, STONE)
	# Вихрь.
	for py in range(-118, -16):
		for px in range(-34, 35):
			var top := -84
			if py < top:
				var d := Vector2(px, py - top).length()
				if d > 34:
					continue
			var dx := px / 34.0
			var dy := (py + 60) / 60.0
			var r := sqrt(dx * dx + dy * dy * 0.7)
			var ang := atan2(dy, dx)
			var sw := sin(ang * 3.0 + r * 9.0)
			var c := Color8(52, 28, 92)
			if sw > 0.6:
				c = Color8(164, 104, 226)
			elif sw > 0.1:
				c = Color8(110, 64, 176)
			elif sw < -0.7:
				c = Color8(96, 168, 226)
			if r < 0.3:
				c = Color8(236, 226, 252) if r < 0.15 else Color8(184, 152, 244)
			put(px, py, c)
	# Колонны.
	for side: int in [-1, 1]:
		var x0 := side * 44 - 10
		for row in 10:
			var y := -26 - row * 9
			bar(x0, y, 20, 8, STONE)
		rect(x0 + 8, -92, 4, 60, Color8(40, 36, 52))
		for k in 3:
			rect(x0 + 9, -86 + k * 20, 2, 10, Color8(120, 226, 250))
			put(x0 + 9, -86 + k * 20, Color8(230, 250, 255))
		bar(x0 - 3, -122, 26, 6, STONE)
	# Арка.
	for py in range(-170, -118):
		for px in range(-58, 59):
			var d := Vector2(px, py + 118).length()
			if d > 56 or d < 36:
				continue
			var ang := atan2(py + 118, px)
			var seg := int(floor((ang + PI) / (PI / 9.0)))
			var local := fposmod((ang + PI) / (PI / 9.0), 1.0)
			var rad := (d - 36) / 20.0
			var c: Color = STONE[1] if seg % 2 == 0 else STONE[1].lightened(0.06)
			if seg == 4:
				c = Color8(150, 220, 240)
			if local < 0.1 or rad > 0.9:
				c = STONE[3]
			elif rad < 0.15:
				c = STONE[2]
			elif local < 0.3:
				c = (c as Color).lightened(0.1)
			put(px, py, c)
	for py in range(-172, -116):
		for px in range(-60, 61):
			var d := Vector2(px, py + 118).length()
			if absf(d - 56.5) < 0.8 or (absf(d - 35.5) < 0.8 and py < -118):
				put(px, py, OUT)
	# Кристаллы.
	for side: int in [-1, 1]:
		var bx := side * 70
		for k in 3:
			var hgt := 18 - k * 4
			var x := bx + (k - 1) * 5 * side
			for yy in hgt:
				var half := int(3 * (1.0 - float(yy) / hgt)) + 1
				for xx in range(-half, half + 1):
					var c := Color8(126, 206, 240) if xx < 0 else Color8(80, 150, 206)
					if xx == -half:
						c = Color8(220, 246, 255)
					put(x + xx, -4 - yy, c)
			put(x, -4 - hgt, OUT)

## Шахта (по референсу): высокая гора угловатых светлых валунов с мхом, массивная крепь
## с раскосами и тёмным проходом вглубь, рельсы по диагонали с вагонеткой руды, высокий
## подъёмник с колесом и корзиной камней на канате.
func _mine() -> void:
	ground_shadow(30, 0, 120, 8, 0.3)
	_cliff()
	_mine_entrance(6, 0)
	# Рельсы и вагонетка.
	_rails(6, 0)
	_cart(36, 30)
	# Трава у подножия.
	for i in 16:
		var gx := -110 + i * 15 + hh(i, 0, 96) % 6
		var gy := -2 + hh(i, 1, 96) % 5
		put(gx, gy, MOSS[0])
		put(gx + 1, gy - 1, MOSS[1])
		put(gx - 1, gy, MOSS[1])
		put(gx, gy - 2, MOSS[0])
	_crane(92, 4)

## Цельная скала рудника: силуэт горы с выступами; сверху освещённая грань со шапкой травы
## и мха (под её кромкой тень, свисающий мох); передняя стена — пласты-уступы (светлая кромка,
## под ней тень) и вертикальные трещины; правый бок в тени; тёмный низ; контур.
func _cliff() -> void:
	var chain := [Vector2(-114, 0), Vector2(-114, -28), Vector2(-100, -50), Vector2(-86, -58), Vector2(-76, -94),
		Vector2(-54, -108), Vector2(-42, -140), Vector2(-14, -162), Vector2(14, -158), Vector2(32, -136),
		Vector2(54, -126), Vector2(70, -100), Vector2(88, -88), Vector2(98, -56), Vector2(106, -30), Vector2(106, 0)]
	var top := {}
	for i in chain.size() - 1:
		var p0: Vector2 = chain[i]
		var p1: Vector2 = chain[i + 1]
		var x0 := int(minf(p0.x, p1.x))
		var x1 := int(maxf(p0.x, p1.x))
		for x in range(x0, x1 + 1):
			var t := 0.0 if x1 == x0 else float(x - p0.x) / (p1.x - p0.x)
			var y := lerpf(p0.y, p1.y, clampf(t, 0.0, 1.0))
			top[x] = minf(top.get(x, 0.0), y)
	# Крупные рубленые грани передней стены и бока (точки-центры граней).
	var seeds: Array[Vector2] = [Vector2(-96, -30), Vector2(-70, -70), Vector2(-62, -20), Vector2(-36, -110),
		Vector2(-30, -60), Vector2(-8, -130), Vector2(22, -100), Vector2(46, -60), Vector2(30, -24),
		Vector2(70, -84), Vector2(86, -30), Vector2(-100, -66), Vector2(0, -36)]
	var pix := {}
	for x in range(-114, 107):
		var ty: float = top.get(x, 0.0)
		var cap := ty + 16.0 + 6.0 * sin(x * 0.11)
		for y in range(int(ty), 1):
			var fy := float(y)
			var c: Color
			var xr := 20.0 + (fy + 160.0) * 0.5
			if fy < cap:
				# Верхняя грань: трава и мох шапкой, камень у края.
				var mn := nz.get_noise_2d(x * 1.8, y * 1.8)
				c = ROCK[0]
				if mn > -0.15:
					c = MOSS[0] if mn > 0.15 else MOSS[1]
				if fy < ty + 1.5:
					c = MOSS[0].lightened(0.1) if mn > -0.15 else ROCK[0].lightened(0.06)
				if fy > cap - 2.0:
					c = ROCK[0]
			elif fy < cap + 2.0:
				c = ROCK[3]                              # тень под кромкой верха
			else:
				# Грань: ближайший центр; шов между гранями — тёмное ребро, верх-лево грани светлее.
				var pp := Vector2(x, fy)
				var d1 := 1e9
				var d2 := 1e9
				var si := 0
				for k in seeds.size():
					var d := pp.distance_to(seeds[k])
					if d < d1:
						d2 = d1
						d1 = d
						si = k
					elif d < d2:
						d2 = d
				var side := x > xr
				var ti := 1 if si % 3 != 2 else 2
				if side:
					ti += 1
				# Ниже — темнее.
				if fy > -40.0 and ti < 3:
					ti += 1 if hh(si, 0, 7) % 2 == 0 else 0
				var dir := (pp - seeds[si]).normalized()
				if d2 - d1 < 1.4:
					c = ROCK[4]
				elif d2 - d1 < 3.0 and dir.dot(Vector2(-0.7, -0.7)) > 0.2:
					c = ROCK[maxi(ti - 1, 0)]               # освещённая кромка грани
				elif d2 - d1 < 3.0 and dir.dot(Vector2(0.7, 0.7)) > 0.2:
					c = ROCK[mini(ti + 1, 4)]
				else:
					c = ROCK[ti]
				if side and absf(x - xr) < 1.0:
					c = ROCK[4]                          # ребро бок/фасад
				if x < -110 and not side:
					c = ROCK[0]
			# Пласты-уступы на передней стене и на боку.
			if fy >= cap + 2.0:
				for L: float in [-96.0 + 6.0 * sin(x * 0.07), -52.0 + 5.0 * sin(x * 0.09 + 1.0)]:
					if absf(fy - L) < 1.2:
						c = ROCK[0] if x <= xr else ROCK[1]
					elif fy > L + 1.2 and fy < L + 4.5:
						c = ROCK[3] if (x <= xr and fy < L + 3.0) else ROCK[4]
				# Вертикальные трещины.
				for k: float in [-84.0, -52.0, 40.0, 76.0]:
					var kx := k + 2.0 * sin(fy * 0.2 + k)
					if absf(x - kx) < 0.7 and fmod(absf(fy * 0.37 + k), 9.0) < 6.5:
						c = ROCK[4]
					elif x - kx > 0.7 and x - kx < 1.7 and fmod(absf(fy * 0.37 + k), 9.0) < 6.5:
						c = c.lightened(0.08)
				if hh(x / 3, y / 3, 98) < 70:
					c = c.darkened(0.06)
			if fy > -3.0:
				c = ROCK[3]
			pix[Vector2i(x, y)] = c
	_blit_outlined(pix)
	# Свисающий с верха мох.
	for x in range(-108, 100, 7):
		var ty: float = top.get(x, 0.0)
		var cap := ty + 16.0 + 6.0 * sin(x * 0.11)
		var l := 2 + hh(x, 0, 99) % 6
		for i in l:
			put(x + (i / 3) % 2, int(cap) + 1 + i, MOSS[1] if i % 3 != 2 else MOSS[2])

## Угловатый валун: многоугольник с гранями — светлая верхняя грань (с мхом), передняя
## средняя, правый бок в тени; под ребром верхней грани тень, рёбра между гранями, трещины,
## тёмный низ, контур.
func _rock(cx: int, cy: int, w: int, h: int, sd: int) -> void:
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
				c = ROCK[0]
				# Мох — цельные шапки по шуму, светлый верх и тёмный край.
				var mn := nz.get_noise_2d(px * 2.2 + sd, py * 2.2)
				if mn > 0.05 and py < ty - 1:
					c = MOSS[0] if mn > 0.2 else MOSS[1]
				elif mn > -0.02 and py < ty - 1:
					c = MOSS[2]
			elif py < ty + 1.5:
				c = ROCK[3]                         # тень под ребром верхней грани
			elif px > sxl:
				c = ROCK[2] if px < sxl + 1.5 or hh(px / 3, py / 3, sd + 2) > 200 else ROCK[3]
				if px < sxl + 1.0:
					c = ROCK[4]                     # ребро между гранями
			else:
				c = ROCK[1]
				if px < r.position.x + 3:
					c = ROCK[0]                     # освещённая левая кромка
			if py > r.end.y - 3:
				c = ROCK[3]
			# Трещины — редкие короткие линии.
			if py > ty + 4 and absf(px - (cx - w * 0.2 + (py - ty) * 0.5 + (sd % 7))) < 0.6 and py < ty + 12:
				c = ROCK[4]
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)

## Вход в шахту: тёмный проход с глубиной (внутренняя крепь темнее), массивные стойки,
## двойная перекладина, раскосы к земле, доски по бокам.
func _mine_entrance(cx: int, base: int) -> void:
	var w := 46
	var h := 76
	var x0 := cx - w / 2
	for py in range(base - h, base):
		for px in range(x0, x0 + w):
			var t := float(py - (base - h)) / h
			put(px, py, Color8(12, 9, 12).lerp(Color8(66, 50, 42), t * t * 0.7))
	# Внутренняя крепь (глубже — темнее).
	var deep := [Color8(96, 66, 46), Color8(74, 50, 38), Color8(56, 38, 32), Color8(40, 28, 26)]
	bar(x0 + 8, base - h + 14, 4, h - 14, deep)
	bar(x0 + w - 12, base - h + 14, 4, h - 14, deep)
	bar(x0 + 8, base - h + 12, w - 16, 4, deep)
	# Стойки, перекладины.
	bar(x0 - 8, base - h - 4, 9, h + 4, WOOD)
	bar(x0 + w - 1, base - h - 4, 9, h + 4, WOOD)
	bar(x0 - 14, base - h - 14, w + 28, 10, WOOD)
	bar(x0 - 10, base - h - 22, w + 20, 7, WOOD)
	for k in 4:
		var nx := x0 - 8 + k * (w + 10) / 3
		put(nx, base - h - 10, IRON[0])
		put(nx, base - h - 9, OUT)
	# Доски по бокам входа.
	for side: int in [-1, 1]:
		for k in 2:
			var bx := (x0 - 18 - k * 6) if side < 0 else (x0 + w + 9 + k * 6)
			bar(bx, base - 40 + k * 6, 5, 40 - k * 6, WOOD)
	# Фонарь на стойке.
	rect(x0 + w + 9, base - h + 8, 8, 10, OUT)
	rect(x0 + w + 10, base - h + 9, 6, 8, Color8(252, 214, 120))
	rect(x0 + w + 12, base - h + 11, 2, 4, Color8(255, 250, 220))

## Рельсы: из прохода по диагонали к зрителю-вправо — шпалы с объёмом, два рельса со светом.
func _rails(cx: int, base: int) -> void:
	for i in 9:
		var y := base - 6 + i * 5
		var x := cx - 14 + i * 3
		bar(x, y, 30, 2, WOOD)
	for side: int in [0, 1]:
		for i in 46:
			var x := cx - 8 + side * 16 + int(i * 0.62)
			var y := base - 6 + i
			put(x - 1, y, OUT)
			put(x, y, HOOP[0])
			put(x + 1, y, HOOP[2])
			put(x + 2, y, OUT)

func _boulder(cx: int, cy: int, rx: int, ry: int, sd: int) -> void:
	_rock(cx, cy, rx * 2, ry * 2, sd)

func _cart(cx: int, base: int) -> void:
	ground_shadow(cx + 12, base, 22, 4, 0.32)
	var pix := {}
	for py in range(base - 22, base - 5):
		var k := py - (base - 22)
		var half := 18 - k / 4
		for px in range(cx - half, cx + half):
			var t := float(px - cx + half) / (half * 2.0)
			var c: Color = HOOP[1] if t < 0.68 else HOOP[2]
			if k < 2:
				c = HOOP[0]
			elif k == 2:
				c = HOOP[3]
			if posmod(px - cx, 9) == 0 and k > 2:
				c = HOOP[3]
			if (px - cx) % 9 == 1 and k > 2:
				c = HOOP[0]
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)
	# Руда горкой: камни с гранями и золотые жилки.
	for k in 9:
		var bx := cx - 15 + (k % 5) * 6 + (k / 5) * 3
		var by := base - 26 - (k / 5) * 3
		rect(bx - 1, by - 1, 7, 6, OUT)
		rect(bx, by, 5, 4, ROCK[1])
		rect(bx, by, 5, 1, ROCK[0])
		rect(bx + 4, by, 1, 4, ROCK[3])
		if k % 3 == 1:
			put(bx + 2, by + 1, Color8(250, 210, 90))
			put(bx + 1, by + 2, Color8(214, 160, 60))
	for wx: int in [cx - 11, cx + 11]:
		for yy in range(-4, 5):
			for xx in range(-4, 5):
				var d := xx * xx + yy * yy
				if d <= 17:
					put(wx + xx, base - 4 + yy, OUT if d > 10 else (HOOP[1] if xx + yy < 0 else HOOP[3]))
		put(wx, base - 4, HOOP[0])

## Подъёмник: четыре стойки (задние темнее), крестовые раскосы, верхняя рама, стрела влево
## над рельсами, колесо-блок, канат и корзина с камнями.
func _crane(x: int, base: int) -> void:
	ground_shadow(x + 16, base, 26, 5, 0.3)
	var hgt := 150
	var dark := [WOOD[1], WOOD[2], WOOD[3], Color8(66, 40, 34)]
	# Задние стойки.
	bar(x - 8, base - hgt - 6, 5, hgt, dark)
	bar(x + 22, base - hgt - 6, 5, hgt, dark)
	# Раскосы (крестом) между передними стойками.
	for k in 4:
		var y0 := base - 10 - k * 34
		for i in 28:
			for pair: Array in [[x - 10 + i, y0 - i], [x + 18 - i, y0 - i]]:
				var px: int = pair[0]
				var py: int = pair[1]
				put(px, py, WOOD[1])
				put(px, py + 1, WOOD[2])
				put(px, py - 1, OUT)
				put(px, py + 2, OUT)
		bar(x - 12, y0 - 30, 32, 3, WOOD)
	# Передние стойки.
	bar(x - 14, base - hgt, 6, hgt, WOOD)
	bar(x + 16, base - hgt, 6, hgt, WOOD)
	# Верхняя рама и стрела влево.
	bar(x - 20, base - hgt - 8, 46, 8, WOOD)
	bar(x - 58, base - hgt - 4, 44, 5, WOOD)
	for i in 30:
		put(x - 14 - i, base - hgt + 2 + i / 2, WOOD[1])
		put(x - 14 - i, base - hgt + 3 + i / 2, OUT)
	# Колесо-блок.
	var wx := x - 52
	var wy := base - hgt - 10
	for yy in range(-7, 8):
		for xx in range(-7, 8):
			var d := xx * xx + yy * yy
			if d <= 49:
				var c: Color = OUT
				if d <= 36:
					c = HOOP[1] if xx + yy < 0 else HOOP[2]
				if d <= 25 and d > 9 and (xx == 0 or yy == 0):
					c = HOOP[3]
				if d <= 4:
					c = HOOP[0]
				put(wx + xx, wy + yy, c)
	# Канат и корзина.
	for yy in range(wy + 6, base - 76):
		put(wx + 6, yy, Color8(204, 178, 126))
		put(wx + 7, yy, Color8(146, 116, 78))
	for py in range(base - 76, base - 60):
		var half := 10 - (py - (base - 76)) / 4
		for px in range(wx + 6 - half, wx + 7 + half):
			var c: Color = WOOD[1] if posmod(px + py, 4) != 0 else WOOD[2]
			if px < wx + 6 - half + 2:
				c = WOOD[0]
			put(px, py, c)
		put(wx + 6 - half - 1, py, OUT)
		put(wx + 7 + half, py, OUT)
	rect(wx - 4, base - 60, 21, 1, OUT)
	for k in 4:
		var bx := wx - 3 + k * 4
		rect(bx - 1, base - 81, 6, 6, OUT)
		rect(bx, base - 80, 4, 4, ROCK[k % 2])
		put(bx, base - 80, ROCK[0])


# ===================================================================================
#                                    МЕЛОЧИ
# ===================================================================================

func _furnace(x: int, y: int) -> void:
	rect(x - 1, y - 27, 34, 28, OUT)
	for yy in 26:
		for xx in 32:
			var t := float(yy) / 26.0
			var c := Color8(70, 26, 20).lerp(Color8(255, 170, 70), t)
			var fl := sin(xx * 0.7) * 3.0 + sin(xx * 1.9) * 2.0
			if yy > 14 - fl:
				c = Color8(255, 214, 110) if yy > 20 else Color8(240, 128, 46)
			put(x + xx, y - 26 + yy, c)
	bar(x - 3, y - 31, 38, 4, STONE)

func _anvil(x: int, base: int) -> void:
	ground_shadow(x + 8, base, 14, 3, 0.32)
	bar(x - 8, base - 12, 16, 12, WOOD)
	bar(x - 6, base - 18, 12, 6, HOOP)
	bar(x - 13, base - 24, 26, 6, HOOP)
	rect(x + 13, base - 23, 4, 3, HOOP[2])

func _dummy(x: int, base: int) -> void:
	ground_shadow(x + 6, base, 10, 3, 0.3)
	bar(x - 2, base - 40, 4, 40, WOOD)
	bar(x - 12, base - 32, 24, 3, WOOD)
	var pix := {}
	for yy in range(-10, 11):
		for xx in range(-7, 8):
			if float(xx * xx) / 49.0 + float(yy * yy) / 100.0 <= 1.0:
				var g := float(yy + xx * 0.4) / 10.0
				var c: Color = R_STRAW[0] if g < -0.4 else (R_STRAW[1] if g < 0.2 else (R_STRAW[2] if g < 0.6 else R_STRAW[3]))
				if posmod(yy, 4) == 0:
					c = R_STRAW[3]
				pix[Vector2i(x + xx, base - 22 + yy)] = c
	_blit_outlined(pix)
	for yy in range(-5, 6):
		for xx in range(-5, 6):
			if xx * xx + yy * yy <= 25:
				put(x + xx, base - 40 + yy, OUT if xx * xx + yy * yy > 18 else (Color8(226, 210, 170) if xx + yy < 0 else Color8(196, 176, 136)))

func _rack(x: int, base: int) -> void:
	ground_shadow(x + 22, base, 22, 3, 0.3)
	bar(x, base - 30, 40, 4, WOOD)
	bar(x, base - 10, 40, 4, WOOD)
	bar(x, base - 34, 4, 34, WOOD)
	bar(x + 36, base - 34, 4, 34, WOOD)
	for k in 4:
		var wx := x + 8 + k * 8
		bar(wx, base - 44, 2, 36, HOOP)
		bar(wx - 2, base - 14, 6, 2, WOOD)

func _chest(x: int, base: int) -> void:
	ground_shadow(x + 12, base, 16, 3, 0.32)
	bar(x, base - 14, 24, 14, WOOD)
	bar(x - 1, base - 20, 26, 7, WOOD)
	rect(x - 1, base - 17, 26, 1, OUT)
	for k: int in [3, 19]:
		bar(x + k, base - 20, 2, 20, HOOP)
	bar(x + 10, base - 15, 4, 4, [Color8(250, 222, 120), Color8(222, 178, 82), Color8(170, 124, 52), Color8(120, 84, 40)])

func _bench(x: int, base: int) -> void:
	ground_shadow(x + 20, base, 22, 3, 0.3)
	bar(x + 2, base - 10, 3, 10, WOOD)
	bar(x + 33, base - 10, 3, 10, WOOD)
	bar(x, base - 14, 38, 4, WOOD)

func _grindstone(x: int, base: int) -> void:
	ground_shadow(x + 8, base, 12, 3, 0.3)
	bar(x - 8, base - 10, 16, 10, WOOD)
	for yy in range(-9, 10):
		for xx in range(-4, 5):
			if float(xx * xx) / 16.0 + float(yy * yy) / 81.0 <= 1.0:
				put(x + xx, base - 20 + yy, STONE[0] if xx < 0 else (STONE[1] if xx < 2 else STONE[2]))
	rect(x - 5, base - 30, 10, 1, OUT)

func _lamp(x: int, base: int) -> void:
	ground_shadow(x + 6, base, 7, 2, 0.3)
	bar(x - 1, base - 44, 3, 44, [Color8(110, 108, 124), Color8(72, 70, 86), Color8(50, 48, 62), Color8(36, 34, 46)])
	bar(x - 4, base - 4, 9, 4, [Color8(110, 108, 124), Color8(72, 70, 86), Color8(50, 48, 62), Color8(36, 34, 46)])
	bar(x - 1, base - 46, 10, 2, [Color8(110, 108, 124), Color8(72, 70, 86), Color8(50, 48, 62), Color8(36, 34, 46)])
	rect(x + 3, base - 44, 9, 11, OUT)
	rect(x + 4, base - 43, 7, 9, Color8(252, 214, 120))
	rect(x + 6, base - 41, 3, 5, Color8(255, 250, 220))
	rect(x + 9, base - 43, 1, 9, Color8(220, 160, 70))
	rect(x + 3, base - 46, 9, 2, Color8(50, 48, 62))

func _fountain(cx: int, base: int) -> void:
	ground_shadow(cx + 14, base, 54, 8, 0.3)
	var pix := {}
	for py in range(base - 30, base + 1):
		for px in range(cx - 50, cx + 51):
			var dx := float(px - cx) / 50.0
			var top := base - 22 + int(10.0 * (1.0 - sqrt(maxf(0.0, 1.0 - dx * dx))))
			var bot := base - int(6.0 * (1.0 - sqrt(maxf(0.0, 1.0 - dx * dx))))
			if absf(dx) > 1.0 or py < top or py > bot:
				continue
			var c: Color = STONE[1]
			if py < top + 2:
				c = STONE[0]
			elif py > bot - 2:
				c = STONE[3]
			elif dx > 0.6:
				c = STONE[2]
			if posmod(px, 9) == 0 and py >= top + 2:
				c = STONE[3]
			pix[Vector2i(px, py)] = c
	# Вода в чаше (эллипс сверху).
	for py in range(base - 34, base - 18):
		for px in range(cx - 46, cx + 47):
			var e := pow((px - cx) / 46.0, 2) + pow((py - (base - 26)) / 8.0, 2)
			if e <= 1.0:
				var c: Color = WATER[1] if e < 0.7 else WATER[2]
				if py < base - 29 and e > 0.5:
					c = WATER[3]
				if sin(px * 0.4 + py * 1.3) > 0.9:
					c = WATER[0].lightened(0.2)
				pix[Vector2i(px, py)] = c
			elif e <= 1.25:
				pix[Vector2i(px, py)] = STONE[0] if py < base - 26 else STONE[1]
	_blit_outlined(pix)
	# Столб, верхняя чаша, струи.
	bar(cx - 4, base - 58, 8, 30, STONE)
	for py in range(base - 66, base - 56):
		for px in range(cx - 16, cx + 17):
			var e := pow((px - cx) / 16.0, 2) + pow((py - (base - 61)) / 5.0, 2)
			if e <= 1.0:
				put(px, py, WATER[1] if py < base - 61 else STONE[1])
			elif e <= 1.3:
				put(px, py, OUT)
	for side: int in [-1, 1]:
		for i in 18:
			var t := i / 17.0
			var p := Vector2(cx + side * (10 + t * 24), base - 66 + t * t * 38 - t * 6)
			put(int(p.x), int(p.y), Color8(214, 240, 252))
			put(int(p.x) + side, int(p.y), Color8(170, 214, 236))
	rect(cx - 1, base - 74, 2, 8, Color8(214, 240, 252))

func _boulder_small(cx: int, base: int, s: int, sd: int) -> void:
	ground_shadow(cx + s / 2, base, s, 3, 0.3)
	_boulder(cx, base - s / 2, s, s / 2 + 2, sd)

func _signpost(x: int, base: int) -> void:
	ground_shadow(x + 6, base, 8, 2, 0.3)
	bar(x - 2, base - 36, 4, 36, WOOD)
	bar(x - 16, base - 34, 26, 7, WOOD)
	bar(x - 6, base - 24, 24, 7, WOOD)
	put(x + 11, base - 31, OUT)
	put(x - 17, base - 21, OUT)

func _flowers(cx: int, base: int, sd: int) -> void:
	for i in 10:
		var x := cx + hh(i, sd, 1) % 20 - 10
		var y := base + hh(i, sd, 2) % 8 - 4
		var c: Color = [Color8(244, 170, 190), Color8(250, 246, 236), Color8(244, 210, 110), Color8(170, 150, 230)][i % 4]
		put(x, y + 1, LEAF5[2])
		put(x, y, c)
		put(x + 1, y, c.darkened(0.2))
		put(x, y - 1, c.lightened(0.2))


# ===================================================================================
#                              РАССТАНОВКА МЕЛОЧЕЙ И ЛЕСА
# ===================================================================================


# ===================================================================================
#        МЕЛОЧИ ДЛЯ ЛАГЕРЯ (референсы владельца: заборы, камни с травой, плющ, растения)
# ===================================================================================

const LEAF_OUT_C := Color8(30, 52, 40)
const WOOD_PALE := [Color8(206, 186, 150), Color8(170, 150, 118), Color8(130, 112, 90), Color8(96, 82, 70)]
const ROPE := [Color8(214, 188, 132), Color8(160, 130, 86)]


## Набор пикселей + контур заданного цвета по силуэту.
func _blit_c(pix: Dictionary, outline: Color) -> void:
	for k: Vector2i in pix:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not pix.has(k + d):
				put(k.x + d.x, k.y + d.y, outline)
	for k: Vector2i in pix:
		put(k.x, k.y, pix[k])


## Жердевой забор: столбы с затёсанным верхом, две жерди (свет сверху, тень снизу, лёгкий
## провис), верёвочные обвязки; broken — одна жердь сломана и свисает.
func _fence_rail(x0: int, x1: int, base: int, sd := 1, broken := false) -> void:
	var step := 22
	var posts: Array[int] = []
	var x := x0
	while x <= x1:
		posts.append(x)
		x += step
	for p: int in posts:
		ground_shadow(p + 6, base, 6, 2, 0.28)
	for i in posts.size() - 1:
		var a: int = posts[i]
		var b: int = posts[i + 1]
		for k: int in [0, 1]:
			var ry := base - 22 + k * 10
			var sag := (hh(i, k, sd) % 3) - 1
			var xe := b + 2
			if broken and i == 1 and k == 0:
				xe = (a + b) / 2
			for xx in range(a + 3, xe):
				var t := float(xx - a) / float(b - a)
				var y := ry + int(round(lerpf(0.0, float(sag), t)))
				if broken and i == 1 and k == 0:
					y += int(t * 16.0)
				put(xx, y - 1, OUT)
				put(xx, y, WOOD[0])
				put(xx, y + 1, WOOD[1] if hh(xx / 4, k, sd + 3) % 5 != 0 else WOOD[2])
				put(xx, y + 2, WOOD[2])
				put(xx, y + 3, OUT)
	for p: int in posts:
		var h := 28 + hh(p, 0, sd) % 5
		bar(p, base - h, 5, h, WOOD)
		# Затёсанный верх: светлая левая грань, тёмная правая.
		put(p, base - h - 1, OUT)
		put(p + 1, base - h - 1, WOOD[0])
		put(p + 2, base - h - 2, WOOD[0])
		put(p + 3, base - h - 1, WOOD[2])
		put(p + 4, base - h - 1, OUT)
		put(p + 1, base - h - 2, OUT)
		put(p + 3, base - h - 2, OUT)
		put(p + 2, base - h - 3, OUT)
		for k: int in [0, 1]:
			var ry := base - 22 + k * 10
			rect(p - 1, ry, 7, 1, ROPE[0])
			rect(p - 1, ry + 1, 7, 1, ROPE[1])
			put(p - 2, ry, OUT)
			put(p - 2, ry + 1, OUT)


## Штакетник: две жерди позади, штакетины 4 px с остриём (свет слева, тень справа), гвозди.
func _fence_picket(x0: int, x1: int, base: int, sd := 1) -> void:
	for xx in range(x0 - 2, x1 + 4):
		put(xx, base + 1, Color(0.16, 0.08, 0.16, 0.25))
	for k: int in [0, 1]:
		var ry := base - 17 + k * 9
		for xx in range(x0, x1):
			put(xx, ry - 1, OUT)
			put(xx, ry, WOOD_PALE[1])
			put(xx, ry + 1, WOOD_PALE[2])
			put(xx, ry + 2, OUT)
	var x := x0
	while x < x1 - 3:
		var h := 22 + hh(x, 0, sd) % 3
		var pix := {}
		for yy in h:
			for xx in 4:
				if yy < 2 and (xx == 0 or xx == 3):
					continue
				var c: Color = WOOD_PALE[1]
				if xx == 0 or (xx == 1 and yy < 2):
					c = WOOD_PALE[0]
				elif xx == 3 or (xx == 2 and yy < 1):
					c = WOOD_PALE[2]
				if hh(x + xx, yy / 3, sd) < 60:
					c = WOOD_PALE[2]
				if yy > h - 3:
					c = WOOD_PALE[3]
				pix[Vector2i(x + xx, base - h + yy)] = c
		_blit_outlined(pix)
		put(x + 1, base - 16, IRON[1])
		put(x + 1, base - 7, IRON[1])
		x += 8


## Калитка: два столба с шапками, створка из досок с перекладинами и раскосом, петли, кольцо.
func _gate(cx: int, base: int) -> void:
	var w := 34
	ground_shadow(cx + 8, base, w / 2 + 10, 3, 0.3)
	bar(cx - w / 2 - 7, base - 40, 7, 40, WOOD)
	bar(cx + w / 2, base - 40, 7, 40, WOOD)
	bar(cx - w / 2 - 9, base - 44, 11, 4, WOOD)
	bar(cx + w / 2 - 2, base - 44, 11, 4, WOOD)
	var pix := {}
	for yy in 30:
		for xx in w:
			if yy < hh(xx / 6, 0, 5) % 3:
				continue
			var pl := xx % 6
			var c: Color = WOOD_PALE[1]
			if pl == 0:
				c = WOOD_PALE[3]
			elif pl == 1:
				c = WOOD_PALE[0]
			elif pl == 5:
				c = WOOD_PALE[2]
			pix[Vector2i(cx - w / 2 + xx, base - 32 + yy)] = c
	_blit_outlined(pix)
	bar(cx - w / 2, base - 28, w, 3, WOOD)
	bar(cx - w / 2, base - 10, w, 3, WOOD)
	for i in 18:
		var t := float(i) / 17.0
		var px := int(lerpf(cx - w / 2 + 2, cx + w / 2 - 4, t))
		var py := int(lerpf(base - 11, base - 26, t))
		put(px, py, WOOD[1])
		put(px + 1, py, WOOD[2])
		put(px - 1, py, OUT)
		put(px + 2, py, OUT)
	for hy: int in [base - 27, base - 9]:
		rect(cx - w / 2 - 1, hy, 7, 1, IRON[0])
		rect(cx - w / 2 - 1, hy + 1, 7, 1, IRON[2])
	for yy in range(-2, 3):
		for xx in range(-2, 3):
			var d := xx * xx + yy * yy
			if d >= 2 and d <= 5:
				put(cx + w / 2 - 6 + xx, base - 18 + yy, IRON[0] if xx + yy < 0 else IRON[2])


## Группа камней: большой задний, средний и малый спереди (угловатые, мох на верхних гранях),
## камушки, папоротник и пучок травы у подножия.
func _rock_group(cx: int, base: int, s: int, sd: int) -> void:
	ground_shadow(cx + s / 2, base, s + 8, 4, 0.32)
	var h1 := int(s * 0.9)
	_rock(cx - s / 3, base - h1 / 2 - 2, s, h1, sd)
	var h2 := int(s * 0.6)
	_rock(cx + s / 2, base - h2 / 2, int(s * 0.7), h2, sd + 7)
	var h3 := int(s * 0.4)
	_rock(cx - s / 2 - 4, base - h3 / 2 + 1, int(s * 0.5), h3, sd + 13)
	for i in 5:
		var px := cx - s + hh(i, sd, 1) % (2 * s)
		var py := base + hh(i, sd, 2) % 4
		rect(px - 1, py - 1, 5, 4, OUT)
		rect(px, py, 3, 2, ROCK[1])
		put(px, py, ROCK[0])
		put(px + 2, py + 1, ROCK[3])
	_fern(cx + s / 2 + 10, base + 2, sd, maxi(14, s / 2))
	_tuft(cx - s + 2, base + 3, sd + 3)


## Папоротник: вайи дугами из основания (провисают к кончикам), перышки по обе стороны —
## верхние светлые, нижние тёмные, кончики светлее; контур тёмно-зелёный.
func _fern(x: int, base: int, sd: int, s := 14) -> void:
	var pix := {}
	var n := 7
	for f in n:
		var ang := lerpf(-PI * 0.94, -PI * 0.06, float(f) / (n - 1)) + float(hh(f, sd, 1) % 10 - 5) * 0.02
		var L := s * (0.75 + float(hh(f, sd, 2) % 30) / 100.0)
		if f == 0 or f == n - 1:
			L *= 0.7
		var d0 := Vector2.from_angle(ang)
		var prev := Vector2(x, base)
		for i in int(L):
			var t := float(i) / L
			var p := Vector2(x, base) + d0 * (i + 1.0)
			p.y += t * t * L * 0.5
			var d := (p - prev).normalized()
			prev = p
			var shaft: Color = LEAF5[2] if t < 0.8 else LEAF5[1]
			pix[Vector2i(int(round(p.x)), int(round(p.y)))] = shaft
			if i % 2 == 1 and t > 0.12:
				var perp := Vector2(-d.y, d.x)
				var ll := int(round((1.0 - t) * 3.0)) + 1
				for side: int in [-1, 1]:
					for k in range(1, ll + 1):
						var q := p + perp * side * k + d * k * 0.6
						var up := (perp * side).y < 0.0
						var c: Color = LEAF5[1] if up else LEAF5[3]
						if t > 0.75:
							c = LEAF5[0] if up else LEAF5[2]
						pix[Vector2i(int(round(q.x)), int(round(q.y)))] = c
	_blit_c(pix, LEAF_OUT_C)


## Пучок травы: травинки веером, к кончику светлее.
func _tuft(x: int, base: int, sd: int) -> void:
	var pix := {}
	for b in 7:
		var lean := float(b - 3) * 0.3 + float(hh(b, sd, 3) % 10 - 5) * 0.05
		var h := 6 + hh(b, sd, 4) % 7
		for i in h:
			var t := float(i) / h
			var px := x + b - 3 + int(round(lean * i * t))
			var c: Color = LEAF5[3] if t < 0.3 else (LEAF5[2] if t < 0.65 else LEAF5[1])
			if t > 0.85:
				c = LEAF5[0]
			pix[Vector2i(px, base - i)] = c
	_blit_c(pix, LEAF_OUT_C)


## Клумба: трава и цветы — daisy (ромашки), tulip (тюльпаны), lavender (лаванда) или mix.
func _flower_bed(cx: int, base: int, sd: int, kind := "mix") -> void:
	_tuft(cx - 6, base, sd)
	_tuft(cx + 5, base + 1, sd + 1)
	var kinds := ["daisy", "tulip", "lavender"]
	for i in 8:
		var x := cx - 10 + hh(i, sd, 5) % 21
		var y := base - 7 - hh(i, sd, 6) % 6
		var k: String = kind if kind != "mix" else kinds[i % 3]
		for yy in range(y + 1, base):
			put(x, yy, LEAF5[2])
		put(x + 1, y + 4, LEAF5[1])
		match k:
			"daisy":
				for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
					put(x + d.x, y + d.y, Color8(250, 248, 240))
				put(x, y + 1, Color8(206, 200, 190))
				put(x + 1, y + 1, Color8(206, 200, 190))
				put(x, y, Color8(246, 204, 80))
			"tulip":
				rect(x - 1, y - 2, 3, 3, Color8(214, 72, 78))
				put(x - 1, y - 2, Color8(244, 128, 128))
				put(x, y - 3, Color8(214, 72, 78))
				put(x + 1, y, Color8(150, 42, 54))
				put(x + 1, y - 1, Color8(170, 52, 60))
			_:
				for j in 5:
					put(x + (j % 2), y - j + 1, Color8(176, 140, 220) if j % 2 == 0 else Color8(128, 96, 180))
				put(x, y - 4, Color8(206, 180, 240))


## Пергола: четыре столба (задние темнее), задняя и передняя балки, поперечины вглубь,
## плющ по балке и столбам, два фонаря на цепях, тень на землю.
func _pergola(cx: int, base: int, w: int, sd := 1) -> void:
	var h := 52
	var d := 14
	ground_shadow(cx + 10, base - d / 2, w / 2 + 12, d / 2 + 3, 0.3)
	var dark := [WOOD[1], WOOD[2], WOOD[3], Color8(66, 40, 34)]
	bar(cx - w / 2 + 3, base - d - h, 6, h, dark)
	bar(cx + w / 2 - 9, base - d - h, 6, h, dark)
	bar(cx - w / 2 - 6, base - d - h - 6, w + 12, 5, dark)
	for k in 6:
		var bx := cx - w / 2 + 2 + k * (w - 8) / 5
		bar(bx, base - h - d - 4, 4, d + 2, WOOD)
	bar(cx - w / 2, base - h, 7, h, WOOD)
	bar(cx + w / 2 - 7, base - h, 7, h, WOOD)
	bar(cx - w / 2 - 8, base - h - 6, w + 16, 6, WOOD)
	_ivy_drape(cx - w / 2 - 6, base - h - 8, w + 12, sd)
	for px: int in [cx - w / 2 + 3, cx + w / 2 - 4]:
		_ivy_strand(px, base - h, 22 + hh(px, 0, sd) % 12, sd + px)
	for lx: int in [cx - w / 4, cx + w / 4]:
		for yy in 6:
			put(lx, base - h + yy, IRON[2] if yy % 2 == 0 else IRON[1])
		_lantern_small(lx, base - h + 6)


func _lantern_small(x: int, y: int) -> void:
	rect(x - 4, y, 9, 11, OUT)
	rect(x - 3, y + 1, 7, 9, Color8(250, 210, 116))
	rect(x - 1, y + 3, 3, 5, Color8(255, 248, 214))
	rect(x + 2, y + 1, 1, 9, Color8(212, 150, 70))
	rect(x - 4, y - 2, 9, 2, IRON[2])
	put(x, y - 3, OUT)


## Листья плюща вдоль балки и свисающие плети.
func _ivy_drape(x: int, y: int, w: int, sd: int) -> void:
	var pix := {}
	for i in range(0, w, 3):
		var ly := y + hh(i, 0, sd) % 4
		_leaf(pix, x + i, ly)
		if hh(i, 1, sd) % 3 == 0:
			_leaf(pix, x + i + 1, ly - 2)
	for i in range(2, w, 9):
		var l := 4 + hh(i, 2, sd) % 10
		for j in range(0, l, 2):
			_leaf(pix, x + i + (j / 2) % 2 * 2 - 1, y + 4 + j)
	_blit_c(pix, LEAF_OUT_C)


func _ivy_strand(x: int, y: int, l: int, sd: int) -> void:
	var pix := {}
	for j in range(0, l, 2):
		_leaf(pix, x + (j / 2) % 2 * 3 - 1, y + j + hh(j, 0, sd) % 2)
	_blit_c(pix, LEAF_OUT_C)


func _leaf(pix: Dictionary, x: int, y: int) -> void:
	pix[Vector2i(x, y)] = LEAF5[0]
	pix[Vector2i(x + 1, y)] = LEAF5[1]
	pix[Vector2i(x, y + 1)] = LEAF5[2]
	pix[Vector2i(x + 1, y + 1)] = LEAF5[3]


## Бревно лёжа: кора бороздами вдоль (свет сверху, тень снизу), сучок, торец-спил слева с кольцами.
func _log(x: int, base: int, length: int, r := 6) -> void:
	ground_shadow(x + length / 2 + 4, base + 1, length / 2 + 6, 3, 0.32)
	var cy := base - r
	var pix := {}
	for xx in length:
		for yy in range(-r, r + 1):
			var t := float(yy + r) / (2.0 * r)
			var c: Color = BARK[1]
			if t < 0.25:
				c = BARK[0]
			elif t > 0.75:
				c = BARK[2]
			if posmod(yy + (xx / 7) % 2, 3) == 0 and t > 0.15:
				c = c.darkened(0.15)
			pix[Vector2i(x + xx, cy + yy)] = c
	var kx := x + length * 2 / 3
	pix[Vector2i(kx, cy - 2)] = BARK[2]
	pix[Vector2i(kx + 1, cy - 2)] = BARK[0]
	pix[Vector2i(kx, cy - 1)] = Color8(60, 40, 34)
	var ex := maxf(2.0, r * 0.55)
	for yy in range(-r, r + 1):
		for xx in range(-int(ex) - 1, int(ex) + 2):
			var dd := pow((xx + 0.0) / (ex + 0.5), 2) + pow((yy + 0.0) / (r + 0.5), 2)
			if dd > 1.0:
				continue
			var c := Color8(224, 192, 142)
			if dd > 0.72:
				c = BARK[1]
			elif int(sqrt(dd) * 5.0) % 2 == 1:
				c = Color8(194, 158, 110)
			if yy > r * 0.4 and dd <= 0.72:
				c = c.darkened(0.12)
			pix[Vector2i(x + xx, cy + yy)] = c
	_blit_outlined(pix)


## Пень: бок коры (свет слева, тень справа), сверху спил-эллипс с кольцами и трещиной, корни;
## axe — воткнутый топор.
func _stump(cx: int, base: int, r := 9, axe := false) -> void:
	ground_shadow(cx + 6, base, r + 6, 3, 0.32)
	var h := 10
	var ry := 4.0
	var yt := base - int(ry) - h
	var pix := {}
	for xx in range(-r, r + 1):
		var arc := ry * sqrt(maxf(0.0, 1.0 - pow(float(xx) / r, 2)))
		var t := float(xx + r) / (2.0 * r)
		for yy in range(int(yt + arc), int(yt + h + arc) + 1):
			var c: Color = BARK[1]
			if t < 0.25:
				c = BARK[0]
			elif t > 0.7:
				c = BARK[2]
			if posmod(xx, 3) == 0:
				c = c.darkened(0.14)
			pix[Vector2i(cx + xx, yy)] = c
	for side: int in [-1, 1]:
		for i in 5:
			pix[Vector2i(cx + side * (r + i), base - 2 + i / 2)] = BARK[0] if side < 0 else BARK[2]
			pix[Vector2i(cx + side * (r + i), base - 3 + i / 2)] = BARK[1]
	for yy in range(-int(ry), int(ry) + 1):
		for xx in range(-r, r + 1):
			var dd := pow(float(xx) / r, 2) + pow(float(yy) / ry, 2)
			if dd > 1.0:
				continue
			var c := Color8(222, 190, 140)
			if dd > 0.7:
				c = Color8(176, 132, 90)
			elif int(sqrt(dd) * 4.0) % 2 == 1:
				c = Color8(196, 160, 112)
			if xx == 2 and yy > -2:
				c = Color8(120, 86, 60)
			pix[Vector2i(cx + xx, yt + yy)] = c
	_blit_outlined(pix)
	if axe:
		for i in 14:
			var px := cx - 1 + i
			var py := yt - i / 2
			put(px, py, WOOD[0])
			put(px, py + 1, WOOD[2])
			put(px, py - 1, OUT)
			put(px, py + 2, OUT)
		rect(cx - 5, yt - 4, 6, 6, OUT)
		rect(cx - 4, yt - 3, 4, 4, IRON[1])
		rect(cx - 4, yt - 3, 4, 1, IRON[0])
		put(cx - 4, yt, IRON[2])


## Поленница: торцы поленьев рядами между двумя колышками.
func _woodpile(cx: int, base: int, cols := 5, rows := 3) -> void:
	ground_shadow(cx + 8, base, cols * 4 + 8, 3, 0.32)
	bar(cx - cols * 4 - 3, base - rows * 8 - 6, 3, rows * 8 + 6, WOOD)
	bar(cx + cols * 4, base - rows * 8 - 6, 3, rows * 8 + 6, WOOD)
	for r in rows:
		for c in cols:
			_log_end(cx - cols * 4 + 4 + c * 8, base - 5 - r * 8, r * 7 + c)


func _log_end(x: int, y: int, sd: int) -> void:
	for yy in range(-5, 6):
		for xx in range(-5, 6):
			var d := sqrt(float(xx * xx + yy * yy))
			if d > 4.6:
				continue
			var c: Color = OUT
			if d <= 3.8:
				c = BARK[1] if xx + yy < 2 else BARK[2]
			if d <= 2.8:
				c = Color8(224, 192, 142) if xx + yy < 1 else Color8(196, 160, 112)
			if d <= 1.2:
				c = Color8(176, 136, 94)
			put(x + xx, y + yy, c)
	if sd % 4 == 1:
		put(x + 1, y - 1, Color8(150, 110, 76))


## Старое дерево: толстый кривой ствол с бороздами коры, корни наружу, дупло; крона — крупные
## пучки. kind: "green" | "autumn".
func _old_tree(cx: int, base: int, s: int, sd: int, kind := "green") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var pal: Array = LEAF5 if kind == "green" else LEAF_AUTUMN
	ground_shadow(cx + s / 2 + 6, base, s + 14, s / 3 + 4, 0.34)
	var pix := {}
	var th := int(s * 1.3)
	var bend_top := 0
	for yy in th + 1:
		var k := float(yy) / th
		var bend := sin(k * 3.0 + sd) * 3.0 + k * 4.0
		bend_top = int(round(bend))
		var half := 8.0 - k * 3.0 + (4.0 if yy < 4 else 0.0) + 1.2 * sin(yy * 0.5 + sd)
		for xx in range(int(floor(-half)), int(ceil(half)) + 1):
			var t := (xx + half) / (half * 2.0)
			var c: Color = BARK[1]
			if t < 0.25:
				c = BARK[0]
			elif t > 0.72:
				c = BARK[2]
			if posmod(xx * 3 + int(yy / 4.0) + sd, 5) == 0:
				c = c.darkened(0.18)
			if k > 0.65:
				c = c.darkened(0.22)
			pix[Vector2i(cx + xx + int(round(bend)), base - yy)] = c
	for side: int in [-1, 1]:
		for j in 2:
			for i in 8 + j * 4:
				var rx := cx + side * (7 + i)
				var ry := base - 2 + i / 3 - j * 3 + (i / 4 if j == 1 else 0)
				pix[Vector2i(rx, ry)] = BARK[0] if side < 0 else BARK[2]
				pix[Vector2i(rx, ry - 1)] = BARK[1]
	_blit_outlined(pix)
	# Дупло.
	var hx := cx + int(round(sin(0.4 * 3.0 + sd) * 3.0 + 1.6)) - 1
	var hy := base - int(th * 0.4)
	for yy in range(-6, 7):
		for xx in range(-4, 5):
			var e := pow(xx / 3.5, 2) + pow(yy / 5.5, 2)
			if e > 1.0:
				continue
			var c: Color = Color8(34, 22, 24)
			if e > 0.6:
				c = OUT
			if yy > 2 and e > 0.45:
				c = BARK[0]
			put(hx + xx, hy + yy, c)
	# Крона.
	var top := base - th
	var cyy := top - s / 3
	var clumps: Array = [[0, -s * 0.32, s * 0.6, 1]]
	for i in 4:
		var ang := PI + 0.2 + i * 0.95 + rng.randf_range(-0.2, 0.2)
		clumps.append([cos(ang) * s * 0.75, -s * 0.2 + sin(ang) * s * 0.3, s * rng.randf_range(0.45, 0.55), 1])
	for i in 5:
		var px := lerpf(-s * 0.9, s * 0.9, i / 4.0) + rng.randf_range(-3, 3)
		clumps.append([px, s * 0.12 + (i % 2) * 4 - 2, s * rng.randf_range(0.38, 0.46), 0])
	for i in 3:
		var px := lerpf(-s * 0.5, s * 0.5, i / 2.0) + rng.randf_range(-2, 2)
		clumps.append([px, s * 0.45, s * rng.randf_range(0.34, 0.4), 0])
	_draw_clumps(clumps, cx + bend_top, cyy, pal, sd, rng)
