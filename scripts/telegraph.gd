extends Node2D
## Предупреждение на полу: сюда сейчас прилетит удар. Заливка растёт до краёв к моменту удара.
## arc_half > 0 — не круг, а сектор (удар мечом) шириной 2·arc_half в сторону arc_dir.

var radius := 30.0
var progress := 0.0  # 0..1, задаёт владелец
var arc_half := 0.0
var arc_dir := Vector2.RIGHT
var rect_size := Vector2.ZERO  # > 0 — прямоугольник с центром в position (волна лавы)
var color := Color(1.0, 0.25, 0.2)
var hostile := true            # false — свой круг (заклинание героя), от него не нужно уворачиваться


func _ready() -> void:
	add_to_group("telegraphs")


func net_props() -> Array:
	return ["radius", "arc_half", "arc_dir", "rect_size", "color", "hostile", "progress"]


func net_state() -> Array:
	return [progress, radius, arc_dir]


func net_apply(a: Array) -> void:
	progress = a[0]
	radius = a[1]
	arc_dir = a[2]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var fill := Color(color, 0.25)
	var base := Color(color, 0.12)
	var edge := Color(color.lightened(0.15), 0.9)
	var k := clampf(progress, 0.0, 1.0)
	if rect_size != Vector2.ZERO:
		var r := Rect2(-rect_size / 2.0, rect_size)
		draw_rect(r, base)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), fill)
		draw_rect(r, edge, false, 1.0)
		return
	if arc_half <= 0.0:
		draw_circle(Vector2.ZERO, radius, base)
		draw_circle(Vector2.ZERO, radius * k, fill)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, edge, 1.0)
		return
	var a := arc_dir.angle()
	draw_colored_polygon(_sector(radius, a), base)
	draw_colored_polygon(_sector(radius * maxf(k, 0.05), a), fill)
	draw_arc(Vector2.ZERO, radius, a - arc_half, a + arc_half, 16, edge, 1.0)


## Точка внутри сектора? (для тех, кто наносит удар)
func contains(pos: Vector2) -> bool:
	var to := pos - global_position
	if rect_size != Vector2.ZERO:
		return absf(to.x) <= rect_size.x / 2.0 and absf(to.y) <= rect_size.y / 2.0
	if to.length() > radius:
		return false
	return arc_half <= 0.0 or absf(arc_dir.angle_to(to)) <= arc_half or to.length() < 6.0


func _sector(r: float, a: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		pts.append(Vector2.from_angle(a - arc_half + 2.0 * arc_half * i / 12.0) * r)
	return pts
