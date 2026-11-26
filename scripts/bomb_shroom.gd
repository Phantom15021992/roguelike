extends "res://scripts/mushroom.gd"
## Гриб-бомба (Подземелье, 6–10): если подойти — шипит (красный круг) и взрывается вместе с собой.
## Успеешь убить, пока шипит, — взрыва не будет. Или отойди из круга.

const BLAST_RADIUS := 38.0
const FUSE := 1.1
var _warn: Node2D
var _blast := 0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.35, 0.6, 0.45)
	_blast = scaled(30)


func _think(delta: float) -> Vector2:
	_t -= delta
	var p := nearest_player()
	match state:
		"idle":
			if p and global_position.distance_to(p.global_position) < 46.0:
				state = "fuse"
				_t = FUSE
				sprite.play("puff")
				_warn = spawn_warning(global_position, BLAST_RADIUS)
		"fuse":
			if is_instance_valid(_warn):
				_warn.progress = 1.0 - _t / FUSE
			if _t <= 0.0:
				hurt_players_in(global_position, BLAST_RADIUS, _blast)
				Game.ring(global_position, BLAST_RADIUS, Color(1.0, 0.5, 0.2))
				Game.burst(global_position + Vector2(0, -6), Color(1.0, 0.6, 0.3), 24)
				Game.shake(3.0, 0.2)
				_clear()
				_die()
	return Vector2.ZERO


func _clear() -> void:
	if is_instance_valid(_warn):
		_warn.queue_free()


func _extra_flash() -> float:
	return 0.4 + 0.4 * sin(Time.get_ticks_msec() / 30.0) if state == "fuse" else 0.0


func _die() -> void:
	_clear()
	super._die()
