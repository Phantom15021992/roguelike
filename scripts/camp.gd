extends Node2D
## Лагерь между забегами: трава, тропинки, деревья по краям, постройки и портал в подземелье.

const TILE := 16
const TILES_TEX := preload("res://assets/camp_tiles.png")
const BUILDING := preload("res://scripts/building.gd")

const GRASS := Vector2i(0, 0)
const FLOWERS := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const TREE := Vector2i(3, 0)

const W := 26
const H := 16

# Где стоят постройки (клетка, на которой стоит её основание).
const PLACES := {
	"portal": Vector2i(13, 4),
	"training": Vector2i(5, 6),
	"library": Vector2i(9, 6),
	"forge": Vector2i(17, 6),
	"infirmary": Vector2i(21, 6),
	"treasury": Vector2i(7, 12),
	"mine": Vector2i(19, 12),
	"workshop": Vector2i(23, 12),
}

@onready var map: TileMapLayer = $Map
@onready var entities: Node2D = $Entities
@onready var player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	map.tile_set = _make_tileset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in H:
		for x in W:
			var edge := x == 0 or y == 0 or x == W - 1 or y == H - 1 or (y == 1 and rng.randf() < 0.5)
			var tile := TREE if edge else (FLOWERS if rng.randf() < 0.12 else GRASS)
			map.set_cell(Vector2i(x, y), 0, tile)
	# Тропинки: от портала вниз и поперёк к постройкам.
	for y in range(5, H - 1):
		_path(13, y)
		_path(12, y)
	for x in range(4, 25):
		_path(x, 8)
		_path(x, 13)
	for id: String in PLACES:
		var b: StaticBody2D = BUILDING.new()
		b.id = id
		b.title = Meta.UPGRADES[id]["name"] if Meta.UPGRADES.has(id) else ""
		b.position = Vector2(PLACES[id] * TILE) + Vector2(TILE / 2.0, TILE)
		entities.add_child(b)
	player.position = Vector2(12.5 * TILE + 8, 9 * TILE)
	var cam: Camera2D = player.get_node("Camera")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W * TILE
	cam.limit_bottom = H * TILE
	cam.reset_smoothing()


func _path(x: int, y: int) -> void:
	map.set_cell(Vector2i(x, y), 0, PATH)


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = TILES_TEX
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for x in 4:
		src.create_tile(Vector2i(x, 0))
	var half := TILE / 2.0
	var data := src.get_tile_data(TREE, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	return ts
