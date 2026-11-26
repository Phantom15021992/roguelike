extends Area2D
## Летящий снаряд. Логически летит «по полу» (чтобы попадать в ноги),
## а рисуется на высоте HEIGHT пикселей.
## team = "enemy" — бьёт героев (сгустки духа и босса);
## team = "player" — бьёт монстров (стрелы, магия).

const HEIGHT := 10.0

var team := "enemy"
var style := "orb"           # orb, arrow, bolt, fireball
var direction := Vector2.RIGHT
var speed := 75.0
var damage := 20
var crit := false
var missable := true         # стрелы могут промахнуться (уклонение монстра), магия — нет
var pierce := 0              # сколько врагов прошьёт насквозь
var explode_radius := 0.0    # > 0 — взрыв по площади при попадании и в конце полёта
var lifetime := 4.0
var color := Color(0.6, 0.35, 0.95)
var on_explode := Callable()  # что сделать на месте взрыва (огненная земля Профессора)
var source: Node              # герой-стрелок (для его вампиризма, точности и т.п.)
var chill := 0.0              # > 0 — попадание замедляет героя на столько секунд
var bounce := 0               # бросок щита: сколько раз отскочить к следующему врагу
var stun_sec := 0.0           # оглушить задетого (босса — замедлить)
var dot_pct := 0.0            # яд: ещё столько урона (доля удара) за 3 с
var quiet := false            # взрыв без тряски экрана (обычная атака мага)
var _t := 0.0
var _hit := []


func net_props() -> Array:
	return ["team", "style", "direction", "speed", "lifetime", "color", "explode_radius"]


func net_state() -> Array:
	return [direction]


func net_apply(a: Array) -> void:
	direction = a[0]  # отражённый щитом снаряд меняет направление


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | (2 if team == "enemy" else 4)
	if team == "enemy":
		add_to_group("enemy_shots")
		Game.shots_seen += 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	rotation = 0.0


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_t += delta
	queue_redraw()
	if _t > lifetime:
		if Net.is_guest():
			queue_free()
			return
		if explode_radius > 0.0:
			_explode()
		queue_free()


func _on_body_entered(body: Node) -> void:
	if Net.is_guest():
		return  # у гостя — только картинка, попадания считает хозяин
	if is_instance_valid(source):
		Game.attacker = source
	if team == "enemy":
		if body.is_in_group("player"):
			if body.dead:
				return
			# Щит паладина: снаряд разворачивается и летит в монстров.
			if body.has_method("try_reflect") and body.try_reflect(self):
				return
			body.take_damage(damage, global_position)
			if chill > 0.0:
				body.apply_chill(chill)
		_pop()
		return
	# Снаряд героя. Героев не трогает (например, только что отражённый щитом паладина).
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemies"):
		if body in _hit:
			return
		if explode_radius > 0.0:
			_explode()
			queue_free()
			return
		_hit.append(body)
		body.take_damage(damage, global_position - direction * 6.0, crit, missable)
		if is_instance_valid(body) and not body.dead:
			if stun_sec > 0.0:
				body.apply_stun(stun_sec, "stun")
			if dot_pct > 0.0:
				body.apply_burn(damage * dot_pct / 3.0, 3.0)
		if bounce > 0 and _bounce_from(body):
			return
		if pierce > 0:
			pierce -= 1
			return
	elif explode_radius > 0.0:
		_explode()
		queue_free()
		return
	_pop()


## Отскок к ближайшему ещё не задетому врагу (бросок щита).
func _bounce_from(body: Node2D) -> bool:
	var best: Node2D = null
	var best_d := 100.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == body or e in _hit or e.dead:
			continue
		var d: float = e.global_position.distance_to(body.global_position)
		if d < best_d:
			best = e
			best_d = d
	if best == null:
		return false
	bounce -= 1
	direction = (best.global_position - global_position).normalized()
	_t = 0.0
	return true


func _pop() -> void:
	Game.burst(global_position + Vector2(0, -HEIGHT), color.lightened(0.3), 6)
	queue_free()


func _explode() -> void:
	if is_instance_valid(source):
		Game.attacker = source
	Game.ring(global_position, explode_radius, color)
	Game.burst(global_position + Vector2(0, -6), color.lightened(0.2), 16)
	if not quiet:
		Game.shake(2.0, 0.15)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= explode_radius:
			e.take_damage(damage, global_position, crit, missable)
	if on_explode.is_valid():
		on_explode.call(global_position)
		on_explode = Callable()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 2.0, Color(0, 0, 0, 0.3))
	var top := Vector2(0, -HEIGHT)
	var pulse := 0.5 + 0.5 * sin(_t * 20.0)
	match style:
		"arrow":
			var tail := top - direction * 7.0
			draw_line(tail, top, Color(0.55, 0.35, 0.2), 1.0)
			draw_line(top - direction * 2.0, top, Color(0.9, 0.9, 0.95), 1.5)
			draw_line(tail, tail - direction * 2.0 + direction.orthogonal() * 1.5, Color(0.95, 0.95, 0.95), 1.0)
		"bone":
			var tail := top - direction * 8.0
			draw_line(tail, top, Color(0.75, 0.72, 0.65), 2.0)
			draw_line(top - direction * 3.0, top, Color(0.95, 0.93, 0.85), 2.5)
		"blade", "axe", "dagger":
			# Вращающийся клинок / топор; кинжал летит остриём вперёд.
			var a := direction if style == "dagger" else Vector2.from_angle(_t * 25.0)
			var n := 7.0 if style == "axe" else (6.0 if style == "blade" else 4.0)
			draw_line(top - a * n, top + a * n, color, 2.0 if style == "axe" else 1.5)
			draw_line(top + a * (n - 2.0), top + a * n, Color.WHITE, 2.0)
			if style == "axe":
				draw_circle(top + a * n, 3.0, color.lightened(0.3))
			else:
				draw_line(top - a * (n - 1.0) + a.orthogonal() * 2.0, top - a * (n - 1.0) - a.orthogonal() * 2.0, Color(0.55, 0.4, 0.25), 1.5)
		"shield":
			draw_circle(top, 4.5, Color(0.55, 0.42, 0.25))
			draw_arc(top, 4.5, 0.0, TAU, 16, color, 1.5)
			draw_circle(top, 1.5, Color.WHITE.lerp(color, 0.5))
		"bolt":
			draw_circle(top, 2.5, color)
			draw_circle(top, 1.3, Color.WHITE.lerp(color, 0.3 * pulse))
		"fireball":
			draw_circle(top - direction * 3.0, 3.0, Color(color, 0.4))
			draw_circle(top, 4.5, color)
			draw_circle(top, 2.5, Color(1.0, 0.9, 0.4).lerp(Color.WHITE, pulse))
		_:
			draw_circle(top, 3.5, color)
			draw_circle(top, 2.0, color.lightened(0.7).lerp(Color.WHITE, pulse))
