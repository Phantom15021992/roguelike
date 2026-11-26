extends "res://scripts/mushroom.gd"
## Светогриб (Хрустальные пещеры): вместо спор — вспышка света. Кто в ней окажется, на 3
## секунды почти слепнет (экран темнеет, видно только рядом с собой).


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.4, 1.3, 0.7)


func _release_cloud() -> void:
	Game.ring(global_position, 44.0, Color(1.0, 0.95, 0.6))
	Game.burst(global_position + Vector2(0, -10), Color(1.0, 1.0, 0.7), 20)
	for pl in get_tree().get_nodes_in_group("player"):
		if not pl.dead and pl.global_position.distance_to(global_position) < 44.0:
			pl.blind(3.0)
			pl.take_damage(maxi(1, int(cloud_damage / 2.0)), global_position)
