extends StaticBody2D
## Постройка лагеря: картинка, подпись, твёрдое основание. Подойти и нажать E —
## откроется её окно в интерфейсе лагеря.

const SHEET := preload("res://assets/buildings.png")
const FRAMES := {"training": 0, "library": 1, "forge": 2, "infirmary": 3, "treasury": 4, "mine": 5, "portal": 6, "workshop": 7, "storage": 8, "exchange": 9}

var id := "training"
var title := ""
var _label: Label


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 1
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.region_rect = Rect2(FRAMES[id] * 32, 0, 32, 32)
	sprite.position = Vector2(0, -16)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 10)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 8)
	_label.position = Vector2(-40, -42)
	add_child(_label)
	refresh()
	Meta.changed.connect(refresh)


func refresh() -> void:
	if id == "portal":
		_label.text = "Вход в подземелье"
		return
	if id == "exchange":
		_label.text = title  # строить не нужно — работает сразу
		return
	var lvl := Meta.level(id)
	_label.text = "%s%s" % [title, (" %d" % lvl) if lvl > 0 else ""]
	_label.modulate = Color.WHITE if lvl > 0 or id == "mine" else Color(0.75, 0.75, 0.8)


## Точка, у которой можно нажать E (перед дверью).
func interact_point() -> Vector2:
	return global_position + Vector2(0, 6)


func prompt() -> String:
	return "E — " + ("войти в подземелье" if id == "portal" else title)


func interact(player: Node) -> void:
	if not player.is_local():
		# Гость в лагере хозяина: портал — выбор класса у себя, постройки — только хозяин.
		if id == "portal":
			Net.send_to(player.peer_id, "ui", {"open": "portal"})
		else:
			Game.hint_to(player, "Постройками управляет хозяин лагеря")
		return
	var hud := get_tree().current_scene.get_node_or_null("CampHUD")
	if hud:
		hud.open_building(id)
