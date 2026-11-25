extends Node2D
## Портал домой — стоит у входа в логово босса и появляется после победы над ним.
## E — закончить забег и вернуться в лагерь живым (следующий забег — снова с 1-го этажа):
## золото, материалы и надетое снаряжение сохраняются (снаряжение — на складе мастерской).
## Это единственный способ вынести добычу: при смерти теряется всё — золото, материалы, снаряжение.

const SHEET := preload("res://assets/buildings.png")
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	var s := Sprite2D.new()
	s.texture = SHEET
	s.region_enabled = true
	s.region_rect = Rect2(6 * 32, 0, 32, 32)
	s.position = Vector2(0, -16)
	add_child(s)
	Game.burst(global_position + Vector2(0, -12), Color(0.7, 0.5, 1.0), 20)


func net_props() -> Array:
	return []


func _process(delta: float) -> void:
	_t += delta
	if Engine.get_process_frames() % 20 == 0:
		Game.burst(global_position + Vector2(randf_range(-6, 6), -14), Color(0.75, 0.55, 1.0), 2)


func map_color() -> Color:
	return Color(0.75, 0.5, 1.0)


func interact_point() -> Vector2:
	return global_position + Vector2(0, 4)


func prompt() -> String:
	return "E — в лагерь: добыча сохранится, забег закончится"


func interact(_player: Node) -> void:
	Game.return_to_camp(true)
