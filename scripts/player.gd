extends CharacterBody2D
## Герой: движение, атака своего класса, навыки (1–3), SP, здоровье, смерть, взаимодействие (E).
## Характеристики берутся из st.derived() — класс + статы + снаряжение + пассивные навыки.

signal died

const Skills := preload("res://scripts/skills.gd")
const PICKUP := preload("res://scripts/pickup.gd")
const Items := preload("res://scripts/items.gd")
const SLASH := preload("res://scripts/slash.gd")
const PROJECTILE := preload("res://scripts/projectile.gd")
const TELEGRAPH := preload("res://scripts/telegraph.gd")
const BLIZZARD := preload("res://scripts/blizzard.gd")
const PUDDLE := preload("res://scripts/puddle.gd")
const TRAP := preload("res://scripts/trap.gd")

const BASE_SPEED := 70.0           # пикселей в секунду без бонусов
const INTERACT_RANGE := 14.0
const MELEE_RANGE := 26.0          # дальность удара мечом от центра героя
const MELEE_HALF_ARC := 1.3        # половина угла дуги удара (≈75°)
const INVULN_TIME := 1.0           # неуязвимость после получения урона
const DIR_ROWS := {"down": 0, "up": 1, "side": 2}
const ARROW_COLOR := Color(0.85, 0.75, 0.55)
const BOLT_COLOR := Color(0.55, 0.75, 1.0)
const FIRE_COLOR := Color(1.0, 0.5, 0.15)
const ICE_COLOR := Color(0.6, 0.85, 1.0)

@export var acceleration := 600.0
@export var friction := 800.0

@onready var sprite: AnimatedSprite2D = $Sprite

var max_speed := BASE_SPEED
var max_hp := 100
var max_sp := 30
var sp_regen := 1.5
var damage_reduction := 0.0        # % срезаемого входящего урона
var hp_regen := 0.0                # HP в секунду
var crit_mult := 2.0               # во сколько раз крит сильнее обычного удара
var accuracy := 0                  # против уклонения монстров
var cooldown_reduction := 0.0      # % сокращения перезарядки навыков
var cast_speed := 0.0              # % скорости каста заклинаний (Меткость)
var evasion := 0                   # % уклонения от ударов монстров (снаряжение)
var _specials := {}                # особые свойства снаряжения: lifesteal, burn, thorns, stun, boss, pierce
var _lifesteal_acc := 0.0


func special(key: String) -> int:
	return _specials.get(key, 0)


## Герой нанёс урон монстру (вызывает enemy.take_damage): вампиризм, поджог, оглушение.
func on_damage_dealt(e: Node, amount: int) -> void:
	if dead or amount <= 0:
		return
	if special("lifesteal") > 0 and hp < max_hp:
		_lifesteal_acc += amount * special("lifesteal") / 100.0
		if _lifesteal_acc >= 1.0:
			hp = mini(max_hp, hp + int(_lifesteal_acc))
			_lifesteal_acc -= int(_lifesteal_acc)
	if special("burn") > 0 and randf() * 100.0 < special("burn"):
		e.apply_burn(amount * 0.3 / 3.0, 3.0)  # 30% удара за 3 секунды
	if _poison_time > 0.0:
		e.apply_burn(amount * _poison_pct / 3.0, 3.0)  # «Отравленный клинок»
	if special("stun") > 0 and randf() * 100.0 < special("stun") and not e.dead:
		e.apply_stun(1.0, "stun")
var _hp_acc := 0.0                 # накопитель дробной регенерации
var attack_damage_min := 8
var attack_damage_max := 12
var crit_chance := 0.05            # крит = x2 урона
var attack_cooldown := 0.35

var hp: int
var sp: float
var dead := false
var god := false                   # бессмертие для автотеста
var facing := "down"
var aim := Vector2.DOWN            # куда смотрит герой (для ударов с клавиатуры)
var skill_cd := {}                 # id навыка -> сколько секунд до готовности

var _invuln := 0.0
var _attack_cd := 0.0
var _facing_lock := 0.0
var _next_crit := false            # после «Отскока» лучника
var _dash_time := 0.0
var _dash_velocity := Vector2.ZERO
var _dash_mult := 0.0
var _dash_hit := []
var _hint_cd := 0.0

# --- Кооператив ---
# peer_id — чей это герой (1 — хозяин; в одиночной игре всегда 1).
# st — состояние героя (Run у своего, у хозяина для гостя — Net.players[id].state).
# ctrl — «пульт»: свой герой заполняет его с клавиатуры, герой гостя — из сети.
var peer_id := 1
var st: Node = Run
var look := ""                     # как выглядит (профессия/класс) — для копий у гостей
var ctrl := {"move": Vector2.ZERO, "attack": false, "attack_mouse": false, "mouse": Vector2.ZERO, "mouse_recent": false}
var _presses := {}                 # нажатия гостя, ещё не обработанные (skill_1..3, interact)


func is_local() -> bool:
	return peer_id == Net.my_id()


func _ready() -> void:
	add_to_group("player")
	var cam: Camera2D = get_node_or_null("Camera")
	if cam:
		cam.enabled = is_local()
	if Net.is_guest():
		# Копия героя: всё присылает хозяин.
		_load_sprite()
		var scene := get_tree().current_scene
		if is_local() and cam and scene and scene.has_method("setup_camera"):
			scene.setup_camera(cam)
		return
	st = Net.state_of(peer_id)
	_apply_stats()
	hp = max_hp if st.hp < 0 else mini(st.hp, max_hp)
	sp = max_sp if st.sp < 0 else minf(st.sp, max_sp)
	st.changed.connect(_on_run_changed)
	st.leveled_up.connect(_on_level_up)
	st.class_chosen.connect(_on_class_chosen)
	st.job_chosen.connect(func(_j: String) -> void:
		_load_sprite()
		Game.burst(center(), Color(1.0, 0.9, 0.5), 30))
	_load_sprite()


## Спрайт профессии, если выбрана, иначе — базового класса.
func _load_sprite() -> void:
	if not Net.is_guest():
		look = st.job if st.job != "" else (st.cls if st.cls != "" else "warrior")
	var l := look if look != "" else "warrior"
	# Новая графика (8 сторон, кадр 24x24) — если для этого героя она уже нарисована.
	var p8 := "res://assets/hero8_%s.png" % l
	if ResourceLoader.exists(p8):
		sprite.sprite_frames = _build_frames8(load(p8))
		sprite.position.y = -11.0
	else:
		sprite.sprite_frames = _build_frames(load("res://assets/hero_%s.png" % l))
		sprite.position.y = -8.0
	sprite.play("idle_" + facing)


# ---------------- Сеть ----------------

func net_props() -> Array:
	return ["peer_id", "look"]


func net_state() -> Array:
	var cast: Array = []
	if not _casting.is_empty():
		cast = [_casting["id"], _casting["t"], _casting["total"], _casting["channel"]]
	return [Net.pack_sprite(sprite), hp, max_hp, sp, max_sp, dead, skill_cd, look,
		_shield_time, _shield_charges, _focus_time, cast, _invuln]


func net_apply(a: Array) -> void:
	Net.unpack_sprite(sprite, a[0])
	hp = a[1]
	max_hp = a[2]
	sp = a[3]
	max_sp = a[4]
	dead = a[5]
	skill_cd = a[6]
	if a[7] != look:
		look = a[7]
		var anim := sprite.animation
		_load_sprite()
		sprite.play(anim)
	_shield_time = a[8]
	_shield_charges = a[9]
	_focus_time = a[10]
	var cast: Array = a[11]
	_casting = {} if cast.is_empty() else {"id": cast[0], "t": cast[1], "total": cast[2], "channel": cast[3]}
	_invuln = a[12]
	if _shield_time > 0.0 or _focus_time > 0.0 or not _casting.is_empty():
		_ensure_overlay()
	if _overlay:
		_overlay.queue_redraw()


## Хозяин: ввод гостя (зажатые кнопки, мышь) — до следующего пакета.
func set_remote_input(d: Dictionary) -> void:
	ctrl["move"] = d["m"]
	ctrl["attack"] = d["a"]
	ctrl["attack_mouse"] = d["am"]
	ctrl["mouse"] = d["mp"]
	ctrl["mouse_recent"] = d["mr"]


## Хозяин: гость нажал навык или E.
func press(action: String) -> void:
	_presses[action] = true


## Было ли нажатие в этом кадре (свой герой — клавиатура, герой гостя — сеть).
func _just(action: String) -> bool:
	if is_local():
		return Input.is_action_just_pressed(action) and not Game.ui_blocks_input()
	if _presses.get(action, false):
		_presses.erase(action)
		return true
	return false


func _read_local_input() -> void:
	var blocked := Game.ui_blocks_input()
	ctrl["move"] = Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	ctrl["attack"] = not blocked and Input.is_action_pressed("attack")
	ctrl["attack_mouse"] = not blocked and Input.is_action_pressed("attack_mouse")
	ctrl["mouse"] = get_global_mouse_position()
	ctrl["mouse_recent"] = Game.mouse_recent()
	if Game.touch_enabled():
		# Телефон: мыши нет — атака и навыки сами целятся в ближайшего монстра.
		ctrl["attack_mouse"] = false
		var target := _auto_target()
		if target:
			ctrl["mouse"] = target.global_position + Vector2(0, -6)
			ctrl["mouse_recent"] = true
			if ctrl["attack"]:
				ctrl["attack"] = false
				ctrl["attack_mouse"] = true


## Ближайший живой монстр в пределах досягаемости (автоприцел на телефоне).
func _auto_target() -> Node2D:
	var best: Node2D = null
	var best_d := 150.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d and not e.get("dead"):
			best = e
			best_d = d
	return best


## Удар по монстру от этого героя (его вампиризм, поджог, точность, урон боссам).
func deal(e: Node, amount: int, from: Vector2, crit := false, missable := true) -> void:
	Game.attacker = self
	e.take_damage(amount, from, crit, missable)


## Кооп: павший герой смотрит за живым напарником (камера переезжает к нему).
func _spectate() -> void:
	if not is_local():
		return
	var cam: Camera2D = get_node_or_null("Camera")
	if cam == null:
		return
	if dead and Net.active():
		for h in get_tree().get_nodes_in_group("player"):
			if h != self and not h.dead:
				cam.top_level = true
				cam.global_position = h.global_position + Vector2(0, -8)
				return
	if cam.top_level:
		cam.top_level = false
		cam.position = Vector2(0, -8)


## Куда смотрит мышь этого игрока (в мире).
func mouse_pos() -> Vector2:
	return ctrl["mouse"]


func mouse_recent() -> bool:
	return ctrl["mouse_recent"]


func _on_class_chosen(_cls: String) -> void:
	_apply_stats()
	hp = max_hp
	sp = max_sp
	skill_cd.clear()
	_load_sprite()


func _apply_stats() -> void:
	var d: Dictionary = st.derived()
	max_hp = d["max_hp"]
	max_sp = d["max_sp"]
	sp_regen = d["sp_regen"]
	damage_reduction = d["dr"]
	hp_regen = d["hp_regen"]
	crit_mult = d["crit_mult"]
	accuracy = d["accuracy"]
	cooldown_reduction = d["cdr"]
	cast_speed = d["cast"]
	evasion = d["eva"]
	for k in ["lifesteal", "burn", "thorns", "stun", "boss", "pierce"]:
		_specials[k] = d[k]
	attack_damage_min = d["atk_min"]
	attack_damage_max = d["atk_max"]
	crit_chance = d["crit"] / 100.0
	attack_cooldown = st.class_data()["attack_cd"] / (1.0 + d["aspd"] / 100.0)
	max_speed = BASE_SPEED * (1.0 + d["speed"] / 100.0)
	if _focus_time > 0.0:  # «Сосредоточение» снайпера: −50% скорости атаки и бега
		attack_cooldown *= 2.0
		max_speed *= 0.5


func _on_run_changed() -> void:
	var old_hp := max_hp
	var old_sp := max_sp
	_apply_stats()
	# Прибавка к максимуму сразу добавляет и текущее значение.
	if max_hp > old_hp:
		hp += max_hp - old_hp
	if max_sp > old_sp:
		sp += max_sp - old_sp
	hp = mini(hp, max_hp)
	sp = minf(sp, max_sp)


func _on_level_up(_level: int) -> void:
	if dead:
		return
	hp = max_hp  # новый уровень полностью лечит
	sp = max_sp
	Game.burst(center(), Color(1.0, 0.85, 0.3), 24)
	Game.float_text(global_position + Vector2(0, -26), "Новый уровень!", Color(1.0, 0.85, 0.3))


# ---------------- Каждый кадр ----------------

func _physics_process(delta: float) -> void:
	if Net.is_guest():
		_spectate()
		return  # копия: позицию и вид присылает хозяин
	if is_local():
		_read_local_input()
		_spectate()
	if dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_invuln = maxf(0.0, _invuln - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_facing_lock = maxf(0.0, _facing_lock - delta)
	_hint_cd = maxf(0.0, _hint_cd - delta)
	for id: String in skill_cd:
		skill_cd[id] = maxf(0.0, skill_cd[id] - delta)
	sp = minf(max_sp, sp + sp_regen * delta)
	if hp < max_hp and hp_regen > 0.0:
		_hp_acc += hp_regen * delta
		if _hp_acc >= 1.0:
			hp = mini(max_hp, hp + int(_hp_acc))
			_hp_acc -= int(_hp_acc)

	# Временные эффекты навыков.
	if _shield_time > 0.0:
		_shield_time -= delta
	if _focus_time > 0.0:
		_focus_time -= delta
		if _focus_time <= 0.0:
			_apply_stats()
	_poison_time = maxf(0.0, _poison_time - delta)
	_smoke_time = maxf(0.0, _smoke_time - delta)
	_bless_time = maxf(0.0, _bless_time - delta)
	_iron_time = maxf(0.0, _iron_time - delta)
	_chill_time = maxf(0.0, _chill_time - delta)
	if _overlay:
		_overlay.queue_redraw()

	if _dash_time > 0.0:
		_process_dash(delta)
		return

	if not _casting.is_empty():
		_process_cast(delta)
		return

	var spinning := _spin_time > 0.0
	if spinning:
		_process_spin(delta)

	var input: Vector2 = ctrl["move"]
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * max_speed * (0.6 if _chill_time > 0.0 else 1.0), acceleration * delta)
		aim = input.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	# Атака: можно зажать кнопку. Во время вращения берсерка и под щитом паладина — нельзя.
	if spinning or _shield_time > 0.0:
		pass
	elif ctrl["attack_mouse"]:
		_attack((mouse_pos() - center()).normalized())
	elif ctrl["attack"]:
		_attack(aim_dir())
	for i in 4:
		if _just("skill_%d" % (i + 1)):
			use_skill(i)
	if _just("interact"):
		_interact()

	_update_animation(input)
	sprite.visible = _invuln <= 0.0 or int(_invuln * 16.0) % 2 == 0


func center() -> Vector2:
	return global_position + Vector2(0, -7)


## Направление для ударов и навыков: на курсор, если мышью недавно двигали, иначе — куда смотрит герой.
func aim_dir() -> Vector2:
	if mouse_recent():
		var d := mouse_pos() - center()
		if d.length() > 4.0:
			return d.normalized()
	return aim


## Урон с учётом множителя и шанса крита: [урон, крит?]
func roll(mult: float) -> Array:
	var crit := _next_crit or randf() < crit_chance
	_next_crit = false
	var dmg := randi_range(attack_damage_min, attack_damage_max) * mult * (crit_mult if crit else 1.0)
	if _focus_time > 0.0:
		dmg *= 1.5  # «Сосредоточение» снайпера: +50% урона
	if _bless_time > 0.0:
		dmg *= 1.0 + _bless_pct / 100.0  # «Благословение»
	return [maxi(1, int(round(dmg))), crit]


## Магия не промахивается, оружие — может (против уклонения монстра).
func _missable() -> bool:
	return st.cls != "mage" and not (st.cls == "acolyte" and st.job != "monk")


# ---------------- Обычная атака ----------------

func _attack(dir: Vector2) -> void:
	if _attack_cd > 0.0 or dir == Vector2.ZERO:
		return
	_attack_cd = attack_cooldown
	_turn_to(dir)
	match st.cls:
		"archer":
			_shoot("arrow", dir, 1.0, 230.0, 0.55)
		"mage":
			var b := _shoot("bolt", dir, 1.0, 150.0, 0.8, BOLT_COLOR)
			b.explode_radius = 10.0
			b.quiet = true  # обычная атака — без тряски экрана
		"thief":
			_slash(dir, 0.75)
			hit_arc(dir, MELEE_RANGE, 1.0, 1.0)
		"acolyte":
			if st.job == "monk":
				_slash(dir, 0.7)
				hit_arc(dir, MELEE_RANGE, 1.0, 1.0)
			else:
				_shoot("bolt", dir, 1.0, 140.0, 0.55, HOLY_COLOR)
		_:
			_slash(dir, 1.0)
			hit_arc(dir, MELEE_RANGE, MELEE_HALF_ARC, 1.0)  # без «замирания» и тряски — это обычная атака


func _turn_to(dir: Vector2) -> void:
	aim = dir
	_face(dir)
	_facing_lock = 0.2


func _slash(dir: Vector2, size: float) -> void:
	var slash: Node2D = SLASH.new()
	slash.position = center() + dir * 6.0
	slash.rotation = dir.angle()
	slash.scale = Vector2(size, size)
	Game.fx().add_child(slash)


func _shoot(style: String, dir: Vector2, mult: float, speed: float, life: float, color := ARROW_COLOR) -> Area2D:
	var r := roll(mult)
	var b: Area2D = PROJECTILE.new()
	b.team = "player"
	b.source = self
	b.style = style
	b.direction = dir
	b.speed = speed
	b.lifetime = life * (_range_mult() if style == "arrow" else 1.0)
	b.damage = r[0]
	b.crit = r[1]
	b.missable = _missable()
	if style == "arrow":
		b.pierce += special("pierce")  # арбалет: стрелы пробивают насквозь
	b.color = color
	b.position = global_position + dir * 4.0
	Game.fx().add_child(b)
	return b


## Удар по дуге перед героем. Возвращает, сколько врагов задето.
func hit_arc(dir: Vector2, reach: float, half_arc: float, mult: float, push := 0.0) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = (e.global_position + Vector2(0, -6)) - center()
		var in_arc := absf(dir.angle_to(to)) <= half_arc or to.length() < 8.0
		if to.length() <= reach and in_arc:
			var r := roll(mult)
			deal(e, r[0], center(), r[1], _missable())
			if push > 0.0:
				e.push(to, push)
			n += 1
	return n


## Удар по кругу. Возвращает список задетых врагов.
func hit_circle(pos: Vector2, radius: float, mult: float) -> Array:
	var hit := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(pos) <= radius:
			var r := roll(mult)
			deal(e, r[0], pos, r[1], _missable())
			hit.append(e)
	return hit


# ---------------- Навыки ----------------

## slot 0..2 — активные навыки класса по порядку.
func use_skill(slot: int) -> bool:
	var ids := Skills.actives_of(st.skill_list())
	if slot >= ids.size():
		return false
	var id: String = ids[slot]
	var lvl: int = st.skill_level(id)
	if is_casting():
		return false
	if _shield_time > 0.0 and id != "holy_charge":  # под щитом можно только рывком
		_hint("Под щитом — только рывок", Color(1.0, 0.9, 0.45))
		return false
	if lvl == 0:
		_hint("Навык не изучен (K)", Color(0.8, 0.8, 0.85))
		return false
	if skill_cd.get(id, 0.0) > 0.0:
		return false
	var cost := Skills.sp_cost(id, lvl)
	if sp < cost:
		_hint("Мало SP", Color(0.5, 0.7, 1.0))
		return false
	sp -= cost
	var cd: float = Skills.SKILLS[id]["cd"]
	if id == "backstep":
		cd -= 0.3 * (lvl - 1)
	skill_cd[id] = cd * (1.0 - cooldown_reduction / 100.0)
	var dir := aim_dir()
	_turn_to(dir)
	var mult := Skills.value(id, lvl) / 100.0
	var cast := Skills.cast_time(id, cast_speed)
	if "--autotest" in OS.get_cmdline_user_args():
		print("  SKILL %s" % id)
	_ensure_overlay()
	if Skills.SKILLS[id].has("channel"):
		_start_cast(id, lvl, dir, mult, Skills.SKILLS[id]["channel"], true)
	elif cast > 0.0:
		_start_cast(id, lvl, dir, mult, cast)
	else:
		call("_cast_" + id, lvl, dir, mult)
	return true


# ---------------- Каст и канал ----------------
# Каст: герой стоит (Профессор с «Подвижным кастом» — идёт на 50% скорости), над головой
# полоса, на полу синий круг — куда ударит. По окончании — _release_<id>.
# Канал (Молитва паладина): стоит всё время, каждую секунду — _tick_<id>.

const CAST_COLOR := Color(0.45, 0.7, 1.0)
const HOLY_COLOR := Color(1.0, 0.9, 0.45)
const METEOR_RADIUS := 42.0
const BLIZZARD_RADIUS := 34.0
const FIREBALL_RADIUS := 22.0
const FROST_RADIUS := 30.0
const THUNDER_RADIUS := 28.0
const PRAYER_RADIUS := 80.0
const CHAIN_RANGE := 160.0      # первая цель цепной молнии
const CHAIN_JUMP := 90.0        # перескок между монстрами
const MAGE_SPELLS := ["fireball", "frost_wave", "thunder", "meteor", "chain_lightning", "blizzard",
	"pro_fireball", "pro_frost", "pro_thunder"]

var _casting := {}              # {id, lvl, dir, mult, t, total, target, marker, mobile, channel, next_tick}
var _overlay: Node2D            # полоса каста, щит, аура бафа


func is_casting() -> bool:
	return not _casting.is_empty()


func _cast_target(dir: Vector2, reach := 110.0) -> Vector2:
	if mouse_recent():
		return global_position + (mouse_pos() - global_position).limit_length(reach)
	return global_position + dir * 70.0


func _start_cast(id: String, lvl: int, dir: Vector2, mult: float, time: float, channel := false) -> void:
	var target := _cast_target(dir)
	var marker: Node2D = TELEGRAPH.new()
	marker.color = HOLY_COLOR if id == "prayer" else CAST_COLOR
	marker.hostile = false
	marker.position = target
	match id:
		"meteor":
			marker.radius = METEOR_RADIUS
		"blizzard":
			marker.radius = BLIZZARD_RADIUS
		"fireball", "pro_fireball":
			marker.radius = FIREBALL_RADIUS
		"frost_wave", "pro_frost":
			marker.radius = FROST_RADIUS
		"thunder", "pro_thunder":
			marker.radius = THUNDER_RADIUS
		"prayer":
			marker.radius = PRAYER_RADIUS
			marker.position = global_position
		"holy_light":
			marker.radius = 26.0
		"great_heal":
			marker.radius = 140.0
			marker.position = global_position
			marker.color = HEAL_COLOR
		"resurrect":
			marker.radius = 70.0
			marker.position = global_position
			marker.color = HOLY_COLOR
		"power_shot":
			marker.radius = 160.0 * _range_mult()
			marker.arc_half = 0.04
			marker.arc_dir = dir
			marker.position = global_position
		_:
			marker.radius = CHAIN_RANGE
			marker.position = global_position
	Game.ground().add_child(marker)
	var mobile: bool = id in MAGE_SPELLS and st.skill_level("mobile_cast") > 0
	_casting = {"id": id, "lvl": lvl, "dir": dir, "mult": mult, "t": 0.0, "total": time, "target": target,
		"marker": marker, "mobile": mobile, "channel": channel, "next_tick": 1.0}
	if not mobile:
		velocity = Vector2.ZERO
	_play("idle_" + facing)
	if channel:
		call("_tick_" + id, lvl, mult)  # первый тик — сразу


func _process_cast(delta: float) -> void:
	var input := Vector2.ZERO
	if _casting["mobile"]:
		input = ctrl["move"]
		velocity = velocity.move_toward(input * max_speed * 0.5, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	if _casting["mobile"]:
		_update_animation(input)
	_casting["t"] += delta
	var k: float = _casting["t"] / _casting["total"]
	var marker: Node2D = _casting["marker"]
	if is_instance_valid(marker):
		marker.progress = k
		if marker.position.distance_to(_casting["target"]) > 0.5 and _casting["id"] in ["chain_lightning", "prayer"]:
			marker.position = global_position  # круги вокруг героя идут за ним
	if _casting["channel"]:
		while _casting["t"] >= _casting["next_tick"] and _casting["next_tick"] < _casting["total"] + 0.01:
			call("_tick_" + _casting["id"], _casting["lvl"], _casting["mult"])
			_casting["next_tick"] += 1.0
	if Engine.get_physics_frames() % 6 == 0:
		Game.burst(center() + Vector2(randf_range(-6, 6), randf_range(-8, 2)), marker.color if is_instance_valid(marker) else CAST_COLOR, 1)
	if k >= 1.0:
		var c := _casting
		_casting = {}
		if is_instance_valid(marker):
			marker.queue_free()
		if "--autotest" in OS.get_cmdline_user_args():
			print("  CAST %s after %.2fs" % [c["id"], c["total"]])
		if not c["channel"]:
			call("_release_" + c["id"], c["lvl"], c["target"], c["mult"])


func _cancel_cast() -> void:
	if _casting.is_empty():
		return
	var marker: Node2D = _casting["marker"]
	if is_instance_valid(marker):
		marker.queue_free()
	_casting = {}


func _ensure_overlay() -> void:
	if _overlay == null:
		_overlay = Node2D.new()
		_overlay.z_index = 5
		_overlay.draw.connect(_draw_overlay)
		add_child(_overlay)


## Полоса каста над головой, круг щита, аура бафа снайпера.
func _draw_overlay() -> void:
	if _shield_time > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		_overlay.draw_arc(Vector2(0, -7), 12.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.45, 0.5 + 0.3 * pulse), 1.5)
		for i in _shield_charges:
			_overlay.draw_rect(Rect2(-6 + i * 5, -30, 3, 3), HOLY_COLOR)
	if _focus_time > 0.0:
		_overlay.draw_arc(Vector2(0, -2), 9.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.3, 0.6), 1.0)
	if _casting.is_empty():
		return
	var k := clampf(_casting["t"] / _casting["total"], 0.0, 1.0)
	if _casting["channel"]:
		k = 1.0 - k  # канал — полоса убывает
	var r := Rect2(-10, -24, 20, 3)
	var c: Color = HOLY_COLOR if _casting["id"] == "prayer" else CAST_COLOR
	_overlay.draw_rect(r, Color(0.05, 0.04, 0.08, 0.85))
	_overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), c)
	_overlay.draw_rect(r, Color(0.8, 0.85, 1.0, 0.8), false, 1.0)


# ---------------- Маг ----------------

func _fire_projectile(target: Vector2, mult: float, radius: float, on_explode: Callable) -> void:
	var dir := (target - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = aim
	var b := _shoot("fireball", dir, mult, 200.0, maxf(0.1, global_position.distance_to(target) / 200.0), FIRE_COLOR)
	b.explode_radius = radius
	b.on_explode = on_explode


func _release_fireball(_lvl: int, target: Vector2, mult: float) -> void:
	_fire_projectile(target, mult, FIREBALL_RADIUS, Callable())


func _release_pro_fireball(lvl: int, target: Vector2, mult: float) -> void:
	var burn := Skills.value("pro_fireball", lvl, "v2") / 100.0
	_fire_projectile(target, mult, FIREBALL_RADIUS, func(pos: Vector2) -> void:
		var f: Node2D = PUDDLE.new()
		f.team = "player"
		f.caster = self
		f.mult = burn
		f.radius = FIREBALL_RADIUS
		f.lifetime = 5.0
		f.color = FIRE_COLOR
		f.position = pos
		Game.ground().add_child(f))


func _frost(target: Vector2, mult: float) -> void:
	Game.ring(target, FROST_RADIUS, ICE_COLOR, 0.35)
	Game.burst(target + Vector2(0, -6), ICE_COLOR, 20)
	for e in hit_circle(target, FROST_RADIUS, mult):
		if not e.dead:
			e.apply_stun(3.0, "freeze")


func _release_frost_wave(_lvl: int, target: Vector2, mult: float) -> void:
	_frost(target, mult)


func _release_pro_frost(_lvl: int, target: Vector2, mult: float) -> void:
	_frost(target, mult)
	var ice: Node2D = PUDDLE.new()
	ice.team = "player"
	ice.slow = 0.5
	ice.radius = FROST_RADIUS
	ice.lifetime = 10.0
	ice.color = ICE_COLOR
	ice.position = target
	Game.ground().add_child(ice)


func _thunder_strike(target: Vector2, mult: float) -> void:
	Game.lightning(PackedVector2Array([target + Vector2(randf_range(-10, 10), -90), target + Vector2(0, -4)]), Color(0.85, 0.9, 1.0))
	Game.ring(target, THUNDER_RADIUS, Color(0.8, 0.85, 1.0), 0.25)
	Game.shake(2.0, 0.1)
	hit_circle(target, THUNDER_RADIUS, mult)


func _release_thunder(_lvl: int, target: Vector2, mult: float) -> void:
	_thunder_strike(target, mult)


func _release_pro_thunder(lvl: int, target: Vector2, mult: float) -> void:
	var strikes := mini(5, int(Skills.value("pro_thunder", lvl, "v2")))
	for i in strikes:
		get_tree().create_timer(i * 0.2).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_thunder_strike(target, mult))


# ---------------- Визард ----------------

func _release_meteor(_lvl: int, target: Vector2, mult: float) -> void:
	Game.shake(5.0, 0.3)
	Game.ring(target, METEOR_RADIUS, Color(1.0, 0.5, 0.15), 0.4)
	Game.burst(target + Vector2(0, -6), Color(1.0, 0.55, 0.2), 30)
	Game.burst(target + Vector2(0, -6), Color(1.0, 0.9, 0.5), 14)
	if not hit_circle(target, METEOR_RADIUS, mult).is_empty():
		Game.hitstop(0.06)


func _release_chain_lightning(_lvl: int, _target: Vector2, mult: float) -> void:
	# Первая цель — ближайший монстр в большом радиусе; дальше по цепи на всех, до кого
	# можно допрыгнуть от уже поражённых (каждый не больше одного раза).
	var enemies := get_tree().get_nodes_in_group("enemies")
	var first: Node2D = null
	var best := CHAIN_RANGE
	for e: Node2D in enemies:
		var d := e.global_position.distance_to(global_position)
		if d < best:
			best = d
			first = e
	if first == null:
		Game.lightning(PackedVector2Array([center(), center() + aim * 60.0]))
		return
	var hit := [first]
	var queue := [first]
	Game.lightning(PackedVector2Array([center(), first.global_position + Vector2(0, -6)]))
	while not queue.is_empty():
		var cur: Node2D = queue.pop_front()
		for e: Node2D in enemies:
			if e in hit or e.dead:
				continue
			if e.global_position.distance_to(cur.global_position) <= CHAIN_JUMP:
				hit.append(e)
				queue.append(e)
				Game.lightning(PackedVector2Array([cur.global_position + Vector2(0, -6), e.global_position + Vector2(0, -6)]))
	for e: Node2D in hit:
		if is_instance_valid(e) and not e.dead:
			var r := roll(mult)
			deal(e, r[0], center(), r[1], false)
	if hit.size() > 2:
		Game.float_text(global_position + Vector2(0, -28), "Цепь ×%d" % hit.size(), CAST_COLOR)


func _release_blizzard(_lvl: int, target: Vector2, mult: float) -> void:
	var b: Node2D = BLIZZARD.new()
	b.caster = self
	b.mult = mult
	b.radius = BLIZZARD_RADIUS
	b.position = target
	Game.ground().add_child(b)


# ---------------- Берсерк ----------------

func _cast_leap_strike(lvl: int, dir: Vector2, mult: float) -> void:
	# Цель — ближайший монстр (впереди — в приоритете).
	var target: Node2D = null
	var best := INF
	for e: Node2D in get_tree().get_nodes_in_group("enemies"):
		var to := e.global_position - global_position
		if to.length() > 130.0:
			continue
		var score := to.length() * (0.6 if absf(dir.angle_to(to)) < 0.8 else 1.0)
		if score < best:
			best = score
			target = e
	var land := target.global_position if target else global_position + dir * 50.0
	var to_land := land - global_position
	var stun_chance := Skills.value("leap_strike", lvl, "v2") / 100.0
	_start_dash(to_land / 0.22, 0.22, 0.0)
	_dash_on_end = func() -> void:
		Game.shake(4.0, 0.2)
		Game.ring(global_position, 26.0, Color(1.0, 0.6, 0.4), 0.25)
		_slash(aim, 1.6)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) <= 28.0:
				var r := roll(mult)
				deal(e, r[0], global_position, r[1], _missable())
				if not e.dead and not e.last_hit_missed and randf() < stun_chance:
					e.apply_stun(2.0, "stun")
		Game.hitstop(0.07)


var _spin_time := 0.0
var _spin_tick := 0.0
var _spin_mult := 0.0


func _cast_spin(_lvl: int, _dir: Vector2, mult: float) -> void:
	_spin_time = 3.0
	_spin_tick = 0.0
	_spin_mult = mult


func _process_spin(delta: float) -> void:
	_spin_time -= delta
	_spin_tick -= delta
	if _spin_tick <= 0.0:
		_spin_tick = 0.25
		var a := Time.get_ticks_msec() / 80.0
		for i in 2:
			_slash(Vector2.from_angle(a + i * PI), 1.2)
		hit_circle(global_position, 30.0, _spin_mult)


func _cast_blood_slam(lvl: int, _dir: Vector2, mult: float) -> void:
	var heal_pct := Skills.value("blood_slam", lvl, "v2") / 100.0
	Game.shake(5.0, 0.3)
	Game.ring(global_position, METEOR_RADIUS, Color(0.9, 0.2, 0.25), 0.4)
	Game.burst(center(), Color(0.85, 0.15, 0.2), 26)
	var total := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= METEOR_RADIUS:
			var r := roll(mult)
			deal(e, r[0], global_position, r[1], _missable())
			if not e.last_hit_missed:
				total += r[0]
	var heal := int(round(total * heal_pct))
	if heal > 0:
		hp = mini(max_hp, hp + heal)
		Game.float_text(global_position + Vector2(0, -28), "+%d HP" % heal, Color(0.5, 1.0, 0.5))
		Game.hitstop(0.08)


# ---------------- Паладин ----------------

func _cast_holy_charge(_lvl: int, dir: Vector2, mult: float) -> void:
	_start_dash(dir * 320.0, 0.3, mult)  # в 1.5 раза дальше обычного рывка
	_dash_stun = true
	_invuln = maxf(_invuln, 0.45)


func _tick_prayer(lvl: int, _mult: float) -> void:
	var heal := int(Skills.value("prayer", lvl))
	var harm := Skills.value("prayer", lvl, "v2") / 100.0
	Game.ring(global_position, PRAYER_RADIUS, HOLY_COLOR, 0.5)
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead and p.global_position.distance_to(global_position) <= PRAYER_RADIUS:
			p.hp = mini(p.max_hp, p.hp + heal)
			Game.float_text(p.global_position + Vector2(0, -24), "+%d" % heal, Color(0.5, 1.0, 0.5))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= PRAYER_RADIUS:
			var r := roll(harm)
			deal(e, r[0], global_position, r[1], false)


var _shield_time := 0.0
var _shield_charges := 0
var _shield_taken := 0.0


func _cast_shield_reflect(lvl: int, _dir: Vector2, _mult: float) -> void:
	_shield_time = 10.0  # 10 с или пока не собьют все заряды; пока щит поднят — атаковать нельзя
	_shield_charges = int(Skills.value("shield_reflect", lvl))
	_shield_taken = Skills.value("shield_reflect", lvl, "v2") / 100.0
	_ensure_overlay()
	Game.burst(center(), HOLY_COLOR, 14)


## Снаряд монстра попал в героя. Если поднят щит — отражаем в сторону курсора.
var reflected_count := 0  # сколько снарядов отражено за всё время (для тестов)


func try_reflect(b: Node) -> bool:
	if dead or _shield_time <= 0.0 or _shield_charges <= 0:
		return false
	_shield_charges -= 1
	reflected_count += 1
	if _shield_charges <= 0:
		_shield_time = 0.0
	var part := int(round(b.damage * _shield_taken))
	if part > 0:
		take_damage(part, b.global_position)
	var r := roll(1.5)
	b.team = "player"
	b.source = self
	b.set_deferred("collision_mask", 1 | 4)  # менять физику внутри сигнала столкновения можно только отложенно
	b.direction = aim_dir()
	b.damage = r[0]
	b.crit = r[1]
	b.missable = false
	b.color = HOLY_COLOR
	b._hit = []
	b._t = 0.0
	b.position = global_position + b.direction * 10.0
	Game.float_text(global_position + Vector2(0, -26), "Отражено!", HOLY_COLOR)
	if "--skilltest" in OS.get_cmdline_user_args():
		print("  REFLECT dir=%s dmg=%d pos=%s" % [b.direction, b.damage, b.position])
	Game.burst(center(), HOLY_COLOR, 8)
	return true


# ---------------- Охотник ----------------

func _cast_trap(_lvl: int, dir: Vector2, mult: float) -> void:
	var traps := get_tree().get_nodes_in_group("traps")
	if traps.size() >= TRAP.MAX_TRAPS:
		traps[0].queue_free()  # самая старая уступает место
	var t: Node2D = TRAP.new()
	t.caster = self
	t.mult = mult
	t.position = _cast_target(dir, 80.0) if mouse_recent() else global_position + dir * 22.0
	Game.ground().add_child(t)


# ---------------- Снайпер ----------------

var _focus_time := 0.0


func _range_mult() -> float:
	return 1.5 if _focus_time > 0.0 else 1.0


func _release_power_shot(_lvl: int, _target: Vector2, mult: float) -> void:
	var dir: Vector2 = aim
	var b := _shoot("arrow", dir, mult, 320.0, 0.55 * _range_mult())
	b.pierce = 20
	b.color = Color(1.0, 0.85, 0.4)
	Game.shake(2.0, 0.1)


func _cast_sniper_focus(lvl: int, _dir: Vector2, _mult: float) -> void:
	_focus_time = Skills.value("sniper_focus", lvl)
	_apply_stats()
	_ensure_overlay()
	Game.float_text(global_position + Vector2(0, -26), "Сосредоточение", Color(1.0, 0.5, 0.4))


func _hint(text: String, color: Color) -> void:
	if _hint_cd > 0.0:
		return
	_hint_cd = 0.8
	Game.float_text(global_position + Vector2(0, -24), text, color)


func _cast_bash(_lvl: int, dir: Vector2, mult: float) -> void:
	_slash(dir, 1.5)
	Game.shake(3.0, 0.15)
	if hit_arc(dir, 32.0, 1.0, mult, 260.0) > 0:
		Game.hitstop(0.08)


func _cast_whirlwind(_lvl: int, _dir: Vector2, mult: float) -> void:
	for i in 4:
		_slash(Vector2.RIGHT.rotated(i * PI / 2.0), 1.2)
	Game.ring(global_position, 28.0, Color(0.9, 0.95, 1.0))
	if not hit_circle(global_position, 30.0, mult).is_empty():
		Game.hitstop(0.06)


func _cast_dash(_lvl: int, dir: Vector2, mult: float) -> void:
	_start_dash(dir * 320.0, 0.2, mult)


func _cast_double_shot(_lvl: int, dir: Vector2, mult: float) -> void:
	_shoot("arrow", dir.rotated(-0.09), mult, 240.0, 0.6)
	_shoot("arrow", dir.rotated(0.09), mult, 240.0, 0.6)


func _cast_arrow_rain(_lvl: int, dir: Vector2, mult: float) -> void:
	var target := global_position + dir * 70.0
	if mouse_recent():
		target = global_position + (mouse_pos() - global_position).limit_length(110.0)
	Game.ring(target, 26.0, ARROW_COLOR, 0.4)
	for wave in 3:
		get_tree().create_timer(0.35 + wave * 0.25).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			for i in 6:
				Game.burst(target + Vector2.from_angle(randf() * TAU) * randf() * 22.0, ARROW_COLOR, 2)
			Game.ring(target, 26.0, ARROW_COLOR, 0.2)
			hit_circle(target, 26.0, mult))


func _cast_backstep(lvl: int, dir: Vector2, _mult: float) -> void:
	var dist := Skills.value("backstep", lvl)
	_start_dash(-dir * dist / 0.18, 0.18, 0.0)
	_next_crit = true
	Game.float_text(global_position + Vector2(0, -24), "Следующий выстрел — крит", Color(1.0, 0.85, 0.3))


# ---------------- Вор, Бандит, Ассасин ----------------

const POISON_COLOR := Color(0.45, 0.85, 0.3)
const SMOKE_COLOR := Color(0.6, 0.6, 0.66)
var _poison_time := 0.0          # «Отравленный клинок»: удары отравляют
var _poison_pct := 0.0
var _smoke_time := 0.0           # «Дымовая шашка»: +уклонение
var _smoke_eva := 0.0
var _bless_time := 0.0           # «Благословение»: +урон
var _bless_pct := 0.0
var _iron_time := 0.0            # «Железная кожа»: −получаемый урон
var _iron_pct := 0.0
var _chill_time := 0.0           # холод (ледяные монстры): −40% скорости бега


## Ослепление (светогриб): экран темнеет, видно только вокруг героя.
func blind(sec: float) -> void:
	if dead:
		return
	if is_local():
		Game.show_blind(sec)
	else:
		Net.send_to(peer_id, "ui", {"blind": sec})


func apply_chill(sec: float) -> void:
	if dead:
		return
	if _chill_time <= 0.0:
		Game.float_text(global_position + Vector2(0, -22), "Холод", Color(0.6, 0.85, 1.0))
	_chill_time = maxf(_chill_time, sec)


## Серия ударов по дуге с паузами (шквал уколов, град ударов).
func _flurry(dir: Vector2, hits: int, gap: float, mult: float, reach := 34.0) -> void:
	for i in hits:
		get_tree().create_timer(gap * i, false).timeout.connect(func() -> void:
			if dead:
				return
			_slash(dir, 0.6)
			hit_arc(dir, reach, 0.8, mult))


func _cast_stab_flurry(_lvl: int, dir: Vector2, mult: float) -> void:
	_flurry(dir, 3, 0.1, mult)


func _cast_poison_blade(_lvl: int, _dir: Vector2, mult: float) -> void:
	_poison_time = 8.0
	_poison_pct = mult
	Game.burst(center(), POISON_COLOR, 14)
	Game.float_text(global_position + Vector2(0, -24), "Клинок отравлен", POISON_COLOR)


func _cast_smoke_bomb(lvl: int, _dir: Vector2, _mult: float) -> void:
	var cloud: Node2D = PUDDLE.new()
	cloud.team = "player"
	cloud.caster = self
	cloud.radius = 36.0
	cloud.lifetime = 4.0
	cloud.slow = 0.6
	cloud.color = SMOKE_COLOR
	cloud.position = global_position
	Game.ground().add_child(cloud)
	_smoke_time = 4.0
	_smoke_eva = Skills.value("smoke_bomb", lvl)
	Game.burst(center(), SMOKE_COLOR, 24)


func _cast_knife_fan(_lvl: int, dir: Vector2, mult: float) -> void:
	for i in 5:
		var d := dir.rotated(-0.4 + 0.2 * i)
		_shoot("arrow", d, mult, 210.0, 0.45, Color(0.8, 0.82, 0.9))


func _cast_mug(lvl: int, dir: Vector2, mult: float) -> void:
	_slash(dir, 1.1)
	var chance := Skills.value("mug", lvl, "v2") / 100.0
	for e in _enemies_in_arc(dir, 36.0, MELEE_HALF_ARC):
		var r := roll(mult)
		deal(e, r[0], center(), r[1], _missable())
		if randf() < chance and is_instance_valid(e):
			for k in randi_range(2, 4):
				e._spawn_pickup("gold", {})
			Game.float_text(e.global_position + Vector2(0, -22), "Ограблен!", Color(1.0, 0.85, 0.3))


func _cast_stun_club(_lvl: int, dir: Vector2, mult: float) -> void:
	_slash(dir, 1.2)
	for e in _enemies_in_arc(dir, 36.0, MELEE_HALF_ARC):
		var r := roll(mult)
		deal(e, r[0], center(), r[1], _missable())
		if is_instance_valid(e) and not e.dead:
			e.apply_stun(2.0, "stun")
	Game.shake(2.0, 0.15)


func _cast_shadow_step(_lvl: int, dir: Vector2, mult: float) -> void:
	var best: Node2D = null
	var best_d := 140.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		_hint("Некого — рядом нет монстров", Color(0.8, 0.8, 0.85))
		return
	Game.burst(center(), Color(0.4, 0.3, 0.55), 16)
	var from_hero := (best.global_position - global_position).normalized()
	if from_hero == Vector2.ZERO:
		from_hero = dir
	global_position = best.global_position + from_hero * 12.0
	_turn_to(-from_hero)
	_next_crit = true
	var r := roll(mult)
	_slash(-from_hero, 1.0)
	deal(best, r[0], center(), true, false)
	Game.burst(center(), Color(0.4, 0.3, 0.55), 16)


func _cast_venom_cloud(_lvl: int, dir: Vector2, mult: float) -> void:
	var cloud: Node2D = PUDDLE.new()
	cloud.team = "player"
	cloud.caster = self
	cloud.mult = mult
	cloud.radius = 30.0
	cloud.lifetime = 5.0
	cloud.color = POISON_COLOR
	cloud.position = _cast_target(dir, 110.0)
	Game.ground().add_child(cloud)


func _cast_execute(_lvl: int, dir: Vector2, mult: float) -> void:
	_slash(dir, 1.2)
	for e in _enemies_in_arc(dir, 36.0, MELEE_HALF_ARC):
		var low: bool = e.hp < e.max_hp * 0.3
		var r := roll(mult * (2.0 if low else 1.0))
		deal(e, r[0], center(), r[1], _missable())
		if low:
			Game.float_text(e.global_position + Vector2(0, -24), "Казнь!", Color(1.0, 0.4, 0.4))


func _enemies_in_arc(dir: Vector2, reach: float, half_arc: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = (e.global_position + Vector2(0, -6)) - center()
		if to.length() <= reach and (absf(dir.angle_to(to)) <= half_arc or to.length() < 8.0):
			out.append(e)
	return out


# ---------------- Послушник, Священник, Монах ----------------

const HEAL_COLOR := Color(0.5, 1.0, 0.55)


## Сколько лечит навык: база + за Интеллект, с «Верой».
func _heal_amount(base: float, per_int: float) -> int:
	var d: Dictionary = st.derived()
	return int(round((base + per_int * (d["stats"]["int"] - 1)) * (1.0 + d["heal_pct"] / 100.0)))


## Вылечить себя и союзников в радиусе.
func _heal_allies(radius: float, amount: int) -> void:
	for h in get_tree().get_nodes_in_group("player"):
		if not h.dead and h.global_position.distance_to(global_position) <= radius:
			h.heal_by(amount)
	Game.ring(global_position, radius, HEAL_COLOR, 0.4)


func heal_by(amount: int) -> void:
	if dead or amount <= 0 or hp >= max_hp:
		return
	var got := mini(amount, max_hp - hp)
	hp += got
	Game.float_text(global_position + Vector2(0, -24), "+%d" % got, HEAL_COLOR)
	Game.burst(center(), HEAL_COLOR, 8)


func bless(time: float, pct: float) -> void:
	if dead:
		return
	_bless_time = time
	_bless_pct = pct
	Game.burst(center(), HOLY_COLOR, 12)


## Поднять павшего (Воскрешение священника).
func revive(pct: float) -> void:
	if not dead:
		return
	dead = false
	hp = maxi(1, int(max_hp * pct / 100.0))
	collision_layer = 2
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	_invuln = 2.0
	Game.burst(center(), HOLY_COLOR, 30)
	Game.float_text(global_position + Vector2(0, -26), "Воскрешён!", HOLY_COLOR)


func _cast_heal(lvl: int, _dir: Vector2, _mult: float) -> void:
	_heal_allies(80.0, _heal_amount(Skills.value("heal", lvl), 2.0))


func _cast_blessing(lvl: int, _dir: Vector2, _mult: float) -> void:
	for h in get_tree().get_nodes_in_group("player"):
		if h.global_position.distance_to(global_position) <= 80.0:
			h.bless(20.0, Skills.value("blessing", lvl))
	Game.ring(global_position, 80.0, HOLY_COLOR, 0.4)


func _release_holy_light(_lvl: int, target: Vector2, mult: float) -> void:
	Game.ring(target, 26.0, HOLY_COLOR, 0.35)
	Game.burst(target + Vector2(0, -10), HOLY_COLOR, 20)
	hit_circle(target, 26.0, mult)


func _release_great_heal(lvl: int, _target: Vector2, _mult: float) -> void:
	_heal_allies(140.0, _heal_amount(Skills.value("great_heal", lvl), 3.0))


func _release_resurrect(lvl: int, _target: Vector2, _mult: float) -> void:
	var best: Node = null
	var best_d := 70.0
	for h in get_tree().get_nodes_in_group("player"):
		if h != self and h.dead:
			var d: float = h.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = h
	if best == null:
		_hint("Некого воскрешать", Color(0.8, 0.8, 0.85))
		return
	best.revive(Skills.value("resurrect", lvl))


func _cast_sanctuary(lvl: int, dir: Vector2, _mult: float) -> void:
	var zone: Node2D = PUDDLE.new()
	zone.team = "player"
	zone.caster = self
	zone.mult = Skills.value("sanctuary", lvl, "v2") / 100.0
	zone.heal = int(round(Skills.value("sanctuary", lvl) * (1.0 + st.derived()["heal_pct"] / 100.0)))
	zone.radius = 40.0
	zone.lifetime = 6.0
	zone.color = HOLY_COLOR
	zone.position = _cast_target(dir, 110.0)
	Game.ground().add_child(zone)


func _cast_chi_flurry(_lvl: int, dir: Vector2, mult: float) -> void:
	_flurry(dir, 5, 0.08, mult, 34.0)


func _cast_chi_wave(_lvl: int, dir: Vector2, mult: float) -> void:
	var b := _shoot("bolt", dir, mult, 170.0, 0.7, Color(0.75, 0.9, 1.0))
	b.pierce = 99
	b.missable = false


# ---------------- Броски (дальний навык ближников) ----------------

func _cast_sword_throw(_lvl: int, dir: Vector2, mult: float) -> void:
	var b := _shoot("blade", dir, mult, 220.0, 0.55, Color(0.85, 0.88, 0.95))
	b.pierce = 1


func _cast_axe_throw(_lvl: int, dir: Vector2, mult: float) -> void:
	var b := _shoot("axe", dir, mult, 170.0, 0.7, Color(0.75, 0.7, 0.65))
	b.pierce = 99


func _cast_shield_throw(lvl: int, dir: Vector2, mult: float) -> void:
	var b := _shoot("shield", dir, mult, 200.0, 0.6, Color(0.95, 0.85, 0.45))
	b.bounce = 2
	b.stun_sec = Skills.value("shield_throw", lvl, "v2")
	b.missable = false


func _cast_poison_dagger(lvl: int, dir: Vector2, mult: float) -> void:
	var b := _shoot("dagger", dir, mult, 230.0, 0.55, POISON_COLOR)
	b.dot_pct = Skills.value("poison_dagger", lvl, "v2") / 100.0


func _cast_iron_skin(lvl: int, _dir: Vector2, _mult: float) -> void:
	_iron_time = 6.0
	_iron_pct = Skills.value("iron_skin", lvl)
	Game.burst(center(), Color(0.75, 0.75, 0.8), 16)
	Game.float_text(global_position + Vector2(0, -24), "Железная кожа", Color(0.85, 0.85, 0.9))


# ---------------- Рывок / отскок ----------------

var _dash_stun := false          # святой рывок паладина оглушает задетых
var _dash_on_end := Callable()   # что сделать по окончании рывка (прыжок-удар берсерка)


func _start_dash(vel: Vector2, time: float, mult: float) -> void:
	_dash_velocity = vel
	_dash_time = time
	_dash_mult = mult
	_dash_hit = []
	_dash_stun = false
	_dash_on_end = Callable()
	_invuln = maxf(_invuln, time + 0.1)


func _process_dash(delta: float) -> void:
	_dash_time -= delta
	velocity = _dash_velocity
	move_and_slide()
	if Engine.get_physics_frames() % 2 == 0:
		Game.burst(center(), HOLY_COLOR if _dash_stun else Color(1, 1, 1, 0.6), 2)
	if _dash_mult > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e in _dash_hit:
				continue
			if e.global_position.distance_to(global_position) < 16.0:
				_dash_hit.append(e)
				var r := roll(_dash_mult)
				deal(e, r[0], global_position, r[1], _missable())
				if _dash_stun and not e.dead:
					e.apply_stun(3.0, "stun")
	if _dash_time <= 0.0:
		velocity = _dash_velocity.normalized() * max_speed
		if _dash_on_end.is_valid():
			var f := _dash_on_end
			_dash_on_end = Callable()
			f.call()


# ---------------- Предметы, лестница ----------------

## Ближайший предмет на полу в радиусе взаимодействия (или null).
func nearest_item() -> Node2D:
	var best: Node2D = null
	var best_d := INTERACT_RANGE
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.kind != "item":
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Ближайшая постройка/объект, с которым можно взаимодействовать (или null).
func nearest_interactable() -> Node2D:
	var best: Node2D = null
	var best_d := 18.0
	for n in get_tree().get_nodes_in_group("interactables"):
		var d: float = global_position.distance_to(n.interact_point())
		if d < best_d:
			best_d = d
			best = n
	return best


func _interact() -> void:
	var thing := nearest_interactable()
	if thing:
		thing.interact(self)
		return
	var item_node := nearest_item()
	if item_node:
		var it: Dictionary = item_node.item
		var reason: String = st.equip_block_reason(it)
		# Слот пуст и предмет подходит — сразу надеть; иначе — в сумку (I — инвентарь).
		if reason != "" or st.equipment[it["slot"]] != null:
			if st.bag_add(it):
				item_node.queue_free()
				_hint("В сумке (I): %s" % Items.display_name(it), Color(0.8, 0.9, 1.0))
			else:
				_hint("Сумка полна — I, чтобы разобрать", Color(1.0, 0.5, 0.45))
			return
		var removed: Array = st.equip(it)
		var pos := item_node.global_position
		item_node.queue_free()
		for i in removed.size():
			var drop: Node2D = PICKUP.new()
			drop.kind = "item"
			drop.item = removed[i]
			drop.position = pos + Vector2(i * 10, 0)
			get_parent().add_child(drop)
		return
	var dungeon := get_tree().current_scene
	if dungeon.has_method("is_near_stairs") and dungeon.is_near_stairs(global_position):
		Game.next_floor()


# ---------------- Инвентарь (сумка) ----------------

## op: "equip" (индекс в сумке), "unequip" (слот), "drop" (индекс в сумке).
## У гостя — просьба хозяину.
func inv(op: String, arg: Variant) -> void:
	if Net.is_guest():
		Net.cmd("inv", [op, arg])
		return
	match op:
		"equip":
			for it: Dictionary in st.equip_from_bag(int(arg)):
				_drop_item(it)
		"unequip":
			if not st.unequip(str(arg)):
				_hint("Сумка полна", Color(1.0, 0.5, 0.45))
		"drop":
			var it: Variant = st.take_from_bag(int(arg))
			if it != null:
				_drop_item(it)


func _drop_item(it: Dictionary) -> void:
	var drop: Node2D = PICKUP.new()
	drop.kind = "item"
	drop.item = it
	drop.position = position + Vector2(randf_range(-6, 6), 4)
	get_parent().add_child(drop)


# ---------------- Урон и смерть ----------------

func take_damage(amount: int, from: Vector2) -> void:
	if dead or _invuln > 0.0:
		return
	if Game.floor_mod() == "glass":
		amount = int(round(amount * 1.4))  # модификатор «Стеклянная пушка»
	# Уклонение (снаряжение): удар не прошёл.
	var eva: float = evasion + (_smoke_eva if _smoke_time > 0.0 else 0.0)
	if eva > 0.0 and randf() * 100.0 < eva:
		_invuln = 0.3
		Game.float_text(global_position + Vector2(0, -22), "Уклонение", Color(0.8, 0.9, 1.0))
		return
	# Шипы: часть урона возвращается обидчику, если он рядом (ближний бой).
	if special("thorns") > 0:
		var best: Node = null
		var best_d := 28.0
		for e in get_tree().get_nodes_in_group("enemies"):
			var dd: float = e.global_position.distance_to(from)
			if dd < best_d:
				best_d = dd
				best = e
		if best:
			deal(best, maxi(1, int(round(amount * special("thorns") / 100.0))), global_position, false, false)
	if god:
		amount = 0
	elif damage_reduction > 0.0 or _iron_time > 0.0:
		var cut: float = damage_reduction + (_iron_pct if _iron_time > 0.0 else 0.0)
		amount = maxi(1, int(round(amount * (1.0 - minf(cut, 85.0) / 100.0))))
	hp = maxi(0, hp - amount)
	if "--autotest" in OS.get_cmdline_user_args():
		print("  PLAYER hurt %d from %s -> hp %d" % [amount, from, hp])
	_invuln = INVULN_TIME
	Game.damage_number(global_position + Vector2(0, -20), amount, Color(1.0, 0.3, 0.3))
	velocity = (global_position - from).normalized() * 150.0
	Game.shake(3.0, 0.2)
	sprite.modulate = Color(1, 0.35, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.3)
	if hp <= 0:
		_die()


func _die() -> void:
	_cancel_cast()
	_spin_time = 0.0
	_shield_time = 0.0
	_focus_time = 0.0
	dead = true
	collision_layer = 0
	sprite.visible = true
	sprite.play("idle_" + facing)
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", PI / 2.0, 0.3)
	tw.parallel().tween_property(sprite, "modulate", Color(0.5, 0.5, 0.6), 0.3)
	Game.shake(5.0, 0.35)
	died.emit()
	Game.on_hero_died()


# ---------------- Анимация ----------------

## Направление взгляда — 8 сторон: down, down_side, side, up_side, up (влево — зеркально).
func _face(dir: Vector2) -> void:
	var oct := posmod(int(round(dir.angle() / (PI / 4.0))), 8)  # 0 — вправо, 2 — вниз, 6 — вверх
	facing = ["side", "down_side", "down", "down_side", "side", "up_side", "up", "up_side"][oct]
	sprite.flip_h = dir.x < -0.01 and facing != "down" and facing != "up"


func _update_animation(input: Vector2) -> void:
	if input == Vector2.ZERO:
		_play("idle_" + facing)
		return
	if _facing_lock <= 0.0:
		_face(input)
	_play("walk_" + facing)


func _play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


## Лист 8 сторон: кадр 24x24, строки — down, down_side, side, up_side, up; 4 кадра шага.
func _build_frames8(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var rows := ["down", "down_side", "side", "up_side", "up"]
	for r in rows.size():
		var dir: String = rows[r]
		var walk := "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for col in 4:
			var t := AtlasTexture.new()
			t.atlas = sheet
			t.region = Rect2(col * 24, r * 24, 24, 24)
			frames.add_frame(walk, t)
		var idle := "idle_" + dir
		frames.add_animation(idle)
		frames.add_frame(idle, frames.get_frame_texture(walk, 0))
	return frames


# Нарезает лист героя на анимации: walk_down/up/side и idle_down/up/side
# (диагонали старых листов — кадры «вбок»).
func _build_frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir: String in DIR_ROWS:
		var row: int = DIR_ROWS[dir]
		var walk := "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for col in 4:
			frames.add_frame(walk, _cell(sheet, col, row))
		var idle := "idle_" + dir
		frames.add_animation(idle)
		frames.add_frame(idle, _cell(sheet, 0, row))
	for diag: String in ["down_side", "up_side"]:
		for kind: String in ["walk_", "idle_"]:
			frames.add_animation(kind + diag)
			frames.set_animation_speed(kind + diag, 8.0)
			for i in frames.get_frame_count(kind + "side"):
				frames.add_frame(kind + diag, frames.get_frame_texture(kind + "side", i))
	return frames


func _cell(sheet: Texture2D, col: int, row: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = sheet
	t.region = Rect2(col * 16, row * 16, 16, 16)
	return t
