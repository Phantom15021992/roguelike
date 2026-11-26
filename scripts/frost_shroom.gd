extends "res://scripts/mushroom.gd"
## Морозный гриб (Ледяные пещеры, 36–40): облако больше и почти не ранит, но сильно замедляет.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.7, 0.95, 1.45)


func _release_cloud() -> void:
	spawn_puddle(global_position, 36.0, 4.0, maxi(1, int(cloud_damage / 3.0)), Color(0.6, 0.85, 1.0), 2.0)
	Game.burst(global_position + Vector2(0, -10), Color(0.7, 0.9, 1.0), 16)
