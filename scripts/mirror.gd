extends "res://scripts/skeleton.gd"
## Зеркальник (Хрустальные пещеры): каждый удар по нему отзывается осколком, который летит
## обратно в ударившего. Бей сериями покрупнее, а не множеством слабых ударов, — или уворачивайся.

var _cd := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.2, 1.0, 1.4)


func _think(delta: float) -> Vector2:
	_cd -= delta
	return super._think(delta)


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	super.take_damage(amount, from, crit, missable)
	if dead or last_hit_missed or _cd > 0.0 or Net.is_guest():
		return
	_cd = 0.35
	var hero: Node = _attacker()
	var target: Vector2 = hero.global_position if hero else from
	spawn_shot(target - global_position, scaled(12), 130.0, Color(1.0, 0.8, 1.0), "bolt")
