extends SceneTree
## Лист-превью картинок папки: godot --headless --path . --script res://tools/contact.gd -- папка out.png [кол-во_в_ряд] [клетка]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var out: String = a[1]
	var cols := int(a[2]) if a.size() > 2 else 8
	var cell := int(a[3]) if a.size() > 3 else 200
	var files: Array = []
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			files.append(f)
	files.sort()
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * (cell + 14), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in files.size():
		var im := Image.load_from_file(dir + "/" + files[i])
		if im == null:
			continue
		im.convert(Image.FORMAT_RGBA8)
		var s := minf(cell / float(im.get_width()), cell / float(im.get_height()))
		im.resize(maxi(1, int(im.get_width() * s)), maxi(1, int(im.get_height() * s)), Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % cols) * cell, (i / cols) * (cell + 14) + 14))
		print(i, " ", files[i])
	sheet.save_png(out)
	quit()
