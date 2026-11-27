extends Node2D
## Лагерь между забегами — деревня в изометрии: мостовая, площадь с фонтаном, участки под стройку,
## лес по краям. Раскладка — scripts/camp_layout.gd, графика — tools/gen_camp.gd (assets/camp/).
## Постоянные постройки: портал, торговец, шахта. Остальное игрок строит сам на участках
## (Meta.plots); пустой участок — E: выбрать, что построить.

const LAY := preload("res://scripts/camp_layout.gd")
const BUILDING := preload("res://scripts/building.gd")
const W := LAY.WIDTH
const H := LAY.HEIGHT
const TITLES := {"exchange": "Обменник", "merchant": "Торговец", "mentor": "Наставник"}  # постройки без улучшений
# Радиус твёрдого основания мелочей (пиксели мира).
const PROP_BODY := {"fountain": 26.0, "lamp": 2.5, "bench": 7.0, "barrels": 8.0, "crates": 8.0, "cart": 9.0, "sign": 2.5,
	"tree": 4.0, "tree2": 4.0, "tree3": 4.0, "bush": 6.0}

var art := {}
var _lots := {}   # номер участка -> узел (пустырь или постройка)

@onready var ground: Node2D = $Ground
@onready var entities: Node2D = $Entities
@onready var player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	if Net.is_guest():
		# Гость в лагере хозяина: героев (и своего) пришлёт хозяин.
		entities.remove_child(player)
		player.queue_free()
	else:
		Meta.fix_plots()
	art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/camp/camp.json"))
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/camp/ground.png")
	bg.centered = false
	bg.scale = Vector2.ONE / LAY.ART
	ground.add_child(bg)
	var grid := preload("res://scripts/camp_grid.gd").new()
	ground.add_child(grid)
	_walls()
	for id: String in LAY.FIXED:
		var f: Dictionary = LAY.FIXED[id]
		_building(id, f["at"], f["size"], f["face"], -1)
	_refresh_lots()
	Meta.changed.connect(_refresh_lots)
	for p: Array in LAY.PROPS:
		_prop(p[0], LAY.to_screen(p[1]), p[2])
	for t: Array in art["trees"]:
		_prop(t[2], Vector2(t[0], t[1]), false)
	if not Net.is_guest():
		player.position = LAY.to_screen(LAY.START)
		setup_camera(player.get_node("Camera"))
		Game.spawn_guest_heroes()
	Net.scene_loaded()


## Участки: пустырь или постройка, которую там построили.
func _refresh_lots() -> void:
	for i in LAY.LOTS.size():
		var want: String = Meta.plots.get(str(i), "")
		var cur: Node = _lots.get(i)
		if cur and is_instance_valid(cur) and cur.get("id") == (want if want != "" else "lot"):
			continue
		if cur and is_instance_valid(cur):
			entities.remove_child(cur)
			cur.queue_free()
		var lot: Dictionary = LAY.LOTS[i]
		var at: Vector2 = lot["at"]
		if want == "":
			_lots[i] = _building("lot", at, Vector2(LAY.LOT_SIZE, LAY.LOT_SIZE), lot["face"], i)
		else:
			_lots[i] = _building(want, at + Vector2(0.5, 0.5), Vector2(3, 3), lot["face"], i)


func _building(id: String, at: Vector2, size: Vector2, face: String, plot: int) -> Node:
	var b: StaticBody2D = BUILDING.new()
	b.id = id
	b.plot = plot
	b.cell = at
	b.size = size
	b.title = Meta.UPGRADES[id]["name"] if Meta.UPGRADES.has(id) else TITLES.get(id, "")
	var key := "b_%s_%s" % [id, face]
	b.art = art["sprites"].get(key, {})
	b.art_name = key
	b.position = LAY.to_screen(at + size / 2.0)
	entities.add_child(b)
	return b


## Непроходимые лес и вода — параллелограммы по рядам клеток.
func _walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	ground.add_child(body)
	for j in LAY.N:
		var i := 0
		while i < LAY.N:
			if not LAY.solid(i, j):
				i += 1
				continue
			var i0 := i
			while i < LAY.N and LAY.solid(i, j):
				i += 1
			var poly := CollisionPolygon2D.new()
			poly.polygon = PackedVector2Array([LAY.to_screen(Vector2(i0, j)), LAY.to_screen(Vector2(i, j)),
				LAY.to_screen(Vector2(i, j + 1)), LAY.to_screen(Vector2(i0, j + 1))])
			body.add_child(poly)


func _prop(name: String, pos: Vector2, solid: bool) -> void:
	var node: Node2D = StaticBody2D.new() if solid else Node2D.new()
	node.position = pos
	var s := Sprite2D.new()
	s.texture = load("res://assets/camp/p_%s.png" % name)
	s.centered = false
	s.scale = Vector2.ONE / LAY.ART
	var an: Array = art["sprites"]["p_" + name]["anchor"]
	s.offset = -Vector2(an[0], an[1])
	node.add_child(s)
	if solid:
		(node as StaticBody2D).collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := CircleShape2D.new()
		r.radius = PROP_BODY.get(name, 5.0)
		shape.shape = r
		shape.scale = Vector2(1, 0.5)
		node.add_child(shape)
	entities.add_child(node)


func setup_camera(cam: Camera2D) -> void:
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W
	cam.limit_bottom = H
	cam.reset_smoothing()


func net_scene() -> Dictionary:
	return {"kind": "camp"}
