extends "res://scripts/golem.gd"
## Механический голем (Механическая кузня): как голем, но когда здоровья меньше трети —
## перегревается: круг на полу и через 1.5 секунды взрыв (сам при этом гибнет). Отбегай.

const OVERHEAT_R := 46.0
var _over := false
var _ot := 0.0
var _warn2: Node2D


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.0, 0.9, 0.7)


func _think(delta: float) -> Vector2:
	if _over:
		_ot -= delta
		if is_instance_valid(_warn2):
			_warn2.progress = 1.0 - _ot / 1.5
		if _ot <= 0.0:
			hurt_players_in(global_position, OVERHEAT_R, scaled(40))
			Game.ring(global_position, OVERHEAT_R, Color(1.0, 0.6, 0.2))
			Game.burst(global_position + Vector2(0, -8), Color(1.0, 0.6, 0.2), 30)
			Game.shake(4.0, 0.3)
			_die()
		return Vector2.ZERO
	return super._think(delta)


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	super.take_damage(amount, from, crit, missable)
	if not dead and not _over and hp * 3 < max_hp and not Net.is_guest():
		_over = true
		_ot = 1.5
		_clear_telegraph()
		_warn2 = spawn_warning(global_position, OVERHEAT_R, Color(1.0, 0.5, 0.15))
		Game.float_text(global_position + Vector2(0, -30), "Перегрев!", Color(1.0, 0.6, 0.2))


func _extra_flash() -> float:
	return 0.5 + 0.4 * sin(Time.get_ticks_msec() / 25.0) if _over else super._extra_flash()


func _die() -> void:
	if is_instance_valid(_warn2):
		_warn2.queue_free()
	super._die()
