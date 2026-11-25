extends "res://scripts/bat.gd"
## Тень (Теневой лабиринт, 30+): полупрозрачная, быстрая, часто уворачивается.


func _setup() -> void:
	super._setup()
	speed *= 1.4
	sprite.self_modulate = Color(0.55, 0.4, 0.95, 0.75)
