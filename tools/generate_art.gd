extends SceneTree
## Генератор временной пиксельной графики.
## Запуск: godot --headless --path . --script res://tools/generate_art.gd
## Позже эти картинки можно заменить настоящими ассетами с теми же размерами.

var PAL := {
	".": Color(0, 0, 0, 0),
	"k": Color8(26, 16, 32),    # контур
	"e": Color8(26, 16, 32),    # глаза
	"s": Color8(242, 199, 154), # кожа
	"h": Color8(107, 58, 31),   # волосы
	"a": Color8(74, 123, 208),  # туника
	"b": Color8(122, 74, 36),   # пояс
	"l": Color8(58, 48, 64),    # штаны
	"g": Color8(92, 184, 92),   # слизень
	"q": Color8(200, 240, 190), # блик слизня
	"d": Color8(52, 120, 60),   # тень слизня
	"p": Color8(150, 90, 220),  # дух
	"P": Color8(190, 140, 255), # дух, светлее
	"w": Color8(240, 225, 255), # ядро духа
	"r": Color8(220, 50, 60),   # сердце
	"R": Color8(255, 150, 150), # блик сердца
	"n": Color8(70, 60, 82),    # пустое сердце
	"#": Color(1, 1, 1),        # цифры
	"o": Color8(228, 222, 200), # кость
	"O": Color8(160, 150, 135), # кость, тень
	"v": Color8(92, 62, 112),   # летучая мышь
	"V": Color8(136, 100, 156), # летучая мышь, светлее
	"c": Color8(196, 58, 58),   # шляпка гриба
	"T": Color8(232, 216, 180), # ножка гриба
	"u": Color8(62, 38, 84),    # мантия
	"U": Color8(102, 66, 132),  # мантия, светлее
	"f": Color8(240, 120, 40),  # пламя
	"F": Color8(255, 214, 90),  # пламя, жёлтое
	"z": Color8(168, 48, 38),   # бес, тёмно-красный
	"Z": Color8(212, 92, 42),   # саламандра / лава
	"j": Color8(74, 66, 72),    # камень голема
	"J": Color8(118, 106, 112), # камень голема, светлее
	"m": Color8(200, 210, 222), # металл
	"M": Color8(130, 140, 156), # металл, тень
	"L": Color8(150, 100, 60),  # кожа (материал)
	"y": Color8(240, 196, 60),  # золото
	"Y": Color8(255, 240, 170), # блик золота
	"G": Color8(80, 220, 240),  # камень
}

# Иконки предметов 12x12, порядок = номер иконки в items.png.
var ICONS := [
	[ # 0 меч
		"..........kk", ".........kmk", "........kmk.", ".......kmk..",
		"......kmk...", "..k..kmk....", "..kkkmk.....", "...kbk......",
		"..kbkkk.....", ".kbk..k.....", "kbk.........", "kk..........",
	],
	[ # 1 топор
		"....kkkk....", "..kkmmmmk...", ".kmmmmmmbk..", ".kmmmmmkbk..",
		"..kkmmk.bk..", "....kk..bk..", "........bk..", "........bk..",
		"........bk..", "........bk..", "........bk..", "........kk..",
	],
	[ # 2 кинжал
		"............", "............", "............", ".......kk...",
		"......kmk...", ".....kmk....", "..k.kmk.....", "..kkmk......",
		"...kbk......", "..kbkkk.....", ".kbk..k.....", ".kk.........",
	],
	[ # 3 кожаная куртка
		"............", "..kk....kk..", ".kLLk..kLLk.", ".kLLLkkLLLk.",
		".kLLLLLLLLk.", "..kLLLLLLk..", "..kLLLLLLk..", "..kbbbbbbk..",
		"..kLLLLLLk..", "..kLLLLLLk..", "..kkkkkkkk..", "............",
	],
	[ # 4 кольчуга
		"............", "..kk....kk..", ".kmMk..kMmk.", ".kmMmkkmMmk.",
		".kMmMmMmMmk.", "..kmMmMmMk..", "..kMmMmMmk..", "..kbbbbbbk..",
		"..kmMmMmMk..", "..kMmMmMmk..", "..kkkkkkkk..", "............",
	],
	[ # 5 кольцо
		"............", ".....kk.....", "....kGGk....", "....kkkk....",
		"...kyyyyk...", "..kyk..kyk..", "..kyk..kyk..", "..kyk..kyk..",
		"...kyyyyk...", "....kkkk....", "............", "............",
	],
	[ # 6 амулет
		"..k......k..", "...k....k...", "....k..k....", ".....kk.....",
		"....kyyk....", "...kyGGyk...", "...kyGGyk...", "....kyyk....",
		".....kk.....", "............", "............", "............",
	],
]

var CROWN := [
	".k...kk...k.",
	"kyk.kyyk.kyk",
	"kyykyyyykyyk",
	"kyyyyGGyyyyk",
	"kyyyyyyyyyyk",
	"kkkkkkkkkkkk",
]

var COIN :=[".kkkk.", "kyYyyk", "kYyyyk", "kyyyyk", "kyyyyk", ".kkkk."]

var SLIME := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"......kkkk......",
	"....kkggggkk....",
	"...kgqggggggk...",
	"..kgqqgggggggk..",
	"..kgggegggeggk..",
	"..kggggggggggk..",
	"..kddddddddddk..",
	"...kkkkkkkkkk...",
	"................",
]

var WISP := [
	"................",
	"................",
	"........k.......",
	".......kpk......",
	"......kpppk.....",
	".....kppPppk....",
	"....kppPPPppk...",
	"....kpPwwwPpk...",
	"....kpwewewpk...",
	"....kpPwwwPpk...",
	".....kpPPPpk....",
	"......kpppk.....",
	".......kpk......",
	"........k.......",
	"................",
	"................",
]


var DIGITS := [
	["###", "#.#", "#.#", "#.#", "###"],
	[".#.", "##.", ".#.", ".#.", "###"],
	["###", "..#", "###", "#..", "###"],
	["###", "..#", ".##", "..#", "###"],
	["#.#", "#.#", "###", "..#", "..#"],
	["###", "#..", "###", "..#", "###"],
	["###", "#..", "###", "#.#", "###"],
	["###", "..#", "..#", ".#.", ".#."],
	["###", "#.#", "###", "#.#", "###"],
	["###", "#.#", "###", "..#", "###"],
]

# Верх тела (строки 0–11) для каждого направления.
var BODY := {
	"down": [
		"................",
		".....kkkkkk.....",
		"....khhhhhhk....",
		"...khhhhhhhhk...",
		"...khsssssshk...",
		"...ksessssesk...",
		"...kssssssssk...",
		"....kssssssk....",
		"..kaaaaaaaaaak..",
		"..kaaaaaaaaaak..",
		"..ksbbbbbbbbsk..",
		"...kaaaaaaaak...",
	],
	"up": [
		"................",
		".....kkkkkk.....",
		"....khhhhhhk....",
		"...khhhhhhhhk...",
		"...khhhhhhhhk...",
		"...khhhhhhhhk...",
		"...khhhhhhhhk...",
		"....kssssssk....",
		"..kaaaaaaaaaak..",
		"..kaaaaaaaaaak..",
		"..ksbbbbbbbbsk..",
		"...kaaaaaaaak...",
	],
	"side": [
		"................",
		".....kkkkkk.....",
		"....khhhhhhk....",
		"...khhhhhhhhk...",
		"...khhhhsssk....",
		"...khhhssesk....",
		"...khhsssssk....",
		"....kkssssk.....",
		"....kaaaaaak....",
		"....kaaaaaak....",
		"....kabbbbsk....",
		"....kaaaaaak....",
	],
}

# Ноги (строки 12–15), 4 кадра ходьбы. Кадр 0 — он же стойка.
var LEGS_DOWN_STAND := ["...kllk..kllk...", "...kllk..kllk...", "...kkkk..kkkk...", "................"]
var LEGS_DOWN_L := ["...kllk..kllk...", "...kkkk..kllk...", ".........kkkk...", "................"]
var LEGS_DOWN_R := ["...kllk..kllk...", "...kllk..kkkk...", "...kkkk.........", "................"]
var LEGS_SIDE_STAND := [".....kllllk.....", ".....kllllk.....", ".....kkkkkk.....", "................"]
var LEGS_SIDE_STEP := ["....kllkkllk....", "...kllk..kllk...", "...kkk....kkk...", "................"]

var LEGS := {
	"down": [LEGS_DOWN_STAND, LEGS_DOWN_L, LEGS_DOWN_STAND, LEGS_DOWN_R],
	"up": [LEGS_DOWN_STAND, LEGS_DOWN_R, LEGS_DOWN_STAND, LEGS_DOWN_L],
	"side": [LEGS_SIDE_STAND, LEGS_SIDE_STEP, LEGS_SIDE_STAND, LEGS_SIDE_STEP],
}

var errors := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets"))
	_make_hero()
	_make_tiles()
	_make_shadow()
	_make_slime()
	_make_wisp()
	_make_digits()
	_make_items()
	_make_boss()
	_make_camp()
	_make_catacomb_monsters()
	_make_crafting()
	_make_fire_monsters()
	print("generate_art: done, errors=%d" % errors)
	quit(1 if errors else 0)


func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("cannot save %s" % path)
		errors += 1
	else:
		print("saved ", path)


func _paint(img: Image, rows: Array, ox: int, oy: int) -> void:
	for y in rows.size():
		var row: String = rows[y]
		if row.length() != (rows[0] as String).length():
			push_error("row length mismatch: '%s'" % row)
			errors += 1
		for x in row.length():
			var c: String = row[x]
			if c == ".":
				continue
			img.set_pixel(ox + x, oy + y, PAL[c])


# Лист героя 64x48: строки — down, up, side (смотрит вправо); столбцы — 4 кадра.
# Герои классов: тот же человечек, другие цвета одежды и волос.
# Герои классов и профессий: тот же человечек, другие цвета (a — одежда, h — волосы/шлем/шляпа,
# b — пояс, l — штаны) и детали поверх (extras: [x, y, цвет, направления]) — рога, плюмаж,
# щит, перо, повязка, шляпа, очки. Координаты деталей — как в кадре 16x16 (с учётом покачивания).
const BONE := Color8(228, 222, 200)
const GOLDC := Color8(230, 190, 70)
const DIRS_ALL := ["down", "up", "side"]

var HERO_STYLES := {
	"warrior": {"a": Color8(74, 123, 208), "h": Color8(107, 58, 31)},
	"archer": {"a": Color8(70, 150, 80), "h": Color8(196, 150, 70)},
	"mage": {"a": Color8(128, 76, 186), "h": Color8(205, 205, 220)},
	"berserker": {"a": Color8(150, 42, 40), "h": Color8(205, 95, 40), "b": Color8(70, 50, 40), "l": Color8(70, 45, 40),
		"extras": [[3, 1, BONE, ["down", "up"]], [3, 2, BONE, ["down", "up"]], [12, 1, BONE, ["down", "up"]], [12, 2, BONE, ["down", "up"]],
			[4, 1, BONE, ["side"]], [4, 2, BONE, ["side"]], [10, 1, BONE, ["side"]], [10, 2, BONE, ["side"]]]},
	"paladin": {"a": Color8(205, 210, 222), "h": Color8(150, 155, 172), "b": Color8(225, 185, 60), "l": Color8(110, 110, 130),
		"extras": [[7, 0, Color8(210, 50, 50), DIRS_ALL], [8, 0, Color8(210, 50, 50), DIRS_ALL],
			[1, 8, Color8(60, 90, 170), ["down"]], [2, 8, Color8(60, 90, 170), ["down"]], [1, 9, GOLDC, ["down"]], [2, 9, GOLDC, ["down"]],
			[1, 10, Color8(60, 90, 170), ["down"]], [2, 10, Color8(60, 90, 170), ["down"]], [1, 11, Color8(40, 60, 120), ["down"]], [2, 11, Color8(40, 60, 120), ["down"]],
			[12, 8, Color8(60, 90, 170), ["side"]], [12, 9, GOLDC, ["side"]], [12, 10, Color8(60, 90, 170), ["side"]], [12, 11, Color8(40, 60, 120), ["side"]]]},
	"hunter": {"a": Color8(100, 122, 62), "h": Color8(120, 80, 42), "b": Color8(90, 60, 35), "l": Color8(75, 70, 50),
		"extras": [[12, 0, Color8(200, 60, 50), ["down", "up"]], [12, 1, Color8(200, 60, 50), ["down", "up"]], [11, 1, Color8(230, 230, 230), ["down", "up"]],
			[4, 0, Color8(200, 60, 50), ["side"]], [4, 1, Color8(200, 60, 50), ["side"]],
			[11, 7, Color8(120, 80, 42), ["up"]], [11, 8, Color8(120, 80, 42), ["up"]], [11, 9, Color8(120, 80, 42), ["up"]], [12, 6, Color8(230, 230, 230), ["up"]]]},
	"sniper": {"a": Color8(58, 72, 88), "h": Color8(40, 38, 48), "b": Color8(160, 40, 40), "l": Color8(40, 45, 55),
		"extras": [[4, 3, Color8(190, 40, 40), ["down", "up"]], [5, 3, Color8(190, 40, 40), ["down", "up"]], [6, 3, Color8(190, 40, 40), ["down", "up"]],
			[7, 3, Color8(190, 40, 40), ["down", "up"]], [8, 3, Color8(190, 40, 40), ["down", "up"]], [9, 3, Color8(190, 40, 40), ["down", "up"]],
			[10, 3, Color8(190, 40, 40), ["down", "up"]], [11, 3, Color8(190, 40, 40), ["down", "up"]],
			[4, 3, Color8(190, 40, 40), ["side"]], [5, 3, Color8(190, 40, 40), ["side"]], [6, 3, Color8(190, 40, 40), ["side"]], [7, 3, Color8(190, 40, 40), ["side"]],
			[3, 4, Color8(190, 40, 40), ["side"]], [2, 5, Color8(190, 40, 40), ["side"]]]},
	"wizard": {"a": Color8(48, 58, 150), "h": Color8(48, 58, 150), "b": GOLDC, "l": Color8(40, 40, 80),
		"extras": [[7, 0, Color8(48, 58, 150), DIRS_ALL], [8, 0, Color8(48, 58, 150), DIRS_ALL], [6, 0, Color8(26, 16, 32), DIRS_ALL], [9, 0, Color8(26, 16, 32), DIRS_ALL],
			[2, 3, Color8(48, 58, 150), ["down", "up"]], [13, 3, Color8(48, 58, 150), ["down", "up"]], [9, 2, Color8(255, 230, 110), ["down", "side"]]]},
	"professor": {"a": Color8(58, 125, 112), "h": Color8(232, 232, 238), "b": Color8(200, 170, 60), "l": Color8(50, 60, 60),
		"extras": [[4, 5, GOLDC, ["down"]], [6, 5, GOLDC, ["down"]], [7, 5, GOLDC, ["down"]], [8, 5, GOLDC, ["down"]], [9, 5, GOLDC, ["down"]], [11, 5, GOLDC, ["down"]],
			[8, 5, GOLDC, ["side"]], [10, 5, GOLDC, ["side"]]]},
	# Вор и его профессии: тёмные цвета, маска/повязка.
	"thief": {"a": Color8(80, 76, 92), "h": Color8(52, 44, 40), "b": Color8(110, 80, 50), "l": Color8(48, 44, 56),
		"extras": [[5, 4, Color8(40, 36, 48), ["down"]], [6, 4, Color8(40, 36, 48), ["down"]], [9, 4, Color8(40, 36, 48), ["down"]], [10, 4, Color8(40, 36, 48), ["down"]]]},
	"bandit": {"a": Color8(140, 70, 40), "h": Color8(60, 40, 30), "b": Color8(70, 50, 40), "l": Color8(80, 60, 45),
		"extras": [[4, 3, Color8(200, 40, 40), ["down", "up"]], [5, 3, Color8(200, 40, 40), ["down", "up"]], [6, 3, Color8(200, 40, 40), ["down", "up"]],
			[7, 3, Color8(200, 40, 40), ["down", "up"]], [8, 3, Color8(200, 40, 40), ["down", "up"]], [9, 3, Color8(200, 40, 40), ["down", "up"]],
			[10, 3, Color8(200, 40, 40), ["down", "up"]], [11, 3, Color8(200, 40, 40), ["down", "up"]], [12, 4, Color8(200, 40, 40), ["down", "up"]]]},
	"assassin": {"a": Color8(40, 36, 52), "h": Color8(40, 36, 52), "b": Color8(150, 40, 60), "l": Color8(30, 28, 40),
		"extras": [[5, 5, Color8(40, 36, 52), ["down"]], [6, 5, Color8(40, 36, 52), ["down"]], [7, 5, Color8(40, 36, 52), ["down"]],
			[8, 5, Color8(40, 36, 52), ["down"]], [9, 5, Color8(40, 36, 52), ["down"]], [10, 5, Color8(40, 36, 52), ["down"]]]},
	# Послушник и его профессии: светлые одежды.
	"acolyte": {"a": Color8(210, 200, 170), "h": Color8(120, 80, 50), "b": Color8(150, 110, 60), "l": Color8(140, 120, 90)},
	"priest": {"a": Color8(236, 236, 244), "h": Color8(200, 170, 90), "b": GOLDC, "l": Color8(200, 200, 215),
		"extras": [[7, 8, GOLDC, ["down"]], [7, 9, GOLDC, ["down"]], [6, 9, GOLDC, ["down"]], [8, 9, GOLDC, ["down"]], [7, 10, GOLDC, ["down"]]]},
	"monk": {"a": Color8(220, 140, 40), "h": Color8(242, 199, 154), "b": Color8(120, 60, 30), "l": Color8(160, 90, 30),
		"extras": [[5, 7, Color8(120, 60, 30), ["down"]], [10, 7, Color8(120, 60, 30), ["down"]]]},
}


func _make_hero() -> void:
	var saved := {}
	for k in ["a", "h", "b", "l"]:
		saved[k] = PAL[k]
	for name: String in HERO_STYLES:
		var st: Dictionary = HERO_STYLES[name]
		for k in ["a", "h", "b", "l"]:
			PAL[k] = st.get(k, saved[k])
		_make_hero_sheet("res://assets/hero_%s.png" % name, st.get("extras", []))
	for k in saved:
		PAL[k] = saved[k]


func _make_hero_sheet(path: String, extras: Array = []) -> void:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	var dirs := ["down", "up", "side"]
	for r in dirs.size():
		var d: String = dirs[r]
		for f in 4:
			var ox := f * 16
			var oy := r * 16
			_paint(img, LEGS[d][f], ox, oy + 12)
			# В шаге (кадры 1 и 3) тело опускается на 1 px — получается «покачивание».
			var bob := 1 if f % 2 == 1 else 0
			_paint(img, BODY[d], ox, oy + bob)
			for ex: Array in extras:
				if d in ex[3]:
					var y: int = ex[1] + bob
					if y >= 0 and y < 16:
						img.set_pixel(ox + ex[0], oy + y, ex[2])
	_save(img, path)


func _noise(img: Image, ox: int, base: Color, rng: RandomNumberGenerator, dark := 0.15, light := 0.10) -> void:
	for y in 16:
		for x in 16:
			var c := base
			var r := rng.randf()
			if r < dark:
				c = base.darkened(0.12)
			elif r < dark + light:
				c = base.lightened(0.08)
			img.set_pixel(ox + x, y, c)


# Тайлсет 96x16: 0–2 пол (варианты), 3 верх стены, 4 лицевая сторона стены, 5 лестница вниз.
func _make_tiles() -> void:
	var img := Image.create(96, 16, false, Image.FORMAT_RGBA8)
	var floor_c := Color8(56, 50, 68)
	var grout := Color8(48, 43, 59)
	for v in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + v
		var ox := v * 16
		_noise(img, ox, floor_c, rng)
		# Швы между плитами: прерывистые, чтобы пол не выглядел как тетрадь в клетку.
		for i in 16:
			if (i + v * 5) % 7 != 0:
				img.set_pixel(ox + i, 0, grout)
			if (i + v * 3) % 6 != 0:
				img.set_pixel(ox, i, grout)
		if v == 1:  # трещина
			var p := Vector2i(4, 5)
			for i in 7:
				img.set_pixel(ox + p.x, p.y, grout)
				p += Vector2i(1, 1 if i % 2 == 0 else 0)
		if v == 2:  # камешки
			for pt in [Vector2i(5, 9), Vector2i(11, 4), Vector2i(9, 12)]:
				img.set_pixel(ox + pt.x, pt.y, floor_c.lightened(0.25))
				img.set_pixel(ox + pt.x + 1, pt.y + 1, grout)

	# Верх стены: тёмная масса.
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = 7
	_noise(img, 48, Color8(17, 14, 23), rng_t, 0.1, 0.06)

	# Лицевая сторона: кирпичная кладка.
	var rng_f := RandomNumberGenerator.new()
	rng_f.seed = 9
	var brick := Color8(96, 82, 104)
	var mortar := Color8(44, 38, 54)
	_noise(img, 64, brick, rng_f, 0.12, 0.08)
	for y in 16:
		var row := y / 4
		var shift := 4 if row % 2 == 1 else 0
		for x in 16:
			if y % 4 == 3 or (x + shift) % 8 == 7:
				img.set_pixel(64 + x, y, mortar)
	for x in 16:
		img.set_pixel(64 + x, 0, brick.lightened(0.2))     # кромка сверху
		img.set_pixel(64 + x, 15, Color8(24, 20, 30))      # тень у пола

	# 5: лестница вниз — ступени уходят в темноту.
	var ox5 := 80
	img.fill_rect(Rect2i(ox5, 0, 16, 16), Color8(14, 11, 20))
	for i in 4:
		var step_c := Color8(110, 98, 122).darkened(i * 0.22)
		img.fill_rect(Rect2i(ox5 + 2 + i, 2 + i * 3, 12 - i * 2, 2), step_c)
	for i in 16:
		for e in [Vector2i(i, 0), Vector2i(i, 15), Vector2i(0, i), Vector2i(15, i)]:
			img.set_pixel(ox5 + e.x, e.y, Color8(70, 60, 82))
	_save(img, "res://assets/tiles.png")


func _make_shadow() -> void:
	var img := Image.create(12, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 12:
			var dx := (x + 0.5 - 6.0) / 6.0
			var dy := (y + 0.5 - 2.0) / 2.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.35))
	_save(img, "res://assets/shadow.png")


# Слизень 48x16: обычный, сплющенный, вытянутый (прыжок).
func _make_slime() -> void:
	var img := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	var squash: Array = ["................"] + SLIME.slice(0, 9) + SLIME.slice(10)
	var stretch: Array = SLIME.slice(1, 13) + [SLIME[12]] + SLIME.slice(13)
	_paint(img, SLIME, 0, 0)
	_paint(img, squash, 16, 0)
	_paint(img, stretch, 32, 0)
	_save(img, "res://assets/slime.png")


# Дух 32x16: два кадра мерцания пламени.
func _make_wisp() -> void:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	var flicker: Array = WISP.duplicate()
	flicker[2] = ".......k........"
	flicker[13] = ".........k......"
	_paint(img, WISP, 0, 0)
	_paint(img, flicker, 16, 0)
	_save(img, "res://assets/wisp.png")


# Цифры 40x5: глифы 3x5 с шагом 4 px.
func _make_digits() -> void:
	var img := Image.create(40, 5, false, Image.FORMAT_RGBA8)
	for d in 10:
		_paint(img, DIGITS[d], d * 4, 0)
	_save(img, "res://assets/digits.png")


func _outline(img: Image, rect: Rect2i, color: Color) -> void:
	var marks: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + o
				if rect.has_point(n) and img.get_pixel(n.x, n.y).a > 0.0 and img.get_pixel(n.x, n.y) != color:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixel(m.x, m.y, color)


# Иконки предметов (items.png, 12x12 каждая) и монета (coin.png, 6x6).
func _make_items() -> void:
	# 0–6 — по шаблонам ICONS; 7 короткий лук, 8 длинный лук, 9 жезл, 10 посох — рисуются кодом.
	# 11+ — новые предметы по шаблонам ICONS2 (см. порядок там).
	var count := ICONS.size() + 4
	var img := Image.create((count + ICONS2.size()) * 12, 12, false, Image.FORMAT_RGBA8)
	for i in ICONS.size():
		_paint(img, ICONS[i], i * 12, 0)
	for i in ICONS2.size():
		_paint(img, ICONS2[i], (count + i) * 12, 0)
	var wood := PAL["b"] as Color
	var string_c := Color8(225, 225, 230)
	# Луки: дуга дерева + тетива.
	for v in 2:
		var ox := (ICONS.size() + v) * 12
		var bend := 2.5 if v == 0 else 3.5
		var y0 := 1 if v == 0 else 0
		var y1 := 10 if v == 0 else 11
		for y in range(y0, y1 + 1):
			var t := float(y - y0) / (y1 - y0)
			var x := 7 - int(round(bend * sin(PI * t)))
			img.set_pixel(ox + x, y, wood if v == 0 else wood.darkened(0.25))
			img.set_pixel(ox + x - 1, y, wood.lightened(0.15))
			img.set_pixel(ox + 8, y, string_c)
	# Жезл: короткая палочка по диагонали со звездой.
	var wx := (ICONS.size() + 2) * 12
	for i in 6:
		img.set_pixel(wx + 3 + i, 10 - i, wood)
		img.set_pixel(wx + 4 + i, 10 - i, wood.lightened(0.15))
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		img.set_pixel(wx + 9 + o.x, 3 + o.y, PAL["y"])
	img.set_pixel(wx + 9, 3, PAL["Y"])
	# Посох: длинное древко с камнем в оправе.
	var sx := (ICONS.size() + 3) * 12
	for y in range(4, 12):
		img.set_pixel(sx + 5, y, wood)
		img.set_pixel(sx + 6, y, wood.lightened(0.15))
	for o in [Vector2i(4, 1), Vector2i(7, 1), Vector2i(4, 2), Vector2i(7, 2), Vector2i(5, 3), Vector2i(6, 3), Vector2i(5, 0), Vector2i(6, 0)]:
		img.set_pixel(sx + o.x, o.y, PAL["y"])
	for o in [Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 2)]:
		img.set_pixel(sx + o.x, o.y, PAL["G"])
	for i in range(ICONS.size(), count):
		_outline(img, Rect2i(i * 12, 0, 12, 12), PAL["k"])
	_save(img, "res://assets/items.png")
	var coin := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	_paint(coin, COIN, 0, 0)
	_save(coin, "res://assets/coin.png")


# Король слизней 96x32: те же три кадра слизня, увеличенные вдвое, с короной.
func _make_boss() -> void:
	var squash: Array = ["................"] + SLIME.slice(0, 9) + SLIME.slice(10)
	var stretch: Array = SLIME.slice(1, 13) + [SLIME[12]] + SLIME.slice(13)
	var frames := [SLIME, squash, stretch]
	var img := Image.create(96, 32, false, Image.FORMAT_RGBA8)
	for f in frames.size():
		var small := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		_paint(small, frames[f], 0, 0)
		small.resize(32, 32, Image.INTERPOLATE_NEAREST)
		var top := 32
		for y in 32:
			for x in 32:
				if small.get_pixel(x, y).a > 0.0:
					top = mini(top, y)
		img.blit_rect(small, Rect2i(0, 0, 32, 32), Vector2i(f * 32, 0))
		_paint(img, CROWN, f * 32 + 10, maxi(0, top - 5))
	_save(img, "res://assets/boss_slime.png")


# ---------------- Лагерь ----------------

# camp_tiles.png 64x16: 0 трава, 1 трава с цветами, 2 тропинка, 3 дерево (непроходимо).
# buildings.png 224x32: 7 построек по 32x32 — плац, библиотека, кузница, лазарет,
# сокровищница, шахта, портал.
func _make_camp() -> void:
	var tiles := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	var grass := Color8(64, 104, 58)
	for v in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + v
		_noise(tiles, v * 16, grass, rng, 0.18, 0.14)
		for i in 5:
			var p := Vector2i(rng.randi_range(1, 14), rng.randi_range(1, 14))
			tiles.set_pixel(v * 16 + p.x, p.y, grass.lightened(0.2))
		if v == 1:
			for p in [Vector2i(4, 5), Vector2i(11, 10), Vector2i(8, 13)]:
				tiles.set_pixel(16 + p.x, p.y, Color8(240, 220, 90))
				tiles.set_pixel(16 + p.x + 1, p.y, Color8(230, 120, 150))
	var rng_d := RandomNumberGenerator.new()
	rng_d.seed = 310
	_noise(tiles, 32, Color8(128, 100, 70), rng_d, 0.2, 0.15)
	# Дерево: тёмная крона на траве.
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = 320
	_noise(tiles, 48, grass.darkened(0.2), rng_t, 0.1, 0.1)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.0).length()
			if d < 7.5:
				var c := Color8(34, 74, 40) if d > 5.0 else Color8(46, 92, 50)
				if rng_t.randf() < 0.2:
					c = c.lightened(0.15)
				tiles.set_pixel(48 + x, y, c)
	_save(tiles, "res://assets/camp_tiles.png")

	var img := Image.create(384, 32, false, Image.FORMAT_RGBA8)
	var roofs := [Color8(176, 60, 54), Color8(60, 92, 170), Color8(70, 66, 76), Color8(225, 225, 230), Color8(214, 170, 50)]
	for i in roofs.size():
		_house(img, i * 32, roofs[i])
	# Эмблемы на крышах.
	_emblem(img, 0, ["#.#", ".#.", "#.#"], Color8(230, 230, 235))        # скрещённые мечи
	_emblem(img, 32, ["###", "#.#", "###"], Color8(240, 230, 200))       # книга
	_emblem(img, 64, ["###", ".#.", "###"], Color8(255, 150, 60))         # наковальня
	_emblem(img, 96, [".#.", "###", ".#."], Color8(210, 40, 40))          # красный крест
	_emblem(img, 128, [".#.", "#.#", ".#."], Color8(255, 240, 170))       # монета
	# Труба кузницы.
	img.fill_rect(Rect2i(64 + 22, 3, 3, 8), Color8(90, 80, 90))
	img.fill_rect(Rect2i(64 + 22, 1, 3, 2), Color8(255, 140, 50))
	_mine(img, 160)
	_portal(img, 192)
	# 7: мастерская — коричневая крыша, эмблема-молот.
	_house(img, 224, Color8(130, 84, 52))
	_emblem(img, 224, ["###", ".#.", ".#."], Color8(200, 205, 215))
	# 8: склад — зелёная крыша, эмблема-сундук, ящики у стены.
	_house(img, 256, Color8(70, 130, 80))
	_emblem(img, 256, ["###", "#.#", "###"], Color8(220, 180, 90))
	img.fill_rect(Rect2i(256 + 2, 24, 5, 5), Color8(150, 105, 60))
	img.fill_rect(Rect2i(256 + 25, 25, 5, 4), Color8(150, 105, 60))
	# 9: обменник — бирюзовая крыша, эмблема-стрелки «туда-обратно», мешки у стены.
	_house(img, 288, Color8(56, 150, 150))
	_emblem(img, 288, ["#..", "###", "..#"], Color8(250, 230, 120))
	img.fill_rect(Rect2i(288 + 2, 24, 5, 5), Color8(190, 160, 100))
	img.fill_rect(Rect2i(288 + 25, 24, 5, 5), Color8(120, 170, 200))
	# 10: торговец — красно-белая полосатая крыша, эмблема-мешочек, ящики с товаром.
	_house(img, 320, Color8(200, 60, 60))
	for x in range(320 + 4, 320 + 28, 6):
		img.fill_rect(Rect2i(x, 6, 3, 8), Color8(235, 230, 225))
	_emblem(img, 320, [".#.", "###", "###"], Color8(240, 200, 80))
	img.fill_rect(Rect2i(320 + 2, 23, 6, 6), Color8(150, 105, 60))
	img.fill_rect(Rect2i(320 + 24, 24, 6, 5), Color8(150, 105, 60))
	# 11: наставник — фиолетовая крыша, эмблема-звезда.
	_house(img, 352, Color8(110, 70, 160))
	_emblem(img, 352, ["#.#", ".#.", "#.#"], Color8(255, 235, 140))
	_outline(img, Rect2i(0, 0, 384, 32), PAL["k"])
	_save(img, "res://assets/buildings.png")


func _house(img: Image, ox: int, roof: Color) -> void:
	var wall := Color8(150, 108, 72)
	# Стены с досками.
	for y in range(14, 31):
		for x in range(5, 27):
			var c := wall.darkened(0.15) if y % 4 == 1 else wall
			img.set_pixel(ox + x, y, c)
	# Окна и дверь.
	img.fill_rect(Rect2i(ox + 7, 18, 5, 4), Color8(250, 220, 120))
	img.fill_rect(Rect2i(ox + 20, 18, 5, 4), Color8(250, 220, 120))
	img.fill_rect(Rect2i(ox + 13, 22, 6, 9), Color8(80, 52, 32))
	img.set_pixel(ox + 17, 26, Color8(230, 200, 90))
	# Крыша-треугольник.
	for y in range(2, 15):
		var hw := (y - 2) + 3
		for x in range(16 - hw, 16 + hw):
			if x >= 1 and x <= 30:
				var c := roof.darkened(0.25) if y == 14 else (roof.lightened(0.12) if x < 16 else roof)
				img.set_pixel(ox + x, y, c)


func _emblem(img: Image, ox: int, rows: Array, color: Color) -> void:
	for y in rows.size():
		for x in (rows[y] as String).length():
			if rows[y][x] == "#":
				img.set_pixel(ox + 15 + x, 8 + y, color)


func _mine(img: Image, ox: int) -> void:
	var rock := Color8(110, 104, 112)
	var rng := RandomNumberGenerator.new()
	rng.seed = 330
	for y in range(6, 31):
		for x in range(2, 30):
			var d := Vector2((x - 16) / 14.0, (y - 31) / 25.0).length()
			if d < 1.0:
				img.set_pixel(ox + x, y, rock.darkened(rng.randf() * 0.2))
	# Вход с деревянной рамой.
	img.fill_rect(Rect2i(ox + 10, 16, 12, 15), Color8(20, 16, 24))
	img.fill_rect(Rect2i(ox + 9, 14, 14, 2), Color8(122, 80, 44))
	img.fill_rect(Rect2i(ox + 9, 16, 2, 15), Color8(122, 80, 44))
	img.fill_rect(Rect2i(ox + 21, 16, 2, 15), Color8(122, 80, 44))
	# Рельсы и вагонетка с золотом.
	img.fill_rect(Rect2i(ox + 12, 29, 8, 1), Color8(160, 160, 170))
	img.fill_rect(Rect2i(ox + 13, 25, 6, 3), Color8(90, 90, 100))
	img.fill_rect(Rect2i(ox + 14, 24, 4, 1), PAL["y"])


func _portal(img: Image, ox: int) -> void:
	var stone := Color8(120, 116, 130)
	for y in range(3, 31):
		for x in range(4, 28):
			var dx := (x - 15.5) / 12.0
			var dy := (y - 16.0) / 13.0
			var outer := dx * dx + dy * dy < 1.0 or y >= 16
			var inner_dx := (x - 15.5) / 8.0
			var inner_dy := (y - 17.0) / 10.0
			var inner := (inner_dx * inner_dx + inner_dy * inner_dy < 1.0 or (y >= 17 and absf(x - 15.5) < 8.0)) and y < 31
			if inner:
				var k := clampf((y - 6.0) / 25.0, 0.0, 1.0)
				img.set_pixel(ox + x, y, Color8(150, 80, 220).lerp(Color8(40, 20, 70), k))
			elif outer and absf(x - 15.5) < 12.0:
				img.set_pixel(ox + x, y, stone.darkened(0.15 if (x + y) % 5 == 0 else 0.0))
	for p in [Vector2i(13, 12), Vector2i(18, 16), Vector2i(15, 21), Vector2i(12, 25)]:
		img.set_pixel(ox + p.x, p.y, Color8(230, 200, 255))


# ---------------- Монстры катакомб и второй босс ----------------

const BLANK := "................"

var BAT_UP := [
	BLANK, BLANK, BLANK, BLANK,
	"..kk........kk..",
	".kvVk......kVvk.",
	".kvvVk.kk.kVvvk.",
	"..kvvvkvvkvvvk..",
	"...kvvvrvrvvk...",
	"....kkvvvvkk....",
	"......kkkk......",
	BLANK, BLANK, BLANK, BLANK, BLANK,
]
var BAT_DOWN := [
	BLANK, BLANK, BLANK, BLANK, BLANK, BLANK,
	"......kkkk......",
	".....kvvvvk.....",
	"..kkkvrvrvkkk...",
	".kvVvvvvvvVvk...",
	"..kvk.kkkk.kvk..",
	"...k........k...",
	BLANK, BLANK, BLANK, BLANK,
]

var SKEL_TOP := [
	BLANK,
	"......kkkk......",
	".....kooook.....",
	"....kooooook....",
	"....kokookok....",
	"....kooooook....",
	".....kooook.....",
	"......kook......",
	"....kOoOoOk.....",
	"...kokOoOoOkok..",
	"...ko.kOoOk.ok..",
	"...k..kOOOk..k..",
]
var SKEL_LEGS_A := ["......ko.ok.....", "......ko.ok.....", ".....kok.kok....", BLANK]
var SKEL_LEGS_B := [".....ko...ok....", ".....ko...ok....", "....kok...kok...", BLANK]

var MUSH := [
	BLANK, BLANK, BLANK,
	"......kkkk......",
	"....kkccwckk....",
	"...kcwccccwck...",
	"..kcccwccccwck..",
	"..kcccccccccck..",
	"..kkkkkkkkkkkk..",
	".....kTTTTk.....",
	".....kTkkTk.....",
	".....kTTTTk.....",
	"....kTTTTTTk....",
	"....kkkkkkkk....",
	BLANK, BLANK,
]

var LICH := [
	BLANK,
	"......kkkk......",
	".....kuuuuk.....",
	"....kuUUUUuk....",
	"....kuoooouk....",
	"....kugoogUk....",
	"....kuoOOouk....",
	"...kuuuooouuk...",
	"..kuuUuuuuUuuk..",
	".kouuUuuuuUuuok.",
	".kokuUuuuuUukok.",
	"..kkuUuuuuUuk...",
	"...kuUuuuuUuk...",
	"...kuuuuuuuuk...",
	"...kkukkukkuk...",
	BLANK,
]

var CRYSTAL := [
	BLANK,
	".......kk.......",
	"......kPPk......",
	".....kPwPPk.....",
	".....kPwPPk.....",
	"....kPPwPPPk....",
	"....kPwPPPpk....",
	"....kPPPPppk....",
	".....kPPppk.....",
	".....kPppPk.....",
	"......kppk......",
	".....kOOOOk.....",
	"....kOOOOOOk....",
	"....kkkkkkkk....",
	BLANK, BLANK,
]


func _make_catacomb_monsters() -> void:
	var bat := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	_paint(bat, BAT_UP, 0, 0)
	_paint(bat, BAT_DOWN, 16, 0)
	_save(bat, "res://assets/bat.png")

	var skel := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	_paint(skel, SKEL_TOP + SKEL_LEGS_A, 0, 0)
	_paint(skel, SKEL_TOP + SKEL_LEGS_B, 16, 0)
	_save(skel, "res://assets/skeleton.png")

	var mush := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	_paint(mush, MUSH, 0, 0)
	# Кадр «выдох»: шляпка подпрыгивает на 1 px.
	var puff: Array = MUSH.duplicate()
	for y in range(2, 8):
		puff[y] = MUSH[y + 1]
	puff[8] = BLANK
	_paint(mush, puff, 16, 0)
	_save(mush, "res://assets/mushroom.png")

	var crystal := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_paint(crystal, CRYSTAL, 0, 0)
	_save(crystal, "res://assets/crystal.png")

	# Повелитель костей 32x32: лич 16x16, увеличенный вдвое.
	var small := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_paint(small, LICH, 0, 0)
	small.resize(32, 32, Image.INTERPOLATE_NEAREST)
	_save(small, "res://assets/bone_lord.png")


# ---------------- Крафт ----------------

# Иконки материалов 8x8 (mats.png 64x8): слизь, пыль, перепонка, кость, споры, руда, корона, филактерия.
var MATS := [
	["........", "...kk...", "..kgqk..", ".kgggk..", ".kgggdk.", ".kdddk..", "..kkk...", "........"],
	["...P....", "..kPk...", ".PwPPk..", "..kPk.P.", "...k.kPk", ".P...kk.", "kPk.....", ".k......"],
	["........", "k.......", "kvk.....", "kvVk....", "kvvVkk..", ".kvvvvk.", "..kkkkk.", "........"],
	["........", ".kk...kk", "kook.kook", ".kooooOk", "kooOooook", ".kk...kk", "........", "........"],
	["........", "..kkkk..", ".kcwcck.", "kccccwck", ".kkkkkk.", "..kTTk..", "..kkkk..", "........"],
	["........", "..kkkk..", ".kOOyOk.", "kOyOOOOk", "kOOOOyOk", ".kOOOOk.", "..kkkk..", "........"],
	["........", "........", "k.k.k.k.", "kykykyk.", "kyyGyyk.", "kyyyyyk.", "kkkkkkk.", "........"],
	["...kk...", "..kgqk..", ".kggggk.", ".kgGggk.", ".kggggk.", "..kggk..", "...kk...", "........"],
	# 8 сера, 9 обсидиан, 10 чешуя, 11 сердце пламени
	["........", "...kk...", "..kFFk..", ".kFYFFk.", "kFFFFYk.", ".kFFFFk.", "..kkkk..", "........"],
	["........", "....kk..", "...kjjk.", "..kjJjk.", ".kjjjjk.", "kjjJjk..", "kkkkk...", "........"],
	["........", "..kkkk..", ".kZZZZk.", "kZfZZfZk", "kZZZZZZk", ".kZZZZk.", "..kkkk..", "........"],
	["...kk...", "..kFfk..", ".kFffzk.", "kFffffzk", ".kffffk.", "..kzzk..", "...kk...", "........"],
]


func _make_crafting() -> void:
	var mats := Image.create(MATS.size() * 8, 8, false, Image.FORMAT_RGBA8)
	for i in MATS.size():
		var rows: Array = MATS[i]
		for y in rows.size():
			var r: String = rows[y]
			for x in mini(r.length(), 8):
				if r[x] != ".":
					mats.set_pixel(i * 8 + x, y, PAL[r[x]])
	_save(mats, "res://assets/mats.png")

	# Наковальня 16x16 на каменном постаменте.
	var anvil := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var iron := Color8(110, 112, 128)
	anvil.fill_rect(Rect2i(2, 5, 12, 3), iron.lightened(0.2))
	anvil.fill_rect(Rect2i(0, 5, 3, 2), iron.lightened(0.2))
	anvil.fill_rect(Rect2i(5, 8, 6, 3), iron)
	anvil.fill_rect(Rect2i(3, 11, 10, 2), iron.darkened(0.2))
	anvil.fill_rect(Rect2i(2, 13, 12, 2), Color8(90, 80, 70))
	anvil.set_pixel(6, 4, Color8(255, 170, 60))
	anvil.set_pixel(9, 3, Color8(255, 220, 120))
	_outline(anvil, Rect2i(0, 0, 16, 16), PAL["k"])
	_save(anvil, "res://assets/anvil.png")


# ---------------- Огненные пещеры ----------------

var IMP := [
	BLANK, BLANK,
	"...k........k...",
	"...kzk....kzk...",
	"....kzkkkkzk....",
	"....kzzzzzzk....",
	"...kzFzzzzFzk...",
	"...kzzzkkzzzk...",
	"....kzzzzzzk....",
	"..kzk.kzzk.kzk..",
	"..kfk.kzzk.kfk..",
	".....kzzzzk.....",
	".....kzkkzk.....",
	".....kk..kk.....",
	BLANK, BLANK,
]

var SALAMANDER := [
	BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK,
	"..........kZZk..",
	".kkk.....kZZFZk.",
	"kZZZkkkkkZZZZZk.",
	".kkZZfZfZZZZkk..",
	"...kZkkkkkZk....",
	"...kk.....kk....",
	BLANK, BLANK, BLANK,
]

var GOLEM := [
	BLANK,
	"....kkkkkkkk....",
	"...kjjjjjjjjk...",
	"...kjJjjjjJjk...",
	"...kjfjjjjfjk...",
	"..kkjjjzzjjjkk..",
	".kjjkjjjjjjkjjk.",
	".kjJkjjZZjjkJjk.",
	".kjjkjjjjjjkjjk.",
	".kkk.kjjjjk.kkk.",
	".....kjjjjk.....",
	"....kjjkkjjk....",
	"....kjjk.kjjk...",
	"...kkkk..kkkk...",
	BLANK, BLANK,
]

var TITAN := [
	"......F..F......",
	".....FfF.FfF....",
	"....kfffffffk...",
	"...kzzzzzzzzzk..",
	"...kzFFzzzFFzk..",
	"...kzzzzzzzzzk..",
	"..kkzzkkkkkzzkk.",
	".kzzkzzZZZzzkzzk",
	".kzfkzZZFZZzkfzk",
	".kzzkzzZZZzzkzzk",
	".kkk.kzzzzzk.kkk",
	".....kzzkzzk....",
	"....kzzk.kzzk...",
	"....kkkk.kkkk...",
	BLANK, BLANK,
]


func _make_fire_monsters() -> void:
	var imp := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	_paint(imp, IMP, 0, 0)
	var imp2: Array = IMP.duplicate()
	imp2[10] = "..kFk.kzzk.kFk.."
	imp2[2] = BLANK
	imp2[3] = "...k........k..."
	_paint(imp, imp2, 16, 0)
	_save(imp, "res://assets/imp.png")

	var sal := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	_paint(sal, SALAMANDER, 0, 0)
	var sal2: Array = SALAMANDER.duplicate()
	sal2[11] = "....kZkkkZk....."
	sal2[12] = "....kk...kk....."
	_paint(sal, sal2, 16, 0)
	_save(sal, "res://assets/salamander.png")

	var golem := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	_paint(golem, GOLEM, 0, 0)
	var golem2: Array = GOLEM.duplicate()
	golem2[12] = "...kjjk..kjjk..."
	golem2[13] = "..kkkk....kkkk.."
	_paint(golem, golem2, 16, 0)
	_save(golem, "res://assets/golem.png")

	var small := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_paint(small, TITAN, 0, 0)
	small.resize(32, 32, Image.INTERPOLATE_NEAREST)
	_save(small, "res://assets/ember_titan.png")


# Иконки 12x12 новых предметов. Номер иконки = 11 + индекс здесь:
# 11 баклер, 12 башенный щит, 13 колчан, 14 гримуар, 15 кожаная шапка, 16 железный шлем,
# 17 венец, 18 плащ, 19 мантия, 20 сапоги, 21 латные сапоги, 22 перстень, 23 талисман,
# 24 двуручный топор, 25 булава, 26 охотничий лук, 27 арбалет, 28 посох стихий, 29 книга мудреца.
const B12 := "............"
var ICONS2 := [
	[B12, "....kkkk....", "...kbbbbk...", "..kbbLLbbk..", "..kbLyyLbk..", "..kbLyyLbk..", "..kbbLLbbk..", "...kbbbbk...", "....kkkk....", B12, B12, B12],
	[".kkkkkkkkkk.", ".kmmmmmmmmk.", ".kmMMyyMMmk.", ".kmMMyyMMmk.", ".kmyyyyyymk.", ".kmMMyyMMmk.", ".kmMMyyMMmk.", "..kmmmmmmk..", "...kmmmmk...", "....kkkk....", B12, B12],
	["...k.k.k....", "...w.w.w....", "..kkkkkkk...", "..kLLLLLk...", "..kLbbbLk...", "..kLLLLLk...", "..kLbbbLk...", "..kLLLLLk...", "..kLLLLLk...", "...kkkkk....", B12, B12],
	[B12, "..kkkkkkkk..", "..kuUUUUUk..", "..kuUyyUUk..", "..kuUyyUUk..", "..kuUUUUUk..", "..kuUUUUUk..", "..kuwwwwwk..", "..kkkkkkkk..", B12, B12, B12],
	[B12, B12, "....kkkk....", "...kLLLLk...", "..kLLLLLLk..", "..kLLLLLLk..", ".kkkkkkkkkk.", ".kbbbbbbbbk.", ".kkkkkkkkkk.", B12, B12, B12],
	["....kkkk....", "...kmmmmk...", "..kmmMmmmk..", "..kmMmmmmk..", "..kmmmmmmk..", "..kmkkkkmk..", "..kmk..kmk..", "..kkk..kkk..", B12, B12, B12, B12],
	[B12, B12, B12, ".....kGk....", "kkkkkyGykkkk", "kyyyyyyyyyyk", "kkkkkkkkkkkk", B12, B12, B12, B12, B12],
	["...kkkkkk...", "..krrrrrrk..", "..krRrrrrk..", ".krrrrrrrrk.", ".krRrrrrrrk.", ".krrrrrrrrk.", "krrrrrrrrrrk", "krrrrrrrrrrk", "kkkkkkkkkkkk", B12, B12, B12],
	["...kkkkkk...", "..kuuuuuuk..", "..kuUuuuuk..", ".kuuuuuuuuk.", ".kuUuuuuuuk.", ".kuuuuuuuuk.", "kuuuuuuuuuuk", "kuuuuuuuuuuk", "kkkkkkkkkkkk", B12, B12, B12],
	[B12, B12, B12, "..kkk..kkk..", "..kLk..kLk..", "..kLk..kLk..", "..kLkk.kLkk.", "..kLLLkkLLLk", "..kkkkkkkkkk", B12, B12, B12],
	[B12, B12, "..kkk..kkk..", "..kmk..kmk..", "..kMk..kMk..", "..kmk..kmk..", "..kmkk.kmkk.", "..kmmmkkmmmk", "..kkkkkkkkkk", B12, B12, B12],
	[B12, ".....kk.....", "....krrk....", "....kkkk....", "...kyyyyk...", "..kyk..kyk..", "..kyk..kyk..", "..kyk..kyk..", "...kyyyyk...", "....kkkk....", B12, B12],
	[B12, "....kkkk....", "...kyyyyk...", "..kyOOOOyk..", "..kyOrrOyk..", "..kyOrrOyk..", "..kyOOOOyk..", "...kyyyyk...", "....kkkk....", B12, B12, B12],
	["kkk......kkk", "kmmk....kmmk", "kmmmkbbkmmmk", "kmmmmbbmmmmk", "kmmmkbbkmmmk", "kmmk.bb.kmmk", "kkk..bb..kkk", ".....bb.....", ".....bb.....", ".....bb.....", ".....bb.....", ".....kk....."],
	["....kkkk....", "...kmMmMk...", "...kMmMmk...", "...kmMmMk...", "....kkkk....", ".....bb.....", ".....bb.....", ".....bb.....", ".....bb.....", ".....bb.....", "....kyyk....", ".....kk....."],
	["....kk......", "...kbk...w..", "..kbk....w..", "..kbk....w..", ".kgk.....w..", ".kbk.....w..", ".kbk.....w..", ".kgk.....w..", "..kbk....w..", "..kbk....w..", "...kbk...w..", "....kk......"],
	[B12, ".kkkkkkkkkk.", "kmmmmmmmmmmk", ".kkkkbbkkkk.", "....kbbk....", "....kbbk....", "....kbbk....", "....kbbk....", "....kbbk....", "...kkbbkk...", "...kbbbbk...", "...kkkkkk..."],
	["...kkk......", "..kfFfk.....", "..kFrFk.....", "..kfFfk.....", "...kbk......", "....kbk.....", ".....kbk....", "......kbk...", ".......kbk..", "........kbk.", ".........kk.", B12],
	[B12, "..kkkkkkkk..", "..kdgggggk..", "..kdgyyggk..", "..kdgyyggk..", "..kdgggggk..", "..kdgggggk..", "..kdwwwwwk..", "..kkkkkkkk..", B12, B12, B12],
	# 30 нож, 31 стилет, 32 тесак, 33 катар, 34 посох послушника, 35 чётки, 36 посох света, 37 кастеты.
	[B12, "........kk..", ".......kmk..", "......kmMk..", ".....kmMk...", "....kmMk....", "...kmMk.....", "..kbkk......", ".kbbk.......", "kbbk........", "kkk.........", B12],
	["..........k.", ".........kmk", "........kMk.", ".......kmk..", "......kMk...", ".....kmk....", "...kykk.....", "....kbk.....", "...kbk......", "..kbk.......", "..kk........", B12],
	[B12, ".kkkkkkk....", ".kmmmmmmk...", ".kmMMMMmk...", ".kmmmmmmk...", ".kkkkmmmk...", "....kbbk....", "....kbbk....", "....kbbk....", "....kbbk....", "....kkkk....", B12],
	[".....kk.....", "....kmMk....", "....kmMk....", "....kmMk....", "....kmMk....", "...kkmMkk...", "..kyk..kyk..", "..kyk..kyk..", "..kykkkkyk..", "..kyybbyyk..", "..kkkkkkkk..", B12],
	[".....kk.....", "....kyyk....", "...kyyyyk...", "....kyyk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kk....."],
	[B12, "....kkkk....", "...kykkyk...", "..ky....yk..", "..k......k..", "..ky....yk..", "...kykkyk...", "....kkyk....", ".....kyk....", "....kyyyk...", ".....kkk....", B12],
	["....kkkk....", "...kwwwwk...", "...kwyywk...", "...kwwwwk...", "....kkkk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kbk....", ".....kk....."],
	[B12, B12, "..kkkkkkkk..", ".kmMkmMkmMk.", ".kmmkmmkmmk.", ".kkkkkkkkkk.", ".kmmmmmmmmk.", "..kkkkkkkk..", B12, B12, B12, B12],
]
