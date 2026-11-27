extends "res://tools/camp_art.gd"
## Вид всего лагеря в утверждённом стиле (картинка-превью, в игру пока не вставлено):
## все постройки построены, раскладка — scripts/camp_layout.gd (клетка 16 px мира = 32 px картинки).
## Рисунки построек и мелочей — tools/camp_art.gd, правила стиля — .claude/skills/pixel-style.
##   godot --headless --path . --script res://tools/camp_preview.gd
## Выход: shots/camp_preview.png (1:1) и shots/camp_preview_x2.png.


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

func add(base_y: float, f: Callable) -> void:
	objects.append([base_y, f])


# ===================================================================================
#                                    ЗЕМЛЯ
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
