extends "res://scripts/skeleton.gd"
## Краб (Затонувший храм): панцирь — получает вдвое меньше урона. Но сразу после своего удара
## раскрывается: в это время урон по нему в полтора раза больше. Бей после его удара.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.35, 0.55, 0.45)


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if state == "recover":
		amount = int(round(amount * 1.5))
	else:
		amount = maxi(1, int(round(amount * 0.5)))
	super.take_damage(amount, from, crit, missable)


func _extra_flash() -> float:
	return 0.35 if state == "recover" else super._extra_flash()
