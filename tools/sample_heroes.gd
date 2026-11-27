extends "res://tools/hero_art.gd"
## Образец героев: 3 ряда по 5 — все классы и профессии лицом вниз; ниже — 5 сторон каждого
## базового класса и 4 кадра шага мечника.
##   godot --headless --path . --script res://tools/sample_heroes.gd  → shots/heroes_sample(_x4).png


func _init() -> void:
	var cell := 52
	var cols := 5
	setup(cols * cell, 9 * cell)
	floor_rect(0, 0, cols * cell, 9 * cell)
	for i in ORDER.size():
		hero(ORDER[i], (i % 5) * cell + cell / 2, (i / 5) * cell + cell - 4, 0, 0)
	for c in 5:
		for d in 5:
			hero(ORDER[c], d * cell + cell / 2, (3 + c) * cell + cell - 4, d, 0)
	for f in 4:
		hero("warrior", f * cell + cell / 2, 8 * cell + cell - 4, 0, f * 2)
	hero("warrior", 4 * cell + cell / 2, 8 * cell + cell - 4, 2, 2)
	save("heroes_sample", 3)
	print("sample_heroes: done")
	quit()
