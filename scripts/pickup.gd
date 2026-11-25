extends Node2D
## Лут на полу: золото и материалы подбираются сами (притягиваются к герою),
## предмет — E, чтобы надеть.

const ITEMS_TEX := preload("res://assets/items.png")
const COIN_TEX := preload("res://assets/coin.png")
const MATS_TEX := preload("res://assets/mats.png")
const Items := preload("res://scripts/items.gd")
const Crafting := preload("res://scripts/crafting.gd")
const MAGNET_RANGE := 40.0
const PICK_RANGE := 14.0  # для предметов: на каком расстоянии работает E

var kind := "gold"       # "gold", "mat" или "item"
var value := 1           # для золота
var mat := ""            # для материала
var item := {}           # для предмета

var _z := 0.0            # высота подлёта при выпадении
var _vz := 0.0
var _vel := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	# Выпадение: подпрыгивает и разлетается в сторону.
	_vz = randf_range(70.0, 100.0)
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 30.0)
	_t = randf() * TAU


func net_props() -> Array:
	return ["kind", "value", "mat", "item"]


func net_state() -> Array:
	return [_z]


func net_apply(a: Array) -> void:
	_z = a[0]


func _process(delta: float) -> void:
	_t += delta
	if Net.is_guest():
		queue_redraw()  # у гостя только картинка: подбирает хозяин
		return
	if _vz != 0.0 or _z > 0.0:
		_z += _vz * delta
		_vz -= 300.0 * delta
		position += _vel * delta
		if _z <= 0.0:
			_z = 0.0
			_vz = 0.0
	if kind != "item" and _z == 0.0:
		var p := _nearest_player()
		if p:
			var d := global_position.distance_to(p.global_position)
			if d < 6.0:
				_collect()
				return
			if d < MAGNET_RANGE:
				global_position = global_position.move_toward(p.global_position, (160.0 - d * 2.0) * delta)
	queue_redraw()


func _collect() -> void:
	if kind == "gold":
		Run.gold += value
		Run.changed.emit()
	else:
		Run.add_material(mat)
		Game.float_text(global_position + Vector2(0, -14), "+" + Crafting.mat_name(mat), Color(0.8, 0.9, 1.0))
	queue_free()


func _nearest_player() -> Node2D:
	var best: Node2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead and (best == null or global_position.distance_to(p.global_position) < global_position.distance_to(best.global_position)):
			best = p
	return best


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0 if kind != "item" else 5.0, Color(0, 0, 0, 0.3))
	if kind == "gold":
		draw_texture(COIN_TEX, Vector2(-3, -6 - _z))
		return
	if kind == "mat":
		var icon: int = Crafting.MATERIALS[mat]["icon"]
		draw_texture_rect_region(MATS_TEX, Rect2(-4, -9 - _z, 8, 8), Rect2(icon * 8, 0, 8, 8), Crafting.MATERIALS[mat].get("tint", Color.WHITE))
		return
	var c: Color = Items.color(item)
	var bob := roundf(sin(_t * 3.0)) - _z
	# Свечение цветом редкости.
	draw_circle(Vector2(0, -2), 7.0, Color(c, 0.18 + 0.08 * sin(_t * 4.0)))
	draw_texture_rect_region(ITEMS_TEX, Rect2(-6, -13 + bob, 12, 12), Rect2(item["icon"] * 12, 0, 12, 12))
