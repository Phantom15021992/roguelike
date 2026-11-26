extends "res://scripts/enemy.gd"
## Владыка пламени — третий босс (Огненные пещеры, 9-й этаж).
##
## Фаза 1 (HP > 60%): метеоритный дождь (много красных кругов, один — под героем),
##   огненное дыхание сектором в сторону героя (после него — передышка, +50% урона),
##   призыв бесов.
## Фаза 2 (HP > 30%): + волна лавы — заливает половину арены, надо успеть перебежать.
## Фаза 3: + два вращающихся огненных луча — бегать по кругу впереди лучей.
##
## Тактики: ловить передышку после дыхания; держаться у края, чтобы успеть уйти от волны;
## бить бесов или игнорировать; в 3-й фазе — кружить на средней дистанции.

signal woke
signal phase_changed(phase: int)

var BOSS_NAME := "Владыка пламени"
var tempo := 1.0             # варианты босса на глубине действуют быстрее
var shot_chill := 0.0        # снаряды замедляют героя (ледяные варианты)
const SHEET := preload("res://assets/ember_titan.png")
const IMP := preload("res://scenes/imp.tscn")
const TELEGRAPH := preload("res://scripts/telegraph.gd")
const PUDDLE := preload("res://scripts/puddle.gd")
const FIRE := Color(1.0, 0.45, 0.15)

const SPRITE_Y := -18.0
const IDLE_TIME := [1.3, 1.0, 0.8, 0.6]   # по фазам (4-я — только у финального босса)
const STUN_BONUS := 1.5
const BEAM_LEN := 170.0
const BEAM_WIDTH := 9.0
const BEAM_TIME := 6.0
const BEAM_WARN := 1.0

@export var meteor_damage := 26
@export var breath_damage := 32
@export var wave_damage := 35
@export var beam_damage := 14

var arena := Rect2()
var awake := false
var phase := 1
var state := "sleep"
var _t := 0.0
var _cast := ""
var _bob := 0.0
var _telegraph: Node2D
var _beam_angle := 0.0
var _beam_dir := 1.0
var _beam_cd := 0.0
var _beam_fx: Node2D
var minion_scene: PackedScene = IMP   # кого призывает (финальные боссы — монстров своего биома)
var beam_cooldown := 12.0


func _setup() -> void:
	add_to_group("boss")
	knockback_power = 0.0
	var k := (1.0 + 0.15 * (Run.depth - 1)) * power
	meteor_damage = int(round(meteor_damage * k))
	breath_damage = int(round(breath_damage * k))
	wave_damage = int(round(wave_damage * k))
	beam_damage = int(round(beam_damage * k))
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0], 1.0]}, 32)
	sprite.play("idle")
	_beam_fx = Node2D.new()
	_beam_fx.draw.connect(_draw_beams)
	add_child(_beam_fx)


func _log(msg: String) -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		print("  BOSS3: " + msg)


# ---------------- Поведение ----------------

func _think(delta: float) -> Vector2:
	_t -= delta
	_bob += delta
	_beam_cd -= delta
	sprite.position.y = SPRITE_Y + roundf(sin(_bob * 2.5) * 1.5)
	var p := nearest_player()
	match state:
		"sleep":
			if p and arena.grow(-12.0).has_point(p.global_position):
				_wake()
		"idle":
			if _t <= 0.0:
				_choose_action()
			elif p:
				var to := p.global_position - global_position
				return to.normalized() * signf(to.length() - 60.0) * 16.0
		"cast":
			if is_instance_valid(_telegraph) and _cast == "breath":
				_telegraph.progress = 1.0 - _t / 0.8
			if _t <= 0.0:
				_do_cast()
		"recover":
			if _t <= 0.0:
				_idle()
		"beams":
			var active := _t < BEAM_TIME
			_beam_angle += _beam_dir * (0.95 if active else 0.0) * delta
			if active:
				_beam_hits()
			_beam_fx.queue_redraw()
			if _t <= 0.0:
				_beam_fx.queue_redraw()
				_beam_cd = beam_cooldown
				_idle()
	return Vector2.ZERO


func _idle() -> void:
	state = "idle"
	_t = IDLE_TIME[phase - 1] / tempo


func _wake() -> void:
	awake = true
	_idle()
	woke.emit()
	if not is_mini:
		Game.banner(BOSS_NAME, 2.5)
	Game.shake(3.0, 0.4)
	_log("woke")


func _choose_action() -> void:
	if phase >= 3 and _beam_cd <= 0.0:
		_start_beams()
		return
	var r := randf()
	var can_summon := _minion_count() < 2
	var action := "meteors"
	if phase == 1:
		action = "meteors" if r < 0.45 else ("breath" if r < 0.85 or not can_summon else "summon")
	else:
		if r < 0.3:
			action = "meteors"
		elif r < 0.6:
			action = "breath"
		elif r < 0.9:
			action = "wave"
		else:
			action = "summon" if can_summon else "meteors"
	_cast = action
	state = "cast"
	match action:
		"breath":
			_t = 0.8
			var p := nearest_player()
			_telegraph = TELEGRAPH.new()
			_telegraph.radius = 80.0
			_telegraph.arc_half = 0.5
			_telegraph.arc_dir = (p.global_position - global_position).normalized() if p else Vector2.DOWN
			_telegraph.color = FIRE
			_telegraph.position = global_position
			Game.ground().add_child(_telegraph)
		"wave":
			_t = 0.2
		_:
			_t = 0.5


func _do_cast() -> void:
	_log("cast %s" % _cast)
	match _cast:
		"meteors":
			_meteors()
			_idle()
		"breath":
			_breath()
		"wave":
			_wave()
			_idle()
		"summon":
			_summon()
			_idle()


func _meteors() -> void:
	var count: int = [6, 8, 10, 12][phase - 1]
	var p := nearest_player()
	var inner := arena.grow(-16.0)
	for i in count:
		var pos := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		if i == 0 and p:
			pos = p.global_position
		var t: Node2D = TELEGRAPH.new()
		t.radius = 16.0
		t.color = FIRE
		t.position = pos
		Game.ground().add_child(t)
		var tw := t.create_tween()
		tw.tween_interval(randf() * 0.4)
		tw.tween_property(t, "progress", 1.0, 1.2)
		tw.tween_callback(_meteor_land.bind(t))


func _meteor_land(t: Node2D) -> void:
	for pl in get_tree().get_nodes_in_group("player"):
		if not pl.dead and t.contains(pl.global_position):
			pl.take_damage(meteor_damage, t.global_position)
	Game.burst(t.global_position + Vector2(0, -4), FIRE, 10)
	if phase >= 2:
		var f: Node2D = PUDDLE.new()
		f.radius = 10.0
		f.lifetime = 3.0
		f.damage = int(meteor_damage / 4.0)
		f.color = FIRE
		f.position = t.global_position
		Game.ground().add_child(f)
	t.queue_free()


func _breath() -> void:
	for pl in get_tree().get_nodes_in_group("player"):
		if not pl.dead and is_instance_valid(_telegraph) and _telegraph.contains(pl.global_position):
			pl.take_damage(breath_damage, global_position)
	if is_instance_valid(_telegraph):
		for i in 14:
			var a: float = _telegraph.arc_dir.angle() + randf_range(-0.5, 0.5)
			Game.burst(global_position + Vector2.from_angle(a) * randf_range(15, 75), FIRE, 2)
		_telegraph.queue_free()
	# Передышка после дыхания — окно для атаки.
	state = "recover"
	_t = 1.2
	Game.float_text(global_position + Vector2(0, -40), "Передышка!", Color(1.0, 0.9, 0.4))


func _wave() -> void:
	var halves := [
		Rect2(arena.position, Vector2(arena.size.x / 2.0, arena.size.y)),
		Rect2(arena.position + Vector2(arena.size.x / 2.0, 0), Vector2(arena.size.x / 2.0, arena.size.y)),
		Rect2(arena.position, Vector2(arena.size.x, arena.size.y / 2.0)),
		Rect2(arena.position + Vector2(0, arena.size.y / 2.0), Vector2(arena.size.x, arena.size.y / 2.0)),
	]
	var r: Rect2 = halves.pick_random()
	var t: Node2D = TELEGRAPH.new()
	t.rect_size = r.size
	t.color = Color(1.0, 0.3, 0.1)
	t.position = r.get_center()
	Game.ground().add_child(t)
	Game.banner("Волна лавы!", 1.2)
	var tw := t.create_tween()
	tw.tween_property(t, "progress", 1.0, 1.5)
	tw.tween_callback(func() -> void:
		for pl in get_tree().get_nodes_in_group("player"):
			if not pl.dead and t.contains(pl.global_position):
				pl.take_damage(wave_damage, t.global_position)
		for i in 20:
			Game.burst(r.position + Vector2(randf() * r.size.x, randf() * r.size.y), FIRE, 2)
		Game.shake(4.0, 0.3)
		t.queue_free())


func _summon() -> void:
	for i in 2:
		var s: Node2D = minion_scene.instantiate()
		s.position = position + Vector2.from_angle(randf() * TAU) * 30.0
		s.xp_reward = 3
		s.gold_min = 0
		s.gold_max = 1
		s.item_chance = 0.0
		s.mat_chance = 0.2
		s.add_to_group("boss_minions")
		get_parent().add_child(s)
		Game.burst(s.position + Vector2(0, -6), FIRE, 10)


func _minion_count() -> int:
	var c := 0
	for m in get_tree().get_nodes_in_group("boss_minions"):
		if not m.dead:
			c += 1
	return c


# ---------------- Лучи (фаза 3) ----------------

func _start_beams() -> void:
	state = "beams"
	_t = BEAM_TIME + BEAM_WARN
	var p := nearest_player()
	# Лучи начинают поперёк направления на героя — есть время отойти.
	_beam_angle = ((p.global_position - global_position).angle() if p else 0.0) + PI / 2.0
	_beam_dir = 1.0 if randf() < 0.5 else -1.0
	Game.banner("Огненные лучи — беги по кругу!", 1.5)
	_log("beams")


func _beam_hits() -> void:
	for pl in get_tree().get_nodes_in_group("player"):
		if pl.dead:
			continue
		var to: Vector2 = pl.global_position - global_position
		for k in 2:
			var d := Vector2.from_angle(_beam_angle + k * PI)
			var along := to.dot(d)
			if along > 0.0 and along < BEAM_LEN and absf(to.cross(d)) < BEAM_WIDTH / 2.0 + 3.0:
				pl.take_damage(beam_damage, global_position)


func _draw_beams() -> void:
	if state != "beams":
		return
	var warn := _t > BEAM_TIME
	var origin := Vector2(0, -12)
	for k in 2:
		var d := Vector2.from_angle(_beam_angle + k * PI)
		if warn:
			_beam_fx.draw_line(origin, origin + d * BEAM_LEN, Color(1.0, 0.3, 0.2, 0.35), 1.0)
		else:
			var flicker := 0.75 + 0.25 * sin(_bob * 30.0)
			_beam_fx.draw_line(origin, origin + d * BEAM_LEN, Color(1.0, 0.45, 0.1, 0.55 * flicker), BEAM_WIDTH)
			_beam_fx.draw_line(origin, origin + d * BEAM_LEN, Color(1.0, 0.9, 0.5, flicker), 3.0)


# ---------------- Урон, фазы, смерть ----------------

func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if dead:
		return
	if state == "sleep":
		_wake()
	if state == "recover":
		amount = int(round(amount * STUN_BONUS))
	super.take_damage(amount, from, crit, missable)
	if dead:
		return
	var ratio := float(hp) / max_hp
	var new_phase := _phase_for(ratio)
	if new_phase > phase:
		phase = new_phase
		phase_changed.emit(phase)
		_on_phase(phase)
		if not is_mini:
			Game.banner("Фаза %d" % phase, 1.5)
		Game.shake(4.0, 0.4)
		_log("phase %d (hp %d/%d)" % [phase, hp, max_hp])


## Фаза по доле здоровья (финальный босс переопределяет: у него 4 фазы).
func _phase_for(ratio: float) -> int:
	return 1 if ratio > 0.6 else (2 if ratio > 0.3 else 3)


func _on_phase(_p: int) -> void:
	pass


func _extra_flash() -> float:
	if state == "cast" or (state == "beams" and _t > BEAM_TIME):
		return 0.35 + 0.3 * sin(Time.get_ticks_msec() / 25.0)
	return 0.0


func _die() -> void:
	if is_mini:
		super._die()  # мини-копия: без уборки арены и заставки
		return
	for m in get_tree().get_nodes_in_group("boss_minions"):
		if not m.dead:
			m._die()
	for t in get_tree().get_nodes_in_group("telegraphs"):
		t.queue_free()
	for p in get_tree().get_nodes_in_group("puddles"):
		p.queue_free()
	state = "dead"
	_beam_fx.queue_redraw()
	_log("defeated")
	Game.banner("%s повержен!" % BOSS_NAME, 3.0)
	Game.shake(6.0, 0.5)
	super._die()


func _drop_loot() -> void:
	if is_mini:
		for i in randi_range(3, 5):
			_spawn_pickup("gold", {})
		return
	if not loot_mats.is_empty():
		_boss_loot(randi_range(25, 32), loot_mats)
		return
	for i in randi_range(25, 30):
		_spawn_pickup("gold", {})
	_spawn_pickup("item", Items.make(Items.random_base(Run.cls, Run.job), 2, Run.depth))
	# Боссы всегда роняют часть комплекта.
	var set_piece := Items.random_set_item(Run.depth, Run.cls, Run.job)
	if not set_piece.is_empty():
		_spawn_pickup("item", set_piece)
	_spawn_pickup("item", Items.make(Items.random_base(Run.cls, Run.job), 2, Run.depth))
	for spec in [["sulfur", 4], ["obsidian", 3], ["scale", 3], ["ember_heart", 1]]:
		for i in spec[1]:
			_spawn_pickup("mat", {}, spec[0])


# ---------------- Сеть (кооп): фаза и особая графика для копии у гостя ----------------

func _net_extra() -> Array:
	return [state, phase, awake, _t, _beam_angle, _bob]


func _net_apply_extra(a: Array) -> void:
	state = a[0]
	phase = a[1]
	awake = a[2]
	_t = a[3]
	_beam_angle = a[4]
	_bob = a[5]
	_beam_fx.queue_redraw()
