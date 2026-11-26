extends "res://scripts/slime.gd"
## Теневой слизень (Теневой лабиринт, 56–60): не прыгает, а растворяется и появляется рядом
## с героем — и сразу бьёт. Пока растворяется — уходи с места.

var _st := "idle"
var _tt := 1.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.55, 0.45, 0.95)
	_tt = randf_range(0.8, 1.6)


func _think(delta: float) -> Vector2:
	_tt -= delta
	var p := nearest_player()
	match _st:
		"idle":
			if _tt <= 0.0 and p and global_position.distance_to(p.global_position) < aggro_range:
				_st = "fade"
				_tt = 0.6
		"fade":
			sprite.self_modulate.a = _tt / 0.6
			if _tt <= 0.0:
				if p:
					var spot: Vector2 = p.global_position + Vector2.from_angle(randf() * TAU) * 22.0
					global_position = open_spot(spot)
				sprite.self_modulate.a = 1.0
				sprite.play("hop")
				_st = "strike"
				_tt = 0.35
		"strike":
			if _tt <= 0.0:
				sprite.play("idle")
				_st = "idle"
				_tt = randf_range(1.4, 2.0)
	return Vector2.ZERO


func _is_dangerous() -> bool:
	return _st == "strike"


func _extra_flash() -> float:
	return 0.5 if _st == "fade" else 0.0
