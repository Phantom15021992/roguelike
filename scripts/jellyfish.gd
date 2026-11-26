extends "res://scripts/wisp.gd"
## Медуза (Затонувший храм): медленно плавает и не стреляет — но раз в 3 секунды между
## медузами, что рядом друг с другом, проскакивает молния. Не стой на линии между ними
## (перед разрядом она светится тонкой линией).

var _zap := 2.0
var _links: Array = []
var _fx: Node2D


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.9, 0.6, 1.3, 0.85)
	speed = 14.0
	_zap = randf_range(1.5, 3.0)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_links)
	add_child(_fx)


func _fire(_dir: Vector2) -> void:
	pass  # не стреляет


func _think(delta: float) -> Vector2:
	_zap -= delta
	if _zap <= 0.8 and _links.is_empty():
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and not e.dead and e.get_script() == get_script() and e.global_position.distance_to(global_position) < 120.0 and e.get_instance_id() > get_instance_id():
				_links.append(e)
	if _zap <= 0.0:
		for e in _links:
			if is_instance_valid(e) and not e.dead:
				_strike(e.global_position)
		_links.clear()
		_zap = 3.0
	_fx.queue_redraw()
	return super._think(delta)


func _strike(to: Vector2) -> void:
	var a := global_position
	var dmg := scaled(18)
	for pl in get_tree().get_nodes_in_group("player"):
		if pl.dead:
			continue
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(pl.global_position, a, to)
		if q.distance_to(pl.global_position) < 7.0:
			pl.take_damage(dmg, q)
	Game.lightning(PackedVector2Array([a + Vector2(0, -10), (a + to) / 2.0 + Vector2(randf_range(-6, 6), -10), to + Vector2(0, -10)]), Color(0.8, 0.7, 1.0))


func _draw_links() -> void:
	for e in _links:
		if is_instance_valid(e):
			_fx.draw_line(Vector2(0, -10), (e.global_position - global_position) / scale + Vector2(0, -10), Color(0.85, 0.7, 1.0, 0.45), 1.0)


func _extra_flash() -> float:
	return 0.5 if not _links.is_empty() else 0.0
