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

# Настройки, которые задаёт список боссов (boss_roster.gd) до появления монстра:
var is_mini := false          # мини-копия босса (её призывает финальный босс биома): без добычи и заставок
var power := 1.0           # множитель урона атак (у боссов)
var hp_mult := 1.0         # множитель здоровья
var tint := Color(1, 1, 1, 1)
var size := 1.0
var loot_mats: Array = []  # добыча-материалы босса [[id, сколько], ...]; пусто — как задумано в его скрипте
var elite := false         # элитный монстр (крупнее, сильнее, с особым свойством, богатая добыча)
var elite_kind := ""       # armored / swift / explosive / regen (см. dungeon.ELITE_KINDS)

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
	var mod := Game.floor_mod()
	max_hp = int(round(max_hp * (1.0 + 0.25 * d) * hp_mult * (2.5 if elite else 1.0) * (1.5 if mod == "gold_rush" and not is_in_group("boss") else 1.0)))
	contact_damage = int(round(contact_damage * (1.0 + 0.15 * d)))
	xp_reward = int(round(xp_reward * (1.0 + 0.3 * d)))
	hp = max_hp
	add_to_group("enemies")
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	sprite.material = mat
	_win_start = global_position
	_setup()
	if own_art:
		# Своя цветная картинка: перекраска наследника не нужна (прозрачность — оставить).
		sprite.self_modulate = Color(1, 1, 1, sprite.self_modulate.a)
	elif tint != Color(1, 1, 1, 1):
		sprite.self_modulate = tint
	if size != 1.0:
		scale = Vector2(size, size)
	if is_mini:
		# Мини-копия: не главный босс этажа (полоса здоровья и ворота — не про неё).
		remove_from_group("boss")
		add_to_group("boss_minions")
	if elite:
		_make_elite()


# ---------------- Сеть (кооп) ----------------
# У гостя монстр — копия: не думает и не ранит, только показывает то, что прислал хозяин.

func net_props() -> Array:
	return ["elite", "elite_kind", "tint", "is_mini", "boss_art"]


func net_state() -> Array:
	return [Net.pack_sprite(sprite), hp, max_hp, dead, _net_extra(), look_dir]


func net_apply(a: Array) -> void:
	Net.unpack_sprite(sprite, a[0])
	hp = a[1]
	max_hp = a[2]
	if a[3] and not dead:
		dead = true
		remove_from_group("enemies")
	_net_apply_extra(a[4])
	if a.size() > 5:
		_set_look(str(a[5]))


## Наследники (боссы) добавляют свои поля: фазы, щиты, лучи.
func _net_extra() -> Array:
	return []


func _net_apply_extra(_a: Array) -> void:
	pass


func _physics_process(delta: float) -> void:
	if dead or Net.is_guest():
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
	if elite_kind == "swift":
		desired *= 1.45
	elif elite_kind == "regen" and hp < max_hp:
		_regen_acc += max_hp * 0.03 * delta
		if _regen_acc >= 1.0:
			hp = mini(max_hp, hp + int(_regen_acc))
			_regen_acc -= int(_regen_acc)
	if _slow_time > 0.0:
		_slow_time -= delta
		desired *= 0.5
		if _slow_time <= 0.0:
			sprite.modulate = Color.WHITE
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	velocity = desired + _knockback
	move_and_slide()
	_check_contact()
	_update_look()
	_update_pose(delta)


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
			if _pose != "attack":
				pose("attack", 0.3)


## missable — удар оружием может промахнуться (уклонение монстра против точности героя).
## Криты и магия попадают всегда.
func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	if dead:
		return
	last_hit_missed = false
	if missable and not crit and evasion > 0:
		var p: Node = _attacker()
		var miss_chance: int = evasion - (p.accuracy if p else 0)
		if miss_chance > 0 and randf() * 100.0 < miss_chance:
			last_hit_missed = true
			if "--autotest" in OS.get_cmdline_user_args():
				print("  miss %s (evasion %d)" % [name, evasion])
			Game.float_text(global_position + Vector2(0, -20), "Мимо", Color(0.75, 0.75, 0.8))
			return
	# Особые свойства снаряжения героя: урон боссам, вампиризм, поджог, оглушение.
	# Урон от горения сам ничего не запускает (иначе поджог поджигал бы сам себя).
	if elite_kind == "armored":
		amount = maxi(1, int(round(amount * 0.5)))
	if Game.floor_mod() == "glass":
		amount = int(round(amount * 1.4))
	var hero: Node = _attacker()
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
	if hp > 0 and not is_in_group("boss"):
		pose("hurt", 0.16)
	Game.damage_number(global_position + Vector2(0, -18), amount, Color(1.0, 0.85, 0.2) if crit else Color.WHITE)
	if hp <= 0:
		_die()


## Кто ударил: герой, отметившийся в Game.attacker, иначе — первый герой.
## Точка рядом, где можно стоять (не в стене и не в колонне арены).
func open_spot(pos: Vector2) -> Vector2:
	var scene := get_tree().current_scene
	if scene and scene.has_method("open_spot"):
		return scene.open_spot(pos)
	return pos


func _attacker() -> Node:
	var a: Node = Game.attacker
	if is_instance_valid(a) and a.is_in_group("player"):
		return a
	return get_tree().get_first_node_in_group("player")


func _die() -> void:
	if elite and not Net.is_guest():
		Game.quest_progress("elites")
		if elite_kind == "explosive":
			_elite_blast()
	if not Net.is_guest() and not is_in_group("boss") and not is_mini:
		Game.quest_progress("kills")
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	died.emit(self)
	Game.burst(global_position + Vector2(0, -6), color, 16)
	# Опыт получают все герои (в коопе — каждый полностью).
	for st: Node in Net.all_states():
		st.add_xp(xp_reward)
	_drop_loot()
	var tw := create_tween()
	if not _look_frames.is_empty() and sprite.sprite_frames.has_animation("die"):
		# Новая графика: оседает (кадры смерти), потом тает.
		_pose = ""
		sprite.play("die")
		tw.tween_interval(0.3)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
	else:
		tw.tween_property(sprite, "scale", Vector2(1.5, 0.2), 0.15)
		tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


## Взрывной элитный: после смерти — круг и взрыв через 0.8 с.
func _elite_blast() -> void:
	var pos := global_position
	var dmg := scaled(30)
	var w := spawn_warning(pos, 34.0, Color(1.0, 0.5, 0.2))
	var tw := w.create_tween()
	tw.tween_property(w, "progress", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		for pl in w.get_tree().get_nodes_in_group("player"):
			if not pl.dead and pl.global_position.distance_to(pos) < 34.0:
				pl.take_damage(dmg, pos)
		Game.ring(pos, 34.0, Color(1.0, 0.5, 0.2))
		Game.burst(pos + Vector2(0, -6), Color(1.0, 0.55, 0.2), 20)
		w.queue_free())


func _drop_loot() -> void:
	var mod := Game.floor_mod()
	# Сокровищница добавляет монет (дробная часть — шанс на ещё одну).
	var coins := randi_range(gold_min, gold_max) * Meta.gold_mult() * (2.0 if mod == "gold_rush" else 1.0) * (3.0 if elite else 1.0)
	for i in int(coins) + (1 if randf() < coins - int(coins) else 0):
		_spawn_pickup("gold", {})
	if mat_id != "" and randf() < mat_chance * (2.0 if mod == "bounty" else 1.0):
		_spawn_pickup("mat", {}, mat_id)
		if mod == "bounty" and randf() < 0.3:
			_spawn_pickup("mat", {}, mat_id)
	# Удача героя повышает шанс выпадения предметов.
	# Лут общий: предмет — под класс случайного героя команды.
	var st: Node = Game.random_hero_state()
	if elite or randf() < item_chance * (1.0 + st.derived()["drop"] / 100.0) * (1.5 if mod == "bounty" else 1.0):
		_spawn_pickup("item", Items.random_item(Run.depth, st.cls, st.job))


func _spawn_pickup(kind: String, item: Dictionary, mat := "") -> void:
	var p: Node2D = PICKUP.new()
	p.kind = kind
	p.mat = mat
	p.value = Run.depth
	p.item = item
	p.position = position
	get_parent().add_child.call_deferred(p)


# ---------------- Элитные монстры ----------------

var _regen_acc := 0.0
const _E_RING_COLORS := {"armored": Color(0.75, 0.8, 0.9), "swift": Color(0.5, 1.0, 0.6), "explosive": Color(1.0, 0.5, 0.2), "regen": Color(1.0, 0.4, 0.5)}
const _E_NAMES := {"armored": "Бронированный", "swift": "Быстрый", "explosive": "Взрывной", "regen": "Живучий"}


func _make_elite() -> void:
	xp_reward *= 3
	if size == 1.0:
		scale = Vector2(1.25, 1.25)
	# Золотое кольцо под ногами и точка цвета свойства.
	var ring := Node2D.new()
	ring.draw.connect(func() -> void:
		ring.draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.3, 0.9), 1.5)
		ring.draw_circle(Vector2(0, -26), 2.0, _E_RING_COLORS.get(elite_kind, Color.WHITE)))
	add_child(ring)
	move_child(ring, 1)  # после тени, но под спрайтом


## Имя для подсказки: «Элита: Бронированный».
func elite_title() -> String:
	return "Элита: " + str(_E_NAMES.get(elite_kind, ""))


# ---------------- Помощники для монстров ----------------

const _E_PUDDLE := preload("res://scripts/puddle.gd")
const _E_SHOT := preload("res://scripts/projectile.gd")
const _E_WARN := preload("res://scripts/telegraph.gd")


## Число, выросшее с глубиной этажа (урон атак: +15% за этаж).
func scaled(v: float) -> int:
	return int(round(v * (1.0 + 0.15 * (Run.depth - 1))))


## Лужа на земле: урон героям внутри и/или замедление (chill).
func spawn_puddle(pos: Vector2, radius: float, lifetime: float, damage: int, col: Color, chill := 0.0) -> Node2D:
	var f: Node2D = _E_PUDDLE.new()
	f.radius = radius
	f.lifetime = lifetime
	f.damage = damage
	f.color = col
	f.chill = chill
	f.position = pos
	Game.ground().add_child(f)
	return f


## Поза атаки (новая графика): выстрел, предупреждение, удар по площади.
func _attack_pose() -> void:
	if _pose != "attack":
		pose("attack", 0.35)


## Снаряд монстра в сторону dir.
func spawn_shot(dir: Vector2, damage: int, speed := 75.0, col := Color(0.6, 0.35, 0.95), style := "orb", chill := 0.0) -> Area2D:
	_attack_pose()
	var b: Area2D = _E_SHOT.new()
	b.direction = dir.normalized()
	b.damage = damage
	b.speed = speed
	b.color = col
	b.style = style
	b.chill = chill
	b.position = global_position
	# Отложенно: монстры стреляют и в момент попадания по ним (зеркальник, осколки при смерти),
	# а добавлять физические тела во время проверки столкновений нельзя.
	Game.fx().add_child.call_deferred(b)
	return b


## Красный круг-предупреждение (заполняется за time секунд; убирает владелец).
func spawn_warning(pos: Vector2, radius: float, col := Color(1.0, 0.25, 0.2)) -> Node2D:
	_attack_pose()
	var t: Node2D = _E_WARN.new()
	t.radius = radius
	t.color = col
	t.position = pos
	Game.ground().add_child(t)
	return t


## Ранить героев в радиусе.
func hurt_players_in(pos: Vector2, radius: float, damage: int) -> void:
	_attack_pose()
	for pl in get_tree().get_nodes_in_group("player"):
		if not pl.dead and pl.global_position.distance_to(pos) < radius:
			pl.take_damage(damage, pos)


# ---------------- Новая графика: 4 стороны ----------------
# Лист assets/mon/<имя>.png: 3 ряда — вниз, вбок (лицом вправо; влево — зеркально), вверх;
# столбцы — те же кадры, что у старого листа (анимации скриптов не меняются), кадр квадратный
# (высота листа / 3). Имя — сцена монстра (ice_slime), иначе — старый лист (slime);
# у босса из списка — art из boss_roster. Нет листа — старая картинка, как раньше.

var own_art := false           # своя картинка (перекраска наследника и tint не применяются)
var boss_art := ""             # имя картинки босса (задаёт boss_roster)
var look_dir := "down"
var _look_frames := {}


func _art_key(sheet: Texture2D) -> String:
	for key: String in [boss_art, scene_file_path.get_file().get_basename()]:
		if key != "" and ResourceLoader.exists("res://assets/mon/%s.png" % key):
			return key
	var base := sheet.resource_path.get_file().get_basename() if sheet else ""
	if base != "" and ResourceLoader.exists("res://assets/mon/%s.png" % base):
		return "~" + base
	return ""


## Куда смотрит монстр: по движению, а стоя — на ближайшего героя.
func _update_look() -> void:
	if _look_frames.is_empty():
		return
	var v := velocity - _knockback
	if v.length() < 6.0:
		var p := nearest_player()
		if p == null or p.global_position.distance_to(global_position) > 260.0:
			return
		v = p.global_position - global_position
	var d := "side"
	if absf(v.x) < absf(v.y) * 1.1:
		d = "up" if v.y < 0.0 else "down"
	_set_look(d)
	if d == "side":
		sprite.flip_h = v.x < 0.0


# Позы поверх анимаций скрипта: урон, атака (на время), смерть. Скрипт может каждый кадр
# включать свою анимацию — поза возвращается и идёт по своему времени.
var _pose := ""
var _pose_t := 0.0
var _pose_len := 0.0
var _pose_prev := ""


func pose(anim: String, seconds: float) -> void:
	if _look_frames.is_empty() or dead or not sprite.sprite_frames.has_animation(anim):
		return
	if _pose == "":
		_pose_prev = String(sprite.animation)
	elif _pose == "attack" and anim == "hurt":
		return  # удар не прерывается
	_pose = anim
	_pose_t = seconds
	_pose_len = seconds
	sprite.play(anim)


func _update_pose(delta: float) -> void:
	if _pose == "":
		return
	_pose_t -= delta
	if _pose_t <= 0.0:
		_pose = ""
		if sprite.sprite_frames.has_animation(_pose_prev):
			sprite.play(_pose_prev)
		return
	var n := sprite.sprite_frames.get_frame_count(_pose)
	var f := mini(n - 1, int((_pose_len - _pose_t) / _pose_len * n))
	if sprite.animation != _pose:
		sprite.play(_pose)
	sprite.frame = f


func _set_look(d: String) -> void:
	if d == look_dir or not _look_frames.has(d):
		return
	look_dir = d
	sprite.sprite_frames = _look_frames[d]


## anims: {"имя": [[номера кадров], fps]} — квадратные кадры size x size по горизонтали.
func make_frames(sheet: Texture2D, anims: Dictionary, size := 16) -> SpriteFrames:
	var key := _art_key(sheet)
	if key != "":
		own_art = not key.begins_with("~")
		var tex: Texture2D = load("res://assets/mon/%s.png" % key.trim_prefix("~"))
		var fs := tex.get_height() / 3
		_look_frames.clear()
		for row in 3:
			_look_frames[["down", "side", "up"][row]] = _frames_from(tex, anims, fs, row)
		# Низ новой картинки — там же, где низ старой.
		sprite.offset.y = -(fs - size) / 2.0
		look_dir = "down"
		return _look_frames["down"]
	return _frames_from(sheet, anims, size, -1)


func _frames_from(sheet: Texture2D, anims: Dictionary, size: int, row: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# Новые листы: после кадров семейства — урон, замах+удар, смерть (tools/gen_monsters.gd).
	var nb := 0
	for anim_name: String in anims:
		for i: int in (anims[anim_name] as Array)[0]:
			nb = maxi(nb, i + 1)
	if row >= 0 and sheet.get_width() / size >= nb + 5:
		anims = anims.duplicate()
		anims["hurt"] = [[nb], 1.0]
		anims["attack"] = [[nb + 1, nb + 2], 6.0]
		anims["die"] = [[nb + 3, nb + 4], 8.0]
	for anim_name: String in anims:
		var spec: Array = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, spec[1])
		frames.set_animation_loop(anim_name, true)
		for i: int in spec[0]:
			var t := AtlasTexture.new()
			t.atlas = sheet
			t.region = Rect2(i * size, maxi(row, 0) * size, size, size)
			frames.add_frame(anim_name, t)
	return frames


## Добыча босса: монеты, два редких предмета и часть комплекта (под классы случайных героев),
## материалы биома. mats: [[id, количество], ...].
func _boss_loot(gold: int, mats: Array) -> void:
	for i in gold:
		_spawn_pickup("gold", {})
	for i in 2:
		var st: Node = Game.random_hero_state()
		_spawn_pickup("item", Items.make(Items.random_base(st.cls, st.job), 2, Run.depth))
	var st2: Node = Game.random_hero_state()
	var set_piece := Items.random_set_item(Run.depth, st2.cls, st2.job)
	if not set_piece.is_empty():
		_spawn_pickup("item", set_piece)
	for spec: Array in mats:
		for i in int(spec[1]):
			_spawn_pickup("mat", {}, str(spec[0]))
