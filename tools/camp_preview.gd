extends "res://tools/pixstyle.gd"
## Вид всего лагеря в утверждённом стиле (картинка-превью, в игру пока не вставлено):
## все постройки построены, раскладка — scripts/camp_layout.gd (клетка 16 px мира = 32 px картинки).
## Правила стиля — .claude/skills/pixel-style.
##   godot --headless --path . --script res://tools/camp_preview.gd
## Выход: shots/camp_preview.png (1:1) и shots/camp_preview_x2.png.

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

var objects: Array = []   # [основание y, Callable] — рисуются по порядку сзади вперёд


func _init() -> void:
	setup(LAY.W * C, LAY.H * C, 0, 0)
	_ground()
	_place_buildings()
	_place_props()
	_place_forest()
	objects.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for o: Array in objects:
		(o[1] as Callable).call()
	save("camp_preview", 2)
	print("camp_preview: done")
	quit()


## Сдвиг начала координат (рисуем постройку в её местных координатах).
func at(x: int, y: int) -> void:
	OX = x
	OY = y


func add(base_y: float, f: Callable) -> void:
	objects.append([base_y, f])


# ===================================================================================
#                                    ЗЕМЛЯ
# ===================================================================================

func _ground() -> void:
	var kinds := PackedByteArray()
	kinds.resize(W * H)
	for y in H:
		for x in W:
			var wn := nz.get_noise_2d(x * 2.0, y * 2.0) * 0.18
			var k := LAY.kind_at(x / float(C) + wn, y / float(C) - wn)
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

func _place_buildings() -> void:
	var lots := {
		"library": LAY.LOTS[0], "training": LAY.LOTS[1], "forge": LAY.LOTS[2], "infirmary": LAY.LOTS[3],
		"mentor": LAY.LOTS[4], "exchange": LAY.LOTS[5], "treasury": LAY.LOTS[6], "storage": LAY.LOTS[7],
		"workshop": LAY.LOTS[8],
	}
	lots["merchant"] = LAY.FIXED["merchant"]
	lots["portal"] = LAY.FIXED["portal"]
	lots["mine"] = LAY.FIXED["mine"]
	for id: String in lots:
		var p: Vector2 = lots[id]
		var sx := int(p.x * C)
		var sy := int(p.y * C)
		add(sy, func() -> void:
			RP = ROOF
			call("_b_" + id, sx, sy)
			at(0, 0)
			RP = ROOF)


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
	_portal()


func _b_mine(sx: int, sy: int) -> void:
	at(sx, sy)
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


## Шахта (по референсу): гора светлых валунов с мхом, деревянная крепь со входом,
## рельсы с вагонеткой руды, подъёмник с колесом и ведром.
func _mine() -> void:
	ground_shadow(40, 0, 100, 8, 0.3)
	var rocks: Array = [
		[-70, -70, 30, 34], [-40, -96, 32, 34], [-8, -112, 28, 30], [24, -96, 26, 30],
		[-86, -36, 26, 26], [-58, -40, 28, 28], [44, -60, 26, 26], [-30, -58, 22, 22],
		[-96, -10, 22, 16], [-66, -10, 20, 16], [54, -14, 22, 18], [72, -30, 18, 18],
	]
	for rk: Array in rocks:
		_boulder(int(rk[0]), int(rk[1]), int(rk[2]), int(rk[3]), int(rk[0]) * 7 + int(rk[1]))
	# Вход: тёмный проём, крепь.
	var ex := -6
	for py in range(-58, 0):
		for px in range(ex - 18, ex + 19):
			var t := float(py + 58) / 58.0
			put(px, py, Color8(14, 10, 14).lerp(Color8(60, 46, 40), t * 0.6))
	for side: int in [-1, 1]:
		bar(ex + side * 22 - 3, -64, 7, 64, WOOD)
		bar(ex + side * 26 - 3, -40, 5, 40, WOOD)
	bar(ex - 30, -72, 60, 9, WOOD)
	bar(ex - 26, -82, 52, 7, WOOD)
	for k in 3:
		rect(ex - 18 + k * 14, -68, 2, 2, IRON[2])
	# Рельсы к зрителю.
	for i in 8:
		var y := -4 + i * 5
		bar(ex - 16 + i, y, 30, 2, WOOD)
	for side: int in [-1, 1]:
		for i in 42:
			var x := ex + side * 9 + int(i * 0.25)
			put(x, -6 + i, IRON[0])
			put(x + 1, -6 + i, IRON[2])
			put(x - 1, -6 + i, OUT)
			put(x + 2, -6 + i, OUT)
	# Вагонетка с рудой.
	_cart(ex + 4, 30)
	# Подъёмник.
	_crane(66, -6)


## Валун: силуэт с гранями — светлая верхняя грань, средняя передняя, тёмный низ и правый бок,
## мох на верхушке, трещины; контур.
func _boulder(cx: int, cy: int, rx: int, ry: int, sd: int) -> void:
	var pix := {}
	for py in range(cy - ry, cy + ry + 1):
		for px in range(cx - rx, cx + rx + 1):
			var dx := float(px - cx) / rx
			var dy := float(py - cy) / ry
			var ang := atan2(dy, dx)
			var edge := 1.0 - 0.12 * absf(sin(ang * 3.0 + sd)) - 0.06 * absf(sin(ang * 7.0 + sd * 0.3))
			var d := sqrt(dx * dx + dy * dy)
			if d > edge:
				continue
			var g := dy + dx * 0.4
			var ti := 1
			if dy < -0.35 + 0.15 * sin(dx * 3.0 + sd):
				ti = 0                                  # верхняя грань
			elif g > 0.55:
				ti = 3
			elif g > 0.2:
				ti = 2
			if d > edge - 0.12 and (dx > 0.3 or dy > 0.4):
				ti = 4
			var c: Color = ROCK[ti]
			if ti <= 1 and dy < -0.45 and hh(px / 3, py / 3, sd) < 520:
				c = MOSS[0] if dy < -0.65 else MOSS[1]
			if absf(nz.get_noise_2d(px * 1.6 + sd, py * 1.6)) < 0.018 and ti > 0 and d < edge - 0.15:
				c = ROCK[3]
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)


func _cart(cx: int, base: int) -> void:
	ground_shadow(cx + 10, base, 20, 3, 0.32)
	var pix := {}
	for py in range(base - 18, base - 4):
		var half := 16 - (py - (base - 18)) / 4
		for px in range(cx - half, cx + half):
			var t := float(px - cx + half) / (half * 2.0)
			var c: Color = HOOP[1] if t < 0.7 else HOOP[2]
			if py == base - 18:
				c = HOOP[0]
			if posmod(px - cx, 8) == 0:
				c = HOOP[3]
			pix[Vector2i(px, py)] = c
	_blit_outlined(pix)
	for k in 7:
		var bx := cx - 12 + k * 4
		var by := base - 20 - (k % 2) * 2
		rect(bx, by, 4, 3, ROCK[1 + k % 2])
		put(bx, by, ROCK[0])
		put(bx + 3, by + 2, ROCK[3])
		if k % 3 == 1:
			put(bx + 1, by + 1, Color8(244, 206, 96))
	for wx: int in [cx - 10, cx + 8]:
		for yy in range(-3, 4):
			for xx in range(-3, 4):
				var d := xx * xx + yy * yy
				if d <= 10:
					put(wx + xx, base - 3 + yy, OUT if d > 5 else (HOOP[1] if xx + yy < 0 else HOOP[2]))


## Подъёмник: две стойки с раскосами, верхняя балка, колесо-блок, канат и ведро с камнями.
func _crane(x: int, base: int) -> void:
	ground_shadow(x + 18, base, 22, 4, 0.3)
	bar(x - 12, base - 96, 5, 96, WOOD)
	bar(x + 8, base - 96, 5, 96, WOOD)
	for k in 3:
		var y0 := base - 20 - k * 26
		for i in 20:
			put(x - 7 + i, y0 - i, WOOD[1])
			put(x - 7 + i, y0 - i + 1, WOOD[2])
			put(x - 7 + i, y0 - i - 1, OUT)
		bar(x - 8, y0 - 22, 17, 3, WOOD)
	bar(x - 18, base - 104, 52, 7, WOOD)
	# Колесо-блок.
	for yy in range(-6, 7):
		for xx in range(-6, 7):
			var d := xx * xx + yy * yy
			if d <= 36:
				var c: Color = OUT
				if d <= 25:
					c = HOOP[1] if xx + yy < 0 else HOOP[2]
				if d <= 4:
					c = HOOP[0]
				put(x + 28 + xx, base - 108 + yy, c)
	# Канат и ведро.
	for yy in range(base - 102, base - 52):
		put(x + 33, yy, Color8(196, 170, 120))
		put(x + 34, yy, Color8(140, 112, 76))
	rect(x + 26, base - 52, 16, 14, OUT)
	bar(x + 27, base - 51, 14, 12, WOOD, false)
	for k in 3:
		rect(x + 28 + k * 4, base - 55, 4, 3, ROCK[k % 2])
		put(x + 28 + k * 4, base - 55, ROCK[0])


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

func _place_props() -> void:
	at(0, 0)
	var fc := LAY.PLAZA * C
	add(fc.y + 16, func() -> void: _fountain(int(fc.x), int(fc.y + 16)))
	for p: Vector2 in [Vector2(18.6, 9.6), Vector2(25.6, 9.6), Vector2(19.8, 22.6), Vector2(24.2, 22.6), Vector2(19.8, 29.6), Vector2(24.2, 29.6), Vector2(3.6, 13.2), Vector2(40.4, 13.2)]:
		var q := p * C
		add(q.y, func() -> void: _lamp(int(q.x), int(q.y)))
	for p: Vector2 in [Vector2(18.4, 17.2), Vector2(25.6, 17.2)]:
		var q := p * C
		add(q.y, func() -> void: _bench(int(q.x) - 19, int(q.y)))
	var sp := Vector2(24.6, 12.6) * C
	add(sp.y, func() -> void: _signpost(int(sp.x), int(sp.y)))
	# Деревья и кусты внутри лагеря.
	var inner := [[26.6, 26.2, "oak"], [17.5, 25.0, "fruit"], [27.8, 29.0, "birch"], [3.4, 25.6, "pine"],
		[40.6, 25.0, "autumn"], [3.0, 17.8, "birch"], [34.2, 14.6, "oak"], [9.6, 14.8, "fruit"]]
	for t: Array in inner:
		var q := Vector2(t[0], t[1]) * C
		var kind: String = t[2]
		add(q.y, func() -> void: _tree(int(q.x), int(q.y), 22, int(q.x) % 97, kind))
	var bushes := [[25.4, 24.0, "flower"], [18.6, 22.9, "green"], [21.0, 27.6, "berry"], [5.0, 14.6, "green"],
		[39.6, 21.6, "flower"], [12.8, 26.0, "dark"], [10.0, 23.4, "flower"], [35.0, 23.4, "green"]]
	for b: Array in bushes:
		var q := Vector2(b[0], b[1]) * C
		var kind: String = b[2]
		add(q.y, func() -> void: _bush(int(q.x), int(q.y), 12, int(q.y) % 91, kind))
	var rocks := [[16.0, 26.6, 9], [33.0, 26.5, 7], [36.6, 21.6, 8], [6.2, 23.0, 6], [41.0, 19.6, 7], [23.4, 26.0, 6]]
	for r: Array in rocks:
		var q := Vector2(r[0], r[1]) * C
		var s: int = r[2]
		add(q.y, func() -> void: _boulder_small(int(q.x), int(q.y), s, int(q.x)))
	for f: Vector2 in [Vector2(23.2, 26.4), Vector2(19.6, 27.0), Vector2(27.6, 23.2), Vector2(15.8, 15.6), Vector2(29.2, 16.4), Vector2(8.6, 26.2)]:
		var q := f * C
		add(q.y - 4, func() -> void: _flowers(int(q.x), int(q.y), int(q.x)))


## Лес по краям: дубы, ели, берёзы вперемешку; внизу — кусты (чтобы не закрывать улицу).
func _place_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := ["oak", "pine", "oak", "birch", "pine", "oak", "autumn"]
	var step := 44
	for gy in range(-1, H / 30 + 2):
		for gx in range(-1, W / step + 2):
			var x := gx * step + (step / 2 if gy % 2 == 1 else 0) + rng.randi_range(-10, 10)
			var y := gy * 30 + rng.randi_range(-6, 6)
			var cx := x / float(C)
			var cy := y / float(C)
			if LAY.kind_at(cx, cy) != LAY.FOREST:
				continue
			var kind: String = kinds[rng.randi() % kinds.size()]
			var s := rng.randi_range(20, 27)
			if cy > LAY.H - 3.2:
				var bk: String = ["green", "dark", "green", "berry"][rng.randi() % 4]
				add(y, func() -> void: _bush(x, y, 14, x + y, bk))
				continue
			add(y, func() -> void: _tree(x, y, s, x * 3 + y, kind))
