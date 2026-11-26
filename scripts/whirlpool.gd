extends "res://scripts/mushroom.gd"
## Водоворот (Затонувший храм): стоит на месте и затягивает героя к себе (течение); в самом
## центре ранит. Отходи против течения или разбей его издалека.

const PULL_RANGE := 95.0
var _spin := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.4, 0.75, 1.3)
	contact_radius = 12.0


func _think(delta: float) -> Vector2:
	_spin += delta
	sprite.rotation = sin(_spin * 6.0) * 0.3
	for pl in get_tree().get_nodes_in_group("player"):
		if pl.dead:
			continue
		var to: Vector2 = global_position - pl.global_position
		var d := to.length()
		if d < PULL_RANGE and d > 6.0:
			pl.move_and_collide(to.normalized() * 34.0 * (1.0 - d / PULL_RANGE + 0.3) * delta)
	if Engine.get_physics_frames() % 12 == 0:
		Game.burst(global_position + Vector2.from_angle(_spin * 4.0) * 20.0, Color(0.5, 0.8, 1.0), 1)
	return Vector2.ZERO


func _is_dangerous() -> bool:
	return true
