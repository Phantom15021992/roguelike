extends "res://scripts/enemy.gd"
## Король слизней — первый босс.
##
## Фаза 1 (HP > 60%): прыжок на героя (место приземления видно заранее — красный круг),
##   после приземления оглушён и получает +50% урона; призывает слизней.
## Фаза 2 (HP > 30%): после прыжка остаётся кислотная лужа; иногда прыгает дважды подряд;
##   плюётся веером сгустков (от них прячутся за колоннами).
## Фаза 3: всё быстрее, между атаками ползёт за героем и ранит касанием.
##
## Разные тактики: бить в окно оглушения; сначала чистить призванных слизней;
## держать дистанцию и прятаться за колоннами; танковать через Живучесть.

signal woke
signal phase_changed(phase: int)

var BOSS_NAME := "Король слизней"
var tempo := 1.0             # варианты босса на глубине действуют быстрее
var shot_chill := 0.0        # снаряды замедляют героя (ледяные варианты)
const SHEET := preload("res://assets/boss_slime.png")
const SLIME_SCENE := preload("res://scenes/slime.tscn")
const PROJECTILE := preload("res://scripts/projectile.gd")
const TELEGRAPH := preload("res://scripts/telegraph.gd")
const PUDDLE := preload("res://scripts/puddle.gd")

const SPRITE_Y := -16.0
const AIR_TIME := 0.55
const JUMP_HEIGHT := 40.0
const STUN_BONUS := 1.5

# По фазам [1, 2, 3]
const TELEGRAPH_TIME := [1.1, 0.9, 0.75]
const STUN_TIME := [1.6, 1.2, 0.9]
const IDLE_TIME := [1.0, 0.75, 0.5]

@export var slam_damage := 30
@export var slam_radius := 30.0
@export var spit_damage := 16
@export var puddle_damage := 6

var arena := Rect2()     # задаёт подземелье; герой внутри — босс просыпается
var awake := false
var phase := 1
var state := "sleep"
var _t := 0.0
var _from := Vector2.ZERO
var _target := Vector2.ZERO
var _telegraph: Node2D
var _cast := ""
var _double_pending := false
var _second_slam := false  # второй прыжок серии — третьего подряд не будет


func _setup() -> void:
	add_to_group("boss")
	knockback_power = 0.0
	var k := (1.0 + 0.15 * (Run.depth - 1)) * power
	slam_damage = int(round(slam_damage * k))
	spit_damage = int(round(spit_damage * k))
	puddle_damage = int(round(puddle_damage * k))
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0, 1], 2.0], "squash": [[1], 1.0], "stretch": [[2], 1.0]}, 32)
	sprite.play("idle")


func _log(msg: String) -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		print("  BOSS: " + msg)


# ---------------- Поведение ----------------

func _think(delta: float) -> Vector2:
	_t -= delta
	match state:
		"sleep":
			var p := nearest_player()
			if p and arena.grow(-12.0).has_point(p.global_position):
				_wake()
		"idle":
			if _t <= 0.0:
				_choose_action()
			elif phase == 3:
				var p := nearest_player()
				if p:
					return (p.global_position - global_position).normalized() * 28.0
		"telegraph":
			if is_instance_valid(_telegraph):
				_telegraph.progress = 1.0 - _t / TELEGRAPH_TIME[phase - 1]
			if _t <= 0.0:
				_start_jump()
		"air":
			var k := clampf(1.0 - _t / AIR_TIME, 0.0, 1.0)
			global_position = _from.lerp(_target, k)
			sprite.position.y = SPRITE_Y - roundf(sin(k * PI) * JUMP_HEIGHT)
			if _t <= 0.0:
				_land()
		"stunned":
			if _t <= 0.0:
				if _double_pending:
					_double_pending = false
					_second_slam = true
					_begin_slam()
				else:
					_set_state("idle", IDLE_TIME[phase - 1] / tempo)
		"cast":
			if _t <= 0.0:
				if _cast == "summon":
					_summon()
				else:
					_spit()
				_set_state("idle", IDLE_TIME[phase - 1] / tempo)
	return Vector2.ZERO


func _set_state(s: String, time: float) -> void:
	state = s
	_t = time
	match s:
		"idle":
			sprite.play("idle")
		"telegraph", "stunned":
			sprite.play("squash")
		"air", "cast":
			sprite.play("stretch")


func _wake() -> void:
	awake = true
	_set_state("idle", 1.2)
	woke.emit()
	if not is_mini:
		Game.banner(BOSS_NAME, 2.5)
	Game.shake(3.0, 0.4)
	_log("woke")


func _choose_action() -> void:
	var r := randf()
	var can_summon := _minion_count() < 2 + phase
	var action := "slam"
	match phase:
		1:
			action = "summon" if r >= 0.7 and can_summon else "slam"
		2:
			if r < 0.5:
				action = "slam"
			elif r < 0.8:
				action = "spit"
			else:
				action = "summon" if can_summon else "spit"
		3:
			if r < 0.45:
				action = "slam"
			elif r < 0.85:
				action = "spit"
			else:
				action = "summon" if can_summon else "slam"
	if action == "slam":
		_begin_slam()
	else:
		_cast = action
		_set_state("cast", 0.6)


func _begin_slam() -> void:
	var p := nearest_player()
	if p == null:
		_set_state("idle", 1.0)
		return
	var inner := arena.grow(-20.0)
	_target = p.global_position.clamp(inner.position, inner.end)
	_telegraph = TELEGRAPH.new()
	_telegraph.radius = slam_radius
	_telegraph.position = _target
	Game.ground().add_child(_telegraph)
	_set_state("telegraph", TELEGRAPH_TIME[phase - 1])


func _start_jump() -> void:
	_from = global_position
	collision_mask = 0
	_set_state("air", AIR_TIME)


func _land() -> void:
	global_position = _target
	sprite.position.y = SPRITE_Y
	collision_mask = 1 | 4
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	Game.shake(5.0, 0.3)
	Game.burst(global_position + Vector2(0, -4), color, 24)
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead and p.global_position.distance_to(global_position) < slam_radius:
			p.take_damage(slam_damage, global_position)
	if phase >= 2:
		var puddle: Node2D = PUDDLE.new()
		puddle.damage = puddle_damage
		puddle.position = global_position
		Game.ground().add_child(puddle)
	var was_second := _second_slam
	_second_slam = false
	if phase >= 2 and not was_second and randf() < 0.4:
		_double_pending = true
		_set_state("stunned", 0.35)  # короткая пауза и сразу второй прыжок
		_log("double slam")
		return
	_set_state("stunned", STUN_TIME[phase - 1])
	Game.float_text(global_position + Vector2(0, -38), "Оглушён!", Color(1.0, 0.9, 0.4))


func _summon() -> void:
	var n := 2 if phase < 3 else 3
	for i in n:
		var s: Node2D = SLIME_SCENE.instantiate()
		s.position = position + Vector2.from_angle(randf() * TAU) * 26.0
		s.xp_reward = 2
		s.gold_min = 0
		s.gold_max = 1
		s.item_chance = 0.0
		s.mat_chance = 0.2
		s.add_to_group("boss_minions")
		get_parent().add_child(s)
		Game.burst(s.position + Vector2(0, -6), color, 8)
	_log("summon %d" % n)


func _spit() -> void:
	var p := nearest_player()
	if p == null:
		return
	var n := 5 if phase < 3 else 7
	var spread := deg_to_rad(70.0)
	var base_dir := (p.global_position - global_position).normalized()
	for i in n:
		var b: Area2D = PROJECTILE.new()
		b.direction = base_dir.rotated(-spread / 2.0 + spread * i / (n - 1))
		b.damage = spit_damage
		b.speed = 70.0
		b.color = Color(0.35, 0.8, 0.3)
		b.chill = shot_chill
		b.position = global_position
		Game.fx().add_child(b)
	_log("spit %d" % n)


func _minion_count() -> int:
	var c := 0
	for m in get_tree().get_nodes_in_group("boss_minions"):
		if not m.dead:
			c += 1
	return c


# ---------------- Урон, фазы, смерть ----------------

func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if dead or state == "air":
		return
	if state == "sleep":
		_wake()
	if state == "stunned":
		amount = int(round(amount * STUN_BONUS))
	super.take_damage(amount, from, crit, missable)
	if dead:
		return
	var ratio := float(hp) / max_hp
	var new_phase := 1 if ratio > 0.6 else (2 if ratio > 0.3 else 3)
	if new_phase > phase:
		phase = new_phase
		phase_changed.emit(phase)
		if not is_mini:
			Game.banner("Фаза %d" % phase, 1.5)
		Game.shake(4.0, 0.4)
		_log("phase %d (hp %d/%d)" % [phase, hp, max_hp])
		if state == "idle":
			_cast = "summon"
			_set_state("cast", 0.6)


func _is_dangerous() -> bool:
	return phase == 3 and state == "idle"


func _extra_flash() -> float:
	if state == "cast":
		return 0.4 + 0.3 * sin(Time.get_ticks_msec() / 25.0)
	return 0.0


func _die() -> void:
	if is_mini:
		super._die()  # мини-копия: без уборки арены и заставки
		return
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	for m in get_tree().get_nodes_in_group("boss_minions"):
		if not m.dead:
			m._die()
	for puddle in get_tree().get_nodes_in_group("puddles"):
		puddle.queue_free()
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
	for i in randi_range(15, 20):
		_spawn_pickup("gold", {})
	_spawn_pickup("item", Items.make(Items.random_base(Run.cls, Run.job), 2, Run.depth))
	# Боссы всегда роняют часть комплекта.
	var set_piece := Items.random_set_item(Run.depth, Run.cls, Run.job)
	if not set_piece.is_empty():
		_spawn_pickup("item", set_piece)
	_spawn_pickup("item", Items.random_item(Run.depth, Run.cls, Run.job))
	for i in 6:
		_spawn_pickup("mat", {}, "gel")
	_spawn_pickup("mat", {}, "crown")


# ---------------- Сеть (кооп): фаза и особая графика для копии у гостя ----------------

func net_props() -> Array:
	return super.net_props() + ["BOSS_NAME"]  # у гостя — то же имя на полосе здоровья


func _net_extra() -> Array:
	return [state, phase, awake]


func _net_apply_extra(a: Array) -> void:
	state = a[0]
	phase = a[1]
	awake = a[2]
