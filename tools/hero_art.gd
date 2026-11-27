extends "res://tools/dungeon_art.gd"
## Герои в утверждённом стиле (правила — .claude/skills/pixel-style): чиби-фигурка в кадре 48x48
## пикселей картинки (24 мира), 5 сторон (вниз, вниз-вбок, вбок, вверх-вбок, вверх; влево —
## зеркалом) × 4 кадра шага. Классы и профессии отличаются одеждой, головой и оружием (HEROES).
## Используют: tools/sample_heroes.gd (образец), tools/gen_heroes.gd (листы для игры).

const SKIN := [Color8(250, 224, 198), Color8(238, 198, 166), Color8(212, 164, 134), Color8(176, 128, 106), Color8(130, 92, 82)]
const STEEL := [Color8(226, 230, 238), Color8(186, 192, 206), Color8(146, 152, 170), Color8(108, 112, 132), Color8(76, 78, 96)]


## Пять тонов из одного цвета: свет, основа, полутень, тень, глубокая тень.
static func p5(c: Color) -> Array:
	return [c.lightened(0.3), c, c.darkened(0.2), c.darkened(0.4), c.darkened(0.6)]


## Внешность: body — одежда, trim — отделка/пояс, legs — штаны, boots, hair, head (вид головы),
## hc — цвет головного убора, main/off — оружие и вторая рука, cape — плащ, back — за спиной.
const HEROES := {
	"warrior": {"body": Color8(70, 104, 170), "trim": Color8(196, 150, 70), "armor": true, "legs": Color8(84, 70, 66), "boots": Color8(96, 66, 46),
		"hair": Color8(124, 76, 44), "head": "short", "main": "sword", "off": "shield", "sc": Color8(64, 94, 170)},
	"archer": {"body": Color8(86, 132, 74), "trim": Color8(150, 104, 62), "legs": Color8(110, 90, 62), "boots": Color8(104, 72, 48),
		"hair": Color8(214, 176, 96), "head": "hood", "hc": Color8(76, 116, 66), "main": "bow", "back": "quiver"},
	"mage": {"body": Color8(118, 80, 160), "trim": Color8(220, 186, 90), "robe": true, "legs": Color8(90, 60, 120), "boots": Color8(80, 56, 70),
		"hair": Color8(226, 222, 232), "head": "hat", "hc": Color8(110, 74, 152), "main": "staff", "orb": Color8(140, 210, 240)},
	"thief": {"body": Color8(82, 80, 96), "trim": Color8(126, 94, 62), "legs": Color8(64, 62, 76), "boots": Color8(70, 56, 50),
		"hair": Color8(60, 50, 46), "head": "hood", "hc": Color8(70, 68, 84), "mask": Color8(52, 50, 64), "main": "dagger"},
	"acolyte": {"body": Color8(226, 220, 206), "trim": Color8(206, 166, 76), "robe": true, "legs": Color8(196, 188, 172), "boots": Color8(130, 98, 70),
		"hair": Color8(150, 100, 60), "head": "short", "main": "mace", "off": "book", "bc": Color8(150, 60, 60)},
	"berserker": {"body": Color8(150, 62, 56), "trim": Color8(120, 90, 62), "legs": Color8(90, 66, 54), "boots": Color8(84, 60, 46),
		"hair": Color8(206, 110, 56), "head": "horned", "hc": Color8(140, 140, 150), "main": "axe", "skinarm": true},
	"paladin": {"body": Color8(200, 204, 218), "trim": Color8(214, 176, 70), "armor": true, "legs": Color8(150, 154, 170), "boots": Color8(120, 122, 140),
		"hair": Color8(196, 160, 96), "head": "helm", "hc": Color8(196, 200, 214), "plume": Color8(196, 64, 60), "main": "mace", "off": "tower", "sc": Color8(66, 92, 168), "cape": Color8(66, 92, 168)},
	"hunter": {"body": Color8(110, 126, 70), "trim": Color8(120, 84, 50), "legs": Color8(100, 84, 58), "boots": Color8(96, 66, 44),
		"hair": Color8(126, 82, 46), "head": "feather", "hc": Color8(116, 86, 54), "plume": Color8(200, 70, 60), "main": "longbow", "back": "quiver", "cape": Color8(90, 104, 60)},
	"sniper": {"body": Color8(68, 78, 96), "trim": Color8(176, 60, 56), "legs": Color8(58, 62, 74), "boots": Color8(52, 50, 58),
		"hair": Color8(46, 42, 52), "head": "short", "scarf": Color8(176, 60, 56), "main": "crossbow", "goggles": true},
	"wizard": {"body": Color8(56, 70, 150), "trim": Color8(228, 196, 90), "robe": true, "legs": Color8(46, 56, 118), "boots": Color8(60, 52, 80),
		"hair": Color8(224, 224, 232), "head": "hat", "hc": Color8(52, 64, 144), "star": true, "beard": Color8(232, 232, 238), "main": "staff", "orb": Color8(250, 210, 110)},
	"professor": {"body": Color8(64, 128, 118), "trim": Color8(214, 180, 80), "robe": true, "legs": Color8(52, 98, 92), "boots": Color8(80, 64, 54),
		"hair": Color8(232, 232, 236), "head": "short", "glasses": true, "main": "book", "bc": Color8(120, 70, 50)},
	"bandit": {"body": Color8(126, 92, 62), "trim": Color8(84, 62, 46), "legs": Color8(84, 70, 60), "boots": Color8(70, 52, 42),
		"hair": Color8(70, 52, 42), "head": "bandana", "hc": Color8(176, 64, 58), "main": "dagger", "off": "dagger"},
	"assassin": {"body": Color8(56, 46, 70), "trim": Color8(140, 60, 80), "legs": Color8(46, 40, 58), "boots": Color8(40, 36, 48),
		"hair": Color8(40, 36, 48), "head": "hood", "hc": Color8(50, 42, 64), "mask": Color8(40, 34, 50), "main": "dagger", "off": "dagger", "cape": Color8(46, 38, 60)},
	"priest": {"body": Color8(234, 230, 220), "trim": Color8(214, 176, 70), "robe": true, "legs": Color8(210, 204, 190), "boots": Color8(150, 120, 80),
		"hair": Color8(170, 126, 80), "head": "mitre", "hc": Color8(236, 232, 222), "main": "cross_staff", "cape": Color8(214, 176, 70)},
	"monk": {"body": Color8(214, 130, 60), "trim": Color8(120, 70, 46), "legs": Color8(190, 112, 54), "boots": Color8(120, 84, 60),
		"hair": Color8(160, 120, 90), "head": "bald", "main": "fists", "skinarm": true},
}
const ORDER := ["warrior", "archer", "mage", "thief", "acolyte", "berserker", "paladin", "hunter", "sniper",
	"wizard", "professor", "bandit", "assassin", "priest", "monk"]


## Герой: dir 0 вниз, 1 вниз-вбок, 2 вбок (вправо), 3 вверх-вбок, 4 вверх; fr 0–3 — шаг.
func hero(name: String, cx: int, base: int, dir: int, fr: int) -> void:
	var h: Dictionary = HEROES[name]
	var back := dir >= 3
	var side := dir == 2
	var fx: int = [0, 3, 5, 3, 0][dir]
	var bob: int = [0, -1, 0, -1][fr]
	ground_shadow(cx + 3, base - 1, 9, 3, 0.3)
	var hand_main: Vector2i
	var hand_off: Vector2i
	match dir:
		0:
			hand_main = Vector2i(cx - 9, base - 11 + bob)
			hand_off = Vector2i(cx + 9, base - 11 + bob)
		1:
			hand_main = Vector2i(cx - 7, base - 11 + bob)
			hand_off = Vector2i(cx + 10, base - 11 + bob)
		2:
			hand_main = Vector2i(cx + 5 + (1 if fr == 1 else (-1 if fr == 3 else 0)), base - 11 + bob)
			hand_off = Vector2i(cx - 3, base - 12 + bob)
		_:
			hand_main = Vector2i(cx + 9, base - 11 + bob)
			hand_off = Vector2i(cx - 9, base - 11 + bob)
	# 1. Сзади: плащ (вид спереди), оружие и вторая рука (вид сзади), колчан (вид спереди).
	if h.has("cape") and not back:
		_cape(h, cx, base, dir, bob, false)
	if not back and h.has("back"):
		_back_item(h, cx, base, dir, bob)
	if back:
		_weapon(h, str(h.get("main", "")), hand_main, dir, true, bob)
	elif side and h.has("off"):
		_weapon(h, str(h["off"]), hand_off, dir, true, bob)
	# 2. Ноги.
	_legs(h, cx, base, dir, fr, bob)
	# 3. Туловище и руки.
	_torso(h, cx, base, dir, fr, bob)
	# 4. Голова.
	_head(h, cx + (fx * 2) / 5, base - 27 + bob, dir)
	# 5. Спереди: плащ и колчан (вид сзади), оружие.
	if back and h.has("cape"):
		_cape(h, cx, base, dir, bob, true)
	if back and h.has("back"):
		_back_item(h, cx, base, dir, bob)
	if not back:
		_weapon(h, str(h.get("main", "")), hand_main, dir, false, bob)
		if h.has("off") and not side:
			_weapon(h, str(h["off"]), hand_off, dir, false, bob)
	elif h.has("off"):
		_weapon(h, str(h["off"]), hand_off, dir, false, bob)


func _legs(h: Dictionary, cx: int, base: int, dir: int, fr: int, _bob: int) -> void:
	var lp := p5(h["legs"])
	var bp := p5(h["boots"])
	var xs: Array
	if dir == 2:
		var sw: int = [0, 2, 0, -2][fr]
		xs = [[cx - 2 - sw, true], [cx - 1 + sw, false]]
	else:
		var lift_l: int = 1 if fr == 1 else 0
		var lift_r: int = 1 if fr == 3 else 0
		xs = [[cx - 5, lift_l == 1], [cx + 2, lift_r == 1]]
	for e: Array in xs:
		var x: int = e[0]
		var up: bool = e[1]
		var leg := {}
		var y0 := base - 9
		var y1 := base - 1 - (1 if up and dir != 2 else 0)
		for y in range(y0, y1 + 1):
			for xx in 4:
				var c: Color = lp[1] if xx < 2 else lp[2]
				if xx == 0:
					c = lp[0]
				if y >= y1 - 2:
					c = bp[1] if xx < 2 else bp[2]
					if y == y1 - 2:
						c = bp[0]
				leg[Vector2i(x + xx, y)] = c
		if dir == 2 and up:
			for k: Vector2i in leg.keys():
				leg[k] = (leg[k] as Color).darkened(0.25)
		blit(leg)


func _torso(h: Dictionary, cx: int, base: int, dir: int, fr: int, bob: int) -> void:
	var bp := p5(h["body"])
	var tp := p5(h["trim"])
	var side := dir == 2
	var robe: bool = h.get("robe", false)
	var w := 13 if not side else 9
	var x0 := cx - w / 2 + (1 if side else 0)
	var y0 := base - 20 + bob
	var y1 := base - 9 + bob + (5 if robe else 0)
	var t := {}
	for y in range(y0, y1):
		var spread := 0
		if robe:
			spread = maxi(0, (y - (base - 12 + bob)) / 2)
		for x in range(x0 - spread, x0 + w + spread):
			var u := float(x - x0 + spread) / (w + spread * 2)
			var c: Color = bp[1] if u < 0.55 else (bp[2] if u < 0.85 else bp[3])
			if u < 0.15:
				c = bp[0]
			if y == y0:
				c = bp[0]
			t[Vector2i(x, y)] = c
	# Латы: нагрудник светлее, полоса-блик.
	if h.get("armor", false) and dir <= 2:
		var ap: Array = STEEL
		for y in range(y0 + 1, y0 + 8):
			for x in range(x0 + 2, x0 + w - 2):
				var u := float(x - x0 - 2) / (w - 4)
				t[Vector2i(x, y)] = ap[0] if u < 0.25 else (ap[1] if u < 0.65 else ap[2])
		t[Vector2i(x0 + 3, y0 + 2)] = Color8(250, 252, 255)
	# Пояс.
	if true:
		var by := base - 12 + bob
		for x in range(x0 - (1 if robe else 0), x0 + w + (1 if robe else 0)):
			if t.has(Vector2i(x, by)):
				t[Vector2i(x, by)] = tp[1]
				t[Vector2i(x, by + 1)] = tp[3]
		if dir <= 1:
			t[Vector2i(cx + (dir * 2) - 1, by)] = tp[0]
			t[Vector2i(cx + (dir * 2), by)] = tp[0]
	# Отделка по низу мантии.
	if robe:
		for k: Vector2i in t.keys():
			if not t.has(k + Vector2i(0, 1)):
				t[k] = tp[1]
	# Шарф снайпера.
	if h.has("scarf"):
		var sp := p5(h["scarf"])
		for x in range(x0, x0 + w):
			t[Vector2i(x, y0)] = sp[0]
			t[Vector2i(x, y0 + 1)] = sp[2]
		if dir <= 2:
			for y in range(y0 + 2, y0 + 7):
				t[Vector2i(x0 + w - 3, y)] = sp[1]
				t[Vector2i(x0 + w - 2, y)] = sp[2]
	blit(t)
	# Руки (у бойцов без рукавов — кожа).
	var arm_c := SKIN if h.get("skinarm", false) else bp
	var sw: int = [0, 1, 0, -1][fr]
	var arms: Array = []
	if side:
		arms = [[cx + 2 + sw, false]]
	else:
		arms = [[x0 - 3, false], [x0 + w, true]]
	for a: Array in arms:
		var ax: int = a[0]
		var right: bool = a[1]
		var s := sw if not right else -sw
		if dir >= 3:
			s = -s
		var arm := {}
		for y in range(y0 + 1, base - 10 + bob + s):
			for xx in 3:
				arm[Vector2i(ax + xx, y)] = arm_c[0] if xx == 0 else (arm_c[1] if xx == 1 else arm_c[2])
		# Кисть.
		for xx in 3:
			arm[Vector2i(ax + xx, base - 10 + bob + s)] = SKIN[1] if xx < 2 else SKIN[2]
			arm[Vector2i(ax + xx, base - 9 + bob + s)] = SKIN[2]
		blit(arm)


func _head(h: Dictionary, hx: int, hy: int, dir: int) -> void:
	var hp := p5(h["hair"])
	var kind: String = h.get("head", "short")
	var back := dir >= 3
	var side := dir == 2
	var fo: float = [0.0, 0.3, 0.55, 0.3, 0.0][dir]   # сдвиг лица вправо (доля радиуса)
	var hd := {}
	var rx := 9.0
	var ry := 8.5
	for y in range(int(hy - ry) - 1, int(hy + ry) + 2):
		for x in range(int(hx - rx) - 1, int(hx + rx) + 2):
			var dx := (x + 0.5 - hx) / rx
			var dy := (y + 0.5 - hy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var skin_here := false
			if not back:
				var fdx := dx - fo
				skin_here = dy > -0.25 and absf(fdx) < 0.82 and not (side and dx < -0.15)
				if kind == "bald":
					skin_here = true
			var pal: Array = SKIN if skin_here else hp
			var c := ball_tone(dx, dy, 8.0, pal)
			# Чёлка: прядки по краю волос над лицом.
			if not back and not skin_here and dy > -0.45 and kind != "bald" and posmod(x, 3) == 0:
				c = hp[2]
			hd[Vector2i(x, y)] = c
	blit(hd)
	if not back:
		_face(h, hx, hy, dir, fo, rx)
	_headgear(h, hx, hy, dir, kind, fo)


func _face(h: Dictionary, hx: int, hy: int, dir: int, fo: float, rx: float) -> void:
	var ex := hx + int(fo * rx)
	var eyes: Array = [ex - 4, ex + 3] if dir == 0 else ([ex - 3, ex + 3] if dir == 1 else [ex + 2])
	for x: int in eyes:
		for i in 3:
			put(x, hy + 1 + i, EYE)
			put(x + 1, hy + 1 + i, EYE)
		put(x, hy + 1, Color8(250, 246, 236))
	# Румянец и рот.
	if dir == 0:
		put(ex - 6, hy + 4, SKIN[2].lerp(Color8(220, 120, 110), 0.5))
		put(ex + 6, hy + 4, SKIN[2].lerp(Color8(220, 120, 110), 0.5))
		put(ex, hy + 5, SKIN[3])
	if h.has("mask"):
		var mp := p5(h["mask"])
		for y in range(hy + 4, hy + 8):
			for x in range(ex - 7, ex + 7):
				if Vector2((x + 0.5 - hx) / 9.0, (y + 0.5 - hy) / 8.5).length() < 1.0 and not (dir == 2 and x < hx - 1):
					put(x, y, mp[1] if y == hy + 4 else mp[2])
	if h.get("glasses", false):
		for x: int in eyes:
			for k: Vector2i in [Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, 3), Vector2i(2, 3), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 4), Vector2i(1, 4)]:
				put(x + k.x, hy + 1 + k.y, Color8(200, 170, 80))
	if h.get("goggles", false):
		for x: int in eyes:
			for k: Vector2i in [Vector2i(-1, -1), Vector2i(2, -1), Vector2i(-1, 3), Vector2i(2, 3)]:
				put(x + k.x, hy + 1 + k.y, Color8(70, 66, 70))
	if h.has("beard"):
		var bp := p5(h["beard"])
		var bd := {}
		for y in range(hy + 4, hy + 12):
			var half := 6 - (y - hy - 4) * 3 / 4
			for x in range(ex - half, ex + half + 1):
				if not (dir == 2 and x < hx):
					bd[Vector2i(x, y)] = bp[1] if x < ex else bp[2]
		blit(bd)


func _headgear(h: Dictionary, hx: int, hy: int, dir: int, kind: String, fo: float) -> void:
	var back := dir >= 3
	var c: Color = h.get("hc", h["hair"])
	var cp := p5(c)
	var g := {}
	match kind:
		"hood":
			for y in range(hy - 10, hy + 7):
				for x in range(hx - 11, hx + 12):
					var dx := (x + 0.5 - hx) / 10.5
					var dy := (y + 0.5 - hy + 1) / 9.5
					if dx * dx + dy * dy > 1.0:
						continue
					var fdx := dx - fo * 0.9
					if not back and dy > -0.35 and absf(fdx) < 0.7 and not (dir == 2 and dx < -0.1):
						continue   # вырез для лица
					g[Vector2i(x, y)] = ball_tone(dx, dy, 9.0, cp)
		"hat", "mitre":
			# Поля / обод и высокий конус.
			var tall := 13 if kind == "hat" else 11
			for x in range(hx - (12 if kind == "hat" else 8), hx + (13 if kind == "hat" else 9)):
				g[Vector2i(x, hy - 5)] = cp[1]
				g[Vector2i(x, hy - 4)] = cp[3]
			for y in range(hy - 5 - tall, hy - 5):
				var t := float(y - (hy - 5 - tall)) / tall
				var half := int(lerpf(1.0, 7.0, t)) if kind == "hat" else int(lerpf(3.0, 7.0, t))
				var tip := int((1.0 - t) * 4.0) if kind == "hat" else 0
				for x in range(hx - half + tip, hx + half + 1 + tip):
					var u := float(x - (hx - half + tip)) / (half * 2 + 1)
					g[Vector2i(x, y)] = cp[0] if u < 0.25 else (cp[1] if u < 0.65 else cp[2])
			if kind == "mitre":
				var tp := p5(h["trim"])
				for y in range(hy - 15, hy - 5):
					g[Vector2i(hx, y)] = tp[1]
				for x in range(hx - 3, hx + 4):
					g[Vector2i(x, hy - 11)] = tp[1]
			if h.get("star", false) and not back:
				for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					g[Vector2i(hx + 1, hy - 10) + k] = Color8(250, 214, 110)
		"helm", "horned":
			for y in range(hy - 9, hy + (2 if kind == "helm" else -1)):
				for x in range(hx - 10, hx + 11):
					var dx := (x + 0.5 - hx) / 10.0
					var dy := (y + 0.5 - hy + 1) / 9.0
					if dx * dx + dy * dy > 1.0:
						continue
					if not back and y > hy - 3 and kind == "helm" and absf(dx - fo) < 0.55:
						continue
					g[Vector2i(x, y)] = ball_tone(dx, dy, 9.0, STEEL if kind == "helm" else cp)
			if kind == "horned":
				for s: int in ([-1, 1] if dir != 2 else [1]):
					var hb := Vector2(hx + s * 9, hy - 4)
					for i in 9:
						var q := hb + Vector2(s * (i * 0.6), -i * 1.1 + i * i * 0.04)
						g[Vector2i(int(q.x), int(q.y))] = BONEP[0] if i < 5 else BONEP[1]
						g[Vector2i(int(q.x), int(q.y) + 1)] = BONEP[2]
			if h.has("plume"):
				var pp := p5(h["plume"])
				for i in 8:
					var q := Vector2(hx - 1 - (i if back else -i * 0) * 0.0, hy - 10 - i * 0.6)
					for xx in 3:
						g[Vector2i(int(q.x) + xx - (i / 2 if dir != 4 else 0), int(q.y))] = pp[0] if xx == 0 else pp[2]
		"feather":
			# Шляпа с полями и пером.
			for x in range(hx - 12, hx + 13):
				g[Vector2i(x, hy - 4)] = cp[1]
				g[Vector2i(x, hy - 3)] = cp[3]
			for y in range(hy - 11, hy - 4):
				for x in range(hx - 7, hx + 8):
					var u := float(x - hx + 7) / 15.0
					g[Vector2i(x, y)] = cp[0] if u < 0.25 else (cp[1] if u < 0.65 else cp[2])
			var pp := p5(h["plume"])
			for i in 10:
				g[Vector2i(hx + 5 + i / 2, hy - 8 - i)] = pp[0] if i % 3 == 0 else pp[1]
				g[Vector2i(hx + 6 + i / 2, hy - 8 - i)] = pp[2]
		"bandana":
			for y in range(hy - 8, hy - 2):
				for x in range(hx - 9, hx + 10):
					var dx := (x + 0.5 - hx) / 9.5
					var dy := (y + 0.5 - hy) / 8.5
					if dx * dx + dy * dy <= 1.0:
						g[Vector2i(x, y)] = cp[1] if y < hy - 4 else cp[2]
			if dir >= 2:
				for i in 5:
					g[Vector2i(hx - 9 - i / 2, hy - 4 + i)] = cp[2]
		"short", "bald":
			pass
	if not g.is_empty():
		blit(g)


func _cape(h: Dictionary, cx: int, base: int, dir: int, bob: int, front: bool) -> void:
	var cp := p5(h["cape"])
	var g := {}
	var w := 16 if dir != 2 else 8
	var x0 := cx - w / 2 - (4 if dir == 2 else 0)
	for y in range(base - 21 + bob, base - 3):
		var spread := (y - (base - 21 + bob)) / 6
		for x in range(x0 - spread, x0 + w + spread):
			var u := float(x - x0 + spread) / (w + spread * 2)
			var c: Color = cp[1] if u < 0.5 else cp[2]
			if posmod(x - cx, 5) == 0 and y > base - 17:
				c = cp[3]
			g[Vector2i(x, y)] = c if front else c.darkened(0.15)
	blit(g)


func _back_item(h: Dictionary, cx: int, base: int, dir: int, bob: int) -> void:
	if str(h["back"]) != "quiver":
		return
	var q := {}
	var x0 := cx + (4 if dir < 3 else -7) - (6 if dir == 2 else 0)
	for y in range(base - 24 + bob, base - 10 + bob):
		for xx in 4:
			q[Vector2i(x0 + xx, y)] = WOODP[1] if xx < 2 else WOODP[2]
	for i in 3:
		q[Vector2i(x0 + i, base - 26 + bob)] = Color8(236, 232, 220)
		q[Vector2i(x0 + i, base - 25 + bob)] = Color8(196, 70, 60)
	blit(q)


## Оружие и предметы второй руки. far — за телом (темнее).
func _weapon(h: Dictionary, kind: String, hand: Vector2i, dir: int, far: bool, _bob: int) -> void:
	var g := {}
	var dk := 0.25 if far else 0.0
	var steel: Array = STEEL.map(func(c: Color) -> Color: return c.darkened(dk))
	var wood: Array = WOODP.map(func(c: Color) -> Color: return c.darkened(dk))
	var hx := hand.x
	var hy := hand.y
	match kind:
		"sword":
			for y in range(hy - 16, hy - 1):
				g[Vector2i(hx, y)] = steel[0]
				g[Vector2i(hx + 1, y)] = steel[2]
			g[Vector2i(hx, hy - 17)] = steel[1]
			for x in range(hx - 3, hx + 5):
				g[Vector2i(x, hy - 1)] = GOLDP[1] if x < hx + 1 else GOLDP[2]
			for y in range(hy, hy + 3):
				g[Vector2i(hx, y)] = wood[2]
				g[Vector2i(hx + 1, y)] = wood[3]
		"dagger":
			for y in range(hy - 7, hy - 1):
				g[Vector2i(hx, y)] = steel[0]
				g[Vector2i(hx + 1, y)] = steel[2]
			for x in range(hx - 1, hx + 3):
				g[Vector2i(x, hy - 1)] = wood[2]
			g[Vector2i(hx, hy)] = wood[3]
		"axe":
			for y in range(hy - 16, hy + 3):
				g[Vector2i(hx, y)] = wood[1]
				g[Vector2i(hx + 1, y)] = wood[3]
			for y in range(hy - 17, hy - 8):
				var t := absf(y - (hy - 12.5)) / 4.5
				var wdt := int(7 - t * 3)
				for x in range(hx - wdt - 1, hx):
					g[Vector2i(x, y)] = steel[0] if x == hx - wdt - 1 else (steel[1] if x < hx - 3 else steel[2])
		"mace":
			for y in range(hy - 10, hy + 3):
				g[Vector2i(hx, y)] = wood[1]
				g[Vector2i(hx + 1, y)] = wood[3]
			var m := {}
			ball(m, hx + 0.5, hy - 12, 3.5, 3.5, steel)
			for k: Vector2i in [Vector2i(0, -5), Vector2i(-4, -1), Vector2i(4, -1), Vector2i(0, 3)]:
				m[Vector2i(hx, hy - 12) + k] = steel[3]
			blit(g)
			blit(m)
			return
		"staff", "cross_staff":
			for y in range(hy - 24, hy + 6):
				g[Vector2i(hx, y)] = wood[0]
				g[Vector2i(hx + 1, y)] = wood[2]
			if kind == "cross_staff":
				for x in range(hx - 3, hx + 5):
					g[Vector2i(x, hy - 20)] = GOLDP[1]
				for y in range(hy - 26, hy - 15):
					g[Vector2i(hx, y)] = GOLDP[0]
					g[Vector2i(hx + 1, y)] = GOLDP[2]
			else:
				blit(g)
				var oc: Color = h.get("orb", Color8(140, 210, 240))
				glow(hx + 1, hy - 27, 7, oc, 0.3)
				var o := {}
				ball(o, hx + 1, hy - 27, 3.5, 3.5, p5(oc))
				blit(o)
				return
		"bow", "longbow":
			var blen := 11 if kind == "bow" else 13
			var bx := hx + (3 if dir == 2 else (-2 if dir <= 1 else 2))
			for i in range(-blen, blen + 1):
				var t := float(i) / blen
				var x := bx + int((1.0 - t * t) * 4.0) * (1 if dir != 4 else -1)
				g[Vector2i(x, hy - 4 + i)] = wood[1]
				g[Vector2i(x + 1, hy - 4 + i)] = wood[3]
			for i in range(-blen + 1, blen):
				g[Vector2i(bx - 1, hy - 4 + i)] = Color8(230, 226, 214).darkened(dk)
		"crossbow":
			for x in range(hx - 5, hx + 7):
				g[Vector2i(x, hy - 2)] = wood[1]
				g[Vector2i(x, hy - 1)] = wood[3]
			for y in range(hy - 6, hy + 3):
				g[Vector2i(hx + 5, y)] = steel[1]
			g[Vector2i(hx + 7, hy - 2)] = steel[0]
		"shield", "tower":
			var sc: Color = h.get("sc", Color8(70, 100, 170))
			var sp: Array = p5(sc.darkened(dk))
			var s := {}
			if kind == "shield":
				ball(s, hx + 1, hy - 3, 6, 7, sp)
				for x in range(hx - 5, hx + 8):
					if s.has(Vector2i(x, hy - 3)):
						s[Vector2i(x, hy - 3)] = GOLDP[1]
				for y in range(hy - 9, hy + 4):
					if s.has(Vector2i(hx + 1, y)):
						s[Vector2i(hx + 1, y)] = GOLDP[1]
			else:
				for y in range(hy - 12, hy + 5):
					for x in range(hx - 4, hx + 7):
						var u := float(x - hx + 4) / 11.0
						s[Vector2i(x, y)] = sp[0] if u < 0.2 else (sp[1] if u < 0.7 else sp[2])
				for y in range(hy - 9, hy + 2):
					s[Vector2i(hx + 1, y)] = GOLDP[1]
				for x in range(hx - 2, hx + 5):
					s[Vector2i(x, hy - 5)] = GOLDP[1]
			if dir >= 3:
				for k: Vector2i in s.keys():
					s[k] = wood[2] if posmod(k.y, 3) != 0 else wood[3]   # обратная сторона — доски
			blit(s)
			return
		"book":
			var bc: Color = h.get("bc", Color8(140, 70, 50))
			var bp: Array = p5(bc.darkened(dk))
			for y in range(hy - 6, hy + 2):
				for x in range(hx - 3, hx + 4):
					g[Vector2i(x, y)] = bp[1] if x < hx + 2 else bp[3]
			for y in range(hy - 5, hy + 1):
				g[Vector2i(hx + 2, y)] = Color8(236, 228, 206)
			g[Vector2i(hx - 1, hy - 3)] = GOLDP[1]
			g[Vector2i(hx, hy - 3)] = GOLDP[1]
		"fists":
			for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
				put(hx + k.x, hy + 1, Color8(236, 228, 206))
			return
		_:
			return
	blit(g)
