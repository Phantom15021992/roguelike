extends "res://tools/dungeon_art.gd"
## Образец боссов первого биома: строка — босс, столбцы — вниз, вбок, вверх (+ кадры короля).
##   godot --headless --path . --script res://tools/sample_bosses.gd  → shots/dungeon_bosses(_x4).png


func _init() -> void:
	var cell := 104
	var cols := 5
	var rows := BOSSES.size()
	setup(cols * cell, rows * cell)
	floor_rect(0, 0, cols * cell, rows * cell)
	var r := 0
	for kind: String in BOSSES:
		var frames: int = BOSSES[kind]
		var list: Array = [[0, 0], [1, 0], [2, 0]]
		for f in range(1, frames):
			list.append([0, f])
		for i in list.size():
			var e: Array = list[i]
			boss(kind, i * cell + cell / 2, r * cell + cell - 6, e[0], e[1])
		r += 1
	save("dungeon_bosses", 3)
	print("sample_bosses: done")
	quit()
