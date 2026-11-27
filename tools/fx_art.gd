extends "res://tools/dungeon_art.gd"
## Эффекты заклинаний в утверждённом стиле (по референсу владельца — лист эффектов магов: снаряд
## с хвостом → вспышка-звезда → искры, тающие кадр за кадром; столбы огня, вихри, молнии).
## Свои рисунки, не копия референса. Светящиеся формы: ядро почти белое → насыщенный цвет →
## тёмный край своего оттенка (вместо чёрного контура), мягкий ступенчатый ореол.
## Используют: tools/sample_fx.gd (образец).

const FIRE := [Color8(255, 250, 220), Color8(255, 218, 116), Color8(246, 152, 62), Color8(212, 88, 46), Color8(140, 46, 40)]
const ICEF := [Color8(244, 252, 255), Color8(176, 224, 250), Color8(106, 172, 232), Color8(64, 112, 192), Color8(40, 70, 140)]
const ARC := [Color8(255, 244, 255), Color8(246, 176, 240), Color8(214, 104, 222), Color8(156, 62, 182), Color8(98, 40, 128)]
const BOLT := [Color8(255, 253, 226), Color8(255, 232, 124), Color8(240, 192, 64), Color8(198, 132, 40), Color8(138, 82, 32)]
const ARCANE := [Color8(246, 238, 255), Color8(204, 176, 255), Color8(152, 114, 242), Color8(104, 72, 202), Color8(66, 44, 150)]
const SMOKE := [Color8(150, 140, 146), Color8(120, 110, 118), Color8(92, 84, 94), Color8(66, 60, 72), Color8(46, 42, 52)]


func _rim(pal: Array) -> Color:
	return (pal[4] as Color).darkened(0.35)


## Светящийся сгусток: тон по расстоянию от центра (ядро — светлое), неровный край.
func glob(pix: Dictionary, cx: float, cy: float, r: float, pal: Array, bias := 0.0, sd := 0, jag := 0.18) -> void:
	for y in range(int(cy - r * 1.3) - 1, int(cy + r * 1.3) + 2):
		for x in range(int(cx - r * 1.3) - 1, int(cx + r * 1.3) + 2):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var a := atan2(dy, dx)
			var edge := r * (1.0 + jag * sin(a * 5.0 + sd) + jag * 0.6 * sin(a * 9.0 + sd * 1.7))
			var d := sqrt(dx * dx + dy * dy)
			if d > edge:
				continue
			# Ядро сдвинуто вверх-влево — свет как у всего остального.
			var dd := Vector2(dx + r * 0.15, dy + r * 0.15).length() / edge
			var ti := int(dd * 3.6 + bias)
			var k := Vector2i(x, y)
			var c: Color = pal[clampi(ti, 0, 4)]
			if not pix.has(k) or (pix[k] as Color).get_luminance() < c.get_luminance():
				pix[k] = c


## Звезда-вспышка: n лучей, длина луча R, ядро светлое.
func star(pix: Dictionary, cx: float, cy: float, R: float, n: int, pal: Array, rot := 0.0, bias := 0.0) -> void:
	for y in range(int(cy - R) - 1, int(cy + R) + 2):
		for x in range(int(cx - R) - 1, int(cx + R) + 2):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var a := atan2(dy, dx) + rot
			var prof := 0.28 + 0.72 * pow(absf(cos(a * n * 0.5)), 10.0)
			var d := sqrt(dx * dx + dy * dy)
			if d > R * prof:
				continue
			var ti := int(d / (R * prof) * 3.2 + bias)
			var k := Vector2i(x, y)
			var c: Color = pal[clampi(ti, 0, 4)]
			if not pix.has(k) or (pix[k] as Color).get_luminance() < c.get_luminance():
				pix[k] = c


## Искры: россыпь по кольцу радиуса r (крестики и точки), тон зависит от «возраста».
func sparks(cx: float, cy: float, r: float, n: int, pal: Array, age: int, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	for i in n:
		var a := rng.randf() * TAU
		var rr := r * rng.randf_range(0.55, 1.1)
		var p := Vector2(cx, cy) + Vector2(cos(a), sin(a) * 0.85) * rr
		var c: Color = pal[clampi(age + rng.randi_range(0, 1), 0, 4)]
		put(int(p.x), int(p.y), c)
		if rng.randf() < 0.55 and age < 3:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				put(int(p.x) + d.x, int(p.y) + d.y, pal[clampi(age + 1, 0, 4)])


## Снаряд-комета, летит вправо: голова-сгусток и хвост из убывающих языков (темнее к концу).
func comet(cx: int, cy: int, r: float, pal: Array, fr: int, tail := 6) -> void:
	glow(cx, cy, r * 2.4, pal[1], 0.22)
	var pix := {}
	for i in range(tail, 0, -1):
		var t := float(i) / tail
		var px := cx - i * r * 0.62
		var py := cy + sin(i * 1.3 + fr * 1.7) * r * 0.22
		glob(pix, px, py, r * (1.0 - t * 0.75), pal, 1.0 + t * 1.8, i * 7 + fr * 3, 0.3)
	glob(pix, cx, cy, r, pal, 0.0, fr * 5, 0.12)
	blit(pix, _rim(pal))
	# Искры позади.
	sparks(cx - r * 3.0, cy, r * 1.4, 4, pal, 2, fr * 11 + 3)


## Ледяной осколок, летит вправо: ромб с гранями (верхняя светлая, нижняя в тени), иней позади.
func shard(cx: int, cy: int, r: float, fr: int) -> void:
	glow(cx, cy, r * 2.2, ICEF[1], 0.22)
	var pix := {}
	var pts := PackedVector2Array([Vector2(cx + r * 1.6, cy), Vector2(cx - r * 0.2, cy - r * 0.8), Vector2(cx - r * 1.2, cy), Vector2(cx - r * 0.2, cy + r * 0.8)])
	var rect := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		rect = rect.expand(q)
	for y in range(int(rect.position.y) - 1, int(rect.end.y) + 2):
		for x in range(int(rect.position.x) - 1, int(rect.end.x) + 2):
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, pts):
				continue
			var c: Color = ICEF[1] if p.y < cy else ICEF[3]
			if absf(p.y - cy) < 0.8:
				c = ICEF[0]
			if p.x > cx + r * 0.9:
				c = ICEF[0] if p.y < cy else ICEF[2]
			pix[Vector2i(x, y)] = c
	# Иней-облачка позади.
	for i in 3:
		glob(pix, cx - r * (1.8 + i * 1.1), cy + sin(i + fr) * r * 0.3, r * (0.6 - i * 0.13), ICEF, 1.2 + i * 0.6, i + fr * 4, 0.25)
	blit(pix, _rim(ICEF))


## Вспышка попадания: f 0 — малая звезда, 1 — большая звезда, 2 — кольцо и искры,
## 3–5 — искры разлетаются и тают. smoke — дым у огня, snow — снежинка у льда.
func impact(cx: int, cy: int, s: float, pal: Array, f: int, kind := "") -> void:
	var pix := {}
	match f:
		0:
			glow(cx, cy, s * 1.6, pal[1], 0.3)
			star(pix, cx, cy, s * 0.7, 4, pal, 0.0)
			glob(pix, cx, cy, s * 0.3, pal)
		1:
			glow(cx, cy, s * 2.0, pal[1], 0.32)
			star(pix, cx, cy, s * 1.25, 8, pal, 0.4)
			glob(pix, cx, cy, s * 0.5, pal)
			if kind == "fire":
				for i in 6:
					var a := i * TAU / 6.0 + 0.3
					glob(pix, cx + cos(a) * s * 0.75, cy + sin(a) * s * 0.65, s * 0.32, pal, 0.8, i)
		2:
			glow(cx, cy, s * 1.8, pal[2], 0.2)
			for i in 8:
				var a := i * TAU / 8.0
				var p := Vector2(cx, cy) + Vector2(cos(a), sin(a) * 0.85) * s * 0.95
				star(pix, p.x, p.y, s * 0.32, 4, pal, a, 0.6)
			if kind == "fire":
				glob(pix, cx, cy - 1, s * 0.6, SMOKE, 0.5, 3)
				glob(pix, cx, cy, s * 0.42, pal, 0.8, 5)
			elif kind == "ice":
				_snowflake(pix, cx, cy, s * 0.7, pal)
			else:
				glob(pix, cx, cy, s * 0.35, pal, 0.6)
		_:
			var age := f - 2
			if kind == "fire":
				for i in 3:
					var a := i * 2.1 + f
					glob(pix, cx + cos(a) * s * 0.4, cy - age * 3 + sin(a) * s * 0.3, s * (0.45 - age * 0.06), SMOKE, 0.6 + age * 0.5, i + f)
			elif kind == "ice" and age < 3:
				_snowflake(pix, cx, cy, s * (0.6 - age * 0.12), [pal[1], pal[2], pal[3], pal[4], pal[4]])
	if not pix.is_empty():
		blit(pix, _rim(pal if f < 3 or kind != "fire" else SMOKE))
	if f >= 1:
		var age := maxi(f - 1, 0)
		sparks(cx, cy, s * (0.9 + age * 0.35), 14 - age * 2, pal, mini(age, 4), cx * 3 + f)


func _snowflake(pix: Dictionary, cx: float, cy: float, R: float, pal: Array) -> void:
	for i in 6:
		var a := i * TAU / 6.0
		for t in int(R):
			var p := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * t
			pix[Vector2i(int(p.x), int(p.y))] = pal[0] if t < R * 0.5 else pal[1]
			if t == int(R * 0.6):
				for s: int in [-1, 1]:
					var b := p + Vector2(cos(a + s * 0.9), sin(a + s * 0.9)) * 2.0
					pix[Vector2i(int(b.x), int(b.y))] = pal[1]


## Столб огня (огненная земля, след метеора): языки пламени разной высоты, светлое ядро у
## основания, угли сверху. f 0–5: разгорается, горит, опадает.
func flame_pillar(cx: int, base: int, h: float, f: int) -> void:
	var k: float = [0.45, 0.85, 1.0, 0.92, 0.65, 0.35][f]
	glow(cx, base - h * k * 0.4, h * 0.6, FIRE[2], 0.22 * k + 0.05)
	ground_shadow(cx, base - 1, int(h * 0.38), 3, 0.25)
	var pix := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + f
	var tongues := [[-0.32, 0.55], [0.3, 0.6], [-0.15, 0.85], [0.12, 0.9], [0.0, 1.0]]
	for i in tongues.size():
		var ox: float = float(tongues[i][0]) * h * 0.45 + rng.randf_range(-1.5, 1.5)
		var th: float = float(tongues[i][1]) * h * k * rng.randf_range(0.85, 1.1)
		var w: float = h * 0.2 * (1.0 if i < 4 else 1.3)
		var lean := rng.randf_range(-0.25, 0.25)
		for yy in int(th):
			var t := float(yy) / th
			var half := w * pow(sin(minf(t * 1.15, 1.0) * PI * 0.5 + 0.35), 1.0) * (1.0 - t)
			var xc := cx + ox + lean * yy + sin(t * 7.0 + f + i) * 1.2
			for xx in range(int(xc - half), int(xc + half) + 1):
				var u := absf(xx + 0.5 - xc) / maxf(half, 0.5)
				var ti := int(u * 2.5 + t * 2.4 + (0.6 if i < 2 else 0.0))
				var key := Vector2i(xx, base - 2 - yy)
				var c: Color = FIRE[clampi(ti, 0, 4)]
				if not pix.has(key) or (pix[key] as Color).get_luminance() < c.get_luminance():
					pix[key] = c
	blit(pix, _rim(FIRE))
	sparks(cx, base - h * k * 0.9, h * 0.35, 6, FIRE, 1 + f / 2, f * 13)


## Вихрь (ледяная метель, смерч): сплошные ленты по спирали, внизу узко, вверху широко;
## передняя часть ленты светлая, задняя тёмная (рисуется раньше); снежинки вокруг.
## f 0–5: раскручивается и тает.
func whirl(cx: int, base: int, h: float, pal: Array, f: int) -> void:
	var k: float = [0.5, 0.9, 1.0, 1.0, 0.75, 0.45][f]
	var hh2 := h * k
	glow(cx, base - hh2 * 0.5, h * 0.5, pal[1], 0.16)
	ground_shadow(cx, base - 1, int(h * 0.3), 3, 0.22)
	var back := {}
	var front := {}
	var bands := 4 if f < 4 else 3
	for b in bands:
		var prev := Vector2.ZERO
		for yy in int(hh2):
			var t := float(yy) / hh2
			var w := lerpf(h * 0.05, h * 0.32, pow(t, 0.75))
			var ph := yy * 0.13 - f * 1.1 + b * TAU / bands
			var p := Vector2(cx + sin(ph) * w, base - 2 - yy - cos(ph) * w * 0.18)
			var is_front := cos(ph) > -0.1
			var tgt: Dictionary = front if is_front else back
			var ti := (0 if cos(ph) > 0.6 else 1) if is_front else 3
			if t > 0.8 or b % 2 == 1:
				ti += 1
			if yy > 0:
				var n := int(prev.distance_to(p)) + 1
				for i in n + 1:
					var q := prev.lerp(p, float(i) / n)
					var th := 2 if t > 0.25 else 1
					for dy in th:
						var key := Vector2i(int(q.x), int(q.y) + dy)
						tgt[key] = pal[clampi(ti + dy, 0, 4)]
			prev = p
	blit(back, _rim(pal))
	blit(front, _rim(pal))
	sparks(cx, base - hh2 * 0.55, h * 0.42, 12, pal, 0 if f < 4 else 2, f * 7 + 1)


## Столб молнии с неба: f 0 — тонкая метка-предупреждение, 1–2 — удар (зигзаг, ветки, вспышка
## у земли), 3 — гаснет, 4–5 — искры.
func lightning(cx: int, base: int, h: float, pal: Array, f: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + (f if f < 3 else 2)
	if f == 0:
		for yy in int(h):
			if yy % 3 != 2:
				put(cx, base - 2 - yy, pal[1])
		glob_put(cx, base - 2, 3.0, pal)
		return
	if f <= 3:
		glow(cx, base - h * 0.5, h * 0.45, pal[1], 0.25 if f < 3 else 0.12)
		var pix := {}
		var p := Vector2(cx + rng.randf_range(-4, 4), base - h)
		var width := 2 if f < 3 else 1
		while p.y < base - 2:
			var q := p + Vector2(rng.randf_range(-5, 5), rng.randf_range(4, 8))
			q.x = clampf(q.x, cx - 8, cx + 8)
			_bolt_seg(pix, p, q, pal, width)
			if rng.randf() < 0.35 and f < 3:
				var b := q + Vector2(rng.randf_range(-10, 10), rng.randf_range(4, 10))
				_bolt_seg(pix, q, b, pal, 0)
			p = q
		if f < 3:
			star(pix, cx, base - 3, 10.0 if f == 1 else 13.0, 6, pal, 0.3)
		blit(pix, _rim(pal))
	if f >= 2:
		sparks(cx, base - 6, 8.0 + f * 3.0, 12 - f, pal, f - 2, f * 5)


func glob_put(cx: int, cy: int, r: float, pal: Array) -> void:
	var pix := {}
	glob(pix, cx, cy, r, pal)
	blit(pix, _rim(pal))


func _bolt_seg(pix: Dictionary, a: Vector2, b: Vector2, pal: Array, w: int) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dx in range(-w, w + 1):
			var c: Color = pal[0] if dx == 0 else (pal[1] if absi(dx) == 1 else pal[2])
			pix[Vector2i(int(p.x) + dx, int(p.y))] = c


## Цепная молния между двумя точками (вправо), f — новая форма зигзага каждый кадр.
func chain(a: Vector2, b: Vector2, pal: Array, f: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + f
	var pix := {}
	var p := a
	var n := 7
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / n)
		if i < n:
			q += Vector2(0, rng.randf_range(-8, 8))
		_bolt_seg(pix, p, q, pal, 1)
		p = q
	glow(int((a.x + b.x) / 2), int(a.y), (b.x - a.x) * 0.5, pal[1], 0.22)
	star(pix, b.x, b.y, 7.0, 4, pal, 0.0)
	blit(pix, _rim(pal))


## Метеорит падает слева-сверху вправо-вниз: каменное ядро в огне, огненный хвост вверх-влево.
func meteor(cx: int, cy: int, r: float, f: int) -> void:
	glow(cx, cy, r * 2.6, FIRE[2], 0.24)
	var pix := {}
	for i in range(7, 0, -1):
		var t := i / 7.0
		glob(pix, cx - i * r * 0.55, cy - i * r * 0.55, r * (1.15 - t * 0.85), FIRE, 0.6 + t * 1.8, i * 3 + f, 0.32)
	glob(pix, cx, cy, r * 1.15, FIRE, 0.0, f, 0.2)
	blit(pix, _rim(FIRE))
	var rock := {}
	ball(rock, cx + 1, cy + 1, r * 0.7, r * 0.7, LROCK)
	blit(rock)
	_cracks(cx - 2, cy - 2, 5, f + 3, LAVA)
