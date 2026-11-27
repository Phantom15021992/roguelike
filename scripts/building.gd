extends StaticBody2D
## Постройка лагеря: картинка assets/camp/b_<id>.png, подпись, твёрдое основание.
## id == "lot" — пустой участок: E — выбрать, что построить.

const LAY := preload("res://scripts/camp_layout.gd")
# Свечение: [смещение в мире, цвет, размер]
const GLOWS := {"portal": [Vector2(0, -32), Color(0.55, 0.35, 1.0), 1.4]}

var id := "training"
var title := ""
var plot := -1
var art := {}                # anchor, door, top, foot — из camp.json
var _label: Label
var _sprite: Sprite2D
var _glow: Sprite2D
var _t := 0.0
var _flat: Sprite2D
var _shape: CollisionShape2D
var _label_y := 0.0


func _exit_tree() -> void:
	if _flat and is_instance_valid(_flat):
		_flat.queue_free()


func _ready() -> void:
	add_to_group("interactables")
	if id == "lot":
		collision_layer = 0
		# Разметка участка — плоская картинка на земле (слой Ground, под героями).
		var lot := Sprite2D.new()
		lot.texture = load("res://assets/camp/p_lot.png")
		lot.centered = false
		lot.scale = Vector2.ONE / LAY.ART
		var la: Array = get_parent().get_parent().art["sprites"]["p_lot"]["anchor"]
		lot.offset = -Vector2(la[0], la[1])
		lot.position = global_position
		_flat = lot
		get_parent().get_parent().get_node("Ground").add_child(lot)
		return
	collision_layer = 1
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/camp/b_%s.png" % id)
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
	# Твёрдое основание: ширина постройки, глубина — почти до верха картинки (за дом не зайти).
	var fp: Array = art.get("foot", [60, 30, 0])
	var top: float = art.get("top", -60.0)
	var depth := clampf(maxf(float(fp[1]), -top - 34.0), 10.0, 60.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(fp[0]) - 6.0, depth)
	shape.shape = rect
	shape.position = Vector2(float(fp[2]) if fp.size() > 2 else 0.0, -depth / 2.0)
	add_child(shape)
	_shape = shape
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 8)
	_label.position = Vector2(-40, top + 4.0)
	_label_y = top + 4.0
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
	# Шахта до 1-го уровня не стоит: только утоптанная земля (её рисует лагерь), можно построить.
	if id == "mine":
		var built := Meta.level("mine") > 0
		_sprite.visible = built
		_shape.set_deferred("disabled", not built)
		_label.position.y = _label_y if built else -30.0
		if not built:
			_label.text = "Шахта — можно построить"


## Точка, у которой можно нажать E: перед дверью; у пустыря — ближайшая к герою точка участка.
func interact_point() -> Vector2:
	if id == "mine" and Meta.level("mine") == 0:
		# Пустое место шахты: ближайшая к герою точка утоптанной земли.
		var hero: Node2D = Game.local_hero()
		var area := Rect2(global_position + Vector2(-64, -48), Vector2(128, 54))
		return hero.global_position.clamp(area.position, area.end) if hero else global_position
	if id == "lot":
		var h: Node2D = Game.local_hero()
		var half := LAY.LOT_W * LAY.TILE / 2.0
		var r := Rect2(global_position + Vector2(-half, -LAY.LOT_DEPTH * LAY.TILE), Vector2(half * 2.0, LAY.LOT_DEPTH * LAY.TILE + 6.0))
		if h:
			return h.global_position.clamp(r.position, r.end)
		return global_position
	var d: Array = art.get("door", [0, 0])
	return global_position + Vector2(d[0], d[1])


func prompt() -> String:
	if id == "lot":
		return "E — свободный участок: построить"
	if id == "mine" and Meta.level("mine") == 0:
		return "E — место для шахты: построить"
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
