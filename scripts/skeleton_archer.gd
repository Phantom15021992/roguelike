extends "res://scripts/wisp.gd"
## Скелет-лучник (Катакомбы, 16–20): держится далеко и пускает по две быстрые стрелы.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.2, 1.15, 0.95)
	keep_distance = 95.0
	fire_range = 170.0
	fire_cooldown = 2.0


func _fire(dir: Vector2) -> void:
	for a: float in [-0.07, 0.07]:
		spawn_shot(dir.rotated(a), scaled(14), 140.0, Color(0.9, 0.88, 0.8), "arrow")
