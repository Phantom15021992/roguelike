extends "res://scripts/golem.gd"
## Ужас (Бездна, 40+): огромный голем бездны — бьёт сильнее, держит удары спереди.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.75, 0.45, 1.0)
	scale = Vector2(1.3, 1.3)
	slam_damage = int(slam_damage * 1.3)
	speed *= 1.2
