extends SceneTree
## Проверка правила владельца: объекты лагеря не пересекаются (касаться можно).
## Берёт спрайты из assets/camp/camp.json и раскладку scripts/camp_layout.gd (все постройки
## построены), рисует непрозрачные пиксели каждого (без теней) и сообщает пары, у которых
## есть общие пиксели. Лес по краям не проверяется.
##   godot --headless --path . --script res://tools/camp_check.gd

const LAY := preload("res://scripts/camp_layout.gd")


func _init() -> void:
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/camp/camp.json"))
	var objs: Array = []
	var lot_ids := ["library", "training", "forge", "infirmary", "mentor", "exchange", "treasury", "storage", "workshop"]
	for i in LAY.LOTS.size():
		objs.append(["b_" + lot_ids[i], (LAY.LOTS[i] as Vector2) * LAY.TILE])
	for id: String in LAY.FIXED:
		objs.append(["b_" + id, (LAY.FIXED[id] as Vector2) * LAY.TILE])
	for p: Array in LAY.PROPS:
		objs.append(["p_" + str(p[0]), (p[1] as Vector2) * LAY.TILE])
	var W := LAY.WIDTH * LAY.ART
	var H := LAY.HEIGHT * LAY.ART
	var owner := PackedInt32Array()
	owner.resize(W * H)
	owner.fill(-1)
	var hits := {}
	for i in objs.size():
		var name: String = objs[i][0]
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/camp/%s.png" % name))
		var an: Array = art["sprites"][name]["anchor"]
		var pos: Vector2 = objs[i][1]
		var ox := int(pos.x * LAY.ART - float(an[0]))
		var oy := int(pos.y * LAY.ART - float(an[1]))
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a < 0.9:
					continue
				var gx := ox + x
				var gy := oy + y
				if gx < 0 or gy < 0 or gx >= W or gy >= H:
					continue
				var o := owner[gy * W + gx]
				if o >= 0 and o != i:
					var key := "%s @%s  x  %s @%s" % [objs[o][0], objs[o][1] / LAY.TILE, name, pos / LAY.TILE]
					hits[key] = hits.get(key, 0) + 1
				owner[gy * W + gx] = i
	for k: String in hits:
		print("OVERLAP %s  (%d px)" % [k, hits[k]])
	print("camp_check: %d overlaps" % hits.size())
	quit()
