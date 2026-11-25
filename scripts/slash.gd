extends Node2D
## Визуальный след взмаха меча. Сам урон считает герой.

const DURATION := 0.15
var _t := 0.0


func net_props() -> Array:
	return []


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var k := _t / DURATION
	var alpha := 1.0 - k
	var sweep := lerpf(-1.2, 1.2, minf(k * 2.5, 1.0))
	draw_arc(Vector2.ZERO, 12.0, -1.2, sweep, 12, Color(1, 1, 1, alpha), 3.0)
	draw_arc(Vector2.ZERO, 15.0, -0.9, sweep * 0.8, 10, Color(0.7, 0.85, 1.0, alpha * 0.7), 1.0)
