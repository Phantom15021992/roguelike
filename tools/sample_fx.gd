extends "res://tools/fx_art.gd"
## Образец эффектов магов (в игру пока не вставлено). Ряды:
## 1 магический снаряд (обычная атака) + попадание; 2 огненный шар + взрыв; 3 ледяная волна + попадание;
## 4 столб огня (огненная земля) ; 5 ледяная метель (вихрь); 6 грозовая молния;
## 7 цепная молния (3 кадра) и метеорит (3 кадра).
##   godot --headless --path . --script res://tools/sample_fx.gd  → shots/fx_sample(_x3).png


func _init() -> void:
	var c := 48
	var hs := [c, c, c, c * 2, c * 2, c * 2, c]
	var total := 0
	for v: int in hs:
		total += v
	setup(9 * c, total)
	floor_rect(0, 0, 9 * c, total)
	for y in total:
		for x in 9 * c:
			tint(x, y, 0.45)
	var y0 := 0
	# 1–3: снаряды и попадания.
	for i in 3:
		for f in 3:
			var cx := f * c + c / 2 + 6
			var cy := y0 + c / 2
			match i:
				0: comet(cx, cy, 4.5, ARCANE, f, 5)
				1: comet(cx, cy, 7.0, FIRE, f, 6)
				2: shard(cx, cy, 6.0, f)
		for f in 6:
			var cx := (3 + f) * c + c / 2
			var cy := y0 + c / 2
			match i:
				0: impact(cx, cy, 12.0, ARCANE, f)
				1: impact(cx, cy, 16.0, FIRE, f, "fire")
				2: impact(cx, cy, 14.0, ICEF, f, "ice")
		y0 += hs[i]
	# 4–6: столбы.
	for f in 6:
		flame_pillar(f * c + c / 2 + 12, y0 + c * 2 - 6, 70.0, f)
	y0 += hs[3]
	for f in 6:
		whirl(f * c + c / 2 + 12, y0 + c * 2 - 6, 78.0, ICEF, f)
	y0 += hs[4]
	for f in 6:
		lightning(f * c + c / 2 + 12, y0 + c * 2 - 6, 86.0, ARC, f)
	y0 += hs[5]
	# 7: цепная молния и метеорит.
	for f in 3:
		chain(Vector2(f * c * 2 / 1.5 + 6, y0 + c / 2), Vector2(f * c * 2 / 1.5 + 54, y0 + c / 2), BOLT, f)
	for f in 3:
		meteor((6 + f) * c + c / 2 + 4, y0 + c / 2 + 4, 6.0, f)
	save("fx_sample", 3)
	print("sample_fx: done")
	quit()
