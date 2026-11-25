extends "res://scripts/enemy.gd"
## Огненный бес: держится на расстоянии и навесом бросает огненные шары. Место падения
## видно заранее (красный круг), после падения остаётся горящая земля. Если герой подошёл
## вплотную — бес отпрыгивает (короткий телепорт).

const SHEET := preload("res://assets/imp.png")
const TELEGRAPH := preload("res://scripts/telegraph.gd")
const PUDDLE := preload("res://scripts/puddle.gd")
const FIRE := Color(1.0, 0.45, 0.15)

@export var speed := 34.0
@export var keep_distance := 70.0
@export var aggro_range := 140.0
@export var throw_damage := 18
@export var fire_damage := 6
@export var throw_cooldown := 2.6

var state := "idle"
var _t := 0.0
var _blink_cd := 0.0
var _bob := 0.0


func _setup() -> void:
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0, 1], 5.0]})
	sprite.play("idle")
	_t = randf_range(1.0, throw_cooldown)
	var k := 1.0 + 0.15 * (Run.depth - 1)
	throw_damage = int(round(throw_damage * k))
	fire_damage = int(round(fire_damage * k))


func _think(delta: float) -> Vector2:
	_t -= delta
	_bob += delta
	_blink_cd -= delta
	sprite.position.y = -9.0 + roundf(sin(_bob * 4.0))
	var p := nearest_player()
	if p == null or global_position.distance_to(p.global_position) > aggro_range:
		return Vector2.ZERO
	var to := p.global_position - global_position
	sprite.flip_h = to.x < 0.0
	# Слишком близко — отпрыгнуть.
	if to.length() < 28.0 and _blink_cd <= 0.0:
		_blink(-to.normalized())
		return Vector2.ZERO
	match state:
		"idle":
			if _t <= 0.0:
				state = "windup"
				_t = 0.5
				return Vector2.ZERO
			var dir := to.normalized()
			if to.length() < keep_distance - 15.0:
				return -dir * speed
			if to.length() > keep_distance + 15.0:
				return dir * speed
			return dir.orthogonal() * speed * 0.6
		"windup":
			if _t <= 0.0:
				_throw(p.global_position)
				state = "idle"
				_t = throw_cooldown + randf_range(-0.4, 0.4)
	return Vector2.ZERO


func _blink(dir: Vector2) -> void:
	_blink_cd = 3.0
	Game.burst(global_position + Vector2(0, -8), FIRE, 10)
	var target := global_position + dir * 50.0
	# Не прыгать в стену: сокращаем прыжок, пока не найдём пол.
	var dungeon := get_tree().current_scene
	for i in 5:
		var c := Vector2i(target / 16.0)
		if dungeon.has_method("find_path") and not dungeon.astar.is_point_solid(c) and dungeon.astar.is_in_boundsv(c):
			break
		target = global_position + dir * (40.0 - i * 8.0)
	global_position = target
	Game.burst(global_position + Vector2(0, -8), FIRE, 10)


func _throw(at: Vector2) -> void:
	var t: Node2D = TELEGRAPH.new()
	t.radius = 14.0
	t.color = FIRE
	t.position = at
	Game.ground().add_child(t)
	var dmg := throw_damage
	var fire := fire_damage
	var tw := t.create_tween()
	tw.tween_property(t, "progress", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		for pl in get_tree().get_nodes_in_group("player"):
			if not pl.dead and t.contains(pl.global_position):
				pl.take_damage(dmg, t.global_position)
		var puddle: Node2D = PUDDLE.new()
		puddle.radius = 12.0
		puddle.lifetime = 3.0
		puddle.damage = fire
		puddle.color = FIRE
		puddle.position = t.global_position
		Game.ground().add_child(puddle)
		Game.burst(t.global_position + Vector2(0, -4), FIRE, 12)
		t.queue_free())


func _extra_flash() -> float:
	return 0.5 if state == "windup" else 0.0
