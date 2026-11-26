extends "res://scripts/salamander.gd"
## Адская гончая (Бездна, 66–70): быстрее саламандры и делает два рывка подряд.

var _second := false


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.3, 0.35, 0.3)


func _think(delta: float) -> Vector2:
	var before := state
	var v := super._think(delta)
	if before == "run" and state == "rest" and not _second:
		_second = true
		state = "aim"
		_t = 0.25
	elif before == "run" and state == "rest":
		_second = false
	return v * 1.35 if state == "run" else v
