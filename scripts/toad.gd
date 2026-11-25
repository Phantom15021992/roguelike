extends "res://scripts/imp.gd"
## Жаба-плевун (Ядовитые топи, 20+): как бес, но плюётся ядом — на земле остаётся ядовитая лужа.


func _setup() -> void:
	FIRE = Color(0.45, 0.85, 0.25)
	super._setup()
	sprite.self_modulate = Color(0.6, 1.2, 0.55)
