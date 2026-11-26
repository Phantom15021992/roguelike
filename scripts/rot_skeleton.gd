extends "res://scripts/skeleton.gd"
## Гнилой скелет (Ядовитые топи, 46–50): «умерев», рассыпается и через 3 секунды встаёт снова
## с половиной здоровья. Пока лежит грудой костей — добей одним ударом.

var _revived := false
var _bones_t := 0.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.75, 0.95, 0.55)


func _think(delta: float) -> Vector2:
	if _bones_t > 0.0:
		_bones_t -= delta
		if _bones_t <= 0.0:
			hp = maxi(1, int(max_hp / 2.0))
			sprite.rotation = 0.0
			sprite.modulate = Color.WHITE
			Game.float_text(global_position + Vector2(0, -22), "Восстал!", Color(0.75, 0.95, 0.55))
		return Vector2.ZERO
	return super._think(delta)


func _is_dangerous() -> bool:
	return _bones_t <= 0.0


func _die() -> void:
	if not _revived and not Net.is_guest():
		_revived = true
		_bones_t = 3.0
		hp = 1
		_clear_telegraph()
		state = "recover"
		sprite.rotation = PI / 2.0
		sprite.modulate = Color(0.6, 0.6, 0.6)
		Game.float_text(global_position + Vector2(0, -22), "Рассыпался — добей!", Color(0.75, 0.95, 0.55))
		return
	sprite.rotation = 0.0
	super._die()
