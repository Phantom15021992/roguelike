extends "res://scripts/bat.gd"
## Минёр (Механическая кузня): летает вокруг и сбрасывает мины (через секунду они взводятся).
## Взведённая мина взрывается, если на неё наступить. Не больше трёх мин сразу.

var _mine_cd := 2.0
var _mines: Array = []   # [телеграф, время взвода]


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.9, 0.85, 0.6)


func _think(delta: float) -> Vector2:
	_mine_cd -= delta
	if _mine_cd <= 0.0 and _mines.size() < 3:
		_mine_cd = 3.0
		var w := spawn_warning(global_position, 12.0, Color(1.0, 0.75, 0.2))
		_mines.append([w, 1.0])
	for m: Array in _mines:
		var wv: Variant = m[0]  # мина могла уже взорваться (освобождена) — проверяем до приведения типа
		if not is_instance_valid(wv) or (wv as Node).is_queued_for_deletion():
			continue
		var w: Node2D = wv
		m[1] -= delta
		w.progress = clampf(1.0 - m[1], 0.0, 1.0)
		if m[1] <= 0.0:
			for pl in get_tree().get_nodes_in_group("player"):
				if not pl.dead and pl.global_position.distance_to(w.global_position) < 12.0:
					_boom(w)
					break
	_mines = _mines.filter(func(m: Array) -> bool: return is_instance_valid(m[0]) and not (m[0] as Node).is_queued_for_deletion())
	return super._think(delta)


func _boom(w: Node2D) -> void:
	hurt_players_in(w.global_position, 22.0, scaled(26))
	Game.ring(w.global_position, 22.0, Color(1.0, 0.6, 0.2))
	Game.burst(w.global_position + Vector2(0, -4), Color(1.0, 0.7, 0.3), 16)
	w.queue_free()


func _die() -> void:
	for m: Array in _mines:
		var wv: Variant = m[0]
		if is_instance_valid(wv):
			(wv as Node).queue_free()
	super._die()
