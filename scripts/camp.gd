extends Node2D
## Лагерь между забегами — деревня: мостовая, площадь с фонтаном, дома-постройки, лес по краям.
## Раскладка — scripts/camp_layout.gd, графика — tools/gen_camp.gd (assets/camp/, двойная детализация).

const LAY := preload("res://scripts/camp_layout.gd")
const BUILDING := preload("res://scripts/building.gd")
const TILE := 16
const W := LAY.W
const H := LAY.H
const TITLES := {"exchange": "Обменник", "merchant": "Торговец", "mentor": "Наставник"}  # постройки без улучшений
# Твёрдое основание мелочей (ширина, высота) в пикселях мира.
const PROP_BODY := {"fountain": Vector2(50, 18), "lamp": Vector2(6, 4), "bench": Vector2(22, 6), "dummy": Vector2(10, 5),
	"target": Vector2(12, 4), "anvil": Vector2(16, 6), "barrels": Vector2(20, 8), "crates": Vector2(20, 9), "hay": Vector2(18, 7),
	"cart": Vector2(20, 8), "sign": Vector2(6, 4), "tree": Vector2(10, 6), "bush": Vector2(16, 7)}

@onready var map: TileMapLayer = $Map
@onready var ground: Node2D = $Ground
@onready var entities: Node2D = $Entities
@onready var player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	if Net.is_guest():
		# Гость в лагере хозяина: героев (и своего) пришлёт хозяин.
		entities.remove_child(player)
		player.queue_free()
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/camp/ground.png")
	bg.centered = false
	bg.scale = Vector2.ONE / LAY.ART
	ground.add_child(bg)
	_walls()
	for id: String in LAY.BUILDINGS:
		var b: StaticBody2D = BUILDING.new()
		b.id = id
		b.title = Meta.UPGRADES[id]["name"] if Meta.UPGRADES.has(id) else TITLES.get(id, "")
		b.door_x = LAY.BUILDINGS[id]["door"]
		b.position = (LAY.BUILDINGS[id]["at"] as Vector2) * TILE
		entities.add_child(b)
	for p: Array in LAY.PROPS:
		_prop(p[0], (p[1] as Vector2) * TILE, p[2])
	if not Net.is_guest():
		player.position = LAY.START * TILE
		setup_camera(player.get_node("Camera"))
		Game.spawn_guest_heroes()
	Net.scene_loaded()


## Непроходимые лес и вода — прямоугольники по рядам клеток.
func _walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	ground.add_child(body)
	for y in H:
		var x := 0
		while x < W:
			if not LAY.solid(x, y):
				x += 1
				continue
			var x0 := x
			while x < W and LAY.solid(x, y):
				x += 1
			var shape := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2((x - x0) * TILE, TILE)
			shape.shape = r
			shape.position = Vector2((x0 + x) * TILE / 2.0, (y + 0.5) * TILE)
			body.add_child(shape)


func _prop(name: String, pos: Vector2, solid: bool) -> void:
	var node: Node2D = StaticBody2D.new() if solid else Node2D.new()
	node.position = pos
	var s := Sprite2D.new()
	s.texture = load("res://assets/camp/p_%s.png" % name)
	s.centered = false
	s.scale = Vector2.ONE / LAY.ART
	s.offset = Vector2(-s.texture.get_width() / 2.0, -(s.texture.get_height() - 6))
	node.add_child(s)
	if solid:
		(node as StaticBody2D).collision_layer = 1
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = PROP_BODY.get(name, Vector2(10, 6))
		shape.shape = r
		shape.position = Vector2(0, -r.size.y / 2.0)
		node.add_child(shape)
	entities.add_child(node)


func setup_camera(cam: Camera2D) -> void:
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W * TILE
	cam.limit_bottom = H * TILE
	cam.reset_smoothing()


func net_scene() -> Dictionary:
	return {"kind": "camp"}
