extends "res://scripts/bat.gd"
## Осколочник (Хрустальные пещеры): бросок оставляет за ним острые кристаллы — на них больно стоять.

var _trail := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.3, 0.8, 1.45)


func _think(delta: float) -> Vector2:
	var v := super._think(delta)
	if state == "dash":
		_trail -= delta
		if _trail <= 0.0:
			_trail = 0.07
			spawn_puddle(global_position, 7.0, 3.0, scaled(4), Color(1.0, 0.7, 1.0))
	return v
