extends "res://scripts/enemy.gd"
## Лавовый голем: медленный и крепкий. Поворачивается к герою и БЛОКИРУЕТ удары спереди
## (−60% урона) — бить надо сзади или сбоку. Когда герой рядом — замах и удар по земле
## вокруг себя (красный круг).

const SHEET := preload("res://assets/golem.png")
const TELEGRAPH := preload("res://scripts/telegraph.gd")
const FRONT_ARC := 1.2       # половина угла «лицевой» стороны (≈70°)
const TURN_SPEED := 1.6      # рад/с — как быстро разворачивается к герою
const SLAM_RADIUS := 34.0

@export var speed := 22.0
@export var aggro_range := 130.0
@export var slam_damage := 30

var facing := Vector2.DOWN
var state := "walk"
var _t := 0.0
var _telegraph: Node2D
var _block_hint := 0.0


func _setup() -> void:
	knockback_power = 0.0
	sprite.sprite_frames = make_frames(SHEET, {"walk": [[0, 1], 3.0], "idle": [[0], 1.0]})
	sprite.play("idle")
	slam_damage = int(round(slam_damage * (1.0 + 0.15 * (Run.depth - 1))))


func _think(delta: float) -> Vector2:
	_t -= delta
	_block_hint -= delta
	var p := nearest_player()
	if p == null or global_position.distance_to(p.global_position) > aggro_range:
		sprite.play("idle")
		return Vector2.ZERO
	var to := p.global_position - global_position
	# Медленно поворачивается к герою — в этот момент его можно обойти.
	facing = facing.rotated(clampf(facing.angle_to(to), -TURN_SPEED * delta, TURN_SPEED * delta))
	sprite.flip_h = facing.x < 0.0
	match state:
		"walk":
			if to.length() < 26.0:
				state = "windup"
				_t = 0.9
				sprite.play("idle")
				_attack_pose()
				_telegraph = TELEGRAPH.new()
				_telegraph.radius = SLAM_RADIUS
				_telegraph.position = global_position
				Game.ground().add_child(_telegraph)
				return Vector2.ZERO
			sprite.play("walk")
			return to.normalized() * speed
		"windup":
			if is_instance_valid(_telegraph):
				_telegraph.progress = 1.0 - _t / 0.9
			if _t <= 0.0:
				for pl in get_tree().get_nodes_in_group("player"):
					if not pl.dead and pl.global_position.distance_to(global_position) < SLAM_RADIUS:
						pl.take_damage(slam_damage, global_position)
				Game.shake(3.0, 0.2)
				Game.ring(global_position, SLAM_RADIUS, Color(1.0, 0.5, 0.2))
				_clear_telegraph()
				state = "recover"
				_t = 1.0
		"recover":
			if _t <= 0.0:
				state = "walk"
	return Vector2.ZERO


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	# Удар спереди — блок (урон −60%).
	var dir := from - global_position
	if dir.length() > 1.0 and absf(facing.angle_to(dir)) < FRONT_ARC:
		amount = maxi(1, int(round(amount * 0.4)))
		if _block_hint <= 0.0:
			_block_hint = 1.2
			Game.float_text(global_position + Vector2(0, -28), "Блок! Бей сзади", Color(0.8, 0.8, 0.9))
	super.take_damage(amount, from, crit, missable)


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _extra_flash() -> float:
	return 0.35 + 0.25 * sin(Time.get_ticks_msec() / 40.0) if state == "windup" else 0.0


func _die() -> void:
	_clear_telegraph()
	super._die()
