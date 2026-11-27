extends Node2D
## Всплывающая цифра урона (пиксельные цифры из assets/digits.png).

const DIGITS := preload("res://assets/digits.png")
const LIFETIME := 0.7

var value := 0
var color := Color.WHITE
var _t := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # всплывает в _process


func _process(delta: float) -> void:
	_t += delta
	position.y -= 24.0 * delta * (1.0 - _t / LIFETIME)
	modulate.a = 1.0 - maxf(0.0, (_t - 0.4) / 0.3)
	if _t >= LIFETIME:
		queue_free()


func _draw() -> void:
	var s := str(value)
	var x0 := -(s.length() * 4 - 1) / 2
	var shadow := Color(0.08, 0.05, 0.1)
	for i in s.length():
		var src := Rect2(int(s[i]) * 4, 0, 3, 5)
		var at := Vector2(x0 + i * 4, 0)
		for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1)]:
			draw_texture_rect_region(DIGITS, Rect2(at + o, Vector2(3, 5)), src, shadow)
		draw_texture_rect_region(DIGITS, Rect2(at, Vector2(3, 5)), src, color)
