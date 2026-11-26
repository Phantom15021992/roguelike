extends "res://scripts/bat.gd"
## Призрак (Катакомбы, 16–20): то и дело становится бесплотным — удары проходят насквозь.
## Бить, пока он видим (и пока замирает перед броском).

var _phase_t := 2.5
var ethereal := false


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.85, 0.95, 1.2, 0.85)
	_phase_t = randf_range(1.5, 3.0)


func _think(delta: float) -> Vector2:
	_phase_t -= delta
	if _phase_t <= 0.0 and state != "windup":
		ethereal = not ethereal
		_phase_t = 1.6 if ethereal else 2.6
	sprite.self_modulate.a = move_toward(sprite.self_modulate.a, 0.2 if ethereal else 0.85, delta * 4.0)
	return super._think(delta)


func _is_dangerous() -> bool:
	return not ethereal and super._is_dangerous()


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if ethereal:
		Game.float_text(global_position + Vector2(0, -20), "Сквозь", Color(0.75, 0.8, 0.95))
		return
	super.take_damage(amount, from, crit, missable)
