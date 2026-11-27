extends "res://tools/dungeon_art.gd"
## Графика первого биома подземелья для игры (утверждённый стиль, 2 пикселя картинки = 1 мира).
##   godot --headless --path . --script res://tools/gen_dungeon.gd   (затем --import)
## Выход (assets/dng/):
##   floor0.png  128x128 — бесшовные плиты пола (4x4 клетки);
##   rock0.png   128x128 — бесшовный верх скалы (глыбы); края скал и тени рисует
##               shaders/cave_art.gdshader по карте этажа;
##   decor0.png  384x32 — украшения по 32 px (номера те же, что у cave_decor):
##               0–2 кристаллы, 3 трутовики, 4 светящиеся грибочки, 5 корни, 6 камешки, 7 кости,
##               8 трутовики на скале у края, 9 кристаллы в породе, 10 мох на скале, 11 корни на скале;
##   stairs0.png — лестница вниз; pillar0_<w>x<h>.png — колонны по размеру в клетках;
## assets/mon2/<монстр>.png — листы монстров (кадр 48: ряды вниз/вбок/вверх; столбцы — кадры
##   семейства + 5 поз: урон, замах, удар, смерть ×2), рисуются в игре с масштабом 0.5.

const OUTDIR := "res://assets/dng/"
const MONDIR := "res://assets/mon2/"
var gallery: Array = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTDIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MONDIR))
	_floor()
	_rock()
	_decor()
	_stairs()
	_pillars()
	_monsters()
	print("gen_dungeon: done")
	quit()


func save_to(path: String) -> void:
	img.save_png(ProjectSettings.globalize_path(path))


func _floor() -> void:
	SLAB_G = 16.0
	SLAB_N = 8
	setup(128, 128)
	for y in 128:
		for x in 128:
			put(x, y, slab(x, y))
	save_to(OUTDIR + "floor0.png")


func _rock() -> void:
	ROCK_G = 25.6
	ROCK_N = 5
	setup(128, 128)
	for y in 128:
		for x in 128:
			put(x, y, rock_top(x, y))
	save_to(OUTDIR + "rock0.png")


func _decor() -> void:
	setup(384, 32)
	var f := func(i: int) -> int: return i * 32 + 16
	crystals(f.call(0), 30, 6.0, 3, false)
	crystals(f.call(1), 30, 7.0, 4, false)
	crystals(f.call(2), 30, 8.0, 5, false)
	tinder(f.call(3), 12, 3)
	shrooms(f.call(4), 28, 1)
	root(f.call(5) - 8, 2, 26, 0.5, 3)
	pebble(f.call(6) - 6, 20, 3, 1)
	pebble(f.call(6) + 4, 24, 2, 2)
	pebble(f.call(6) + 1, 14, 2, 3)
	pebble(f.call(7) - 3, 22, 4, 5)
	pebble(f.call(7) + 6, 17, 2, 6)
	tuft_floor(f.call(7) + 3, 27)
	tinder(f.call(8), 14, 2)
	crystals(f.call(9), 28, 5.0, 6, false)
	# Мох на скале: несколько неровных клочков.
	for m: Vector3i in [Vector3i(-7, 12, 5), Vector3i(4, 18, 6), Vector3i(-2, 24, 4), Vector3i(8, 9, 3)]:
		var moss := {}
		for y in range(-m.z, m.z + 1):
			for x in range(-m.z - 2, m.z + 3):
				var n := nz.get_noise_2d((x + m.x) * 4.0, (y + m.y) * 4.0) * 0.5
				if float(x * x) / ((m.z + 2) * (m.z + 2)) + float(y * y) / (m.z * m.z * 0.5) < 1.0 + n:
					moss[Vector2i(f.call(10) + m.x + x, m.y + y)] = MOSS[1] if y < 0 else MOSS[2]
		blit(moss, MOSS[2].darkened(0.55))
	root(f.call(11) - 10, 6, 24, 1.4, 9)
	save_to(OUTDIR + "decor0.png")


func _stairs() -> void:
	setup(64, 64)
	stairs(10, 14, 44, 36)
	save_to(OUTDIR + "stairs0.png")


## Колонны: ширина 1–3 клетки, глубина 1–3. Низ картинки — нижний край колонны.
func _pillars() -> void:
	for w in range(1, 4):
		for h in range(1, 4):
			var r := w * 16 - 3
			var cap := 5 + h * 7
			var fh := 26
			var cw := w * 32 + 24
			var ch := fh + cap * 2 + 26
			setup(cw, ch)
			pillar(cw / 2, ch - 4, r, fh, cap, w >= 2 or h >= 2)
			save_to(OUTDIR + "pillar0_%dx%d.png" % [w, h])


# ---------------- Монстры ----------------

func _monsters() -> void:
	var fsz := 48
	for kind: String in MONSTERS:
		var frames: int = MONSTERS[kind]
		var sheet := Image.create((frames + 5) * fsz, fsz * 3, false, Image.FORMAT_RGBA8)
		for row in 3:
			var first: Image
			for col in frames:
				setup(fsz, fsz)
				monster(kind, fsz / 2, fsz - 3, row, col)
				if col == 0:
					first = img.duplicate()
				sheet.blit_rect(img, Rect2i(0, 0, fsz, fsz), Vector2i(col * fsz, row * fsz))
			var fw: Vector2 = [Vector2(0, 1.0), Vector2(2.0, 0), Vector2(0, -1.6)][row]
			var poses: Array = [
				_xf(first, 1.08, 0.9, -fw * 1.5, Color(1.0, 0.25, 0.2), 0.3, 1.0),
				_xf(first, 1.12, 0.86, -fw * 1.0, Color.WHITE, 0.0, 1.0),
				_xf(first, 0.94, 1.06, fw * 2.0, Color(1, 1, 0.9), 0.15, 1.0),
				_xf(first, 1.2, 0.62, Vector2.ZERO, Color(0.1, 0.05, 0.12), 0.35, 1.0),
				_xf(first, 1.35, 0.32, Vector2.ZERO, Color(0.1, 0.05, 0.12), 0.55, 0.75),
			]
			for i in 5:
				sheet.blit_rect(poses[i], Rect2i(0, 0, fsz, fsz), Vector2i((frames + i) * fsz, row * fsz))
		sheet.save_png(ProjectSettings.globalize_path(MONDIR + kind + ".png"))
		gallery.append(sheet)
	# Галерея для просмотра: все листы друг под другом, ×2.
	var gw := 0
	var gh := 0
	for s: Image in gallery:
		gw = maxi(gw, s.get_width())
		gh += s.get_height()
	var g := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	g.fill(Color8(110, 108, 126))
	var y := 0
	for s: Image in gallery:
		g.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(0, y))
		y += s.get_height()
	g.resize(gw * 2, gh * 2, Image.INTERPOLATE_NEAREST)
	g.save_png(ProjectSettings.globalize_path("res://shots/dungeon_mon_sheets.png"))


## Пучок травинок на полу (в шве у плиты).
func tuft_floor(cx: int, base: int) -> void:
	var pix := {}
	for i in 5:
		var x := cx - 4 + i * 2
		var h := 3 + (i * 7) % 4
		for y in h:
			pix[Vector2i(x + (1 if y > h / 2 and i % 2 == 0 else 0), base - y)] = MOSS[0] if y >= h - 1 else MOSS[1]
	blit(pix, MOSS[2].darkened(0.5))


## Поза из первого кадра: сжатие/растяжение от низа, сдвиг, подкраска (как в gen_monsters.gd).
func _xf(src: Image, sx: float, sy: float, off: Vector2, tnt: Color, ta: float, alpha: float) -> Image:
	var size := src.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	if used.size == Vector2i.ZERO:
		return out
	var cx := used.position.x + used.size.x / 2.0
	var by := float(used.end.y)
	for yy in size:
		for xx in size:
			var u := int(floor((xx + 0.5 - cx - off.x) / sx + cx))
			var v := int(floor((yy + 0.5 - by - off.y) / sy + by))
			if u < 0 or v < 0 or u >= size or v >= size:
				continue
			var c := src.get_pixel(u, v)
			if c.a <= 0.0:
				continue
			var a := c.a * alpha
			c = c.lerp(tnt, ta)
			c.a = a
			out.set_pixel(xx, yy, c)
	return out
