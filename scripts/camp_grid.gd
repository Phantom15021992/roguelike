extends Node2D
## Сетка поля лагеря (клетки-ромбы): G — показать/скрыть.

const LAY := preload("res://scripts/camp_layout.gd")

static var shown := true


func _ready() -> void:
	visible = shown


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		shown = not shown
		visible = shown


func _draw() -> void:
	var c := Color(1, 1, 0.9, 0.13)
	for k in range(LAY.INNER0, LAY.INNER1 + 1):
		draw_line(LAY.to_screen(Vector2(k, LAY.INNER0)), LAY.to_screen(Vector2(k, LAY.INNER1)), c, 0.25)
		draw_line(LAY.to_screen(Vector2(LAY.INNER0, k)), LAY.to_screen(Vector2(LAY.INNER1, k)), c, 0.25)
