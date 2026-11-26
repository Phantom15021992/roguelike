extends "res://scripts/salamander.gd"
## Морской змей (Затонувший храм): проносится по прямой, как саламандра, но оставляет не огонь,
## а воду — она замедляет.

var _wt := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.45, 0.85, 1.1)
	trail_damage = 0


func _think(delta: float) -> Vector2:
	if state == "run":
		_wt -= delta
		if _wt <= 0.0:
			_wt = 0.08
			spawn_puddle(global_position, 8.0, 3.0, 0, Color(0.4, 0.7, 1.0), 1.2)
		_trail_t = 1.0  # огненный след саламандры не нужен
	return super._think(delta)
