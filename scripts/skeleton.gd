extends "res://scripts/enemy.gd"
## Скелет-воин: идёт к герою, замахивается (на полу — красный сектор удара) и рубит.
## Сильный удар во время замаха (≥15% его HP) сбивает замах.

const SHEET := preload("res://assets/skeleton.png")
const TELEGRAPH := preload("res://scripts/telegraph.gd")
const WINDUP := 0.6
const RECOVER := 0.6
const REACH := 26.0
const HALF_ARC := 1.2

@export var speed := 32.0
@export var aggro_range := 130.0
@export var swing_damage := 25

var state := "walk"
var _t := 0.0
var _dir := Vector2.DOWN
var _telegraph: Node2D


func _setup() -> void:
	sprite.sprite_frames = make_frames(SHEET, {"walk": [[0, 1], 4.0], "idle": [[0], 1.0]})
	sprite.play("idle")
	swing_damage = int(round(swing_damage * (1.0 + 0.15 * (Run.depth - 1))))


func _think(delta: float) -> Vector2:
	_t -= delta
	var p := nearest_player()
	match state:
		"walk":
			if p == null or global_position.distance_to(p.global_position) > aggro_range:
				sprite.play("idle")
				return Vector2.ZERO
			var to := p.global_position - global_position
			if to.length() < 22.0:
				_start_windup(to.normalized())
				return Vector2.ZERO
			sprite.play("walk")
			sprite.flip_h = to.x < 0.0
			return to.normalized() * speed
		"windup":
			if is_instance_valid(_telegraph):
				_telegraph.progress = 1.0 - _t / WINDUP
			if _t <= 0.0:
				_swing()
		"recover":
			if _t <= 0.0:
				state = "walk"
	return Vector2.ZERO


func _start_windup(dir: Vector2) -> void:
	state = "windup"
	_t = WINDUP
	_dir = dir
	sprite.play("idle")
	_telegraph = TELEGRAPH.new()
	_telegraph.radius = REACH
	_telegraph.arc_half = HALF_ARC
	_telegraph.arc_dir = dir
	_telegraph.position = global_position
	Game.ground().add_child(_telegraph)


func _swing() -> void:
	for pl in get_tree().get_nodes_in_group("player"):
		if not pl.dead and is_instance_valid(_telegraph) and _telegraph.contains(pl.global_position):
			pl.take_damage(swing_damage, global_position)
	Game.burst(global_position + _dir * 14.0 + Vector2(0, -6), Color(0.9, 0.9, 0.85), 8)
	_clear_telegraph()
	state = "recover"
	_t = RECOVER


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	super.take_damage(amount, from, crit, missable)
	if not dead and not last_hit_missed and state == "windup" and amount >= max_hp * 0.15:
		_clear_telegraph()
		state = "recover"
		_t = 0.5
		Game.float_text(global_position + Vector2(0, -22), "Сбит!", Color(1.0, 0.9, 0.4))


func _extra_flash() -> float:
	return 0.35 + 0.25 * sin(Time.get_ticks_msec() / 40.0) if state == "windup" else 0.0


func _die() -> void:
	_clear_telegraph()
	super._die()
