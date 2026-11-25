extends StaticBody2D
## Наковальня в подземелье: E — заточка надетого снаряжения за золото и материалы забега.
## Удача героя (бонус к крафту) повышает шанс успеха.

const TEX := preload("res://assets/anvil.png")


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 1
	var s := Sprite2D.new()
	s.texture = TEX
	s.position = Vector2(0, -8)
	add_child(s)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)


func map_color() -> Color:
	return Color(1.0, 0.55, 0.2)


func interact_point() -> Vector2:
	return global_position + Vector2(0, 6)


func prompt() -> String:
	return "E — наковальня (заточка)"


func interact(_player: Node) -> void:
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.toggle_panel("anvil")
