extends "res://scripts/slime.gd"
## Паук-механизм (Механическая кузня): целится (круг под героем) и прыгает туда, раня при
## приземлении. Отходи из круга — пока он перезаряжается, его безопасно бить.

var _st := "idle"
var _tt := 1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _warn: Node2D


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.8, 0.8, 0.85)
	_tt = randf_range(0.8, 1.6)


func _think(delta: float) -> Vector2:
	_tt -= delta
	var p := nearest_player()
	match _st:
		"idle":
			if _tt <= 0.0 and p and global_position.distance_to(p.global_position) < 120.0:
				_st = "aim"
				_tt = 0.75
				_to = open_spot(p.global_position)
				_warn = spawn_warning(_to, 18.0)
		"aim":
			if is_instance_valid(_warn):
				_warn.progress = 1.0 - _tt / 0.75
			if _tt <= 0.0:
				_st = "jump"
				_tt = 0.35
				_from = global_position
				collision_mask = 0
				sprite.play("hop")
		"jump":
			global_position = _from.lerp(_to, 1.0 - _tt / 0.35)
			sprite.position.y = -8.0 - sin((1.0 - _tt / 0.35) * PI) * 18.0
			if _tt <= 0.0:
				global_position = _to
				collision_mask = 1 | 4
				sprite.position.y = -8.0
				hurt_players_in(_to, 18.0, scaled(22))
				Game.burst(_to + Vector2(0, -4), Color(0.8, 0.8, 0.85), 10)
				if is_instance_valid(_warn):
					_warn.queue_free()
				sprite.play("idle")
				_st = "idle"
				_tt = 1.3
	return Vector2.ZERO


func _is_dangerous() -> bool:
	return false  # ранит только приземление


func _die() -> void:
	if is_instance_valid(_warn):
		_warn.queue_free()
	super._die()
