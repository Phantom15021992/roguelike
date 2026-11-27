extends SceneTree
## Графика биомов в стиле новой пещеры (по референсам владельца):
## 2 — Огненные пещеры (лавовые глыбы), 3 — Ледяные (зимний набор), 4 — Ядовитые топи
## (грибы, зелень), 8 — Механическая кузня (стимпанк). Остальные биомы — пока старые плитки
## (референсов нет), первый биом — tools/gen_cave.gd.
## На каждый биом: assets/biome_floor_<b>.png (64x128: пол 4x4 клетки + скала 4x4, как cave_floor)
## и assets/biome_decor_<b>.png (192x16, кадры как у cave_decor: 0–2 большие светящиеся,
## 4 малые светящиеся, 6 трава, 7 камешки, 8 у края скалы, 9 светящееся в скале, 10 глыба, 11 искры).
##   godot --headless --path . --script res://tools/gen_biomes.gd

const Pix := preload("res://tools/pix.gd")

var d: Pix = Pix.new()


func _init() -> void:
	_floor(2, {"slabs": [Color8(112, 88, 78), Color8(124, 94, 78), Color8(100, 82, 80)], "seam": Color8(44, 26, 22),
		"glow_seam": Color8(255, 120, 30), "speck": Color8(255, 150, 60),
		"rock": [Color8(24, 16, 18), Color8(30, 18, 18), Color8(20, 16, 22)], "rock_seam": Color8(8, 4, 6), "rock_glow": Color8(230, 90, 20)})
	_floor(3, {"slabs": [Color8(150, 180, 215), Color8(170, 200, 230), Color8(130, 165, 205)], "seam": Color8(70, 100, 150),
		"snow": true, "speck": Color8(240, 250, 255),
		"rock": [Color8(30, 42, 76), Color8(36, 50, 88), Color8(26, 38, 70)], "rock_seam": Color8(12, 18, 36), "rock_snow": true})
	_floor(4, {"slabs": [Color8(108, 100, 64), Color8(120, 110, 68), Color8(96, 94, 66)], "seam": Color8(46, 44, 28),
		"puddles": true, "moss": true, "speck": Color8(150, 200, 90),
		"rock": [Color8(14, 24, 14), Color8(18, 30, 16), Color8(12, 20, 18)], "rock_seam": Color8(4, 8, 4), "rock_moss": true})
	_mech_floor(8)
	_decor_fire(2)
	_decor_ice(3)
	_decor_swamp(4)
	_decor_mech(8)
	print("gen_biomes: done")
	quit()


func _save(img: Image, path: String) -> void:
	img.save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)


# ---------------- Вороной на торе (как в gen_cave) ----------------

func _vor(p: Vector2, pts: Array, size: float) -> Array:
	var d1 := 1e9
	var d2 := 1e9
	var idx := 0
	var near := Vector2.ZERO
	for i in pts.size():
		var q: Vector2 = pts[i]
		for ox: float in [-size, 0.0, size]:
			for oy: float in [-size, 0.0, size]:
				var dd := p.distance_to(q + Vector2(ox, oy))
				if dd < d1:
					d2 = d1
					d1 = dd
					idx = i
					near = q + Vector2(ox, oy)
				elif dd < d2:
					d2 = dd
	return [d1, d2, idx, near]


func _pts(rng: RandomNumberGenerator, n: int, size: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2(rng.randf() * size, rng.randf() * size))
	return out


# ---------------- Пол и скала ----------------

func _floor(b: int, st: Dictionary) -> void:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + b
	var slabs: Array = st["slabs"]
	var pts := _pts(rng, 18, 64.0)
	var kind: Array = []
	for i in pts.size():
		kind.append(rng.randi_range(0, slabs.size() - 1))
	# Пятна снега / лужи — мягкие «капли» по тору.
	var blobs := _pts(rng, 5, 64.0)
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var r := _vor(p, pts, 64.0)
			var gap: float = r[1] - r[0]
			var to: Vector2 = p - (r[3] as Vector2)
			var c: Color = slabs[kind[r[2]]]
			var shade := clampf(-(to.x + to.y) / 22.0, -0.6, 0.6)
			c = c.lightened(maxf(0.0, shade) * 0.2).darkened(maxf(0.0, -shade) * 0.26)
			if gap < 0.9:
				c = st["seam"]
				if st.has("glow_seam") and int(r[2]) % 5 == 0:
					c = st["glow_seam"]
			elif gap < 1.9:
				c = c.darkened(0.22)
				if st.has("glow_seam") and int(r[2]) % 5 == 0:
					c = c.lerp(st["glow_seam"], 0.35)
			if gap > 3.0 and rng.randf() < 0.012:
				c = c.darkened(0.3)
			var bd: float = _vor(p, blobs, 64.0)[0]
			if st.get("snow", false) and bd < 6.0 + sin(x * 0.7) * 1.5:
				c = Color8(236, 244, 252).darkened(0.12 if bd > 4.5 else 0.0)
			if st.get("puddles", false) and bd < 5.0 + sin(y * 0.8) * 1.2:
				c = Color8(40, 64, 50).lightened(0.15 if bd < 1.5 else 0.0)
				if int(x + y) % 9 == 0:
					c = Color8(90, 130, 100)
			elif st.get("moss", false) and gap < 3.0 and int(r[2]) % 2 == 0:
				c = c.lerp(Color8(90, 140, 60), 0.5)
			img.set_pixel(x, y, c.lightened((rng.randf() - 0.5) * 0.05))
	for i in 18:
		img.set_pixel(rng.randi_range(0, 63), rng.randi_range(0, 63), st["speck"])
	_rock(img, rng, st)
	_save(img, "res://assets/biome_floor_%d.png" % b)


## Скала: груда валунов цвета биома (как в первом биоме), с лавой / снегом / мхом.
func _rock(img: Image, rng: RandomNumberGenerator, st: Dictionary) -> void:
	var cols: Array = st["rock"]
	var stones := _pts(rng, 17, 64.0)
	var kind: Array = []
	for i in stones.size():
		kind.append(rng.randi_range(0, cols.size() - 1))
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var r := _vor(p, stones, 64.0)
			var gap: float = r[1] - r[0]
			var to: Vector2 = p - (r[3] as Vector2)
			var rad: float = (r[0] + r[1]) * 0.5
			var dome := clampf(1.0 - r[0] / maxf(rad, 1.0), 0.0, 1.0)
			var lit := clampf(-(to.x + to.y * 1.3) / (rad * 1.6 + 0.01), -1.0, 1.0)
			var c: Color = cols[kind[r[2]]]
			c = c.lightened(dome * 0.07 + maxf(0.0, lit) * 0.16 * (0.4 + dome))
			c = c.darkened(maxf(0.0, -lit) * 0.4)
			if st.get("rock_snow", false) and lit > 0.6 and gap > 2.5:
				c = Color8(200, 214, 236).darkened(0.35 - lit * 0.2)
			if st.get("rock_moss", false) and lit > 0.25 and gap > 2.0 and int(r[2]) % 2 == 0:
				c = c.lerp(Color8(60, 110, 50), 0.6)
			if gap < 1.0:
				c = st["rock_seam"]
				if st.has("rock_glow") and int(r[2]) % 3 == 0:
					c = st["rock_glow"]
			elif gap < 2.2:
				c = c.darkened(0.45)
			img.set_pixel(x, 64 + y, c.lightened((rng.randf() - 0.5) * 0.04))


## Кузня: пол — клёпаные металлические плиты и решётки, «скала» — сплетение труб и механизмов.
func _mech_floor(b: int) -> void:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7008
	var iron := Color8(92, 90, 98)
	var brass := Color8(150, 112, 66)
	for y in 64:
		for x in 64:
			var px := x % 32
			var py := y % 32
			var plate := int(x / 32) + int(y / 32) * 2
			var c := iron if plate != 1 else brass
			if plate == 2 and px > 4 and px < 28 and py > 4 and py < 28:
				# Решётка.
				c = Color8(40, 38, 44) if (px % 4 == 0 or py % 4 == 0) else Color8(22, 20, 26)
				if (px % 4 == 0 and py % 4 == 0):
					c = Color8(70, 68, 76)
			else:
				var shade := (16.0 - px) / 32.0 * 0.12 + (16.0 - py) / 32.0 * 0.12
				c = c.lightened(maxf(0.0, shade)).darkened(maxf(0.0, -shade))
				if px == 0 or py == 0:
					c = Color8(30, 28, 34)
				elif px == 1 or py == 1:
					c = c.lightened(0.18)
				elif px == 31 or py == 31:
					c = c.darkened(0.3)
				if (px == 4 or px == 27) and (py == 4 or py == 27):
					c = c.lightened(0.4)
				if (px == 5 or px == 28) and (py == 5 or py == 28):
					c = c.darkened(0.4)
			img.set_pixel(x, y, c.lightened((rng.randf() - 0.5) * 0.04))
	# «Скала»: тёмная масса механизмов — горизонтальные и вертикальные трубы, шестерни.
	for y in 64:
		for x in 64:
			img.set_pixel(x, 64 + y, Color8(14, 12, 16).lightened((rng.randf() - 0.5) * 0.04))
	var pipe := Color8(44, 42, 48)
	for py2: int in [10, 40]:
		for x in 64:
			for t in 6:
				var c := pipe.lightened(0.15 - t * 0.06)
				img.set_pixel(x, 64 + py2 + t, c)
		for x in range(0, 64, 16):
			for t in 6:
				img.set_pixel(x, 64 + py2 + t, Color8(74, 58, 36))
	for px2: int in [24, 54]:
		for y in 64:
			for t in 5:
				img.set_pixel(px2 + t, 64 + y, Color8(66, 48, 30).lightened(0.12 - t * 0.05))
	for g: Vector2 in [Vector2(10, 28), Vector2(42, 56)]:
		for y in range(-8, 9):
			for x in range(-8, 9):
				var rr := Vector2(x, y).length()
				var a := atan2(y, x)
				var tooth := 6.5 + (1.5 if int(round(a / (TAU / 10.0))) % 2 == 0 else 0.0)
				if rr <= tooth:
					var c := Color8(58, 48, 34).lightened(clampf(-(x + y) / 20.0, -0.2, 0.2))
					if rr < 2.0:
						c = Color8(40, 36, 30)
					img.set_pixel(posmod(int(g.x) + x, 64), 64 + posmod(int(g.y) + y, 64), c)
	_save(img, "res://assets/biome_floor_%d.png" % b)


# ---------------- Украшения ----------------

func _decor_begin() -> Image:
	return Image.create(192, 16, false, Image.FORMAT_RGBA8)


## Нарисовать кадр f кисточкой (кадр 16x16, координаты как есть).
func _frame(sheet: Image, f: int, draw: Callable) -> void:
	d.begin(16)
	d.k = 1.0
	draw.call()
	d.outline()
	sheet.blit_rect(d.img, Rect2i(0, 0, 16, 16), Vector2i(f * 16, 0))


func _crystals(c: Color, n: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in n:
		var base := Vector2(5 + i * 2.5 + rng.randf(), 15)
		var ang := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.4
		var length := rng.randf_range(7.0, 12.0) - absf(i - (n - 1) / 2.0) * 2.0
		var tip := base + Vector2.from_angle(ang) * length
		var side := Vector2.from_angle(ang).orthogonal() * 1.6
		d.spoly(PackedVector2Array([base - side, tip, base + side]), Pix.pal(c.lightened(0.1 * (i % 2))))
		d.line(base, tip, c.lightened(0.55))


func _decor_fire(b: int) -> void:
	var s := _decor_begin()
	for f in 3:
		_frame(s, f, func() -> void: _crystals(Color8(255, 120, 40), 2 + f, 300 + f))
	_frame(s, 4, func() -> void:
		d.poly(PackedVector2Array([Vector2(5, 15), Vector2(7, 6), Vector2(8, 10), Vector2(10, 4), Vector2(11, 15)]), Color8(255, 140, 40))
		d.poly(PackedVector2Array([Vector2(7, 15), Vector2(8.5, 9), Vector2(10, 15)]), Color8(255, 230, 120)))
	_frame(s, 6, func() -> void:
		for i in 6:
			d.line(Vector2(3 + i * 2, 15), Vector2(2 + i * 2.2, 8 + (i % 3)), [Color8(200, 70, 40), Color8(230, 120, 50), Color8(160, 50, 40)][i % 3]))
	_frame(s, 7, func() -> void:
		for v: Vector2 in [Vector2(4, 12), Vector2(9, 13), Vector2(12, 10)]:
			d.ball(v.x, v.y, 1.6, 1.2, Pix.pal(Color8(70, 60, 64))))
	_frame(s, 8, func() -> void:
		for sp: Array in [[5, 13, 3], [10, 9, 2], [13, 6, 1.5]]:
			d.spoly(PackedVector2Array([Vector2(sp[0] - sp[2], 15), Vector2(sp[0], 15 - sp[1]), Vector2(sp[0] + sp[2], 15)]), Pix.pal(Color8(40, 30, 44))))
	_frame(s, 9, func() -> void:
		d.ell(8, 12, 5, 2.5, Color8(60, 20, 10))
		d.ell(8, 12, 3.5, 1.6, Color8(255, 110, 30))
		d.ell(7, 11.5, 1.5, 0.8, Color8(255, 220, 120)))
	_frame(s, 10, func() -> void:
		d.ball(8, 9, 6.5, 5.5, Pix.pal(Color8(50, 34, 34)))
		d.line(Vector2(5, 7), Vector2(8, 11), Color8(255, 110, 30))
		d.line(Vector2(8, 11), Vector2(11, 9), Color8(255, 110, 30)))
	_frame(s, 11, func() -> void:
		for v: Vector2 in [Vector2(3, 4), Vector2(11, 7), Vector2(6, 12), Vector2(13, 13)]:
			d.px(v.x, v.y, Color8(255, 170, 60)))
	_save(s, "res://assets/biome_decor_%d.png" % b)


func _decor_ice(b: int) -> void:
	var s := _decor_begin()
	for f in 3:
		_frame(s, f, func() -> void: _crystals(Color8(150, 230, 255), 2 + f, 400 + f))
	_frame(s, 4, func() -> void:
		for a in 6:
			var v := Vector2.from_angle(TAU * a / 6.0)
			d.line(Vector2(8, 9), Vector2(8, 9) + v * 4.5, Color8(170, 230, 255))
		d.ell(8, 9, 1.5, 1.5, Color8(240, 252, 255)))
	_frame(s, 6, func() -> void:
		d.ball(8, 11, 6, 4.5, Pix.pal(Color8(90, 140, 150)))
		d.ell(8, 8.5, 5, 2.5, Color8(240, 248, 255))
		d.ell(6, 8, 2, 1, Color8(255, 255, 255)))
	_frame(s, 7, func() -> void:
		for v: Vector2 in [Vector2(4, 12), Vector2(9, 13), Vector2(12, 10)]:
			d.ball(v.x, v.y, 1.6, 1.2, Pix.pal(Color8(190, 225, 245))))
	_frame(s, 8, func() -> void:
		for sp: Array in [[5, 12, 2.5], [10, 9, 2], [13, 6, 1.5]]:
			d.spoly(PackedVector2Array([Vector2(sp[0] - sp[2], 15), Vector2(sp[0], 15 - sp[1]), Vector2(sp[0] + sp[2], 15)]), Pix.pal(Color8(170, 215, 245))))
	_frame(s, 9, func() -> void: _crystals(Color8(120, 200, 255), 3, 499))
	_frame(s, 10, func() -> void:
		d.ball(8, 9.5, 6.5, 5, Pix.pal(Color8(70, 90, 130)))
		d.ell(7, 6.5, 5, 2.5, Color8(236, 244, 252)))
	_frame(s, 11, func() -> void:
		for v: Vector2 in [Vector2(3, 4), Vector2(11, 7), Vector2(6, 12), Vector2(13, 13)]:
			d.px(v.x, v.y, Color8(240, 250, 255))
			d.px(v.x + 1, v.y, Color8(160, 210, 240)))
	_save(s, "res://assets/biome_decor_%d.png" % b)


func _shroom_cluster(cap: Color, n: int, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in n:
		var x := 4.0 + i * (8.0 / maxf(1, n - 1)) + rng.randf_range(-0.5, 0.5)
		var h := rng.randf_range(5.0, 9.0) - absf(i - (n - 1) / 2.0) * 1.5
		d.rect(x - 0.5, 15 - h, 1.5, h, Color8(220, 220, 200))
		d.ball(x + 0.2, 15 - h, 2.6 - absf(i - (n - 1) / 2.0) * 0.3, 1.7, Pix.pal(cap))


func _decor_swamp(b: int) -> void:
	var s := _decor_begin()
	var caps: Array = [Color8(120, 240, 160), Color8(110, 220, 230), Color8(170, 250, 120)]
	for f in 3:
		_frame(s, f, func() -> void: _shroom_cluster(caps[f], 2 + f, 500 + f))
	_frame(s, 4, func() -> void: _shroom_cluster(Color8(240, 220, 90), 2, 540))
	_frame(s, 6, func() -> void:
		for i in 5:
			var x := 3 + i * 2.5
			d.line(Vector2(x, 15), Vector2(x + (i % 2), 4 + (i % 3) * 2), Color8(90, 130, 60))
			if i % 2 == 0:
				d.rect(x - 0.5 + (i % 2), 4 + (i % 3) * 2, 1.5, 3, Color8(120, 80, 40)))
	_frame(s, 7, func() -> void:
		d.ell(8, 12, 5, 2.5, Color8(70, 140, 70))
		d.ell(8, 12, 1.5, 2.5, Color8(40, 64, 50))
		d.px(10, 11, Color8(240, 150, 200)))
	_frame(s, 8, func() -> void:
		d.spoly(PackedVector2Array([Vector2(5, 15), Vector2(6, 6), Vector2(10, 6), Vector2(11, 15)]), Pix.pal(Color8(80, 64, 48)))
		d.line(Vector2(6, 7), Vector2(3, 3), Color8(70, 56, 42))
		d.line(Vector2(10, 7), Vector2(13, 2), Color8(70, 56, 42))
		d.ell(8, 6, 2.5, 1, Color8(60, 48, 36)))
	_frame(s, 9, func() -> void: _shroom_cluster(Color8(90, 230, 150), 3, 590))
	_frame(s, 10, func() -> void:
		d.ball(8, 9.5, 6.5, 5, Pix.pal(Color8(50, 66, 46)))
		d.ell(6, 7, 4, 2, Color8(80, 140, 60)))
	_frame(s, 11, func() -> void:
		for v: Vector2 in [Vector2(3, 4), Vector2(11, 7), Vector2(6, 12), Vector2(13, 13)]:
			d.px(v.x, v.y, Color8(220, 255, 120)))
	_save(s, "res://assets/biome_decor_%d.png" % b)


func _decor_mech(b: int) -> void:
	var s := _decor_begin()
	# 0: котёл с топкой, 1: фонарь на столбе, 2: катушка с искрой.
	_frame(s, 0, func() -> void:
		d.rect(10, 1, 2, 5, Color8(90, 80, 70))
		d.spoly(PackedVector2Array([Vector2(3, 5), Vector2(13, 5), Vector2(13, 15), Vector2(3, 15)]), Pix.pal(Color8(180, 120, 60)))
		d.rect(3, 9, 10, 1, Color8(120, 80, 40))
		d.ell(8, 12, 2.5, 1.8, Color8(255, 140, 40))
		d.ell(6, 7, 1.4, 1.4, Color8(230, 230, 210)))
	_frame(s, 1, func() -> void:
		d.rect(7.5, 5, 1.5, 10, Color8(70, 70, 80))
		d.rect(5.5, 14, 5.5, 1.5, Color8(70, 70, 80))
		d.spoly(PackedVector2Array([Vector2(5, 1), Vector2(11, 1), Vector2(10, 6), Vector2(6, 6)]), Pix.pal(Color8(140, 110, 60)))
		d.rect(6.5, 2.5, 3, 2.5, Color8(255, 220, 120)))
	_frame(s, 2, func() -> void:
		d.rect(6, 6, 4, 9, Color8(150, 100, 50))
		for y in range(6, 15, 2):
			d.rect(5.5, y, 5, 1, Color8(200, 140, 70))
		d.ell(8, 4, 2.5, 2.5, Color8(160, 220, 255))
		d.px(4, 2, Color8(200, 240, 255))
		d.px(12, 3, Color8(200, 240, 255)))
	_frame(s, 4, func() -> void:
		d.ball(8, 10, 4, 4, Pix.pal(Color8(170, 140, 80)))
		d.ell(8, 10, 2.8, 2.8, Color8(240, 235, 210))
		d.line(Vector2(8, 10), Vector2(10, 8), Color8(200, 40, 40)))
	_frame(s, 6, func() -> void:
		for v: Vector2 in [Vector2(4, 12), Vector2(11, 13)]:
			d.ell(v.x, v.y, 1.5, 1.0, Color8(130, 130, 140))
			d.px(v.x, v.y, Color8(60, 60, 70)))
	_frame(s, 7, func() -> void:
		for v: Vector2 in [Vector2(5, 11), Vector2(11, 12)]:
			d.ball(v.x, v.y, 2.6, 2.6, Pix.pal(Color8(150, 120, 70)))
			d.ell(v.x, v.y, 0.8, 0.8, Color8(50, 40, 30)))
	_frame(s, 8, func() -> void:
		d.rect(5, 4, 6, 11, Color8(80, 76, 84))
		d.rect(4, 4, 8, 2, Color8(120, 110, 100))
		d.rect(5, 9, 6, 1, Color8(150, 110, 60)))
	_frame(s, 9, func() -> void:
		d.rect(3, 8, 10, 6, Color8(50, 46, 50))
		for x in range(4, 13, 2):
			d.rect(x, 9, 1, 4, Color8(255, 130, 40)))
	_frame(s, 10, func() -> void:
		d.spoly(PackedVector2Array([Vector2(3, 4), Vector2(13, 4), Vector2(13, 15), Vector2(3, 15)]), Pix.pal(Color8(140, 100, 60)))
		d.line(Vector2(3, 4), Vector2(13, 15), Color8(100, 70, 40))
		d.line(Vector2(13, 4), Vector2(3, 15), Color8(100, 70, 40)))
	_frame(s, 11, func() -> void:
		for v: Vector2 in [Vector2(3, 4), Vector2(11, 7), Vector2(6, 12), Vector2(13, 13)]:
			d.px(v.x, v.y, Color8(255, 210, 120)))
	_save(s, "res://assets/biome_decor_%d.png" % b)
