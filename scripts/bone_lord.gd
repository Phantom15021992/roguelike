extends "res://scripts/enemy.gd"
## Повелитель костей — второй босс (катакомбы).
##
## Фаза 1 (HP > 65%): телепортируется по арене, бросает залпы костяных копий, поднимает скелетов.
## Фаза 2 (HP > 35%): + кольцо снарядов с проёмом (в проём и надо проскочить),
##   + могилы: красные круги вокруг героя, из которых через секунду бьют кости.
## Фаза 3: поднимает щит и призывает 3 кристалла — пока они целы, его не ранить.
##   Разбил кристаллы — он оглушён 3 с и получает +50% урона. Дальше всё быстрее.
##
## Тактики: прятаться от копий за колоннами; ловить его после телепорта;
## отвлекаться на скелетов или игнорировать их; разделить внимание между кристаллами.

signal woke
signal phase_changed(phase: int)

var BOSS_NAME := "Повелитель костей"
var tempo := 1.0             # варианты босса на глубине действуют быстрее
var shot_chill := 0.0        # снаряды замедляют героя (ледяные варианты)
const SHEET := preload("res://assets/bone_lord.png")
const SKELETON := preload("res://scenes/skeleton.tscn")
const CRYSTAL := preload("res://scenes/crystal.tscn")
const PROJECTILE := preload("res://scripts/projectile.gd")
const TELEGRAPH := preload("res://scripts/telegraph.gd")

const SPRITE_Y := -18.0
const IDLE_TIME := [1.2, 0.9, 0.65]
const STUN_BONUS := 1.5
const BONE := Color(0.9, 0.88, 0.8)
const MAGIC := Color(0.55, 0.85, 0.5)

@export var spear_damage := 18
@export var orb_damage := 14
@export var grave_damage := 24

var arena := Rect2()
var awake := false
var phase := 1
var state := "sleep"
var shielded := false
var _t := 0.0
var _cast := ""
var _shield_done := false
var _bob := 0.0
var _shield_fx: Node2D
var _shield_hint := 0.0


func _setup() -> void:
	add_to_group("boss")
	knockback_power = 0.0
	var k := (1.0 + 0.15 * (Run.depth - 1)) * power
	spear_damage = int(round(spear_damage * k))
	orb_damage = int(round(orb_damage * k))
	grave_damage = int(round(grave_damage * k))
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0], 1.0]}, 32)
	sprite.play("idle")
	_shield_fx = Node2D.new()
	_shield_fx.draw.connect(_draw_shield)
	add_child(_shield_fx)


func _log(msg: String) -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		print("  BOSS2: " + msg)


# ---------------- Поведение ----------------

func _think(delta: float) -> Vector2:
	_t -= delta
	_bob += delta
	_shield_hint = maxf(0.0, _shield_hint - delta)
	sprite.position.y = SPRITE_Y + roundf(sin(_bob * 2.0) * 1.5)
	_shield_fx.queue_redraw()
	var p := nearest_player()
	match state:
		"sleep":
			if p and arena.grow(-12.0).has_point(p.global_position):
				_wake()
		"idle":
			if _t <= 0.0:
				_choose_action()
			elif p:
				# Держит дистанцию ~70 px.
				var to := p.global_position - global_position
				return to.normalized() * signf(to.length() - 70.0) * 18.0
		"fade_out":
			sprite.modulate.a = clampf(_t / 0.4, 0.0, 1.0)
			if _t <= 0.0:
				_teleport_now()
		"fade_in":
			sprite.modulate.a = clampf(1.0 - _t / 0.4, 0.0, 1.0)
			if _t <= 0.0:
				sprite.modulate.a = 1.0
				_idle()
		"cast":
			if _t <= 0.0:
				_do_cast()
				_idle()
		"stunned":
			if _t <= 0.0:
				_idle()
	return Vector2.ZERO


func _idle() -> void:
	state = "idle"
	_t = IDLE_TIME[phase - 1] / tempo * (1.4 if shielded else 1.0)


func _wake() -> void:
	awake = true
	_idle()
	woke.emit()
	if not is_mini:
		Game.banner(BOSS_NAME, 2.5)
	Game.shake(3.0, 0.4)
	_log("woke")


func _choose_action() -> void:
	var r := randf()
	var can_summon := _minion_count() < 1 + phase
	var action := "spears"
	if phase == 1:
		action = "teleport" if r < 0.25 else ("spears" if r < 0.75 or not can_summon else "summon")
	else:
		if r < 0.15 and not shielded:
			action = "teleport"
		elif r < 0.45:
			action = "spears"
		elif r < 0.7:
			action = "ring"
		elif r < 0.9:
			action = "graves"
		else:
			action = "summon" if can_summon else "graves"
	if action == "teleport":
		state = "fade_out"
		_t = 0.4
		return
	_cast = action
	state = "cast"
	_t = {"spears": 0.5, "ring": 0.7, "graves": 0.4, "summon": 0.6}[action]


func _teleport_now() -> void:
	var p := nearest_player()
	var inner := arena.grow(-28.0)
	var spot := open_spot(inner.get_center())
	for i in 30:
		var cand := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		if (p == null or cand.distance_to(p.global_position) > 70.0) and open_spot(cand) == cand:
			spot = cand
			break
	Game.burst(global_position + Vector2(0, -12), MAGIC, 12)
	global_position = spot
	Game.burst(global_position + Vector2(0, -12), MAGIC, 12)
	state = "fade_in"
	_t = 0.4


func _do_cast() -> void:
	_log("cast %s" % _cast)
	match _cast:
		"spears":
			for v in 3:
				get_tree().create_timer(v * 0.3).timeout.connect(_spear_volley)
		"ring":
			_ring(randf() * TAU)
			get_tree().create_timer(0.7).timeout.connect(func() -> void:
				if not dead:
					_ring(randf() * TAU))
		"graves":
			_graves()
		"summon":
			_summon()


func _spear_volley() -> void:
	if dead:
		return
	var p := nearest_player()
	if p == null:
		return
	var dir := (p.global_position - global_position).normalized()
	for a in [-0.18, 0.0, 0.18]:
		_shoot(dir.rotated(a), "bone", spear_damage, 120.0, BONE)


func _ring(gap_angle: float) -> void:
	var n := 18
	for i in n:
		var a := TAU * i / n
		if absf(angle_difference(a, gap_angle)) < TAU / n * 1.6:
			continue  # проём, в который можно проскочить
		_shoot(Vector2.from_angle(a), "orb", orb_damage, 55.0, MAGIC)


func _shoot(dir: Vector2, style: String, dmg: int, speed: float, col: Color) -> void:
	var b: Area2D = PROJECTILE.new()
	b.direction = dir
	b.style = style
	b.damage = dmg
	b.speed = speed
	b.lifetime = 4.0
	b.color = col
	b.chill = shot_chill
	b.position = global_position
	Game.fx().add_child(b)


func _graves() -> void:
	var p := nearest_player()
	if p == null:
		return
	var count := 4 if phase == 2 else 6
	for i in count:
		var pos := p.global_position if i == 0 else p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 55.0)
		pos = pos.clamp(arena.position + Vector2(12, 12), arena.end - Vector2(12, 12))
		var t: Node2D = TELEGRAPH.new()
		t.radius = 16.0
		t.position = pos
		Game.ground().add_child(t)
		var tw := t.create_tween()
		tw.tween_property(t, "progress", 1.0, 1.0)
		tw.tween_callback(func() -> void:
			for pl in get_tree().get_nodes_in_group("player"):
				if not pl.dead and t.contains(pl.global_position):
					pl.take_damage(grave_damage, t.global_position)
			Game.burst(t.global_position + Vector2(0, -6), BONE, 12)
			t.queue_free())


func _summon() -> void:
	for i in 2:
		var s: Node2D = SKELETON.instantiate()
		s.position = position + Vector2.from_angle(randf() * TAU) * 28.0
		s.xp_reward = 3
		s.gold_min = 0
		s.gold_max = 1
		s.item_chance = 0.0
		s.mat_chance = 0.2
		s.add_to_group("boss_minions")
		get_parent().add_child(s)
		Game.burst(s.position + Vector2(0, -6), BONE, 10)


func _minion_count() -> int:
	var c := 0
	for m in get_tree().get_nodes_in_group("boss_minions"):
		if not m.dead:
			c += 1
	return c


# ---------------- Щит и кристаллы ----------------

func _raise_shield() -> void:
	_shield_done = true
	shielded = true
	var spots := [
		arena.position + Vector2(40, 40),
		Vector2(arena.end.x - 40, arena.position.y + 40),
		Vector2(arena.get_center().x, arena.end.y - 30),
	]
	for s in spots:
		var c: Node2D = CRYSTAL.instantiate()
		s = open_spot(s)  # не в колонну арены
		c.position = s
		c.died.connect(_on_crystal_died)
		get_parent().add_child.call_deferred(c)  # щит поднимается в момент попадания — добавлять только после
		Game.burst(s + Vector2(0, -8), Color(0.7, 0.5, 1.0), 12)
	Game.banner("Щит! Разбей кристаллы", 2.5)
	_log("shield up")


func _on_crystal_died(_c: Node) -> void:
	for c in get_tree().get_nodes_in_group("crystals"):
		if not c.dead:
			return
	shielded = false
	state = "stunned"
	_t = 3.0
	Game.banner("Щит разбит!", 2.0)
	Game.shake(4.0, 0.4)
	Game.float_text(global_position + Vector2(0, -40), "Оглушён!", Color(1.0, 0.9, 0.4))
	_log("shield broken")


func _draw_shield() -> void:
	if not shielded:
		return
	var pulse := 0.5 + 0.5 * sin(_bob * 5.0)
	_shield_fx.draw_circle(Vector2(0, -14), 20.0, Color(0.6, 0.45, 1.0, 0.15 + 0.1 * pulse))
	_shield_fx.draw_arc(Vector2(0, -14), 20.0, 0.0, TAU, 32, Color(0.75, 0.6, 1.0, 0.8), 1.0)
	for c in get_tree().get_nodes_in_group("crystals"):
		if not c.dead:
			_shield_fx.draw_line(Vector2(0, -14), c.global_position - global_position + Vector2(0, -9), Color(0.7, 0.5, 1.0, 0.35 + 0.3 * pulse), 1.0)


# ---------------- Урон, фазы, смерть ----------------

func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if dead or state in ["fade_out", "fade_in"]:
		return
	if shielded:
		if _shield_hint <= 0.0:
			_shield_hint = 0.8
			Game.float_text(global_position + Vector2(0, -40), "Щит!", Color(0.75, 0.6, 1.0))
		return
	if state == "sleep":
		_wake()
	if state == "stunned":
		amount = int(round(amount * STUN_BONUS))
	super.take_damage(amount, from, crit, missable)
	if dead:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > 0.65 else (2 if ratio > 0.35 else 3)
	if new_phase > phase:
		phase = new_phase
		phase_changed.emit(phase)
		if not is_mini:
			Game.banner("Фаза %d" % phase, 1.5)
		Game.shake(4.0, 0.4)
		_log("phase %d (hp %d/%d)" % [phase, hp, max_hp])
		if phase == 3 and not _shield_done and not is_mini:
			_raise_shield()


func _extra_flash() -> float:
	if state == "cast":
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
	for i in randi_range(20, 26):
		_spawn_pickup("gold", {})
	_spawn_pickup("item", Items.make(Items.random_base(Run.cls, Run.job), 2, Run.depth))
	# Боссы всегда роняют часть комплекта.
	var set_piece := Items.random_set_item(Run.depth, Run.cls, Run.job)
	if not set_piece.is_empty():
		_spawn_pickup("item", set_piece)
	_spawn_pickup("item", Items.make(Items.random_base(Run.cls, Run.job), 2, Run.depth))
	for i in 6:
		_spawn_pickup("mat", {}, "bone")
	for i in 3:
		_spawn_pickup("mat", {}, "ore")
	_spawn_pickup("mat", {}, "phylactery")


# ---------------- Сеть (кооп): фаза и особая графика для копии у гостя ----------------

func _net_extra() -> Array:
	return [state, phase, awake, shielded, _bob]


func _net_apply_extra(a: Array) -> void:
	state = a[0]
	phase = a[1]
	awake = a[2]
	shielded = a[3]
	_bob = a[4]
	_shield_fx.queue_redraw()
