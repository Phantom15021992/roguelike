extends "res://scripts/enemy.gd"
## Кристалл Повелителя костей: пока хоть один цел, босс неуязвим. Стоит на месте.

const SHEET := preload("res://assets/crystal.png")
var _t := 0.0


func _setup() -> void:
	knockback_power = 0.0
	add_to_group("crystals")
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0], 1.0]})
	sprite.play("idle")
	_t = randf() * TAU


func _think(delta: float) -> Vector2:
	_t += delta
	sprite.position.y = -9.0 + roundf(sin(_t * 2.0))
	return Vector2.ZERO


func _drop_loot() -> void:
	pass
