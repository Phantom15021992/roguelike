extends "res://tools/camp_art.gd"
## Спрайты лагеря для игры в утверждённом стиле (рисунки — tools/camp_art.gd, те же, что у
## превью tools/camp_preview.gd). Плотность 2: в игре спрайты уменьшены вдвое (LAY.ART = 2).
##   godot --headless --path . --script res://tools/gen_camp.gd
## Выход assets/camp/: ground.png (земля: трава, мостовая, пруд, лесная подстилка),
##   b_<постройка>.png, p_<мелочь>.png, camp.json (anchor — точка основания в пикселях картинки,
##   door — дверь относительно основания в пикселях мира, top — верх картинки, foot — ширина;
##   forest — деревья по краям [x, y мира, имя спрайта]).

const BUILDINGS := ["merchant", "portal", "mine", "training", "library", "forge", "infirmary", "treasury", "storage", "workshop", "exchange", "mentor"]
const TREE_KINDS := ["oak", "birch", "pine", "fruit", "autumn"]
const TREE_SIZES := [21, 24, 27]
const BUSH_KINDS := ["green", "flower", "berry", "dark"]

var meta := {"sprites": {}, "forest": []}
var errors := 0


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/camp")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png") or f.ends_with(".json") or f.ends_with(".import"):
			DirAccess.remove_absolute(dir + "/" + f)
	# Земля.
	setup(LAY.W * C, LAY.H * C, 0, 0)
	_ground()
	_out(img, "ground")
	# Постройки.
	for id: String in BUILDINGS:
		_sprite("b_" + id, 440, 380, Vector2i(220, 330), func(sx: int, sy: int) -> void: call("_b_" + id, sx, sy), true)
	# Мелочи.
	_sprite("p_fountain", 160, 120, Vector2i(80, 100), func(sx: int, sy: int) -> void: _fountain(sx, sy))
	_sprite("p_lamp", 40, 70, Vector2i(14, 62), func(sx: int, sy: int) -> void: _lamp(sx, sy))
	_sprite("p_bench", 60, 30, Vector2i(26, 24), func(sx: int, sy: int) -> void: _bench(sx - 19, sy))
	_sprite("p_signpost", 50, 50, Vector2i(24, 44), func(sx: int, sy: int) -> void: _signpost(sx, sy))
	for i in 3:
		_sprite("p_flowers_%d" % i, 40, 20, Vector2i(20, 12), func(sx: int, sy: int) -> void: _flowers(sx, sy, 11 + i * 7))
	for r: Array in [["s", 6], ["m", 8], ["l", 10]]:
		var sz: int = r[1]
		_sprite("p_rock_%s" % r[0], 50, 40, Vector2i(22, 32), func(sx: int, sy: int) -> void: _boulder_small(sx, sy, sz, sz * 13))
	for k: String in BUSH_KINDS:
		_sprite("p_bush_%s" % k, 60, 44, Vector2i(28, 36), func(sx: int, sy: int) -> void: _bush(sx, sy, 12, 40 + k.length(), k))
		_sprite("p_bushbig_%s" % k, 70, 50, Vector2i(32, 40), func(sx: int, sy: int) -> void: _bush(sx, sy, 14, 60 + k.length(), k))
	for k: String in TREE_KINDS:
		for i in TREE_SIZES.size():
			var s: int = TREE_SIZES[i]
			_sprite("p_tree_%s_%d" % [k, i], 120, 130, Vector2i(56, 118), func(sx: int, sy: int) -> void: _tree(sx, sy, s, 17 + i * 31 + k.length(), k))
	_sprite("p_lot", 220, 120, Vector2i(110, 104), func(sx: int, sy: int) -> void: _lot_overlay(sx, sy))
	_sprite("p_minedirt", 280, 120, Vector2i(0, 0), func(sx: int, sy: int) -> void: _mine_dirt(sx, sy))
	# Мягкое пятно света (свечение портала).
	var g := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var al := clampf(1.0 - d, 0.0, 1.0)
			g.set_pixel(x, y, Color(1, 1, 1, al * al))
	_out(g, "glow")
	_forest_list()
	var f := FileAccess.open("res://assets/camp/camp.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("gen_camp: done, errors=%d" % errors)
	quit(1 if errors else 0)


func _out(im: Image, name: String) -> void:
	if im.save_png(ProjectSettings.globalize_path("res://assets/camp/%s.png" % name)) != OK:
		push_error("cannot save " + name)
		errors += 1


## Нарисовать один спрайт: холст cw x ch, точка основания anchor; обрезка по рисунку.
func _sprite(name: String, cw: int, ch: int, anchor: Vector2i, f: Callable, building := false) -> void:
	setup(cw, ch, 0, 0)
	RP = ROOF
	last_door = Vector2(anchor)
	f.call(anchor.x, anchor.y)
	at(0, 0)
	RP = ROOF
	var used := img.get_used_rect()
	if used.size.x <= 0:
		push_error("empty sprite " + name)
		errors += 1
		return
	var out := img.get_region(used)
	_out(out, name)
	var a := Vector2(anchor) - Vector2(used.position)
	var info := {"anchor": [a.x, a.y]}
	if building:
		# Ширина стен у земли: самые левые/правые плотные пиксели чуть выше основания.
		var x0 := cw
		var x1 := 0
		for x in cw:
			var c := img.get_pixel(x, anchor.y - 6)
			if c.a > 0.95:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
		info["door"] = [(last_door.x - anchor.x) / LAY.ART, (last_door.y - anchor.y) / LAY.ART]
		info["top"] = float(used.position.y - anchor.y) / LAY.ART
		info["foot"] = [float(x1 - x0) / LAY.ART, 30.0, float((x0 + x1) / 2.0 - anchor.x) / LAY.ART]
	meta["sprites"][name] = info


## Пустой участок под стройку: утоптанная земля с разметкой клетками, колышки и верёвка.
func _lot_overlay(cx: int, base: int) -> void:
	var w := int(LAY.LOT_W * C)
	var d := int(LAY.LOT_DEPTH * C)
	var x0 := cx - w / 2
	var y0 := base - d
	for y in range(y0 - 2, base + 3):
		for x in range(x0 - 2, x0 + w + 3):
			var e := mini(mini(x - x0, x0 + w - x), mini(y - y0, base - y))
			var jag := int(nz.get_noise_2d(x * 3.0, y * 3.0) * 3.0)
			if e + jag < 0:
				continue
			var c := Color8(166, 136, 98) if hh(x / 3, y / 2, 80) > 200 else Color8(148, 118, 86)
			if hh(x, y, 81) < 24:
				c = Color8(192, 172, 138)
			elif hh(x, y, 82) < 30:
				c = Color8(118, 92, 68)
			if posmod(x - x0, C) == 0 or posmod(y - y0, C) == 0:
				c = c.lerp(Color8(226, 206, 162), 0.5)
			if e + jag < 2:
				c = GRASS[2]
			put(x, y, c)
	for p: Vector2i in [Vector2i(x0, y0), Vector2i(x0 + w, y0), Vector2i(x0, base), Vector2i(x0 + w, base)]:
		ground_shadow(p.x + 4, p.y, 5, 2, 0.3)
		bar(p.x - 2, p.y - 14, 4, 14, WOOD)
		bar(p.x - 3, p.y - 16, 6, 3, [Color8(222, 108, 90), Color8(190, 74, 64), Color8(150, 52, 50), Color8(110, 36, 40)])
	for pair: Array in [[Vector2(x0, y0), Vector2(x0 + w, y0)], [Vector2(x0, base), Vector2(x0 + w, base)], [Vector2(x0, y0), Vector2(x0, base)], [Vector2(x0 + w, y0), Vector2(x0 + w, base)]]:
		var a: Vector2 = pair[0]
		var b: Vector2 = pair[1]
		var n := int(a.distance_to(b))
		for i in n:
			var t := float(i) / n
			var p := a.lerp(b, t) + Vector2(0, -11 + sin(t * PI) * 3.0)
			put(int(p.x), int(p.y), Color8(236, 216, 168))
			put(int(p.x), int(p.y) + 1, Color8(150, 122, 86))


## Утоптанная земля у шахты (пока шахта не построена).
func _mine_dirt(x0: int, y0: int) -> void:
	var w := 8 * C
	var h := 3 * C
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var e := mini(mini(x - x0, x0 + w - x), mini(y - y0, y0 + h - y))
			var jag := int(nz.get_noise_2d(x * 2.0, y * 2.0) * 6.0)
			if e + jag < 4:
				continue
			var c := Color8(170, 142, 104) if hh(x / 3, y / 2, 80) > 160 else Color8(150, 122, 88)
			if hh(x, y, 81) < 20:
				c = Color8(196, 182, 152)
			put(x, y, c)


## Деревья по краям (как в превью): позиции и спрайты.
func _forest_list() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := ["oak", "pine", "oak", "birch", "pine", "oak", "autumn"]
	var step := 44
	var gw := LAY.W * C
	var gh := LAY.H * C
	for gy in range(-1, gh / 30 + 2):
		for gx in range(-1, gw / step + 2):
			var x := gx * step + (step / 2 if gy % 2 == 1 else 0) + rng.randi_range(-10, 10)
			var y := gy * 30 + rng.randi_range(-6, 6)
			var cx := x / float(C)
			var cy := y / float(C)
			if LAY.kind_at(cx, cy) != LAY.FOREST:
				continue
			var kind: String = kinds[rng.randi() % kinds.size()]
			var s := rng.randi_range(20, 27)
			var name := ""
			if cy > LAY.H - 3.2:
				name = "bushbig_%s" % ["green", "dark", "green", "berry"][rng.randi() % 4]
			else:
				name = "tree_%s_%d" % [kind, clampi((s - 20) / 3, 0, 2)]
			meta["forest"].append([x / float(LAY.ART), y / float(LAY.ART), name])
