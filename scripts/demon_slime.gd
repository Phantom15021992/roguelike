extends "res://scripts/slime.gd"
## Демонический слизень (Бездна, 66–70): крупный; приземлившись, выпускает кольцо огненных шаров.

var _was_hopping := false


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.4, 0.4, 0.4)


func _think(delta: float) -> Vector2:
	var v := super._think(delta)
	if _was_hopping and not _hopping:
		var off := randf() * TAU
		for i in 6:
			spawn_shot(Vector2.from_angle(off + TAU * i / 6.0), scaled(14), 70.0, Color(1.0, 0.35, 0.2), "fireball")
	_was_hopping = _hopping
	return v
