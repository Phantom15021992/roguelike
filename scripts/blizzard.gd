extends Node2D
## Ледяная метель мага: 5 секунд на средней площади, 4 удара в секунду + замедление.
## Урон считается от характеристик кастующего в момент каждого удара.

const DURATION := 5.0
const TICK := 0.25
const COLOR := Color(0.6, 0.85, 1.0)

var caster: Node          # герой-маг
var mult := 0.3           # доля урона за один удар
var radius := 34.0
var _t := 0.0
var _tick := 0.0
var _flakes := []


var _whirl: Sprite2D


func _ready() -> void:
	# Вихрь (assets/fx/whirl.png, tools/gen_fx.gd): раскрутка, кружится, в конце тает.
	_whirl = Sprite2D.new()
	_whirl.texture = load("res://assets/fx/whirl.png")
	_whirl.hframes = 6
	_whirl.centered = false
	_whirl.offset = -Vector2(24, 92)
	_whirl.scale = Vector2.ONE * 0.5 * (radius / 34.0) * 1.4
	_whirl.position = Vector2(0, 4)
	add_child(_whirl)
	for i in 26:
		_flakes.append([Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius, randf() * 20.0, randf_range(18.0, 30.0)])


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_hit()
	for f in _flakes:
		f[1] -= f[2] * delta
		if f[1] < 0.0:
			f[0] = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
			f[1] = 20.0
	if _whirl:
		if _t < 0.2:
			_whirl.frame = 0
		elif _t > DURATION - 0.4:
			_whirl.frame = 4 if _t < DURATION - 0.2 else 5
		else:
			_whirl.frame = 1 + int(_t * 9.0) % 3
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func net_props() -> Array:
	return ["radius"]


func _hit() -> void:
	if Net.is_guest():
		return
	if not is_instance_valid(caster) or caster.dead:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= radius:
			var r: Array = caster.roll(mult)
			Game.attacker = caster
			e.take_damage(r[0], global_position, r[1], false)
			e.apply_slow(0.6)


func _draw() -> void:
	var fade := clampf((DURATION - _t) / 0.5, 0.0, 1.0) * clampf(_t / 0.2, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.16 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(COLOR.lightened(0.3), 0.6 * fade), 1.0)
	for f in _flakes:
		var p: Vector2 = f[0] + Vector2(-f[1] * 0.3, -f[1])
		draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1, 0.85 * fade))
