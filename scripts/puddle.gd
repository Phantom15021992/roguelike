extends Node2D
## Опасная земля (кислота, огонь, споры): ранит тех, кто в ней стоит. Исчезает через lifetime секунд.
## team = "enemy" — ранит героев (лужи монстров); team = "player" — земля героя (Профессор):
## огонь ранит монстров уроном от характеристик caster, лёд (slow > 0) — замедляет их.

var radius := 16.0
var damage := 6
var lifetime := 8.0
var color := Color(0.35, 0.8, 0.3)
var team := "enemy"
var caster: Node          # для team = "player"
var mult := 0.0           # доля урона героя за тик (team = "player")
var slow := 0.0           # > 0 — замедляет монстров (секунд за тик)
var _t := 0.0
var _tick := 0.3


func _ready() -> void:
	add_to_group("puddles" if team == "enemy" else "player_zones")


func net_props() -> Array:
	return ["radius", "lifetime", "color", "team", "slow"]


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if Net.is_guest():
		_tick = 1.0  # у гостя только картинка: урон считает хозяин
	if _tick <= 0.0:
		_tick = 0.5 if slow <= 0.0 else 0.2
		if team == "enemy":
			for p in get_tree().get_nodes_in_group("player"):
				if not p.dead and p.global_position.distance_to(global_position) < radius:
					p.take_damage(damage, global_position)
		else:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) < radius:
					if slow > 0.0:
						e.apply_slow(slow)
					if mult > 0.0 and is_instance_valid(caster):
						var r: Array = caster.roll(mult)
						Game.attacker = caster
						e.take_damage(r[0], global_position, r[1], false)
	if _t >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - _t) / 1.0, 0.0, 1.0) * clampf(_t / 0.3, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.35 * fade))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(color.lightened(0.15), 0.25 * fade))
	# Пузырьки.
	for i in 4:
		var a := i * 1.7 + _t * 0.6
		var r := radius * (0.25 + 0.15 * i)
		var pop := fmod(_t * 1.3 + i * 0.37, 1.0)
		draw_circle(Vector2(cos(a), sin(a)) * r, 1.0 + pop, Color(color.lightened(0.5), 0.6 * fade * (1.0 - pop)))
