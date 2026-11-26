extends "res://scripts/slime.gd"
## Хрустальный слизень (Хрустальные пещеры): после смерти раскалывается — шесть осколков
## разлетаются во все стороны. Добивай издалека или отскакивай.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.3, 0.8, 1.45)


func _die() -> void:
	if not Net.is_guest():
		var off := randf() * TAU
		for i in 6:
			spawn_shot(Vector2.from_angle(off + TAU * i / 6.0), scaled(14), 95.0, Color(1.0, 0.75, 1.0), "bolt")
	super._die()
