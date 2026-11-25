extends "res://scripts/mushroom.gd"
## Болотник (Ядовитые топи, 20+): почти невидим, пока герой не подойдёт, и выпускает облако яда.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.55, 0.8, 0.45, 0.3)


func _think(delta: float) -> Vector2:
	var v := super._think(delta)
	var p := nearest_player()
	var near := p != null and global_position.distance_to(p.global_position) < trigger_range * 1.4
	var a := move_toward(sprite.self_modulate.a, 1.0 if near else 0.3, delta * 2.0)
	sprite.self_modulate = Color(0.55, 0.8, 0.45, a)
	return v
