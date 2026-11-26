extends "res://scripts/mushroom.gd"
## Щупальце (Затонувший храм): торчит из пола. Если герой рядом — под ним появляется круг,
## и через миг оттуда бьёт щупальце. Не стой на месте.

var _warn: Node2D
var _hit := 0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.5, 0.7, 1.2)
	_hit = scaled(24)


func _think(delta: float) -> Vector2:
	_t -= delta
	var p := nearest_player()
	match state:
		"idle":
			if _t <= 0.0 and p and global_position.distance_to(p.global_position) < 85.0:
				state = "windup"
				_t = 0.9
				sprite.play("puff")
				_warn = spawn_warning(p.global_position, 16.0, Color(0.4, 0.6, 1.0))
		"windup":
			if is_instance_valid(_warn):
				_warn.progress = 1.0 - _t / 0.9
			if _t <= 0.0:
				if is_instance_valid(_warn):
					hurt_players_in(_warn.global_position, 16.0, _hit)
					Game.burst(_warn.global_position + Vector2(0, -6), Color(0.45, 0.6, 1.0), 14)
					_warn.queue_free()
				state = "idle"
				_t = 1.8
				sprite.play("idle")
	return Vector2.ZERO


func _die() -> void:
	if is_instance_valid(_warn):
		_warn.queue_free()
	super._die()
