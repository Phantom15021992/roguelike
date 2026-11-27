extends "res://tools/dungeon_art.gd"
## Образец первого биома подземелья в утверждённом стиле (в игру пока не вставлено):
## зал с плитами, скалы по краям, колонна, кристаллы, грибы, корни, лестница вниз и все монстры
## первого биома. Плюс лист монстров крупно (вниз / вбок / вверх и кадры анимации).
##   godot --headless --path . --script res://tools/sample_dungeon.gd
## Выход: shots/dungeon_sample.png (+_x2), shots/dungeon_monsters.png (+_x4).

const SW := 640
const SH := 400
const FACE := 0   # обрывов-стен нет (решение владельца): только верх скал
var mask := PackedByteArray()   # 1 — пол
var objects: Array = []


func _init() -> void:
	_scene()
	_sheet()
	print("sample_dungeon: done")
	quit()


func add(base_y: float, f: Callable) -> void:
	objects.append([base_y, f])


func is_floor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= SW or y >= SH:
		return false
	return mask[y * SW + x] == 1


func _shape(x: int, y: int) -> bool:
	var n := nz.get_noise_2d(x * 0.7, y * 0.7) * 18.0
	var dx := absf(x - 300.0) / (250.0 + n)
	var dy := absf(y - 222.0) / (138.0 + n)
	if pow(dx, 4.0) + pow(dy, 4.0) < 1.0:
		return true
	if x > 470 and absf(y - 214.0) < 34.0 + n * 0.5:
		return true                                  # коридор вправо
	if absf(x - 132.0) < 32.0 + n * 0.5 and y < 140:
		return true                                  # коридор вверх
	return false


func _scene() -> void:
	setup(SW, SH)
	mask.resize(SW * SH)
	for y in SH:
		for x in SW:
			mask[y * SW + x] = 1 if _shape(x, y) else 0
	for y in SH:
		for x in SW:
			if is_floor(x, y):
				var c := slab(x, y)
				# Тень от скалы вправо и под обрывчиком.
				var sh := 0.0
				for k in range(1, 9):
					if not is_floor(x - k, y):
						sh = maxf(sh, 0.32 - k * 0.025)
						break
				for k in range(1, 5):
					if not is_floor(x, y - k):
						sh = maxf(sh, 0.34 - k * 0.05)
						break
				put(x, y, c.darkened(sh))
				continue
			var below := 0
			for k in range(1, FACE + 1):
				if is_floor(x, y + k):
					below = k
					break
			if below > 0:
				put(x, y, rock_face(x, y, FACE - below, FACE))
				continue
			var c2 := rock_top(x, y)
			# Край скалы у пола скруглён: со стороны пола снизу и справа — тёмная полоса,
			# сверху и слева — светлая кромка; по самому краю — контур.
			if c2 != CREV:
				for k in range(2, 4):
					if is_floor(x, y + k) or is_floor(x + k, y):
						c2 = ROCKD[4]
						break
					if is_floor(x, y - k) or is_floor(x - k, y):
						c2 = ROCKD[0]
						break
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if is_floor(x + d.x, y + d.y):
					c2 = OUT
			# Светлая кромка верха скалы над обрывом.
			put(x, y, c2)
	_props()
	objects.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	for o: Array in objects:
		(o[1] as Callable).call()
	save("dungeon_sample", 2)


func _props() -> void:
	# Корни из скалы.
	add(96, func() -> void: root(220, 92, 34, 0.4, 3))
	add(100, func() -> void: root(410, 96, 28, -0.5, 7))
	# Трутовики на обрывчиках.
	add(95, func() -> void: tinder(300, 84, 3))
	add(330, func() -> void: tinder(560, 166, 2))
	# Кристаллы у скал и в породе.
	add(108, func() -> void: crystals(470, 108, 8.0, 5))
	add(372, func() -> void: crystals(90, 340, 7.0, 3))
	add(30, func() -> void: crystals(40, 30, 7.0, 8))
	add(380, func() -> void: crystals(560, 388, 8.0, 6))
	add(60, func() -> void: crystals(330, 40, 6.0, 4))
	# Грибочки, камешки, кости.
	add(122, func() -> void: shrooms(180, 122, 1))
	add(330, func() -> void: shrooms(470, 330, 2))
	for p: Vector3i in [Vector3i(260, 150, 3), Vector3i(266, 156, 2), Vector3i(420, 300, 3), Vector3i(150, 260, 2), Vector3i(380, 140, 2), Vector3i(530, 238, 3)]:
		var q := p
		add(q.y, func() -> void: pebble(q.x, q.y, q.z, q.x))
	add(318, func() -> void: bones(220, 318))
	# Колонна.
	add(250, func() -> void: pillar(330, 250, 14, 28))
	# Лестница вниз.
	add(300, func() -> void: stairs(498, 266, 48, 40))
	# Монстры.
	var mons := [["slime", 150, 200, 0, 0], ["slime", 186, 214, 1, 1], ["slime_splitter", 420, 210, 0, 0],
		["bat", 250, 270, 0, 0], ["vampire_bat", 560, 220, 1, 1], ["wisp", 410, 360, 0, 0],
		["mushroom", 120, 320, 0, 0], ["bomb_shroom", 300, 350, 0, 1]]
	for m: Array in mons:
		var kind: String = m[0]
		var mx: int = m[1]
		var my: int = m[2]
		var md: int = m[3]
		var mf: int = m[4]
		add(my, func() -> void: monster(kind, mx, my, md, mf))


## Лист монстров: строка — монстр; столбцы — вниз, вбок, вверх (кадр 0) и остальные кадры вниз.
func _sheet() -> void:
	var cell := 56
	var cols := 7
	var rows := MONSTERS.size()
	setup(cols * cell, rows * cell)
	floor_rect(0, 0, cols * cell, rows * cell)
	# Тёмные рамки клеток.
	for r in rows:
		for c in cols:
			for i in cell:
				put(c * cell + i, r * cell, SEAM.darkened(0.3))
				put(c * cell, r * cell + i, SEAM.darkened(0.3))
	var r := 0
	for kind: String in MONSTERS:
		var frames: int = MONSTERS[kind]
		var list: Array = [[0, 0], [1, 0], [2, 0]]
		for f in range(1, frames):
			list.append([0, f])
			list.append([1, f])
		for i in mini(list.size(), cols):
			var e: Array = list[i]
			monster(kind, i * cell + cell / 2, r * cell + cell - 4, e[0], e[1])
		r += 1
	save("dungeon_monsters", 4)
