extends "res://scripts/bat.gd"
## Пила (Механическая кузня): ездит туда-обратно по прямой и режет всё на пути; крепкая —
## урон по ней вдвое меньше. Просто не стой на её линии.

var _dir := Vector2.RIGHT
var _last := Vector2.ZERO
var _stuck := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.85, 0.85, 0.9)
	knockback_power = 0.0
	_dir = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN].pick_random()
	_last = global_position


func _think(delta: float) -> Vector2:
	_bob += delta
	sprite.rotation += delta * 14.0
	# Упёрлась в стену — разворот.
	if global_position.distance_to(_last) < 0.2:
		_stuck += delta
		if _stuck > 0.15:
			_dir = -_dir
			_stuck = 0.0
	else:
		_stuck = 0.0
	_last = global_position
	return _dir * 60.0


func _is_dangerous() -> bool:
	return true


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	super.take_damage(maxi(1, int(round(amount * 0.5))), from, crit, missable)
