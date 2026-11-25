extends "res://scripts/enemy.gd"
## Саламандра: замирает, нацеливается — и проносится по прямой к герою, оставляя огненный след.
## Опасна касанием только во время рывка. Уходить в сторону и не стоять в огне.

const SHEET := preload("res://assets/salamander.png")
const PUDDLE := preload("res://scripts/puddle.gd")
const FIRE := Color(1.0, 0.45, 0.15)
const RUN_SPEED := 125.0
const RUN_TIME := 0.7

@export var aggro_range := 140.0
@export var trail_damage := 5

var state := "rest"
var _t := 0.0
var _dir := Vector2.RIGHT
var _trail_t := 0.0


func _setup() -> void:
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0], 1.0], "run": [[0, 1], 12.0]})
	sprite.play("idle")
	_t = randf_range(0.5, 1.5)
	trail_damage = int(round(trail_damage * (1.0 + 0.15 * (Run.depth - 1))))


func _think(delta: float) -> Vector2:
	_t -= delta
	var p := nearest_player()
	match state:
		"rest":
			sprite.play("idle")
			if _t <= 0.0 and p and global_position.distance_to(p.global_position) < aggro_range:
				state = "aim"
				_t = 0.45
		"aim":
			if p:
				_dir = (p.global_position - global_position).normalized()
				sprite.flip_h = _dir.x < 0.0
			if _t <= 0.0:
				state = "run"
				_t = RUN_TIME
				sprite.play("run")
		"run":
			_trail_t -= delta
			if _trail_t <= 0.0:
				_trail_t = 0.09
				var f: Node2D = PUDDLE.new()
				f.radius = 7.0
				f.lifetime = 2.5
				f.damage = trail_damage
				f.color = FIRE
				f.position = global_position
				Game.ground().add_child(f)
			if _t <= 0.0:
				state = "rest"
				_t = randf_range(1.0, 1.6)
			return _dir * RUN_SPEED
	return Vector2.ZERO


func _is_dangerous() -> bool:
	return state == "run"


func _extra_flash() -> float:
	return 0.55 if state == "aim" else 0.0
