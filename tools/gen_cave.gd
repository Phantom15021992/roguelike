extends SceneTree
## Графика «кристальной пещеры» (первый биом) в новом стиле — по референсам владельца:
## сине-фиолетовый камень плитами, тёмные скалы с холодной подсветкой краёв, светящиеся
## голубые кристаллы, оранжевые грибы-трутовики, корни, трава. Плюс герой-мечник в стиле
## «чиби» с 8 сторон (5 нарисованных + зеркальные).
##
##   godot --headless --path . --script res://tools/gen_cave.gd
## Выход: assets/cave_tiles.png (как tiles.png: 3 пола, верх стены, стена, лестница),
##        assets/cave_decor.png (украшения 16x16), assets/light.png (пятно света),
##        assets/hero8_warrior.png (24x24, строки: вниз, вниз-вбок, вбок, вверх-вбок, вверх; 4 кадра).

var errors := 0

# Палитра (по референсам 1, 2, 5).
const DEEP := Color8(20, 19, 38)
const ROCK_D := Color8(22, 21, 40)
const ROCK_M := Color8(58, 61, 96)
const ROCK_L := Color8(90, 97, 140)
const RIM := Color8(140, 160, 214)
const GAP := Color8(34, 33, 56)
const SLAB := Color8(84, 88, 128)
const CYAN := Color8(110, 225, 255)
const CYAN_HI := Color8(214, 248, 255)
const TEAL := Color8(52, 130, 140)
const ORANGE := Color8(226, 120, 40)
const ORANGE_HI := Color8(255, 186, 90)
const OUTLINE := Color8(18, 16, 30)


func _init() -> void:
	_tiles()
	_big_floor()
	_decor()
	_light()
	_hero()
	print("gen_cave: done, errors=%d" % errors)
	quit(1 if errors else 0)


func _save(img: Image, path: String) -> void:
	if img.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("cannot save " + path)
		errors += 1
	else:
		print("saved ", path)


# ---------------- Вороной на торе (бесшовные плиты и глыбы) ----------------

## Для пикселя p: [расстояние до ближайшей точки, до второй, индекс ближайшей, сама ближайшая точка
## с учётом заворота — чтобы свет на глыбах не рвался на краю куска].
func _vor(p: Vector2, pts: Array, size: float) -> Array:
	var d1 := 1e9
	var d2 := 1e9
	var idx := 0
	var near := Vector2.ZERO
	for i in pts.size():
		var q: Vector2 = pts[i]
		for ox in [-size, 0.0, size]:
			for oy in [-size, 0.0, size]:
				var d := p.distance_to(q + Vector2(ox, oy))
				if d < d1:
					d2 = d1
					d1 = d
					idx = i
					near = q + Vector2(ox, oy)
				elif d < d2:
					d2 = d
	return [d1, d2, idx, near]


func _pts(rng: RandomNumberGenerator, n: int, size: float) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2(rng.randf() * size, rng.randf() * size))
	return out


# ---------------- Тайлы ----------------

func _tiles() -> void:
	var img := Image.create(96, 16, false, Image.FORMAT_RGBA8)
	# 0–2: пол — каменные плиты неровной формы, швы тёмные, плиты светлее к верхнему левому краю.
	for v in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + v * 17
		var pts := _pts(rng, 2 + v % 2, 16.0)
		var tints: Array = []
		for i in pts.size():
			tints.append([0.0, 0.0, 0.06, -0.04].pick_random() if true else 0.0)
		for y in 16:
			for x in 16:
				var p := Vector2(x + 0.5, y + 0.5)
				var r := _vor(p, pts, 16.0)
				var c: Color
				if r[1] - r[0] < 0.8:
					c = GAP
				else:
					var q: Vector2 = r[3]
					var to := (p - q)
					# Лёгкий объём плиты: свет сверху-слева, тень снизу-справа.
					var shade := clampf(-(to.x + to.y) / 14.0, -0.5, 0.5)
					c = SLAB.lightened(maxf(0.0, shade) * 0.35).darkened(maxf(0.0, -shade) * 0.35)
					var t: float = tints[r[2]]
					if t > 0.0:
						c = c.lerp(Color8(90, 70, 120), t * 3.0)  # фиолетовые плиты
					elif t < 0.0:
						c = c.lerp(TEAL, -t * 3.0)               # бирюзовые
					# У самого шва плита чуть темнее (скруглённые края).
					if r[1] - r[0] < 1.8:
						c = c.darkened(0.15)
					c = c.lightened((rng.randf() - 0.5) * 0.08)
				img.set_pixel(v * 16 + x, y, c)
		# Мелочь: голубые искорки мха и камешки.
		for i in 3:
			var px := rng.randi_range(1, 14)
			var py := rng.randi_range(1, 14)
			if rng.randf() < 0.5:
				img.set_pixel(v * 16 + px, py, Color8(80, 170, 190))
			else:
				img.set_pixel(v * 16 + px, py, ROCK_L)
				img.set_pixel(v * 16 + px + 1, py + 1, GAP)

	# 3: верх стены — тёмная скальная масса из глыб с холодной кромкой.
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = 611
	var pts_t := _pts(rng_t, 4, 16.0)
	for y in 16:
		for x in 16:
			var p := Vector2(x + 0.5, y + 0.5)
			var r := _vor(p, pts_t, 16.0)
			var q: Vector2 = pts_t[r[2]]
			var to := p - q
			var c := ROCK_D
			if r[1] - r[0] < 1.0:
				c = DEEP
			elif r[1] - r[0] < 1.6 and to.x + to.y < 0.0:
				c = Color8(40, 40, 68)  # едва заметная кромка глыбы
			else:
				c = ROCK_D.lightened(clampf(-(to.x + to.y) / 40.0, -0.1, 0.12))
			img.set_pixel(48 + x, y, c.lightened((rng_t.randf() - 0.5) * 0.04))

	# 4: стена (обрыв скалы, вид сбоку-сверху): слои породы, светлая кромка, тень у пола.
	var rng_f := RandomNumberGenerator.new()
	rng_f.seed = 712
	var strata: Array = [3, 7, 11]
	for y in 16:
		for x in 16:
			var k := y / 15.0
			var c := ROCK_L.lerp(DEEP, k * 0.95)
			# Слои: неровные горизонтальные трещины.
			for s: int in strata:
				var sy := s + int(round(sin((x + s * 3) * 0.9) * 0.8))
				if y == sy:
					c = c.darkened(0.35)
				elif y == sy - 1:
					c = c.lightened(0.12)
			# Вертикальные трещины.
			if (x == 4 and y > 4 and y < 11) or (x == 11 and y > 8 and y < 14):
				c = c.darkened(0.25)
			# Блик на выступах слоёв слева.
			if x < 3 and y > 2:
				c = c.lightened(0.06)
			img.set_pixel(64 + x, y, c.lightened((rng_f.randf() - 0.5) * 0.025))
	for x in 16:
		img.set_pixel(64 + x, 0, RIM)                          # холодная кромка сверху
		img.set_pixel(64 + x, 1, RIM.darkened(0.3))
		img.set_pixel(64 + x, 15, DEEP.darkened(0.3))          # тень у пола

	# 5: лестница вниз — каменные ступени, светящиеся голубым снизу.
	var ox5 := 80
	img.fill_rect(Rect2i(ox5, 0, 16, 16), DEEP)
	for i in 4:
		var step_c := ROCK_L.darkened(i * 0.2)
		img.fill_rect(Rect2i(ox5 + 2 + i, 2 + i * 3, 12 - i * 2, 2), step_c)
		img.fill_rect(Rect2i(ox5 + 2 + i, 4 + i * 3, 12 - i * 2, 1), step_c.darkened(0.4))
	for y in range(11, 15):
		for x in range(6, 10):
			img.set_pixel(ox5 + x, y, CYAN.darkened(0.3 + (14 - y) * 0.12))
	for i in 16:
		for e in [Vector2i(i, 0), Vector2i(i, 15), Vector2i(0, i), Vector2i(15, i)]:
			img.set_pixel(ox5 + e.x, e.y, ROCK_M)
	_save(img, "res://assets/cave_tiles.png")


# ---------------- Большой бесшовный пол и скала (64x64 = 4x4 клетки) ----------------
# cave_floor.png 64x128: сверху пол (плиты идут через границы клеток — сетка не видна),
# снизу верх скалы. Клетка карты (x, y) берёт кусок (x % 4, y % 4).

func _big_floor() -> void:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var pts := _pts(rng, 18, 64.0)
	var tint: Array = []
	for i in pts.size():
		tint.append(rng.randf_range(-1.0, 1.0))
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var r := _vor(p, pts, 64.0)
			var gap: float = r[1] - r[0]
			var q: Vector2 = r[3]
			var to := p - q
			var c := SLAB
			var t: float = tint[r[2]]
			c = c.lerp(Color8(96, 78, 132), maxf(0.0, t) * 0.35)   # фиолетовые плиты
			c = c.lerp(TEAL, maxf(0.0, -t) * 0.22)                   # бирюзовые
			var shade := clampf(-(to.x + to.y) / 22.0, -0.6, 0.6)   # объём: свет сверху-слева
			c = c.lightened(maxf(0.0, shade) * 0.22).darkened(maxf(0.0, -shade) * 0.28)
			if gap < 0.9:
				c = c.darkened(0.55)                                   # шов
			elif gap < 1.9:
				c = c.darkened(0.22)                                   # скруглённый край плиты
			# Мелкие трещинки внутри плит.
			if gap > 3.0 and rng.randf() < 0.012:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c.lightened((rng.randf() - 0.5) * 0.05))
	# Редкие голубые искорки мха.
	for i in 22:
		img.set_pixel(rng.randi_range(0, 63), rng.randi_range(0, 63), Color8(90, 180, 200))
	# Скала (там, где ходить нельзя): груда тёмных валунов — каждый выпуклый, со светом сверху-слева,
	# между ними глубокие чёрные щели; заметно темнее пола, чтобы не путать.
	var stones := _pts(rng, 17, 64.0)
	var stint: Array = []
	for i in stones.size():
		stint.append(rng.randf_range(-1.0, 1.0))
	for y in 64:
		for x in 64:
			var p := Vector2(x + 0.5, y + 0.5)
			var r := _vor(p, stones, 64.0)
			var gap: float = r[1] - r[0]
			var to: Vector2 = p - (r[3] as Vector2)
			# Размер валуна ~ половина расстояния до соседа: купол по расстоянию до центра.
			var rad: float = (r[0] + r[1]) * 0.5
			var dome := clampf(1.0 - r[0] / maxf(rad, 1.0), 0.0, 1.0)
			var lit := clampf(-(to.x + to.y * 1.3) / (rad * 1.6 + 0.01), -1.0, 1.0)
			var t: float = stint[r[2]]
			var c := Color8(22, 21, 38)
			c = c.lerp(Color8(32, 23, 46), maxf(0.0, t) * 0.6)      # фиолетовые
			c = c.lerp(Color8(18, 30, 40), maxf(0.0, -t) * 0.5)     # сине-зелёные
			c = c.lightened(dome * 0.07 + maxf(0.0, lit) * 0.16 * (0.4 + dome))
			c = c.darkened(maxf(0.0, -lit) * 0.4)
			if gap < 1.0:
				c = Color8(9, 8, 18)                                  # щель
			elif gap < 2.2:
				c = c.darkened(0.45)                                  # тень у щели
			elif gap < 3.2 and lit > 0.2:
				c = c.lightened(0.08)                                 # светлая кромка валуна
			if gap > 3.0 and rng.randf() < 0.01:
				c = c.darkened(0.35)                                  # выбоинки
			img.set_pixel(x, 64 + y, c.lightened((rng.randf() - 0.5) * 0.04))
	# Редкие холодные искорки (вкрапления кристаллов).
	for i in 9:
		var sx := rng.randi_range(0, 63)
		var sy := 64 + rng.randi_range(0, 63)
		img.set_pixel(sx, sy, Color8(110, 190, 230))
		if sx < 63:
			img.set_pixel(sx + 1, sy, Color8(50, 90, 130))
	_save(img, "res://assets/cave_floor.png")


# ---------------- Украшения ----------------
# cave_decor.png 128x16: 0–2 кристаллы, 3 грибы-трутовики (на стене), 4 светящиеся грибочки,
# 5 корни (свисают со стены), 6 трава, 7 камешки.

func _decor() -> void:
	var img := Image.create(192, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900
	# Кристаллы: 2–4 вытянутых призмы из одной точки, голубые, к кончику светлее.
	for v in 3:
		var ox := v * 16
		var n := 2 + v
		for i in n:
			var base := Vector2(5 + i * 2.5 + rng.randf(), 15)
			var ang := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.38 + rng.randf_range(-0.1, 0.1)
			var length := rng.randf_range(7.0, 13.0) - absf(i - (n - 1) / 2.0) * 2.0
			var w := 1.4 if i % 2 == 0 else 1.1
			var dir := Vector2.from_angle(ang)
			for t in range(0, int(length * 4)):
				var f := t / (length * 4.0)
				var c := Vector2(base) + dir * (f * length)
				var half := w * (1.0 - f * 0.6)
				for k in range(-2, 3):
					var p := c + dir.orthogonal() * (k * 0.5)
					if absf(k * 0.5) <= half:
						var col := CYAN.lerp(CYAN_HI, 0.25 + f * 0.75).darkened(0.22 if k < 0 else 0.0)
						_px(img, ox + int(p.x), int(p.y), col)
		_outline_rect(img, Rect2i(ox, 0, 16, 16))
	# 3: трутовики — полукруглые оранжевые полки в два-три яруса.
	for s in [[4, 6, 5], [9, 10, 4], [5, 12, 3]]:
		for x in range(-s[2], s[2] + 1):
			for y in range(0, 3):
				if x * x / float(s[2] * s[2]) + y * y / 6.0 <= 1.0:
					_px(img, 48 + s[0] + x + 3, s[1] + y, ORANGE_HI if y == 0 else (ORANGE if y == 1 else ORANGE.darkened(0.4)))
	_outline_rect(img, Rect2i(48, 0, 16, 16))
	# 4: светящиеся грибочки — тонкие ножки и голубые шляпки.
	for m in [[4, 9], [8, 6], [11, 10]]:
		for y in range(m[1] + 2, 15):
			_px(img, 64 + m[0], y, Color8(150, 170, 190))
		for x in range(-2, 3):
			_px(img, 64 + m[0] + x, m[1], CYAN if absf(x) < 2 else CYAN.darkened(0.3))
			if absf(x) < 2:
				_px(img, 64 + m[0] + x, m[1] + 1, CYAN.darkened(0.45))
		_px(img, 64 + m[0], m[1] - 1, CYAN_HI)
	# 5: корни — тёмные плети сверху вниз с отростками.
	for r in [[4, 15], [9, 11], [12, 13]]:
		var x: float = r[0]
		for y in r[1]:
			x += rng.randf_range(-0.5, 0.5)
			_px(img, 80 + int(x), y, Color8(70, 72, 92))
			if rng.randf() < 0.15:
				_px(img, 80 + int(x) + (1 if rng.randf() < 0.5 else -1), y, Color8(100, 104, 128))
	# 6: трава — тёмные бирюзовые травинки с красными кончиками (как на референсе 1).
	for i in 7:
		var x := 2 + i * 2
		var h := rng.randi_range(5, 10)
		for y in h:
			var col := Color8(40, 90, 96).lightened(y * 0.03)
			if y >= h - 2 and i % 3 == 0:
				col = Color8(190, 60, 70)
			_px(img, 96 + x + (1 if y > h / 2 and i % 2 == 0 else 0), 15 - y, col)
	# 7: камешки.
	for p in [Vector2i(3, 12), Vector2i(8, 13), Vector2i(12, 11), Vector2i(6, 9)]:
		img.fill_rect(Rect2i(112 + p.x, p.y, 2, 2), ROCK_L)
		_px(img, 112 + p.x, p.y, RIM)
		_px(img, 112 + p.x + 1, p.y + 2, GAP)
	_rock_decor(img, rng)
	_save(img, "res://assets/cave_decor.png")


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Тёмный контур вокруг непрозрачных пикселей внутри rect.
func _outline_rect(img: Image, r: Rect2i) -> void:
	var add: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= r.position.x and q.y >= r.position.y and q.x < r.end.x and q.y < r.end.y and img.get_pixel(q.x, q.y).a > 0.0:
					add.append(Vector2i(x, y))
					break
	for p: Vector2i in add:
		img.set_pixelv(p, OUTLINE)


# ---------------- Свет ----------------

func _light() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x + 0.5 - 32, y + 0.5 - 32).length() / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_save(img, "res://assets/light.png")


# ---------------- Герой-мечник с 8 сторон (чиби) ----------------
# Кадр 24x24, ступни на y = 22. Строки: 0 вниз (лицом к нам), 1 вниз-вправо, 2 вправо,
# 3 вверх-вправо, 4 вверх (спиной). Влево — те же кадры зеркально.

const SKIN := Color8(244, 204, 172)
const SKIN_D := Color8(214, 160, 128)
const HAIR := Color8(122, 70, 38)
const HAIR_L := Color8(166, 102, 56)
const STEEL := Color8(176, 186, 206)
const STEEL_L := Color8(222, 230, 242)
const STEEL_D := Color8(108, 116, 140)
const CLOTH := Color8(52, 84, 168)
const GOLD := Color8(228, 186, 72)
const LEATHER := Color8(96, 62, 38)
const BLADE := Color8(214, 222, 236)
const SHIELD := Color8(58, 90, 176)


func _hero() -> void:
	var img := Image.create(96, 120, false, Image.FORMAT_RGBA8)
	for row in 5:
		for f in 4:
			var frame := Image.create(24, 24, false, Image.FORMAT_RGBA8)
			_draw_knight(frame, row, f)
			_outline_rect(frame, Rect2i(0, 0, 24, 24))
			img.blit_rect(frame, Rect2i(0, 0, 24, 24), Vector2i(f * 24, row * 24))
	_save(img, "res://assets/hero8_warrior.png")


func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


## row: 0 вниз, 1 вниз-вбок, 2 вбок, 3 вверх-вбок, 4 вверх; f — кадр шага (0..3).
func _draw_knight(img: Image, row: int, f: int) -> void:
	var bob := 1 if f % 2 == 1 else 0
	var step: int = [0, 1, 0, -1][f]   # ноги: вперёд-назад
	var front := row <= 1
	var back := row >= 3
	var side := row == 2
	var shift: float = [0.0, 1.0, 1.5, 1.0, 0.0][row]   # куда смотрит голова (вправо)

	# Задний предмет (за телом): со спины щит на левой руке (слева на экране), меч справа.
	if back:
		_rect(img, 3, 12 + bob, 5, 7, LEATHER)                      # щит изнанкой
		_rect(img, 4, 13 + bob, 3, 5, LEATHER.lightened(0.15))
		_rect(img, 18, 7 + bob, 1, 10, BLADE)                       # меч поднят
		_rect(img, 17, 16 + bob, 3, 1, GOLD)

	# Ноги (сапоги).
	if side:
		_rect(img, 10 + step, 19, 3, 3 + (1 if step >= 0 else 0), LEATHER)
		_rect(img, 12 - step, 19, 3, 3, LEATHER.darkened(0.25))
		_rect(img, 10 + step, 21, 4, 1, LEATHER.darkened(0.4))
	else:
		_rect(img, 9, 19 + (1 if step > 0 else 0), 3, 3, LEATHER)
		_rect(img, 13, 19 + (1 if step < 0 else 0), 3, 3, LEATHER)
		_rect(img, 9, 21, 3, 1, LEATHER.darkened(0.4))
		_rect(img, 13, 21, 3, 1, LEATHER.darkened(0.4))

	# Корпус в латах.
	var bx := 8 if not side else 9
	var bw := 9 if not side else 7
	_rect(img, bx, 12 + bob, bw, 7, STEEL)
	_rect(img, bx, 12 + bob, bw, 1, STEEL_L)
	_rect(img, bx + bw - 2, 13 + bob, 2, 6, STEEL_D)               # тень справа
	if front:
		_rect(img, 11 + int(shift), 13 + bob, 3, 5, CLOTH)          # синяя накидка спереди
	_rect(img, bx, 17 + bob, bw, 1, LEATHER)                        # пояс
	_px(img, bx + bw / 2, 17 + bob, GOLD)
	# Наплечники.
	if not side:
		_ell(img, 8, 13 + bob, 2.2, 1.8, STEEL_L)
		_ell(img, 17, 13 + bob, 2.2, 1.8, STEEL)
	else:
		_ell(img, 12, 13 + bob, 2.5, 1.8, STEEL_L)

	# Голова (крупная — чиби).
	var hx: float = 12.5 + shift * 0.6
	var hy := 7.5 + bob
	_ell(img, hx, hy, 6.2, 5.6, HAIR)
	if front or side:
		# Лицо: смещено туда, куда смотрит герой.
		var fx: float = hx + (0.0 if row == 0 else (1.2 if row == 1 else 2.2))
		_ell(img, fx, hy + 1.6, 4.4 if row == 0 else 3.6, 3.4, SKIN)
		_rect(img, int(fx - 3), int(hy + 3.5), 6, 1, SKIN_D)        # тень под щеками
		# Чёлка поверх лба.
		_ell(img, hx - 0.5, hy - 1.6, 5.6, 2.4, HAIR)
		_ell(img, hx - 1.5, hy - 2.6, 3.0, 1.2, HAIR_L)
		# Глаза.
		var eyes: Array = [[fx - 2, hy + 1.5], [fx + 2, hy + 1.5]] if row == 0 else ([[fx - 1, hy + 1.5], [fx + 2, hy + 1.5]] if row == 1 else [[fx + 1, hy + 1.5]])
		for e: Array in eyes:
			_rect(img, int(e[0]), int(e[1]), 1, 2, Color8(40, 30, 50))
			_px(img, int(e[0]), int(e[1]), Color8(250, 250, 255))
	else:
		_ell(img, hx - 1.5, hy - 2.0, 3.5, 1.6, HAIR_L)             # блик на макушке
		if row == 3:
			_px(img, int(hx + 5), int(hy + 1), SKIN)                 # краешек щеки

	# Передний предмет: щит и меч.
	if row == 0:
		_ell(img, 18.5, 15.5 + bob, 3.4, 4.0, SHIELD)                # щит на левой руке (справа на экране)
		_ell(img, 18.5, 15.5 + bob, 2.2, 2.8, SHIELD.lightened(0.15))
		_rect(img, 18, 13 + bob, 1, 5, GOLD)
		_rect(img, 16, 15 + bob, 5, 1, GOLD)
		_rect(img, 5, 7 + bob, 1, 10, BLADE)                         # меч в правой (слева на экране)
		_rect(img, 4, 16 + bob, 3, 1, GOLD)
		_rect(img, 5, 17 + bob, 1, 2, LEATHER)
	elif row == 1:
		_ell(img, 8.0, 15.5 + bob, 3.0, 3.8, SHIELD)                 # щит ближе к нам, слева
		_rect(img, 7, 13 + bob, 1, 5, GOLD)
		_rect(img, 19, 8 + bob, 1, 9, BLADE)
		_rect(img, 18, 16 + bob, 3, 1, GOLD)
	elif side:
		_ell(img, 11.0, 15.5 + bob, 3.2, 3.8, SHIELD)                # щит сбоку, ближний к нам
		_ell(img, 11.0, 15.5 + bob, 2.0, 2.6, SHIELD.lightened(0.15))
		_rect(img, 11, 13 + bob, 1, 5, GOLD)
		for i in 7:                                                   # меч вперёд, чуть вверх
			_px(img, 15 + i, 15 + bob - i / 2, BLADE)
		_rect(img, 14, 14 + bob, 1, 3, GOLD)
	elif row == 3:
		_rect(img, 19, 8 + bob, 1, 9, BLADE)


## Украшения скалы (фон, где ходить нельзя): 8 сталагмиты, 9 кристаллы в породе, 10 валун,
## 11 далёкие искры кристаллов.
func _rock_decor(img: Image, rng: RandomNumberGenerator) -> void:
	# 8: сталагмиты — 3 конуса, свет слева, светлая верхушка.
	for sp in [[5, 13, 3], [10, 9, 2], [13, 6, 1]]:
		var cx: int = sp[0]
		var hgt: int = sp[1]
		var half: int = sp[2]
		for yy in hgt:
			var wdt := int(round(half * (1.0 - float(yy) / hgt))) 
			for xx in range(-wdt, wdt + 1):
				var c := Color8(46, 46, 76) if xx < 0 else (Color8(34, 33, 58) if xx == 0 else Color8(22, 21, 40))
				if yy > hgt - 3:
					c = c.lightened(0.2)
				_px(img, 128 + cx + xx, 15 - yy, c)
	_outline_rect(img, Rect2i(128, 0, 16, 16))
	# 9: кристаллы, торчащие из породы — тусклее тех, что на полу.
	for i in 4:
		var base := Vector2(4 + i * 2.6 + rng.randf(), 13 + rng.randf() * 2.0)
		var ang := -PI / 2.0 + (i - 1.5) * 0.45
		var length := rng.randf_range(5.0, 10.0) - absf(i - 1.5) * 1.5
		var dir := Vector2.from_angle(ang)
		for t in range(0, int(length * 3)):
			var f := t / (length * 3.0)
			var c := Vector2(base) + dir * (f * length)
			for k in range(-1, 2):
				var pp := c + dir.orthogonal() * (k * 0.5)
				var col := CYAN.darkened(0.35).lerp(CYAN_HI.darkened(0.15), f).darkened(0.3 if k < 0 else 0.0)
				_px(img, 144 + int(pp.x), int(pp.y), col)
	for xx in range(2, 14):
		_px(img, 144 + xx, 15, Color8(22, 21, 40))
	_outline_rect(img, Rect2i(144, 0, 16, 16))
	# 10: валун — купол со светом сверху-слева.
	for yy in 16:
		for xx in 16:
			var d := Vector2((xx - 8) / 6.5, (yy - 9) / 5.5)
			if d.length() <= 1.0:
				var lit := -(d.x + d.y) * 0.5
				var c := Color8(38, 38, 64).lightened(maxf(0.0, lit) * 0.35).darkened(maxf(0.0, -lit) * 0.5)
				if d.length() > 0.85 and lit > 0.1:
					c = c.lightened(0.2)
				_px(img, 160 + xx, yy, c)
	_px(img, 160 + 6, 7, Color8(30, 30, 52))
	_px(img, 160 + 7, 8, Color8(30, 30, 52))
	_outline_rect(img, Rect2i(160, 0, 16, 16))
	# 11: искры далёких кристаллов.
	for i in 5:
		var px := 176 + rng.randi_range(1, 14)
		var py := rng.randi_range(1, 14)
		_px(img, px, py, Color8(150, 220, 255) if i % 2 == 0 else Color8(80, 140, 200))
