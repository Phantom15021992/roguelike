extends "res://scripts/bat.gd"
## Снежная мышь (Ледяные пещеры, 36–40): бросок оставляет ледяную дорожку — она замедляет.

var _trail := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.85, 0.95, 1.45)


func _think(delta: float) -> Vector2:
	var v := super._think(delta)
	if state == "dash":
		_trail -= delta
		if _trail <= 0.0:
			_trail = 0.07
			spawn_puddle(global_position, 7.0, 3.0, 0, Color(0.65, 0.9, 1.0), 1.0)
	return v
