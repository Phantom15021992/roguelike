extends StaticBody2D
## Постройка лагеря: картинка (assets/camp/b_<id>.png, двойная детализация), подпись, твёрдое основание.
## Подойти к двери и нажать E — откроется её окно в интерфейсе лагеря. Не построена — строительные леса.

const LAY := preload("res://scripts/camp_layout.gd")
const PAD := 6
# Свечение: [смещение в мире, цвет, размер]
const GLOWS := {"portal": [Vector2(0, -30), Color(0.55, 0.35, 1.0), 1.6], "forge": [Vector2(26, -14), Color(1.0, 0.55, 0.2), 0.9]}

var id := "training"
var title := ""
var door_x := 0.0
var _label: Label
var _sprite: Sprite2D
var _scaffold: Sprite2D
var _glow: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 1
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/camp/b_%s.png" % id)
	_sprite.centered = false
	_sprite.scale = Vector2.ONE / LAY.ART
	var tw := _sprite.texture.get_width()
	var th := _sprite.texture.get_height()
	_sprite.offset = Vector2(-tw / 2.0, -(th - PAD))
	add_child(_sprite)
	if ResourceLoader.exists("res://assets/camp/x_%s.png" % id):
		_scaffold = Sprite2D.new()
		_scaffold.texture = load("res://assets/camp/x_%s.png" % id)
		_scaffold.centered = false
		_scaffold.scale = _sprite.scale
		_scaffold.offset = _sprite.offset
		add_child(_scaffold)
	if GLOWS.has(id):
		_glow = Sprite2D.new()
		_glow.texture = load("res://assets/camp/glow.png")
		var g: Array = GLOWS[id]
		_glow.position = g[0]
		_glow.modulate = g[1]
		_glow.scale = Vector2.ONE * float(g[2])
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		add_child(_glow)
	# Твёрдое основание: почти вся ширина, глубина — до верхней трети картинки.
	var used := _sprite.texture.get_image().get_used_rect()
	var w := used.size.x / 2.0 - 8.0
	var depth := clampf((th - PAD - used.position.y) / 2.0 - 22.0, 10.0, 60.0)
	if id in ["merchant", "exchange", "training"]:
		depth = minf(depth, 22.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, depth)
	shape.shape = rect
	shape.position = Vector2(0, -depth / 2.0)
	add_child(shape)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 8)
	_label.position = Vector2(-40, -(th - PAD - used.position.y) / 2.0 - 9)
	_label.z_index = 5
	add_child(_label)
	refresh()
	Meta.changed.connect(refresh)


func _process(delta: float) -> void:
	if _glow:
		_t += delta
		_glow.modulate.a = 0.55 + 0.2 * sin(_t * 2.2) + (0.08 * sin(_t * 13.0) if id == "forge" else 0.0)


func refresh() -> void:
	var built := true
	if id == "portal":
		_label.text = "Вход в подземелье"
	elif not Meta.UPGRADES.has(id):
		_label.text = title  # обменник, торговец, наставник: строить не нужно — работают сразу
	else:
		var lvl := Meta.level(id)
		_label.text = "%s%s" % [title, (" %d" % lvl) if lvl > 0 else ""]
		_label.modulate = Color.WHITE if lvl > 0 or id == "mine" else Color(0.75, 0.75, 0.8)
		built = lvl > 0
	if _scaffold:
		_scaffold.visible = not built
	_sprite.modulate = Color.WHITE if built else Color(0.62, 0.6, 0.62)
	if _glow:
		_glow.visible = built


## Точка, у которой можно нажать E (перед дверью).
func interact_point() -> Vector2:
	return global_position + Vector2(door_x, 6)


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
