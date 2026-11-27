extends "res://tools/hero_art.gd"
## Листы героев для игры (утверждённый стиль): assets/hero2/<класс или профессия>.png —
## кадр 48x48 (24 мира, в игре масштаб 0.5), строки: вниз, вниз-вбок, вбок, вверх-вбок, вверх;
## 8 кадров шага (STEPS). Рисунки — tools/hero_art.gd.
##   godot --headless --path . --script res://tools/gen_heroes.gd   (затем --import)


func _init() -> void:
	var dir := "res://assets/hero2/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var fsz := 48
	for name: String in ORDER:
		var sheet := Image.create(STEPS * fsz, 5 * fsz, false, Image.FORMAT_RGBA8)
		for d in 5:
			for f in STEPS:
				setup(fsz, fsz)
				hero(name, fsz / 2, fsz - 3, d, f)
				sheet.blit_rect(img, Rect2i(0, 0, fsz, fsz), Vector2i(f * fsz, d * fsz))
		sheet.save_png(ProjectSettings.globalize_path(dir + name + ".png"))
	print("gen_heroes: %d sheets" % ORDER.size())
	quit()
