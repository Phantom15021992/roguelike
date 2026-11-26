extends "res://scripts/wisp.gd"
## Огненный дух (Огненные пещеры, 26–30): плюётся веером из трёх огненных шаров.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.45, 0.7, 0.35)
	fire_cooldown = 2.8


func _fire(dir: Vector2) -> void:
	for a: float in [-0.3, 0.0, 0.3]:
		spawn_shot(dir.rotated(a), scaled(16), 80.0, Color(1.0, 0.5, 0.2), "fireball")
