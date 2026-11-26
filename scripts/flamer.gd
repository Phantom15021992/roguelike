extends "res://scripts/skeleton.gd"
## Огнемёт (Механическая кузня): подходит на 50 px и обдаёт огнём длинным узким конусом
## (виден заранее); на земле остаётся пламя. Заходи сбоку.

const FIRE := Color(1.0, 0.45, 0.15)


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.2, 0.75, 0.45)


func _think(delta: float) -> Vector2:
	if state == "walk":
		var p := nearest_player()
		if p and global_position.distance_to(p.global_position) < 50.0:
			_start_windup((p.global_position - global_position).normalized())
			_telegraph.radius = 62.0
			_telegraph.arc_half = 0.42
			_telegraph.color = FIRE
			_t = WINDUP + 0.2
			return Vector2.ZERO
	return super._think(delta)


func _swing() -> void:
	for i in 3:
		spawn_puddle(global_position + _dir * (18.0 + 16.0 * i), 9.0, 2.5, scaled(5), FIRE)
	super._swing()
