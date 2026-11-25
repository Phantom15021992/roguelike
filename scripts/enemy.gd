extends CharacterBody2D
## Базовый монстр: здоровье, урон при касании, отбрасывание, вспышка, смерть.
## Конкретные монстры наследуются и переопределяют _setup() и _think().
## Слои столкновений: 1 — стены, 2 — игроки, 4 — монстры.

signal died(enemy: Node)

@export var max_hp := 30
@export var contact_damage := 15
@export var contact_radius := 9.0
@export var knockback_power := 120.0
@export var color := Color(1, 1, 1)   # цвет брызг при смерти
@export var xp_reward := 6
@export var gold_min := 1
@export var gold_max := 3
@export var item_chance := 0.12        # шанс выронить предмет
@export var evasion := 0               # % уклонения от ударов оружием (точность героя его снижает)
@export var mat_id := ""               # какой материал выпадает (см. crafting.gd)
@export var mat_chance := 0.0          # шанс выпадения материала

var last_hit_missed := false

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const PICKUP := preload("res://scripts/pickup.gd")
const Items := preload("res://scripts/items.gd")

@onready var sprite: AnimatedSprite2D = $Sprite

var hp: int
var dead := false
var _knockback := Vector2.ZERO
var _flash := 0.0
var _slow_time := 0.0


## Замедление: монстр ходит вдвое медленнее и синеет.
func apply_slow(seconds: float) -> void:
	if dead:
		return
	_slow_time = maxf(_slow_time, seconds)
	if _stun_time <= 0.0:
		sprite.modulate = Color(0.6, 0.8, 1.0)


var _stun_time := 0.0
var _burn_time := 0.0
var _burn_dps := 0.0
var _burn_acc := 0.0
var _in_dot := false


## Поджог (свойство «пламени»): урон в секунду в течение seconds.
func apply_burn(dps: float, seconds: float) -> void:
	if dead:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, seconds)


func _process_burn(delta: float) -> void:
	if _burn_time <= 0.0:
		return
	_burn_time -= delta
	_burn_acc += _burn_dps * delta
	if Engine.get_physics_frames() % 8 == 0:
		Game.burst(global_position + Vector2(randf_range(-4, 4), -8), Color(1.0, 0.5, 0.15), 1)
	if _burn_acc >= 1.0:
		var dmg := int(_burn_acc)
		_burn_acc -= dmg
		_in_dot = true
		take_damage(dmg, global_position, false, false)
		_in_dot = false
	if _burn_time <= 0.0:
		_burn_dps = 0.0


## Оглушение / заморозка: обычный монстр полностью стоит (не ходит, не атакует, не ранит
## касанием). Боссов не оглушить — их это только замедляет на 50%.
## kind: "freeze" (голубой) или "stun" (жёлтый). Возвращает true, если монстр обездвижен.
func apply_stun(seconds: float, kind := "stun") -> bool:
	if dead:
		return false
	if is_in_group("boss"):
		apply_slow(seconds)
		return false
	var fresh := _stun_time <= 0.0
	_stun_time = maxf(_stun_time, seconds)
	sprite.modulate = Color(0.55, 0.9, 1.0) if kind == "freeze" else Color(1.0, 0.95, 0.5)
	if fresh:
		Game.float_text(global_position + Vector2(0, -22), "Заморожен" if kind == "freeze" else "Оглушён", sprite.modulate)
	return true


func is_stunned() -> bool:
	return _stun_time > 0.0


## Дополнительный толчок (мощный удар и т.п.).
func push(dir: Vector2, power: float) -> void:
	if knockback_power > 0.0:
		_knockback = dir.normalized() * power


func _ready() -> void:
	# Чем глубже этаж, тем крепче, больнее и щедрее монстры.
	var d := Run.depth - 1
	max_hp = int(round(max_hp * (1.0 + 0.25 * d)))
	contact_damage = int(round(contact_damage * (1.0 + 0.15 * d)))
	xp_reward = int(round(xp_reward * (1.0 + 0.3 * d)))
	hp = max_hp
	add_to_group("enemies")
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	sprite.material = mat
	_win_start = global_position
	_setup()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_flash = maxf(0.0, _flash - delta * 6.0)
	_process_burn(delta)
	if dead:
		return
	sprite.material.set_shader_parameter("flash", maxf(_flash, _extra_flash()))
	if _stun_time > 0.0:
		# Обездвижен: только отлёт от ударов, никакого «мышления» и урона касанием.
		_stun_time -= delta
		_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
		velocity = _knockback
		move_and_slide()
		if _stun_time <= 0.0:
			sprite.modulate = Color(0.6, 0.8, 1.0) if _slow_time > 0.0 else Color.WHITE
		return
	var desired := _avoid_stuck(_think(delta), delta)
	if _slow_time > 0.0:
		_slow_time -= delta
		desired *= 0.5
		if _slow_time <= 0.0:
			sprite.modulate = Color.WHITE
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	velocity = desired + _knockback
	move_and_slide()
	_check_contact()


# --- Обход препятствий ---
# Раз в секунду: если монстр пытался идти, но прошёл меньше 25% от того, что должен был,
# значит упёрся (в колонну, стену, другого монстра). Тогда какое-то время идёт вбок —
# каждый раз в другую сторону — и потом снова к цели.

const STUCK_WINDOW := 1.0
const STUCK_RATIO := 0.25
const DETOUR_TIME := 0.66

var _win_time := 0.0
var _win_expected := 0.0
var _win_start := Vector2.ZERO
var _detour_time := 0.0
var _detour_dir := Vector2.ZERO
var _detour_side := 1.0
var _last_dir := Vector2.DOWN


func _avoid_stuck(desired: Vector2, delta: float) -> Vector2:
	if _detour_time > 0.0:
		_detour_time -= delta
		if _detour_time <= 0.0:
			_reset_stuck_window()
		return _detour_dir * desired.length()

	if desired != Vector2.ZERO:
		_last_dir = desired.normalized()
	_win_time += delta
	_win_expected += desired.length() * delta
	if _win_time >= STUCK_WINDOW:
		var moved := global_position.distance_to(_win_start)
		if _win_expected > 8.0 and moved < _win_expected * STUCK_RATIO:
			_detour_side *= -1.0
			_detour_dir = _last_dir.orthogonal() * _detour_side
			_detour_time = DETOUR_TIME
			if "--autotest" in OS.get_cmdline_user_args():
				print("  %s stuck: moved %.1f of %.1f -> step %s" % [name, moved, _win_expected, "left" if _detour_side > 0 else "right"])
			_reset_stuck_window()
			return _detour_dir * desired.length()
		_reset_stuck_window()
	return desired


func _reset_stuck_window() -> void:
	_win_time = 0.0
	_win_expected = 0.0
	_win_start = global_position


# --- Переопределяется в наследниках ---

func _setup() -> void:
	pass


## Возвращает желаемую скорость на этот кадр.
func _think(_delta: float) -> Vector2:
	return Vector2.ZERO


## Дополнительная подсветка (например, перед выстрелом).
func _extra_flash() -> float:
	return 0.0


# --- Общее ---

func nearest_player() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p.dead:
			continue
		var d := global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Опасен ли монстр при касании прямо сейчас (слизень — только в прыжке).
func _is_dangerous() -> bool:
	return true


func _check_contact() -> void:
	if contact_damage <= 0 or not _is_dangerous():
		return
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead and global_position.distance_to(p.global_position) < contact_radius:
			p.take_damage(contact_damage, global_position)


## missable — удар оружием может промахнуться (уклонение монстра против точности героя).
## Криты и магия попадают всегда.
func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if dead:
		return
	last_hit_missed = false
	if missable and not crit and evasion > 0:
		var p := get_tree().get_first_node_in_group("player")
		var miss_chance: int = evasion - (p.accuracy if p else 0)
		if miss_chance > 0 and randf() * 100.0 < miss_chance:
			last_hit_missed = true
			if "--autotest" in OS.get_cmdline_user_args():
				print("  miss %s (evasion %d)" % [name, evasion])
			Game.float_text(global_position + Vector2(0, -20), "Мимо", Color(0.75, 0.75, 0.8))
			return
	# Особые свойства снаряжения героя: урон боссам, вампиризм, поджог, оглушение.
	# Урон от горения сам ничего не запускает (иначе поджог поджигал бы сам себя).
	var hero: Node = get_tree().get_first_node_in_group("player")
	if hero and not _in_dot and is_in_group("boss"):
		amount = int(round(amount * (1.0 + hero.special("boss") / 100.0)))
	hp -= amount
	if hero and not _in_dot:
		hero.on_damage_dealt(self, amount)
	if OS.is_debug_build() and "--autotest" in OS.get_cmdline_user_args():
		print("  hit %s -%d -> hp %d" % [name, amount, hp])
	_flash = 1.0
	_reset_stuck_window()  # отлёт от удара не считаем за движение
	_knockback =(global_position - from).normalized() * knockback_power * (1.5 if crit else 1.0)
	Game.damage_number(global_position + Vector2(0, -18), amount, Color(1.0, 0.85, 0.2) if crit else Color.WHITE)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	died.emit(self)
	Game.burst(global_position + Vector2(0, -6), color, 16)
	Run.add_xp(xp_reward)
	_drop_loot()
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.5, 0.2), 0.15)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	# Сокровищница добавляет монет (дробная часть — шанс на ещё одну).
	var coins := randi_range(gold_min, gold_max) * Meta.gold_mult()
	for i in int(coins) + (1 if randf() < coins - int(coins) else 0):
		_spawn_pickup("gold", {})
	if mat_id != "" and randf() < mat_chance:
		_spawn_pickup("mat", {}, mat_id)
	# Удача героя повышает шанс выпадения предметов.
	if randf() < item_chance * (1.0 + Run.derived()["drop"] / 100.0):
		_spawn_pickup("item", Items.random_item(Run.depth, Run.cls, Run.job))


func _spawn_pickup(kind: String, item: Dictionary, mat := "") -> void:
	var p: Node2D = PICKUP.new()
	p.kind = kind
	p.mat = mat
	p.value = Run.depth
	p.item = item
	p.position = position
	get_parent().add_child.call_deferred(p)


## anims: {"имя": [[номера кадров], fps]} — квадратные кадры size x size по горизонтали.
func make_frames(sheet: Texture2D, anims: Dictionary, size := 16) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in anims:
		var spec: Array = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, spec[1])
		frames.set_animation_loop(anim_name, true)
		for i: int in spec[0]:
			var t := AtlasTexture.new()
			t.atlas = sheet
			t.region = Rect2(i * size, 0, size, size)
			frames.add_frame(anim_name, t)
	return frames
