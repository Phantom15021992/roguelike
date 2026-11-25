extends "res://scripts/enemy.gd"
## Летучая мышь: кружит вокруг героя, потом замирает на миг и бросается по прямой.
## Опасна только во время броска — от него отходят в сторону.

const SHEET := preload("res://assets/bat.png")
const WINDUP := 0.35
const DASH_TIME := 0.35
const DASH_SPEED := 170.0

@export var speed := 55.0
@export var aggro_range := 120.0

var state := "flutter"
var _t := 0.0
var _orbit := 1.0
var _dash_dir := Vector2.ZERO
var _bob := 0.0


func _setup() -> void:
	sprite.sprite_frames = make_frames(SHEET, {"fly": [[0, 1], 10.0]})
	sprite.play("fly")
	_t = randf_range(1.0, 2.5)
	_orbit = 1.0 if randf() < 0.5 else -1.0


func _think(delta: float) -> Vector2:
	_bob += delta
	sprite.position.y = -12.0 + roundf(sin(_bob * 6.0) * 1.5)
	var p := nearest_player()
	if p == null or global_position.distance_to(p.global_position) > aggro_range:
		state = "flutter"
		return Vector2.from_angle(_bob * 1.3) * speed * 0.3
	_t -= delta
	var to := p.global_position - global_position
	match state:
		"flutter":
			# Держится на расстоянии ~40 px и кружит, слегка дёргаясь.
			var want := to.normalized() * (to.length() - 40.0) * 2.0 + to.normalized().orthogonal() * speed * _orbit
			if _t <= 0.0:
				state = "windup"
				_t = WINDUP
			return want.limit_length(speed) + Vector2.from_angle(randf() * TAU) * 10.0
		"windup":
			if _t <= 0.0:
				state = "dash"
				_t = DASH_TIME
				_dash_dir = to.normalized()
			return Vector2.ZERO
		"dash":
			if _t <= 0.0:
				state = "flutter"
				_t = randf_range(1.5, 2.5)
				_orbit *= -1.0
			return _dash_dir * DASH_SPEED
	return Vector2.ZERO


func _is_dangerous() -> bool:
	return state == "dash"


func _extra_flash() -> float:
	return 0.6 if state == "windup" else 0.0
