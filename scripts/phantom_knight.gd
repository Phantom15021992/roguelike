extends "res://scripts/skeleton.gd"
## Призрачный рыцарь (Теневой лабиринт, 56–60): издалека нацеливается (мерцает) и проносится
## к герою по прямой, раня касанием; вблизи рубит, как скелет. Уходи вбок от рывка.

var _charge_cd := 2.0
var _cdir := Vector2.RIGHT


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.6, 0.55, 1.1, 0.85)


func _think(delta: float) -> Vector2:
	_charge_cd -= delta
	var p := nearest_player()
	match state:
		"aim":
			_t -= delta
			if p:
				_cdir = (p.global_position - global_position).normalized()
			if _t <= 0.0:
				state = "charge"
				_t = 0.45
			return Vector2.ZERO
		"charge":
			_t -= delta
			if _t <= 0.0:
				state = "recover"
				_t = 0.6
				_charge_cd = 3.5
			return _cdir * 170.0
		"walk":
			if p and _charge_cd <= 0.0:
				var d := global_position.distance_to(p.global_position)
				if d > 45.0 and d < 120.0:
					state = "aim"
					_t = 0.55
					return Vector2.ZERO
	return super._think(delta)


func _is_dangerous() -> bool:
	return state == "charge"


func _extra_flash() -> float:
	return 0.6 if state == "aim" else super._extra_flash()
