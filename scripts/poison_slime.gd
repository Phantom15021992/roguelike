extends "res://scripts/slime.gd"
## Ядовитый слизень (Ядовитые топи, 46–50): прыгает чаще, а после смерти лопается большой
## ядовитой лужей — добивать лучше издалека.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.6, 1.35, 0.4)
	speed = 60.0


func _die() -> void:
	spawn_puddle(global_position, 28.0, 5.0, scaled(6), Color(0.45, 0.85, 0.3))
	super._die()
