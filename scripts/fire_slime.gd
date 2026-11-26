extends "res://scripts/slime.gd"
## Огненный слизень (Огненные пещеры, 26–30): где приземлится — там загорается земля.

const FIRE := Color(1.0, 0.45, 0.15)
var _was_hopping := false


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.45, 0.65, 0.35)


func _think(delta: float) -> Vector2:
	var v := super._think(delta)
	if _was_hopping and not _hopping:
		spawn_puddle(global_position, 11.0, 3.0, scaled(5), FIRE)
	_was_hopping = _hopping
	return v
