extends "res://scripts/skeleton.gd"
## Демон (Бездна, 40+): как скелет-мечник, но крупнее, быстрее и сильнее.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.35, 0.5, 0.4)
	scale = Vector2(1.2, 1.2)
	speed *= 1.35
	swing_damage = int(swing_damage * 1.3)
