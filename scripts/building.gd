extends StaticBody2D
## Постройка лагеря (изометрия): картинка assets/camp/b_<id>_<y|x>.png, подпись, основание-ромб.
## id == "lot" — пустой участок: E — выбрать, что построить.

const LAY := preload("res://scripts/camp_layout.gd")
# Свечение: [смещение в мире, цвет, размер]
const GLOWS := {"portal": [Vector2(0, -30), Color(0.55, 0.35, 1.0), 1.7]}

var id := "training"
var title := ""
var plot := -1
var cell := Vector2.ZERO     # угол основания (клетки)
var size := Vector2(3, 3)    # размер основания (клетки)
var art := {}                # anchor, door — из camp.json
var art_name := ""
var _label: Label
var _sprite: Sprite2D
var _glow: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	if id == "lot":
		collision_layer = 0
		return
	collision_layer = 1
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/camp/%s.png" % art_name)
	_sprite.centered = false
	_sprite.scale = Vector2.ONE / LAY.ART
	var an: Array = art.get("anchor", [0, 0])
	_sprite.offset = -Vector2(an[0], an[1])
	add_child(_sprite)
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
	# Основание — ромб чуть меньше клеток.
	var poly := CollisionPolygon2D.new()
	var fp := LAY.footprint(cell, size)
	for k in fp.size():
		fp[k] *= 0.86
	poly.polygon = fp
	add_child(poly)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 8)
	_label.position = Vector2(-40, float(art.get("top", -float(an[1]) / LAY.ART)) - 10.0)
	_label.z_index = 5
	add_child(_label)
	refresh()
	Meta.changed.connect(refresh)


func _process(delta: float) -> void:
	if _glow:
		_t += delta
		_glow.modulate.a = 0.55 + 0.2 * sin(_t * 2.2)


func refresh() -> void:
	if id == "portal":
		_label.text = "Вход в подземелье"
	elif not Meta.UPGRADES.has(id):
		_label.text = title
	else:
		var lvl := Meta.level(id)
		_label.text = "%s%s" % [title, (" %d" % lvl) if lvl > 0 else ""]
		_label.modulate = Color.WHITE if lvl > 0 or id == "mine" else Color(0.75, 0.75, 0.8)


## Точка, у которой можно нажать E: перед дверью; у пустыря — ближайшая точка участка к герою.
func interact_point() -> Vector2:
	if id == "lot":
		var h: Node2D = Game.local_hero()
		if h:
			var c := LAY.to_cell(h.global_position)
			c = c.clamp(cell, cell + size)
			return LAY.to_screen(c)
		return global_position
	var d: Array = art.get("door", [0, 0])
	return global_position + Vector2(d[0], d[1]) + Vector2(0, 2)


func prompt() -> String:
	if id == "lot":
		return "E — свободный участок: построить"
	return "E — " + ("войти в подземелье" if id == "portal" else title)


func interact(player: Node) -> void:
	if not player.is_local():
		if id == "portal":
			Net.send_to(player.peer_id, "ui", {"open": "portal"})
		else:
			Game.hint_to(player, "Постройками управляет хозяин лагеря")
		return
	var hud := get_tree().current_scene.get_node_or_null("CampHUD")
	if hud:
		hud.open_building("plot:%d" % plot if id == "lot" else id)
