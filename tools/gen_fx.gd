extends "res://tools/fx_art.gd"
## Листы эффектов заклинаний для игры (рисунки — tools/fx_art.gd), прозрачный фон, кадры в ряд:
##   assets/fx/arcane_proj, fire_proj — снаряды (3 кадра 48x48, летят вправо, голова в (30, 24));
##   arcane_hit, fire_hit, ice_hit, bolt_hit — вспышки (6 кадров 48x48, центр (24, 24));
##   flame, whirl, lightning — столбы (6 кадров 48x96, основание в (24, 92));
##   meteor — падающий метеорит (3 кадра 48x48, голова в (32, 32)).
##   godot --headless --path . --script res://tools/gen_fx.gd   (затем --import)

const DIR := "res://assets/fx/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_strip("arcane_proj", 3, 48, func(f: int) -> void: comet(30, 24, 4.5, ARCANE, f, 5))
	_strip("fire_proj", 3, 48, func(f: int) -> void: comet(30, 24, 7.0, FIRE, f, 6))
	_strip("arcane_hit", 6, 48, func(f: int) -> void: impact(24, 24, 12.0, ARCANE, f))
	_strip("fire_hit", 6, 48, func(f: int) -> void: impact(24, 24, 16.0, FIRE, f, "fire"))
	_strip("ice_hit", 6, 48, func(f: int) -> void: impact(24, 24, 14.0, ICEF, f, "ice"))
	_strip("bolt_hit", 6, 48, func(f: int) -> void: impact(24, 24, 10.0, BOLT, f))
	_strip("flame", 6, 96, func(f: int) -> void: flame_pillar(24, 92, 70.0, f))
	_strip("whirl", 6, 96, func(f: int) -> void: whirl(24, 92, 78.0, ICEF, f))
	_strip("lightning", 6, 96, func(f: int) -> void: lightning(24, 92, 86.0, ARC, f))
	_strip("meteor", 3, 48, func(f: int) -> void: meteor(32, 32, 6.0, f))
	print("gen_fx: done")
	quit()


func _strip(name: String, n: int, h: int, draw: Callable) -> void:
	var sheet := Image.create(48 * n, h, false, Image.FORMAT_RGBA8)
	for f in n:
		setup(48, h)
		draw.call(f)
		sheet.blit_rect(img, Rect2i(0, 0, 48, h), Vector2i(f * 48, 0))
	sheet.save_png(ProjectSettings.globalize_path(DIR + name + ".png"))
