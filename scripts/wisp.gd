extends "res://scripts/enemy.gd"
## Дух: держит дистанцию, кружит вокруг героя и стреляет медленными сгустками.
## Перед выстрелом замирает и мерцает — у игрока есть время среагировать.

const SHEET := preload("res://assets/wisp.png")
const PROJECTILE := preload("res://scripts/projectile.gd")
const CHARGE_TIME := 0.5

@export var speed := 30.0
@export var keep_distance := 75.0
@export var fire_range := 150.0
@export var fire_cooldown := 2.4

var _cd := 0.0
var _strafe := 1.0
var _t := 0.0


func _setup() -> void:
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0, 1], 6.0]})
	sprite.play("idle")
	_cd = randf_range(1.0, fire_cooldown)
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _think(delta: float) -> Vector2:
	_t += delta
	sprite.position.y = -12.0 + roundf(sin(_t * 3.0) * 1.5)  # парит
	var p := nearest_player()
	if p == null:
		return Vector2.ZERO
	var to := p.global_position - global_position
	var d := to.length()
	if d > fire_range + 30.0:
		return Vector2.ZERO

	_cd -= delta
	if _cd <= 0.0:
		_fire(to.normalized())
		_cd = fire_cooldown + randf_range(-0.3, 0.3)
		if randf() < 0.4:
			_strafe *= -1.0
	if _cd < CHARGE_TIME:
		return Vector2.ZERO

	var dir := to.normalized()
	var v: Vector2
	if d < keep_distance - 15.0:
		v = -dir
	elif d > keep_distance + 15.0:
		v = dir
	else:
		v = dir.orthogonal() * _strafe
	return v * speed


func _extra_flash() -> float:
	if _cd < CHARGE_TIME:
		return 0.45 + 0.35 * sin(_t * 40.0)
	return 0.0


var shot_chill := 0.0   # ледяные снаряды замедляют героя (морозный дух)
var shot_color := Color(0, 0, 0, 0)


func _fire(dir: Vector2) -> void:
	var b: Area2D = PROJECTILE.new()
	b.direction = dir
	b.chill = shot_chill
	if shot_color.a > 0.0:
		b.color = shot_color
	b.damage = int(round(b.damage * (1.0 + 0.15 * (Run.depth - 1))))
	b.position = global_position
	Game.fx().add_child(b)
