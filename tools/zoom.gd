extends SceneTree
## Крупный просмотр куска картинки (проверка пикселей):
##   godot --headless --path . --script res://tools/zoom.gd -- <вход.png> <выход.png> x y w h [масштаб=8]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img = img.get_region(Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5])))
	var k := int(a[6]) if a.size() > 6 else 8
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	img.save_png(a[1])
	quit()
