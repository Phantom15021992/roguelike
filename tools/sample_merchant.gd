extends "res://tools/pixstyle.gd"
## Образец графики (не в игре): дом торговца «пиксель в пиксель» по референсу владельца (дом-бар).
## Ракурс — сверху-спереди: виден фасад и крыша целиком (как у домика с фронтоном из референса).
## Плотность как у референса: 2 пикселя картинки на пиксель мира (в референсе ~1,5).
## Правила: у каждой детали тёмный контур, свет 1–2 px сверху-слева, тень 1–2 px снизу-справа,
## приглушённая естественная палитра.
## Кисти — tools/pixstyle.gd, правила стиля — .claude/skills/pixel-style.
##   godot --headless --path . --script res://tools/sample_merchant.gd
## Выход: shots/sample_merchant.png (1:1), shots/sample_merchant_x4.png (увеличено).

const BASE := 180    # линия земли у фасада

func _init() -> void:
	setup(232 + 70, 204, 70, 84)
	_ground()
	_tree(-34, 126, 26, 3)
	_tree(258, 112, 23, 8, "birch")
	_bush(-52, 152, 13, 21, "flower")
	_bush(286, 140, 13, 22, "berry")
	_house_shadow()
	_wing_roof()
	_chimney_slope(175, 6, 16)
	_main_wall()
	_main_roof()
	_vent(70, 56)
	_window(40, 132, 52, 28)
	_awning(30, 116, 72)
	_gable_wing()
	# Тёмная обводка по низу дома (стык стен с землёй).
	rect(11, BASE, 186, 1, OUT)
	_door(160, BASE, 22, 46)
	_sign_board(140, 104, 46)
	_hanging_sign(196, 124)
	_crates()
	# Бочки вокруг дома.
	_keg(-24, 166, 16, 20)
	_keg(-8, 172, 16, 20)
	_keg_side(-34, 190, 22, 7)
	_keg(14, BASE + 4, 16, 20)
	_keg(224, 160, 16, 20, true)
	_keg(241, 166, 16, 20)
	_keg(230, 176, 12, 14)
	_keg(206, BASE + 4, 16, 20)
	_easel(118, BASE + 10)
	_fence()
	_ivy()
	var out := ProjectSettings.globalize_path("res://shots/")
	img.save_png(out + "sample_merchant.png")
	var big := img.duplicate()
	big.resize(W * 4, H * 4, Image.INTERPOLATE_NEAREST)
	big.save_png(out + "sample_merchant_x4.png")
	_gallery()
	print("sample: done")
	quit()

## Галерея деревьев и кустов на траве (shots/sample_trees.png, увеличено в 4 раза).
func _gallery() -> void:
	var main := img
	img = Image.create(W, 200, false, Image.FORMAT_RGBA8)
	for y in range(-OY, 200 - OY):
		for x in range(-OX, W - OX):
			var n := nz.get_noise_2d(x, y * 1.3)
			var c: Color = GRASS[1]
			if n > 0.25:
				c = GRASS[1].lerp(GRASS[0], 0.35)
			elif n < -0.3:
				c = GRASS[1].lerp(GRASS[2], 0.6)
			put(x, y, c)
	var kinds := ["oak", "birch", "pine", "fruit", "autumn"]
	for i in kinds.size():
		_tree(-38 + i * 74, 30, 24, 3 + i * 5, kinds[i])
	var bk := ["green", "flower", "berry", "dark", "green", "flower"]
	for i in bk.size():
		_bush(-44 + i * 62, 96, 12 + (i % 3) * 3, 40 + i, bk[i])
	var big := img.duplicate()
	big.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	big.save_png(ProjectSettings.globalize_path("res://shots/sample_trees.png"))
	img = main


# ------------------------------- кисточки -------------------------------

func _ground() -> void:
	# Трава вокруг (чтобы были видны тени на земле).
	for y in range(-OY, BASE - 6):
		for x in range(-OX, W - OX):
			# Спокойная трава: крупные пятна тона + редкие травинки (2 px: свет сверху, тень снизу).
			var n := nz.get_noise_2d(x, y * 1.3)
			var c: Color = GRASS[1]
			if n > 0.25:
				c = GRASS[1].lerp(GRASS[0], 0.35)
			elif n < -0.3:
				c = GRASS[1].lerp(GRASS[2], 0.6)
			var tuft := hh(x / 2, y / 3, 20)
			if tuft < 26:
				c = GRASS[0] if posmod(y, 3) == 0 else GRASS[2]
			if hh(x / 2, y / 2, 22) < 2:
				c = [Color8(236, 214, 120), Color8(232, 140, 150), Color8(240, 236, 226)][hh(x, y, 23) % 3]
			put(x, y, c)
	# Мощёный дворик перед лавкой: плиты с объёмом, мох в швах.
	for y in range(BASE - 6, H):
		for x in range(-OX, W - OX):
			var row := (y - BASE + 6) / 9
			var off := (row % 2) * 9
			var sx := posmod(x + off, 18)
			var sy := (y - BASE + 6) % 9
			var c: Color = GROUND[1]
			var v := hh(int(floor((x + off) / 18.0)), row, 3) % 4
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
			put(x, y, c)
	# Пучки травы.
	for i in 14:
		var gx := hh(i, 0, 5) % W
		var gy := BASE + 2 + hh(i, 1, 5) % (H - BASE - 4)
		put(gx, gy, MOSS[0])
		put(gx + 1, gy - 1, MOSS[1])
		put(gx - 1, gy, MOSS[1])
		put(gx, gy + 1, MOSS[2])
	# Тень дома на дворе (у фасада и вправо).
	shadow(10, BASE - 6, 196, 6, 0.3)
	shadow(10, BASE, 196, 2, 0.18)


# ------------------------------- крыша -------------------------------

## Крыша основного дома, вид сверху-спереди: большой передний скат, за коньком — полоска
## заднего ската (он смотрит от света — темнее), слева торец с ветровой доской.
## Крыша основного дома (правка владельца): виден только передний скат; правый край срезан
## по диагонали и лежит поверх левого ската крыла; фасад под крышей выше.
func _main_roof() -> void:
	var poly := PackedVector2Array([Vector2(6, 35), Vector2(146, 35), Vector2(121, 60), Vector2(121, 99), Vector2(6, 99)])
	_shingles(poly, 35, 0.07)
	for y in range(35, 99):
		for k in 12:
			tint(7 + k, y, -(0.12 - k * 0.01))
	# Конёк сверху — брус, под ним тень.
	bar(5, 32, 142, 4, ROOF)
	shadow(6, 37, 138, 1, 0.3)
	# Срезанный край справа — ветровая доска по диагонали, за ней тень на скате крыла.
	var n := 25
	for i in n + 1:
		var p := Vector2(147, 36).lerp(Vector2(122, 61), float(i) / n)
		var x := int(round(p.x))
		var y := int(round(p.y))
		put(x - 1, y, WOOD[0])
		put(x, y, WOOD[1])
		put(x + 1, y, WOOD[2])
		put(x + 2, y, OUT)
		tint(x + 3, y, 0.25)
		tint(x + 4, y, 0.15)
	# Левый торец и карниз.
	bar(3, 32, 4, 69, WOOD)
	bar(4, 98, 118, 4, WOOD)
	shadow(8, 103, 112, 3, 0.35)

## Крыша крыла с фронтоном к зрителю (стык — как в референсе с пабом): левый скат отделён от
## основной крыши ендовой — диагональю от угла карниза крыла к коньку основного дома; выше
## основного конька скаты крыла сходятся к верхней точке (вальма). Левый скат на свету, правый в тени.
func _wing_roof() -> void:
	var l := Vector2(121, 104)
	var a := Vector2(162, 58)
	var r := Vector2(203, 104)
	var back := Vector2(0, -77)
	var t := a + back
	var v := l + back
	var rv := r + back
	_slope(l, a - l, back, 0.0)
	_slope(r, a - r, back, 0.26)
	# Левый карниз крыла (вертикальный край ската) — доска.
	for y in range(int(v.y), int(l.y) + 1):
		put(int(l.x) - 1, y, OUT)
		put(int(l.x), y, WOOD[0])
		put(int(l.x) + 1, y, WOOD[1])
	# Задние края скатов (контур сзади): светлое слева, тёмное справа.
	for pair: Array in [[v, t, true], [rv, t, false]]:
		var p0: Vector2 = pair[0]
		var p1: Vector2 = pair[1]
		var lit: bool = pair[2]
		var m := int(maxf(absf(p1.x - p0.x), absf(p1.y - p0.y)))
		for i in m + 1:
			var p := p0.lerp(p1, float(i) / m)
			var x := int(round(p.x))
			var y := int(round(p.y))
			put(x + (-1 if lit else 1), y, OUT)
			put(x, y, ROOF[0] if lit else ROOF[3])
	# Правый карниз крыла (вертикальный край ската) — доска.
	for y in range(int(rv.y), int(r.y) + 1):
		put(int(r.x) + 1, y, OUT)
		put(int(r.x), y, WOOD[2])
		put(int(r.x) - 1, y, WOOD[1])
	# Конёк крыла: свет слева, тень справа.
	for y in range(int(t.y), int(a.y) + 1):
		put(int(a.x) - 2, y, OUT)
		put(int(a.x) - 1, y, ROOF[0])
		put(int(a.x), y, ROOF[1])
		put(int(a.x) + 1, y, ROOF[3])
		put(int(a.x) + 2, y, OUT)
	put(int(t.x) - 1, int(t.y) - 1, OUT)
	put(int(t.x), int(t.y) - 1, OUT)
	put(int(t.x) + 1, int(t.y) - 1, OUT)
	_board(l, a)
	_board(a, r)
	rect(int(a.x) - 2, int(a.y) - 7, 4, 6, OUT)
	rect(int(a.x) - 1, int(a.y) - 6, 2, 4, WOOD[1])
	put(int(a.x) - 1, int(a.y) - 6, WOOD[0])

## Тень дома на траве справа (свет сверху-слева).
func _house_shadow() -> void:
	# Полоса справа от крыла, как раньше, но короче: от уровня карниза крыла вниз до земли
	# (проходит и позади подвесной вывески).
	for y in range(62, BASE):
		var w := 16 if y > 75 else clampi((y - 62) + 3, 0, 16)
		# От линии стены крыла (x = 196): под свесом крыши светлого зазора нет.
		for x in range(196, 204 + w):
			put(x, y, Color(0.16, 0.08, 0.16, 0.3))

func _main_wall() -> void:
	# Стена основного дома: фахверк.
	var x0 := 12
	var x1 := 128
	var top := 102
	_plaster(x0, top, x1 - x0, BASE - top)
	# Цоколь из камня.
	for yy in 8:
		for xx in range(x0, x1):
			var c: Color = STONE[1]
			var sx := (xx + (yy / 4) * 4) % 10
			if yy % 4 == 0 or sx == 0:
				c = STONE[3]
			elif yy % 4 == 1 or sx == 1:
				c = STONE[0]
			put(xx, BASE - 8 + yy, c)
	rect(x0 - 1, BASE - 9, x1 - x0 + 2, 1, OUT)
	# Балки: рамка, стойки, раскосы — каждая с объёмом и тенью на штукатурке.
	bar(x0, top, x1 - x0, 4, WOOD)
	bar(x0, BASE - 13, x1 - x0, 4, WOOD)
	for px: int in [x0, 30, 98, x1 - 5]:
		bar(px, top + 4, 5, BASE - 13 - top - 4, WOOD)
		shadow(px + 5, top + 4, 1, BASE - 17 - top, 0.22)
	# Тень под верхней балкой.
	shadow(x0, top + 4, x1 - x0, 1, 0.25)
	# Раскос справа от окна.
	for i in 26:
		var bx := 104 + int(i * 0.75)
		var by := BASE - 14 - i
		rect(bx, by, 4, 1, WOOD[1])
		put(bx, by, WOOD[0])
		put(bx + 3, by, WOOD[2])
		put(bx - 1, by, OUT)
		put(bx + 4, by, OUT)

func _gable_wing() -> void:
	var x0 := 128
	var x1 := 196
	var top := 104
	var cx := (x0 + x1) / 2
	_plaster(x0, top, x1 - x0, BASE - top)
	for yy in 8:
		for xx in range(x0, x1):
			var c: Color = STONE[1]
			var sx := (xx + (yy / 4) * 4) % 10
			if yy % 4 == 0 or sx == 0:
				c = STONE[3]
			elif yy % 4 == 1 or sx == 1:
				c = STONE[0]
			put(xx, BASE - 8 + yy, c)
	rect(x0 - 1, BASE - 9, x1 - x0 + 2, 1, OUT)
	# Фронтон: треугольник штукатурки под досками крыши.
	var apex := 62
	for y in range(apex, top):
		var half := int(float(y - apex) / float(top - apex) * (x1 - x0 + 10) / 2.0)
		for xx in range(cx - half, cx + half):
			var c: Color = PLAST[1]
			if hh(xx / 2, y / 2, 11) < 80:
				c = PLAST[2]
			put(xx, y, c)
	# Тень под ветровыми досками.
	for y in range(apex + 4, top):
		var half := int(float(y - apex) / float(top - apex) * (x1 - x0 + 10) / 2.0)
		tint(cx - half + 1, y, 0.25)
		tint(cx - half + 2, y, 0.15)
		tint(cx + half - 2, y, 0.25)
		tint(cx + half - 3, y, 0.15)
	# Окошко во фронтоне.
	rect(cx - 7, 74, 14, 15, OUT)
	bar(cx - 6, 75, 12, 13, WOOD, false)
	rect(cx - 4, 77, 8, 9, GLASS[1])
	rect(cx - 4, 77, 8, 2, GLASS[2])
	put(cx - 3, 80, GLASS[0])
	put(cx - 2, 79, GLASS[0])
	rect(cx - 1, 77, 2, 9, WOOD[2])
	bar(cx - 8, 89, 16, 2, WOOD)
	shadow(cx - 7, 92, 14, 1, 0.3)
	# Балки: перекладина под фронтоном, угловые стойки.
	bar(x0 - 2, top - 4, x1 - x0 + 4, 4, WOOD)
	shadow(x0, top, x1 - x0, 2, 0.25)
	bar(x0, top, 5, BASE - 9 - top, WOOD)
	bar(x1 - 5, top, 5, BASE - 9 - top, WOOD)
	shadow(x0 + 5, top + 2, 1, BASE - 12 - top, 0.22)

func _crates() -> void:
	_crate(30, BASE - 4, 16, Color8(196, 70, 66))
	_crate(48, BASE - 2, 16, Color8(222, 150, 66))
	_crate(66, BASE - 4, 16, Color8(130, 170, 80))

## Забор: каждый столбик и перекладина — 2 px света и тени.
func _fence() -> void:
	for seg: Array in [[0, 26], [200, 232]]:
		var a: int = seg[0]
		var b: int = seg[1]
		for px in range(a + 2, b, 12):
			rect(px - 1, BASE + 2, 6, 20, OUT)
			rect(px, BASE + 3, 4, 18, WOOD[1])
			rect(px, BASE + 3, 1, 18, WOOD[0])
			rect(px + 1, BASE + 3, 1, 18, WOOD[0].darkened(0.05))
			rect(px + 3, BASE + 3, 1, 18, WOOD[2])
			rect(px, BASE + 3, 4, 1, WOOD[0].lightened(0.1))
			shadow(px + 4, BASE + 18, 4, 3, 0.3)
		for ry: int in [BASE + 7, BASE + 14]:
			rect(a, ry - 1, b - a, 5, OUT)
			rect(a, ry, b - a, 3, WOOD[1])
			rect(a, ry, b - a, 1, WOOD[0])
			rect(a, ry + 2, b - a, 1, WOOD[2])
		# Столбики поверх перекладин спереди.
		for px in range(a + 2, b, 12):
			rect(px, BASE + 6, 4, 2, WOOD[1])
			put(px, BASE + 6, WOOD[0])

## Плющ и мох, свисающие с карнизов (как в референсе).
func _ivy() -> void:
	for x: int in [16, 22, 60, 118, 132, 190]:
		var l := 4 + hh(x, 0, 14) % 9
		for i in l:
			var xx := x + (i / 3) % 2
			put(xx, 117 + i, MOSS[1] if i % 3 != 2 else MOSS[2])
			if i % 3 == 0:
				put(xx + 1, 117 + i, MOSS[0])
				put(xx - 1, 118 + i, MOSS[2])
