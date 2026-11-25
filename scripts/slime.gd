extends "res://scripts/enemy.gd"
## Слизень: передвигается прыжками, заметив героя — прыгает к нему.
## Ранит только во время прыжка — между прыжками его безопасно бить.

const SHEET := preload("res://assets/slime.png")

@export var speed := 45.0
@export var aggro_range := 110.0

var _timer := 0.0
var _hopping := false
var _dir := Vector2.ZERO


func _setup() -> void:
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0, 1], 3.0], "hop": [[2], 1.0]})
	sprite.play("idle")
	_timer = randf_range(0.2, 1.0)


func _think(delta: float) -> Vector2:
	_timer -= delta
	if _timer <= 0.0:
		_hopping = not _hopping
		if _hopping:
			_timer = 0.4
			_dir = _choose_direction()
			sprite.play("hop")
		else:
			_timer = randf_range(0.45, 0.7)
			sprite.play("idle")
	return _dir * speed if _hopping else Vector2.ZERO


func _is_dangerous() -> bool:
	return _hopping


func _choose_direction() -> Vector2:
	var p := nearest_player()
	if p and global_position.distance_to(p.global_position) < aggro_range:
		return (p.global_position - global_position).normalized().rotated(randf_range(-0.3, 0.3))
	if randf() < 0.5:
		return Vector2.from_angle(randf() * TAU)
	return Vector2.ZERO
