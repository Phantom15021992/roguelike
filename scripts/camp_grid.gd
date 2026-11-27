extends Node2D
## Сетка клеток лагеря: G — показать/скрыть (по умолчанию скрыта).

const LAY := preload("res://scripts/camp_layout.gd")

static var shown := false


func _ready() -> void:
	visible = shown


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		shown = not shown
		visible = shown


func _draw() -> void:
	var c := Color(1, 1, 0.9, 0.14)
	for x in range(2, LAY.W - 1):
		draw_line(Vector2(x * LAY.TILE, 2 * LAY.TILE), Vector2(x * LAY.TILE, (LAY.H - 2) * LAY.TILE), c, 0.25)
	for y in range(2, LAY.H - 1):
		draw_line(Vector2(2 * LAY.TILE, y * LAY.TILE), Vector2((LAY.W - 2) * LAY.TILE, y * LAY.TILE), c, 0.25)
