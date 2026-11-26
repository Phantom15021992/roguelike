extends "res://scripts/skeleton.gd"
## Утопленник (Затонувший храм): лежит под водой — почти не виден и неуязвим. Когда герой
## подходит, встаёт (всплеск) и рубит, как скелет. Обходи тёмные пятна или жди, пока встанет.

var _hidden := true
var _rise := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.45, 0.8, 0.85, 0.15)


func _think(delta: float) -> Vector2:
	var p := nearest_player()
	if _hidden:
		if _rise > 0.0:
			_rise -= delta
			sprite.self_modulate.a = 1.0 - _rise / 0.6
			if _rise <= 0.0:
				_hidden = false
				sprite.self_modulate.a = 1.0
		elif p and global_position.distance_to(p.global_position) < 50.0:
			_rise = 0.6
			Game.burst(global_position + Vector2(0, -4), Color(0.5, 0.75, 1.0), 14)
		return Vector2.ZERO
	return super._think(delta)


func _is_dangerous() -> bool:
	return not _hidden


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if _hidden and _rise <= 0.0:
		Game.float_text(global_position + Vector2(0, -16), "Под водой", Color(0.6, 0.8, 1.0))
		return
	super.take_damage(amount, from, crit, missable)
