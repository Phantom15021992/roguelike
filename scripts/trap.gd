extends Node2D
## Ловушка охотника: лежит на полу, срабатывает на первого монстра, который наступит.
## Урон от характеристик охотника + держит монстра 3 с (босса — замедляет).

const MAX_TRAPS := 3
const HOLD := 3.0

var caster: Node
var mult := 1.5
var radius := 10.0
var _t := 0.0


func _ready() -> void:
	add_to_group("traps")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t < 0.3:  # секунду на «взвод», чтобы не срабатывала в момент установки сквозь монстра
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) < radius:
			_spring(e)
			return


func _spring(e: Node) -> void:
	if is_instance_valid(caster):
		var r: Array = caster.roll(mult)
		e.take_damage(r[0], global_position, r[1], false)
	if not e.dead:
		e.apply_stun(HOLD, "stun")
	Game.burst(global_position + Vector2(0, -3), Color(0.85, 0.7, 0.45), 12)
	queue_free()


func _draw() -> void:
	var c := Color(0.75, 0.62, 0.4)
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))
	# Капкан: два полукольца с зубьями.
	draw_arc(Vector2.ZERO, 5.0, PI, TAU, 8, c, 1.0)
	draw_arc(Vector2.ZERO, 5.0, 0.0, PI, 8, c.darkened(0.2), 1.0)
	for i in 5:
		var x := -4.0 + i * 2.0
		draw_line(Vector2(x, -1), Vector2(x, 1), c.lightened(0.3), 1.0)
	if _t < 0.3:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(c, 0.5), 1.0)
