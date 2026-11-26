extends "res://scripts/salamander.gd"
## Бес-подрывник (Огненные пещеры, 26–30): бежит к герою и взрывается (красный круг на полу).
## Отбегай из круга — или убей его, пока он шипит.

const BLAST := 32.0
const FUSE := 0.6
var _warn: Node2D
var _blast := 0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.3, 0.35, 0.3)
	_blast = scaled(34)


func _think(delta: float) -> Vector2:
	if state == "fuse":
		_t -= delta
		if is_instance_valid(_warn):
			_warn.progress = 1.0 - _t / FUSE
		if _t <= 0.0:
			hurt_players_in(global_position, BLAST, _blast)
			Game.ring(global_position, BLAST, FIRE)
			Game.burst(global_position + Vector2(0, -6), FIRE, 24)
			Game.shake(3.0, 0.2)
			_die()
		return Vector2.ZERO
	var v := super._think(delta)
	var p := nearest_player()
	# Добежал до героя (или рывок кончился рядом) — поджигает фитиль.
	if state == "run" and p and global_position.distance_to(p.global_position) < 16.0:
		_start_fuse()
		return Vector2.ZERO
	if state == "rest" and p and global_position.distance_to(p.global_position) < 26.0:
		_start_fuse()
	return v


func _start_fuse() -> void:
	state = "fuse"
	_t = FUSE
	_warn = spawn_warning(global_position, BLAST)


func _is_dangerous() -> bool:
	return false  # ранит только взрыв


func _extra_flash() -> float:
	return 0.5 + 0.4 * sin(Time.get_ticks_msec() / 25.0) if state == "fuse" else super._extra_flash()


func _die() -> void:
	if is_instance_valid(_warn):
		_warn.queue_free()
	super._die()
