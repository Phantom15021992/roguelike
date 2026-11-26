extends Node
## Глобальный узел (autoload «Game»): управление, эффекты, переходы между этажами, автотест.

const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")
const Skills := preload("res://scripts/skills.gd")
const DUNGEON_SCENE := "res://scenes/main.tscn"
const CAMP_SCENE := "res://scenes/camp.tscn"

var shots_seen := 0  # сколько снарядов выпустили монстры (для тестов)
var attacker: Node   # герой, который сейчас наносит удар (см. player.deal)
var menu_done := false  # меню «одиночная / кооператив» уже показано
var coop_depth := 1     # кооп: с какого этажа начнёт хозяин
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
var pause_menu: CanvasLayer
var _shake_time := 0.0
var _shake_strength := 0.0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Физические клавиши: работают и на русской раскладке.
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("attack", [KEY_SPACE, KEY_J])
	_bind("interact", [KEY_E])
	_bind("skill_1", [KEY_1])
	_bind("skill_2", [KEY_2])
	_bind("skill_3", [KEY_3])
	if not InputMap.has_action("attack_mouse"):
		InputMap.add_action("attack_mouse")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack_mouse", click)


func _ready() -> void:
	pause_menu = PAUSE_MENU.new()
	add_child(pause_menu)
	# Для тестов: `--depth=3` — начать сразу с нужного этажа.
	# `--class=archer` — сразу выбрать класс (в автотесте без него — случайный).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--depth="):
			Run.depth = int(arg.get_slice("=", 1))
		if arg.begins_with("--class="):
			Run.set_class(arg.get_slice("=", 1))
		# `--job=paladin` — сразу профессия (класс подставится сам).
		if arg.begins_with("--job="):
			var j := arg.get_slice("=", 1)
			Run.set_class(Skills.JOBS[j]["base"])
			Run.set_job(j)
	if Run.cls == "" and ("--autotest" in OS.get_cmdline_user_args()):
		Run.set_class(["warrior", "archer", "mage", "thief", "acolyte"].pick_random())
	if "--autotest" in OS.get_cmdline_user_args():
		print("class: " + Run.cls)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--uitest" in args or "--camptest" in args or "--skilltest" in args or "--zootest" in args:
		# Тесты бота и интерфейса подземелья начинаются сразу в подземелье, не в лагере.
		if not "--camptest" in args:
			get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE)
		# Страховка: если тест сломается, окно не останется висеть.
		get_tree().create_timer(480.0, true, false, true).timeout.connect(func() -> void:
			print("AUTOTEST WATCHDOG: timeout, quitting")
			get_tree().quit(1))
	if "--autotest" in args:
		_autotest()
	elif "--uitest" in args:
		_uitest()
	elif "--camptest" in args:
		_camptest()
	elif "--clicktest" in args:
		_clicktest()
	elif "--skilltest" in args:
		_skilltest()
	elif "--zootest" in args:
		_zootest()
	elif "--herotest" in args:
		_herotest()
	elif "--coopsave" in args:
		_coopsavetest()
	elif "--savetest" in args:
		_savetest()
	elif "--cooptest" in args:
		get_tree().create_timer(150.0, true, false, true).timeout.connect(func() -> void:
			print("COOPTEST WATCHDOG: timeout")
			get_tree().quit(1))
		_cooptest()


## Проверка навыков профессии (`--skilltest --job=paladin` или `--class=mage`):
## рядом с героем ставятся слизни, каждый навык применяется по очереди, печатается,
## что стало с монстрами (HP, оглушение) и героем. Скриншот в середине каждого навыка.
func _skilltest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	while get_tree().current_scene == null or not get_tree().current_scene.has_method("find_path"):
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var dungeon := get_tree().current_scene
	var p: Node2D = get_tree().get_first_node_in_group("player")
	p.god = true
	# Убираем обычных монстров этажа, чтобы не мешали.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await get_tree().process_frame
	for id: String in Run.skill_list():
		Run.skill_levels[id] = 3
	Run.changed.emit()
	var ids := Skills.actives_of(Run.skill_list())
	var tag := Run.job if Run.job != "" else Run.cls
	for slot in ids.size():
		var id: String = ids[slot]
		var dummies := []
		# Заклинания в цель бьют на 70 px впереди — туда и ставим монстров.
		var offs := [Vector2(30, 0), Vector2(44, 12), Vector2(40, -14)]
		if Skills.SKILLS[id].has("cast") and id != "power_shot":
			offs = [Vector2(68, 0), Vector2(74, 8), Vector2(72, -8)]
		while p.is_casting():  # дождаться конца прошлого каста/канала
			await get_tree().create_timer(0.2).timeout
		# Дальние монстры: два духа слева от героя стреляют по нему (герой бессмертен).
		var shooters := []
		for off in [Vector2(-70, -30), Vector2(-70, 30)]:
			var w: Node2D = preload("res://scenes/wisp.tscn").instantiate()
			w.position = p.position + off
			w.max_hp = 2000
			w.contact_damage = 0
			w.fire_cooldown = 1.2
			dungeon.get_node("Entities").add_child(w)
			shooters.append(w)
		var shots_before := shots_seen
		for off in offs:
			var s: Node2D = preload("res://scenes/slime.tscn").instantiate()
			s.position = p.position + off
			s.max_hp = 2000
			s.contact_damage = 0
			dungeon.get_node("Entities").add_child(s)
			dummies.append(s)
		await get_tree().create_timer(0.3).timeout
		p.skill_cd.clear()
		p.sp = p.max_sp
		p.hp = maxi(1, p.max_hp - 60)  # чтобы было видно лечение
		var hp_before: int = p.hp
		p.aim = Vector2.RIGHT
		var used: bool = p.use_skill(slot)
		var reflected_before: int = p.reflected_count
		if id == "shield_reflect":  # щиту нужно время, чтобы духи успели по нему выстрелить
			p.skill_cd.clear()
			p.sp = p.max_sp
			print("  under shield: prayer=%s (expect false), charge=%s (expect true)" % [p.use_skill(1), p.use_skill(0)])
			await get_tree().create_timer(3.0).timeout
		if id == "trap":  # подтолкнуть монстра в ловушку
			await get_tree().create_timer(0.5).timeout
			var t: Node2D = get_tree().get_first_node_in_group("traps")
			if t:
				dummies[0].global_position = t.global_position
		await get_tree().create_timer(0.7).timeout
		_shot("skill_%s_%d_%s" % [tag, slot + 1, id])
		await get_tree().create_timer(2.0).timeout
		var hps := []
		var stunned := []
		for d in dummies:
			if is_instance_valid(d):
				hps.append(d.max_hp - d.hp)
				stunned.append(d.is_stunned() or d._slow_time > 0.0)
		var extra := " shots_on_hero=%d" % (shots_seen - shots_before)
		if id == "shield_reflect":
			extra += " reflected=%d (charges left %d, shield %.1fs)" % [p.reflected_count - reflected_before, p._shield_charges, maxf(0.0, p._shield_time)]
		var shooter_dmg := []
		for w in shooters:
			if is_instance_valid(w):
				shooter_dmg.append(w.max_hp - w.hp)
		extra += " shooters_dmg=%s" % [shooter_dmg]
		print("SKILLTEST %s slot%d %s used=%s dmg=%s ctrl=%s hero_hp %d->%d%s" % [tag, slot + 1, id, used, hps, stunned, hp_before, p.hp, extra])
		for d in dummies + shooters:
			if is_instance_valid(d):
				d.queue_free()
		for b in get_tree().get_nodes_in_group("enemy_shots"):
			b.queue_free()
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()


## Нажимает в окнах настоящие кнопки (через сигнал pressed), как игрок мышью.
## Ловит ошибки вида «кнопка удаляет сама себя при нажатии».
func _clicktest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	await _frames_idle(20)
	var hud: Node = get_tree().current_scene.get_node("CampHUD")
	print("save: gold=%d stash=%d mine=%d" % [Meta.gold, Meta.stash.size(), Meta.level("mine")])
	hud.open_building("mine")
	await _frames_idle(3)
	print("click mine collect: %s" % _click(hud, "Собрать"))
	await _frames_idle(3)
	hud.close()
	await _frames_idle(3)
	hud.open_building("portal")
	await _frames_idle(3)
	print("click class: %s" % _click(hud, "Выбрать (2)"))
	await _frames_idle(5)
	_shot("click_1_loadout")
	print("click take: %s" % _click(hud, "Взять"))
	await _frames_idle(3)
	print("click take 2: %s" % _click(hud, "Взять"))
	await _frames_idle(3)
	print("click go: %s" % _click(hud, "В путь"))
	while get_tree().current_scene == null or not get_tree().current_scene.has_method("find_path"):
		await get_tree().process_frame
	await _frames_idle(20)
	_shot("click_2_dungeon")
	print("in dungeon: class=%s weapon=%s armor=%s" % [Run.cls, Items_display(Run.equipment["weapon"]), Items_display(Run.equipment["armor"])])
	# Окна подземелья: навыки и характеристики через кнопки «+».
	var dhud: Node = get_tree().current_scene.get_node("HUD")
	dhud.toggle_panel("skills")
	await _frames_idle(3)
	print("click skill +: %s" % _click(dhud, "+"))
	await _frames_idle(3)
	dhud.toggle_panel("stats")
	Run.points += 2
	Run.changed.emit()
	await _frames_idle(3)
	print("click stat +: %s" % _click(dhud, "+"))
	await _frames_idle(3)
	print("click stat + again: %s" % _click(dhud, "+"))
	await _frames_idle(3)
	_shot("click_3_stats")
	print("CLICKTEST DONE: skills=%s stats=%s" % [Run.skill_levels, Run.stats])
	get_tree().quit()


func _frames_idle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Найти видимую доступную кнопку, чей текст начинается с prefix, и «нажать» её.
func _click(root: Node, prefix: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and (b.text as String).begins_with(prefix):
			b.pressed.emit()
			return true
	return false


## Проверка лагеря: постройки, улучшение, портал, возвращение после забега.
func _camptest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	for i in 20:
		await get_tree().process_frame
	_shot("camp_1_start")
	var hud: Node = get_tree().current_scene.get_node("CampHUD")
	Meta.gold = 300
	hud.open_building("forge")
	for i in 5:
		await get_tree().process_frame
	_shot("camp_2_forge")
	Meta.upgrade("forge")
	Meta.upgrade("mine")
	Meta.upgrade("training")
	Meta.mine_stored = 37.0
	hud.open_building("mine")
	for i in 5:
		await get_tree().process_frame
	_shot("camp_3_mine")
	hud.close()
	# Мастерская: построить, создать предмет, заточить на складе.
	Meta.gold = 1000
	Meta.add_materials({"ore": 20, "bone": 12, "wing": 10, "gel": 8, "dust": 8, "spore": 6, "crown": 1})
	Meta.upgrade("workshop")
	hud.open_building("workshop")
	for i in 5:
		await get_tree().process_frame
	_shot("camp_4_workshop_craft")
	hud._craft("bow", "")
	hud._craft("chain", "crown")
	hud._tab = "stash"
	hud._refill()
	for i in 5:
		await get_tree().process_frame
	var bow: Dictionary = Meta.stash[0]
	for i in 6:
		hud._refine_stash(bow, 3.0)
	print("stash: %s" % [Meta.stash.map(func(it: Dictionary) -> String: return Items_display(it))])
	for i in 5:
		await get_tree().process_frame
	_shot("camp_5_workshop_stash")
	hud.close()
	# Портал: лучник, взять лук и кольчугу.
	hud.open_building("portal")
	hud._pick_class("archer")
	hud._loadout = {"weapon": 0, "armor": 1}
	hud._refill()
	for i in 5:
		await get_tree().process_frame
	_shot("camp_6_loadout")
	hud._go()
	for i in 30:
		await get_tree().process_frame
	_shot("camp_7_dungeon")
	print("run started: class=%s weapon=%s armor=%s dmg=%s hp=%s stash_left=%d" % [Run.cls,
		Items_display(Run.equipment["weapon"]), Items_display(Run.equipment["armor"]),
		Run.derived()["atk_min"], Run.derived()["max_hp"], Meta.stash.size()])
	Run.gold = 42
	Run.depth = 3
	Run.add_material("bone", 4)
	return_to_camp(true)
	for i in 30:
		await get_tree().process_frame
	_shot("camp_8_back")
	print("back in camp alive: gold=%d stash=%d bones=%d runs=%d" % [Meta.gold, Meta.stash.size(), Meta.materials.get("bone", 0), Meta.runs])
	# Второй забег — гибель: золото, материалы и снаряжение теряются.
	var bones_before: int = Meta.materials.get("bone", 0)
	var gold_before := Meta.gold
	hud = get_tree().current_scene.get_node("CampHUD")
	hud.open_building("portal")
	hud._pick_class("archer")
	hud._loadout = {"weapon": 0}
	hud._go()
	for i in 30:
		await get_tree().process_frame
	Run.gold = 10
	Run.add_material("bone", 5)
	return_to_camp(false)
	for i in 30:
		await get_tree().process_frame
	_shot("camp_9_died")
	print("back in camp dead: gold +%d (expect 0), bones %d -> %d (expect same), stash=%d (expect 1)" % [
		Meta.gold - gold_before, bones_before, Meta.materials.get("bone", 0), Meta.stash.size()])
	get_tree().quit()


func Items_display(it: Variant) -> String:
	return "-" if it == null else preload("res://scripts/items.gd").display_name(it)


## Проверка интерфейса: предмет под ногами, новый уровень, окно характеристик.
func _uitest() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	for i in 20:
		await get_tree().process_frame
	var hud: Node = get_tree().current_scene.get_node("HUD")
	_shot("ui_0_class_select")
	hud._choose_class("mage")
	var p: Node2D = get_tree().get_first_node_in_group("player")
	var drop: Node2D = preload("res://scripts/pickup.gd").new()
	drop.kind = "item"
	drop.item = preload("res://scripts/items.gd").make("staff", 2, 1)
	drop.position = p.position + Vector2(6, 0)
	p.get_parent().add_child(drop)
	for i in 40:
		await get_tree().process_frame
	_shot("ui_1_tooltip")
	Run.add_xp(Run.xp_to_next())
	Run.learn_skill("meteor")
	for i in 15:
		await get_tree().process_frame
	_shot("ui_2_levelup")
	# Две части комплекта архимага + редкое кольцо — проверить бонусы и особые свойства.
	Run.equip(preload("res://scripts/items.gd").make_set_piece("archmage", "circlet", 3))
	Run.equip(preload("res://scripts/items.gd").make_set_piece("archmage", "mantle", 3))
	Run.equip(preload("res://scripts/items.gd").make("ring", 2, 3))
	hud.toggle_panel("stats")
	Run.add_stat("int")
	for i in 5:
		await get_tree().process_frame
	_shot("ui_3_stats")
	# Инвентарь: три предмета в сумке.
	var IL := preload("res://scripts/items.gd")
	Run.bag_add(IL.make("staff", 2, 3))
	Run.bag_add(IL.make("chain", 1, 3))
	Run.bag_add(IL.make("bow", 1, 3))
	hud.toggle_panel("inv")
	for i in 5:
		await get_tree().process_frame
	_shot("ui_3b_inventory")
	hud.toggle_panel("skills")
	for i in 5:
		await get_tree().process_frame
	_shot("ui_4_skills")
	hud.toggle_panel("skills")
	Run.gold = 200
	Run.add_material("gel", 6)
	Run.add_material("bone", 4)
	hud.toggle_panel("anvil")
	for i in 3:
		hud._do_refine(Run.equipment["weapon"], Run.derived()["craft"])
	for i in 5:
		await get_tree().process_frame
	_shot("ui_5_anvil")
	hud.toggle_panel("anvil")
	hud.toggle_map()
	for i in 5:
		await get_tree().process_frame
	_shot("ui_6_map")
	hud.toggle_map()
	pause_menu.open()
	await _wait(0.3)
	_shot("ui_6b_pause")
	pause_menu.open("help")
	await _wait(0.3)
	_shot("ui_6c_help")
	pause_menu.close()
	await _wait(0.2)
	# Каст мага: метеорит (полоса + синий круг), потом метель.
	for id in ["meteor", "chain_lightning", "blizzard"]:
		Run.skill_levels[id] = 3
	Run.changed.emit()
	p.sp = p.max_sp
	p.aim = Vector2.RIGHT
	p.use_skill(0)
	await get_tree().create_timer(0.8).timeout
	_shot("ui_7_cast_meteor")
	await get_tree().create_timer(1.0).timeout
	p.skill_cd.clear()
	p.sp = p.max_sp
	print("  blizzard started: %s" % p.use_skill(2))
	await get_tree().create_timer(2.0).timeout
	_shot("ui_8_blizzard")
	# Смена профессии на 5-м уровне.
	Run.skill_levels = {}
	Run.skill_points = 2
	while Run.level < Skills.JOB_LEVEL:
		Run.add_xp(Run.xp_to_next())
	await get_tree().create_timer(0.5).timeout
	_shot("ui_9_job")
	hud._choose_job("professor")
	await get_tree().create_timer(0.3).timeout
	hud.toggle_panel("skills")
	await get_tree().create_timer(0.3).timeout
	_shot("ui_10_job_skills")
	print("job=%s skill_points=%d" % [Run.job, Run.skill_points])
	get_tree().quit()


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				# Меню паузы (выход из игры — кнопкой в нём; в браузере выхода нет).
				if not pause_menu.is_open():
					pause_menu.open()
			KEY_F1:
				if not pause_menu.is_open():
					pause_menu.open("help")
			KEY_R:
				var p := local_hero()
				if p and p.dead:
					if not Net.active():
						return_to_camp()
					elif all_dead():
						if Net.is_host():
							coop_restart()
						else:
							Net.send_to(1, "restart", true)
			KEY_C:
				var hud := get_tree().current_scene.get_node_or_null("HUD")
				if hud:
					hud.toggle_panel("stats")
			KEY_M:
				var hud := get_tree().current_scene.get_node_or_null("HUD")
				if hud:
					hud.toggle_map()
			KEY_I:
				var hud := get_tree().current_scene.get_node_or_null("HUD")
				if hud:
					hud.toggle_panel("inv")
			KEY_K:
				var hud := get_tree().current_scene.get_node_or_null("HUD")
				if hud:
					hud.toggle_panel("skills")
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


var _mouse_time := -100.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_time = Time.get_ticks_msec() / 1000.0


## Пользовались ли мышью последние 3 секунды (тогда навыки целятся в курсор).
func mouse_recent() -> bool:
	if _ignore_mouse:
		return false
	return Time.get_ticks_msec() / 1000.0 - _mouse_time < 3.0


## В тестах мышь, случайно оказавшаяся над окном, не должна уводить заклинания в сторону.
var _ignore_mouse: bool = "--skilltest" in OS.get_cmdline_user_args() or "--autotest" in OS.get_cmdline_user_args()


func _process(delta: float) -> void:
	# Незаконченный забег сохраняется каждые 20 с (в браузере закрытие вкладки не ловится).
	_autosave_t += delta
	if _autosave_t > 20.0:
		_autosave_t = 0.0
		if not get_tree().paused:
			save_run()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * _shake_strength
	else:
		cam.offset = Vector2.ZERO


# --- Забег ---

## Из лагеря в подземелье: новый забег выбранным классом с бонусами лагеря.
## loadout — предметы со склада, взятые в забег (их уже убрали со склада).
func start_run(cls: String, loadout: Array = [], depth := 1) -> void:
	Meta.run_save = {}  # новый забег вместо незаконченного
	Run.reset()
	_load_or_new_hero(Run, cls, Meta.current_hero())
	Run.depth = depth
	for it: Dictionary in loadout:
		Run.equipment[it["slot"]] = it
	Meta.apply_to_run()
	if Net.is_host():
		# Кооп: каждый гость — своим классом, с бонусами лагеря хозяина.
		for pid: int in Net.players:
			if pid != 1:
				var st: Node = Net.players[pid]["state"]
				st.reset()
				_load_or_new_hero(st, Net.players[pid]["cls"], Net.players[pid].get("hero", {}))
				st.depth = depth
				Meta.apply_to_run(st)
				Net.players[pid]["ready"] = false
		Net.players[1]["ready"] = false
		Net.send_lobby()
	if not Meta.heroes.has(cls) or not Meta.current_hero().has("stats"):
		Meta.save_hero(Run.to_hero())  # новый герой: класс закреплён сразу
	Meta.save_game()
	_change_scene(DUNGEON_SCENE)


## Сохранённый герой этого класса — или новый 1-го уровня.
func _load_or_new_hero(st: Node, cls: String, h: Dictionary) -> void:
	if h.get("cls", "") == cls and h.has("stats"):
		st.load_hero(h)
	else:
		st.set_class(cls)


## Этаж-сохранение (5, 10, ...): герои запоминаются, отсюда можно начать следующий забег.
func checkpoint(depth: int) -> void:
	for h in get_tree().get_nodes_in_group("player"):
		var st: Node = h.st
		st.checkpoint = maxi(st.checkpoint, depth)
		st.best = maxi(st.best, depth)
		_save_hero_of(h.peer_id, st)
	banner("Сохранение: теперь можно начинать с %d этажа" % depth, 3.0)


## Незаконченный забег — в файл сохранения (начало этажа, раз в 20 с, выход из игры).
## Кооп: хозяин сохраняет всех героев, гостей — по их номеру (Meta.uid гостя);
## героев, которых сейчас нет в игре, не трогает — они смогут вернуться.
func save_run() -> void:
	if Net.is_guest() or Run.cls == "" or _scene_name() != "Main":
		return
	if all_dead():
		Meta.clear_run()
		return
	var saved: Dictionary = Meta.run_save.get("players", {}) if Meta.run_save.get("coop", false) == Net.is_host() else {}
	var players := saved.duplicate(true)
	for pid: int in (Net.players.keys() if Net.is_host() else [1]):
		var st: Node = Net.state_of(pid)
		var key := "host" if pid == Net.my_id() or not Net.is_host() else str(Net.players[pid].get("uid", ""))
		if key == "" or st.cls == "":
			continue
		var h: Node = Net.hero_of(pid) if Net.is_host() else local_hero()
		if h and is_instance_valid(h):
			players[key] = st.to_run(maxi(1, h.max_hp / 2) if h.dead else h.hp, int(h.sp))
		else:
			players[key] = st.to_run()
	Meta.run_save = {"depth": Run.depth, "gold": Run.gold, "materials": Run.materials.duplicate(),
		"coop": Net.is_host(), "players": players}
	Meta.save_game()


## Продолжить сохранённый забег (выбрано сохранение с забегом / кооп: «Продолжить забег»).
func continue_run() -> void:
	var r: Dictionary = Meta.run_save
	var ps: Dictionary = r.get("players", {})
	if not ps.has("host"):
		Meta.clear_run()
		return
	Run.reset()
	Run.load_run(ps["host"])
	Run.depth = maxi(1, int(r.get("depth", 1)))
	Run.gold = int(r.get("gold", 0))
	var m: Dictionary = r.get("materials", {})
	for k: String in m:
		Run.materials[k] = int(m[k])
	if Net.is_host():
		for pid: int in Net.players:
			if pid == 1:
				continue
			var p: Dictionary = Net.players[pid]
			var st: Node = p["state"]
			st.reset()
			var uid_key := str(p.get("uid", ""))
			if uid_key != "" and ps.has(uid_key):
				st.load_run(ps[uid_key])
			else:
				# Новый в этом забеге: его сохранённый герой (или новый мечник).
				var h: Dictionary = p.get("hero", {})
				_load_or_new_hero(st, str(h.get("cls", "warrior")), h)
				Meta.apply_to_run(st)
			st.depth = Run.depth
			p["ready"] = false
		Net.players[1]["ready"] = false
		Net.send_lobby()
	menu_done = true
	_change_scene(DUNGEON_SCENE)


## Имена героев сохранённого забега (для меню кооператива): {ключ: "Мечник, 7 ур."}.
func run_save_names() -> Dictionary:
	var out := {}
	var ps: Dictionary = Meta.run_save.get("players", {})
	for k: String in ps:
		var h: Dictionary = ps[k]
		var job := str(h.get("job", ""))
		var t: String = Skills.JOBS[job]["name"] if job != "" else Skills.CLASSES.get(str(h.get("cls", "warrior")), Skills.CLASSES["warrior"])["name"]
		out[k] = "%s, %d ур." % [t, int(h.get("level", 1))]
	return out


## Герой погиб: если пали все — сохранённый забег пропадает (выйти из игры, чтобы спастись, нельзя).
func on_hero_died() -> void:
	if not Net.is_guest() and all_dead():
		Meta.clear_run()


var _autosave_t := 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()
		Meta.save_game()


var camp_panel := ""   # какое окно открыть, когда загрузится лагерь ("coop" и т.п.)


## В лагерь (перезагрузить его — например, после выбора сохранения) и открыть окно panel.
func open_camp(panel := "") -> void:
	Run.reset()
	camp_panel = panel
	_change_scene(CAMP_SCENE)


## Выйти в главное меню (выбор сохранения): забег сохраняется, кооп закрывается.
func to_main_menu() -> void:
	save_run()
	Meta.save_game()
	if Net.active():
		Net.leave()
	Run.reset()
	menu_done = false
	_change_scene(CAMP_SCENE)


## Сохранить героя: свой — в лагерь, гостя — ему (в его сохранение).
func _save_hero_of(pid: int, st: Node) -> void:
	var h: Dictionary = st.to_hero()
	if pid == Net.my_id():
		Meta.save_hero(h)
	else:
		Net.send_to(pid, "hero_save", h)


## Забег окончен: золото уносится в лагерь, итоги запоминаются.
## alive = true — вернулся через портал после босса: золото, материалы и снаряжение сохраняются.
## Погиб — всё найденное в забеге теряется.
func return_to_camp(alive := false) -> void:
	if Net.is_guest():
		return  # в коопе забег заканчивает хозяин
	Meta.run_save = {}  # забег окончен — продолжать нечего
	var items: Array = []
	# В коопе на склад хозяина уходит снаряжение всех героев.
	for st: Node in Net.all_states():
		var all_items: Array = st.equipment.values() + st.bag  # надетое и сумка
		for it: Variant in all_items:
			if it != null and not it.get("starter", false):  # стартовое оружие на склад не нужно
				items.append(it)
	Meta.bank_run(Run.depth, Run.gold, Run.level, Run.title(), Run.materials, items, alive)
	# Герои: живые сохраняются как есть; павшие возвращаются к последнему сохранению
	# (запоминается только самый глубокий этаж — для смены класса).
	for pid: int in (Net.players.keys() if Net.is_host() else [1]):
		var st: Node = Net.state_of(pid)
		if st.cls == "":
			continue
		if alive:
			_save_hero_of(pid, st)
		elif pid == Net.my_id():
			var saved: Dictionary = Meta.heroes.get(st.cls, {})
			if not saved.is_empty():
				saved["best"] = maxi(int(saved.get("best", 0)), st.depth)
				Meta.save_game()
		else:
			Net.send_to(pid, "hero_best", st.depth)
	for st: Node in Net.all_states():
		st.reset()
	_change_scene(CAMP_SCENE)


func _change_scene(path: String) -> void:
	Net.scene_leaving()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


func next_floor() -> void:
	# HP/SP каждого героя переходят на следующий этаж; павшие в коопе возрождаются с половиной HP.
	for p in get_tree().get_nodes_in_group("player"):
		var st: Node = p.st
		st.hp = maxi(1, p.max_hp / 2) if p.dead else p.hp
		st.sp = int(p.sp)
	Run.depth += 1
	_reload()


func _reload() -> void:
	Net.scene_leaving()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()


# --- Кооператив ---

## Свой герой (в одиночной игре — единственный).
func local_hero() -> Node:
	for h in get_tree().get_nodes_in_group("player"):
		if h.is_local():
			return h
	return null


## Пали ли все герои (в одиночной — сам герой).
func all_dead() -> bool:
	for h in get_tree().get_nodes_in_group("player"):
		if not h.dead:
			return false
	return true


## Состояние случайного героя команды (под чей класс выпадет предмет).
func random_hero_state() -> Node:
	return Net.all_states().pick_random()


## Открыто ли окно, которое перехватывает управление героем.
func ui_blocks_input() -> bool:
	if pause_menu and pause_menu.is_open():
		return true
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var hud := scene.get_node_or_null("HUD")
	if hud and hud.open_panel != "":
		return true
	var camp_hud := scene.get_node_or_null("CampHUD")
	return camp_hud != null and camp_hud.is_open()


## Подсказка над героем: своему — сразу, гостю — по сети.
func hint_to(hero: Node, text: String) -> void:
	if hero.is_local():
		hero._hint(text, Color(1.0, 0.85, 0.5))
	else:
		Net.send_to(hero.peer_id, "ui", {"hint": text})


## Хозяин: в сцене (лагерь/подземелье) ставит героев гостей рядом со своим.
func spawn_guest_heroes() -> void:
	if not Net.is_host():
		return
	for pid: int in Net.players:
		if pid != 1:
			_spawn_guest_hero(pid)


func _spawn_guest_hero(pid: int) -> void:
	var scene := get_tree().current_scene
	if scene == null or Net.hero_of(pid) != null:  # сцена как раз сменяется — гость пришлёт «готов» ещё раз
		return
	var mine := scene.get_node_or_null("Entities/Player")
	var h: Node2D = PLAYER_SCENE.instantiate()
	h.peer_id = pid
	h.name = "Player%d" % pid
	h.position = (mine.position if mine else Vector2(100, 100)) + Vector2(12 * (pid - 1), 6)
	scene.get_node("Entities").add_child(h)


## Хозяин: гость загрузил сцену — у него должен быть герой.
func on_guest_scene_ready(pid: int) -> void:
	_spawn_guest_hero(pid)


## Хозяин: все выбрали класс у портала — в путь (нужно минимум двое).
func coop_try_start() -> void:
	if not Net.is_host() or Net.player_count() < 2:
		return
	for pid: int in Net.players:
		if not Net.players[pid]["ready"]:
			banner("Ждём игроков: %d/%d готовы" % [_ready_count(), Net.player_count()])
			return
	var hud := get_tree().current_scene.get_node_or_null("CampHUD")
	var loadout: Array = hud.take_loadout() if hud and hud.has_method("take_loadout") else []
	start_run(Net.players[1]["cls"], loadout, coop_depth)


func _ready_count() -> int:
	var n := 0
	for pid: int in Net.players:
		if Net.players[pid]["ready"]:
			n += 1
	return n


## Хозяин: все пали — забег окончен, все в лагерь (добыча потеряна).
func coop_restart() -> void:
	if Net.is_host() and all_dead():
		return_to_camp(false)


## Гость: хозяин сменил сцену.
func guest_load_scene(kind: String) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE if kind == "dungeon" else CAMP_SCENE)


## Гость: связь потеряна — в свой лагерь.
func go_camp_offline() -> void:
	Run.reset()
	_change_scene(CAMP_SCENE)


## Гость: хозяин просит что-то показать (подсказку, окно портала).
func guest_ui(d: Dictionary) -> void:
	var scene := get_tree().current_scene
	if d.has("hint"):
		var h := local_hero()
		if h:
			h._hint(str(d["hint"]), Color(1.0, 0.85, 0.5))
	if d.get("open", "") == "portal" and scene:
		var camp_hud := scene.get_node_or_null("CampHUD")
		if camp_hud:
			camp_hud.open_building("portal")


# --- Эффекты ---

## Слой для эффектов текущей сцены (вспышки, снаряды, цифры).
func fx() -> Node:
	var scene := get_tree().current_scene
	if scene == null:  # сцена как раз сменяется — эффект просто повиснет в корне и исчезнет
		return get_tree().root
	var layer := scene.get_node_or_null("FX")
	return layer if layer else scene


## Слой на полу под персонажами (предупреждения об ударах, лужи).
func ground() -> Node:
	var scene := get_tree().current_scene
	var layer := scene.get_node_or_null("Ground") if scene else null
	return layer if layer else fx()


## Крупная надпись по центру экрана (через HUD).
func banner(text: String, time := 2.0) -> void:
	Net.fx("banner", [text, time])
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.show_banner(text, time)


func shake(strength: float, duration: float) -> void:
	Net.fx("shake", [strength, duration])
	if not Meta.setting("shake"):
		return
	_shake_strength = maxf(strength, _shake_strength if _shake_time > 0.0 else 0.0)
	_shake_time = maxf(duration, _shake_time)


## Короткая «заморозка» игры при попадании — удар ощущается весомее.
func hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func damage_number(pos: Vector2, value: int, color := Color.WHITE) -> void:
	Net.fx("damage_number", [pos, value, color])
	if not Meta.setting("numbers"):
		return
	var n: Node2D = DAMAGE_NUMBER.new()
	n.value = value
	n.color = color
	n.position = pos
	fx().add_child(n)


## Всплывающая надпись в мире (например, «Новый уровень!»).
func float_text(pos: Vector2, text: String, color := Color.WHITE) -> void:
	Net.fx("float_text", [pos, text, color])
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 12)
	l.position = pos - Vector2(60, 6)
	l.z_index = 10
	fx().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 16.0, 1.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tw.tween_callback(l.queue_free)


## Расширяющееся кольцо на полу (взрывы, вихрь, ледяная волна).
func ring(pos: Vector2, radius: float, color: Color, duration := 0.3) -> void:
	Net.fx("ring", [pos, radius, color, duration])
	var n := Node2D.new()
	n.position = pos
	n.set_meta("t", 0.0)
	n.draw.connect(func() -> void:
		var k: float = n.get_meta("t") / duration
		var r := radius * (0.4 + 0.6 * k)
		n.draw_circle(Vector2.ZERO, r, Color(color, 0.18 * (1.0 - k)))
		n.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.lightened(0.3), 0.9 * (1.0 - k)), 1.5))
	ground().add_child(n)
	var tw := n.create_tween()
	tw.tween_method(func(t: float) -> void:
		n.set_meta("t", t)
		n.queue_redraw(), 0.0, duration, duration)
	tw.tween_callback(n.queue_free)


## Молния-зигзаг между точками.
func lightning(points: PackedVector2Array, color := Color(0.7, 0.85, 1.0)) -> void:
	Net.fx("lightning", [points, color])
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = color
	for i in points.size():
		line.add_point(points[i])
		if i < points.size() - 1:
			var mid := points[i].lerp(points[i + 1], 0.5)
			var side := (points[i + 1] - points[i]).orthogonal().normalized() * randf_range(-5.0, 5.0)
			line.add_point(mid + side)
	fx().add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.25)
	tw.tween_callback(line.queue_free)


func burst(pos: Vector2, color: Color, amount := 12) -> void:
	Net.fx("burst", [pos, color, amount])
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 180)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.position = pos
	fx().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# --- Автотест: `godot --path . -- --autotest [--god]`, скриншоты в shots/ ---
# Бот: идёт по пути (A*) к ближайшему монстру и бьёт; подбирает предметы; раскидывает
# очки характеристик; когда монстров нет — идёт к лестнице. Цель — дойти до 3-го этажа.

const STUCK_WINDOW := 60      # кадров = 1 секунда
const STUCK_RATIO := 0.25     # прошёл меньше 25% обычного пути — застрял
const DETOUR_FRAMES := 40     # сколько кадров идти вбок


func _autotest() -> void:
	var target_depth := 3  # `--until=N` — до какого этажа идти
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--until="):
			target_depth = int(arg.get_slice("=", 1))
	var shots_dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	for f in DirAccess.get_files_at(shots_dir):
		DirAccess.remove_absolute(shots_dir + "/" + f)
	var god := "--god" in OS.get_cmdline_user_args()
	# Ждём, пока загрузится подземелье (тест стартует со сцены лагеря).
	while get_tree().current_scene == null or not get_tree().current_scene.has_method("find_path"):
		await get_tree().process_frame
	await _frames(2)
	# `--prep`: герой как будто прошёл предыдущие этажи — 4 уровень, броня и украшение.
	if "--prep" in OS.get_cmdline_user_args():
		const ItemsLib := preload("res://scripts/items.gd")
		while Run.level < Run.depth + 1:  # 3-й этаж → 4 ур., 6-й → 7 ур.
			Run.add_xp(Run.xp_to_next())
		Run.equip(ItemsLib.make(["leather", "chain"].pick_random(), 1, Run.depth))
		Run.equip(ItemsLib.make(["ring", "amulet"].pick_random(), 1, Run.depth))
		var pl0: Node = get_tree().get_first_node_in_group("player")
		pl0.hp = pl0.max_hp
	# `--allskills`: все навыки класса сразу 3-го уровня — проверить, что каждый работает.
	if "--allskills" in OS.get_cmdline_user_args():
		for id: String in Run.skill_list():
			Run.skill_levels[id] = 3
		Run.changed.emit()
	await _frames(20)
	_shot("01_floor1")

	var frame := 0
	var shot_i := 2
	var detour := 0
	var reposition := 0             # кадров «смены позиции» после 3 атак без урона
	var tracked_target: Node = null
	var tracked_hp := 0
	var no_dmg_attacks := 0
	var detour_side := 1.0
	var window_frames := 0
	var window_start := Vector2.ZERO
	var path := PackedVector2Array()
	var path_i := 0
	var scene_id := 0
	var items_picked := 0
	var skills_tried := 0
	var seen_depth := Run.depth

	while frame < 60 * 400:
		await get_tree().physics_frame
		frame += 1
		var p: Node2D = get_tree().get_first_node_in_group("player")
		var dungeon := get_tree().current_scene
		if p == null or dungeon == null or not dungeon.has_method("find_path"):
			continue
		if dungeon.get_instance_id() != scene_id:  # новый этаж
			scene_id = dungeon.get_instance_id()
			path = PackedVector2Array()
			window_start = p.global_position
			window_frames = 0
			detour = 0
			p.god = god
			if Run.depth != seen_depth:
				seen_depth = Run.depth
				await _frames(20)
				_shot("%02d_floor%d" % [shot_i, Run.depth])
				shot_i += 1
				continue
		if p.dead or Run.depth >= target_depth:
			break

		# Очки характеристик как у разумного игрока: в основном главная и Живучесть.
		if Run.job_pending():
			var hud_j: Node = dungeon.get_node_or_null("HUD")
			if hud_j:
				var pick: String = (Run.class_data()["jobs"] as Array).pick_random()
				print("  bot becomes %s" % pick)
				hud_j._choose_job(pick)
		while Run.points > 0:
			var r := randf()
			var key: String = Run.class_data()["primary"] if r < 0.55 else ("vit" if r < 0.85 else Run.STAT_KEYS.pick_random())
			Run.add_stat(key)
		if Run.skill_points > 0:
			var ids: Array = Run.skill_list().duplicate()
			ids.shuffle()
			for id: String in ids:
				if Run.learn_skill(id):
					print("  bot learns %s -> %d" % [id, Run.skill_level(id)])
					break
		var ranged := not (Run.cls in ["warrior", "thief"] or Run.job == "monk")
		var attack_range := 60.0 if ranged else 24.0
		var keep_range := 45.0 if ranged else 16.0

		# Цель: ближайший монстр, иначе лестница.
		var enemies := get_tree().get_nodes_in_group("enemies")
		var goal: Vector2 = dungeon.stairs_pos
		var enemy_dist := INF
		var target_e: Node2D = null
		for e: Node2D in enemies:
			if e.get("shielded"):
				continue  # босс под щитом — сначала кристаллы
			var d := e.global_position.distance_to(p.global_position)
			if d < enemy_dist:
				enemy_dist = d
				goal = e.global_position
				target_e = e

		# Путь пересчитываем раз в 15 кадров. Первая точка пути — центр клетки, где бот
		# уже стоит: её пропускаем, иначе он каждый раз дёргается назад.
		if frame % 15 == 0 or path.is_empty():
			path = dungeon.find_path(p.global_position, goal)
			path_i = 1 if path.size() > 1 else 0
		# Следующая точка — только когда дошли почти до центра клетки, чтобы не срезать углы.
		while path_i < path.size() - 1 and p.global_position.distance_to(path[path_i]) < 4.0:
			path_i += 1
		var move_dir: Vector2
		# Напрямую к цели — только если по пути до неё осталось не больше двух клеток.
		var direct := path.size() - path_i <= 2
		if direct or path.is_empty():
			move_dir = (goal - p.global_position).normalized()
		else:
			move_dir = (path[path_i] - p.global_position).normalized()

		# Застревание: за секунду прошёл меньше 25% обычного пути — отходит вбок.
		var fighting := enemy_dist <= attack_range
		# 3 атаки подряд не ранили цель (стреляет в колонну, промахи) — сменить позицию:
		# ~1 с идти по пути к цели в обход препятствия, не атакуя.
		if reposition > 0:
			reposition -= 1
			fighting = false
			if path_i < path.size() and path.size() > 1:
				move_dir = (path[path_i] - p.global_position).normalized()
			else:
				move_dir = (goal - p.global_position).normalized().orthogonal() * detour_side
		if detour > 0:
			detour -= 1
			move_dir = move_dir.orthogonal() * detour_side
			if detour == 0:
				window_start = p.global_position
				window_frames = 0
		elif fighting:
			window_start = p.global_position
			window_frames = 0
		else:
			window_frames += 1
			if window_frames >= STUCK_WINDOW:
				var moved: float = p.global_position.distance_to(window_start)
				var normal: float = p.max_speed * STUCK_WINDOW / 60.0
				if moved < normal * STUCK_RATIO:
					detour_side *= -1.0
					detour = DETOUR_FRAMES
					move_dir = move_dir.orthogonal() * detour_side
					print("  bot stuck: moved %.1f px of %.0f -> step %s" % [moved, normal, "left" if detour_side > 0 else "right"])
				window_start = p.global_position
				window_frames = 0

		# Красный круг под ногами — сначала выбегаем из него.
		var dodging := false
		for t: Node2D in get_tree().get_nodes_in_group("telegraphs"):
			if not t.hostile:
				continue  # свои круги (заклинания мага) не опасны
			var away: Vector2 = p.global_position - t.global_position
			if (t.rect_size != Vector2.ZERO and t.contains(p.global_position)) or (t.rect_size == Vector2.ZERO and away.length() < t.radius + 6.0):
				move_dir = away.normalized() if away.length() > 1.0 else Vector2.RIGHT
				dodging = true
		# Стрелок отступает, если враг подошёл вплотную.
		var retreating := ranged and enemy_dist < 28.0 and not dodging and detour == 0
		if retreating:
			dodging = true  # пока отступает — не стреляет (иначе стрелял бы себе за спину)
			move_dir = (p.global_position - goal).normalized()
			_set_move(move_dir)
		else:
			_set_move(move_dir * (1.0 if enemy_dist > keep_range or detour > 0 or dodging or reposition > 0 else 0.15))
		if fighting:
			p.aim = (goal - p.global_position).normalized()  # бот «целится» в цель
		var attacking: bool = fighting and not dodging and frame % 4 == 0
		# Учёт «пустых» атак: в момент, когда атака действительно происходит (перезарядка
		# готова), сравниваем HP цели с прошлой атакой.
		if attacking and target_e and p._attack_cd <= 0.0 and not p.is_casting():
			if target_e != tracked_target:
				tracked_target = target_e
				tracked_hp = target_e.hp
				no_dmg_attacks = 0
			else:
				if target_e.hp < tracked_hp:
					no_dmg_attacks = 0
				else:
					no_dmg_attacks += 1
				tracked_hp = target_e.hp
			if no_dmg_attacks >= 3:
				no_dmg_attacks = 0
				reposition = 60
				detour_side *= -1.0
				print("  bot repositions: 3 attacks without damage")
		_send_action("attack", attacking)
		# Навыки: в бою раз в полсекунды пробует случайный — только изученный и если хватает SP.
		var skill_slot := -1
		if fighting and not dodging and frame % 30 == 0:
			var ready := []
			var act := Skills.actives_of(Run.skill_list())
			for i in act.size():
				var sid: String = act[i]
				var lv := Run.skill_level(sid)
				if lv > 0 and p.sp >= Skills.sp_cost(sid, lv) and p.skill_cd.get(sid, 0.0) <= 0.0:
					ready.append(i)
			if not ready.is_empty():
				skill_slot = ready.pick_random()
		for i in 3:
			_send_action("skill_%d" % (i + 1), i == skill_slot)
		if skill_slot >= 0:
			skills_tried += 1

		# E: надеть предмет под ногами (только если он лучше надетого) или спуститься по лестнице.
		var item_node: Node2D = p.nearest_item()
		var on_item: bool = item_node != null and \
			_gear_score(Run.derived_with(item_node.item)) > _gear_score(Run.derived()) + 0.5
		var on_stairs: bool = enemies.is_empty() and dungeon.is_near_stairs(p.global_position)
		var want_e := (on_item or on_stairs) and frame % 6 == 0
		if want_e and on_item and not Input.is_action_pressed("interact"):
			items_picked += 1
			print("  bot equips: %s" % item_node.item["name"])
		_send_action("interact", want_e)
		# Подобранное в сумку — надеть, если лучше.
		if frame % 30 == 0:
			for bi in Run.bag.size():
				var bit: Dictionary = Run.bag[bi]
				if Run.equip_block_reason(bit) == "" and _gear_score(Run.derived_with(bit)) > _gear_score(Run.derived()) + 0.5:
					print("  bot equips from bag: %s" % bit["name"])
					p.inv("equip", bi)
					break

		if frame % 300 == 0:
			print("  status f=%d t=%.0fs depth=%d enemies=%d hp=%d time_scale=%.2f paused=%s pos=%s goal=%s" % [
				frame, Time.get_ticks_msec() / 1000.0, Run.depth, enemies.size(), p.hp, Engine.time_scale,
				get_tree().paused, p.global_position.round(), goal.round()])
		if frame == 1500:  # снимок большой карты этажа
			var hud := get_tree().current_scene.get_node_or_null("HUD")
			if hud:
				hud.toggle_map()
				for i in 3:
					await get_tree().process_frame
				_shot("map_big")
				hud.toggle_map()
		if frame % 480 == 0 and shot_i < 14:
			_shot("%02d_play" % shot_i)
			shot_i += 1

	_set_move(Vector2.ZERO)
	_send_action("attack", false)
	_send_action("interact", false)
	await _frames(30)
	_shot("99_end")
	var pl: Node = get_tree().get_first_node_in_group("player")
	var eq: PackedStringArray = []
	for slot: String in Run.equipment:
		eq.append("%s=%s" % [slot, Run.equipment[slot]["name"] if Run.equipment[slot] else "-"])
	print("AUTOTEST RESULT: class=%s depth=%d level=%d hp=%d/%d dead=%s gold=%d items_equipped=%d skills_tried=%d seconds=%.1f" % [
		Run.cls, Run.depth, Run.level, pl.hp, pl.max_hp, pl.dead, Run.gold, items_picked, skills_tried, frame / 60.0])
	print("  stats: %s  skills: %s" % [Run.stats, Run.skill_levels])
	print("  equipment: " + ", ".join(eq))
	get_tree().quit()


## Грубая «ценность» характеристик для бота: урон в секунду с критами + немного за HP и SP.
func _gear_score(d: Dictionary) -> float:
	var avg: float = (d["atk_min"] + d["atk_max"]) / 2.0
	var dps: float = avg * (1.0 + d["aspd"] / 100.0) * (1.0 + d["crit"] / 100.0)
	return dps + d["max_hp"] * 0.1 + d["max_sp"] * 0.05 + d["speed"] * 0.2


func _send_action(action: String, pressed: bool) -> void:
	if Input.is_action_pressed(action) == pressed:
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _set_move(v: Vector2) -> void:
	_axis("move_left", "move_right", v.x)
	_axis("move_up", "move_down", v.y)


func _axis(neg: String, pos: String, value: float) -> void:
	Input.action_release(neg)
	Input.action_release(pos)
	if value > 0.05:
		Input.action_press(pos, value)
	elif value < -0.05:
		Input.action_press(neg, -value)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img.get_width() < 640:
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://shots/%s.png" % shot_name))
	print("shot %s  depth=%d level=%d enemies=%d" % [shot_name, Run.depth, Run.level, get_tree().get_nodes_in_group("enemies").size()])


# --- Тест кооператива: два окна, локальный сигнальный сервер ---
# node tools/signal_server.js 9000
# хозяин: godot --path . -- --cooptest --nethost --key=TEST01 --signal=ws://127.0.0.1:9000/peerjs --class=warrior
# гость:  godot --path . -- --cooptest --netjoin=TEST01 --signal=ws://127.0.0.1:9000/peerjs --class=archer

func _arg(prefix: String, def := "") -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix + "="):
			return a.get_slice("=", 1)
	return def


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## Ждёт условие не дольше limit секунд. Возвращает, выполнилось ли.
func _wait_for(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while not cond.call():
		await _wait(0.1)
		t += 0.1
		if t > limit:
			return false
	return true


func _scene_name() -> String:
	var s := get_tree().current_scene
	return String(s.name) if s else ""


func _cooptest() -> void:
	var cls := _arg("--class", "warrior")
	if "--nethost" in OS.get_cmdline_user_args():
		await _cooptest_host(cls)
	else:
		await _cooptest_guest(cls)
	get_tree().quit()


func _cooptest_host(cls: String) -> void:
	await _wait(0.5)
	Net.host_game(_arg("--key", "TEST01"))
	var ok: bool = await _wait_for(func() -> bool: return Net.player_count() >= 2, 40.0)
	print("COOP host: guest connected=%s status=%s" % [ok, Net.status])
	if not ok:
		return
	ok = await _wait_for(func() -> bool: return Net.hero_of(2) != null, 15.0)
	print("COOP host: guest hero in camp=%s" % ok)
	await _wait(1.5)
	_shot("coop_host_1_camp")
	Net.players[1]["cls"] = cls
	Net.players[1]["ready"] = true
	coop_try_start()
	ok = await _wait_for(func() -> bool: return _scene_name() == "Main" and Net._ready_peers.has(2), 20.0)
	print("COOP host: dungeon with guest=%s" % ok)
	await _wait(1.0)
	var guest := Net.hero_of(2)
	var me := local_hero()
	print("COOP host: heroes=%d guest_class=%s guest_hp=%d enemies=%d" % [
		get_tree().get_nodes_in_group("player").size(), guest.st.cls, guest.hp, get_tree().get_nodes_in_group("enemies").size()])
	# Монстры рядом — посмотреть бой у обоих.
	var slime: PackedScene = load("res://scenes/slime.tscn")
	for i in 3:
		var s: Node2D = slime.instantiate()
		s.position = me.global_position + Vector2(40 + i * 12, -10 + i * 10)
		get_tree().current_scene.get_node("Entities").add_child(s)
	_send_action("attack", true)
	await _wait(4.0)
	_send_action("attack", false)
	_shot("coop_host_2_fight")
	print("COOP host: guest pos=%s guest_hp=%d guest_xp=%d host_xp=%d team_gold=%d" % [guest.global_position, guest.hp, guest.st.xp, Run.xp, Run.gold])
	await _wait(3.0)
	print("COOP host: guest dealt damage? enemies left=%d guest_lvl=%d" % [get_tree().get_nodes_in_group("enemies").size(), guest.st.level])
	# Гость падает: игра продолжается, он смотрит за хозяином.
	guest.take_damage(99999, guest.global_position + Vector2(5, 0))
	await _wait(2.0)
	print("COOP host: guest dead=%s all_dead=%s" % [guest.dead, all_dead()])
	_shot("coop_host_3_guest_dead")
	next_floor()
	ok = await _wait_for(func() -> bool: return _scene_name() == "Main" and Net._ready_peers.has(2) and Net.hero_of(2) != null, 20.0)
	await _wait(1.5)
	guest = Net.hero_of(2)
	print("COOP host: floor %d, guest revived=%s hp=%d/%d" % [Run.depth, guest != null and not guest.dead, guest.hp if guest else -1, guest.max_hp if guest else -1])
	_shot("coop_host_4_floor2")
	# Все пали — в лагерь.
	for h in get_tree().get_nodes_in_group("player"):
		h.take_damage(99999, h.global_position + Vector2(5, 0))
	await _wait(1.0)
	coop_restart()
	ok = await _wait_for(func() -> bool: return _scene_name() == "Camp" and Net._ready_peers.has(2), 20.0)
	await _wait(1.5)
	print("COOP host: back in camp=%s heroes=%s" % [ok, get_tree().get_nodes_in_group("player").map(func(h: Node) -> String: return "%s(peer %d)" % [h.name, h.peer_id])])
	_shot("coop_host_5_camp")
	await _wait(2.0)


func _cooptest_guest(cls: String) -> void:
	await _wait(2.0)
	Net.join_game(_arg("--netjoin", "TEST01"))
	var ok: bool = await _wait_for(func() -> bool: return Net._peer_open(1) and Net.hero_of(Net.my_id()) != null and _scene_name() == "Camp", 40.0)
	print("COOP guest: in host camp=%s id=%d status=%s gold_shown=%d" % [ok, Net.my_id(), Net.status, Meta.gold])
	if not ok:
		return
	await _wait(1.0)
	_shot("coop_guest_1_camp")
	Net.send_to(1, "class", cls)
	ok = await _wait_for(func() -> bool: return _scene_name() == "Main" and Net.hero_of(Net.my_id()) != null, 25.0)
	await _wait(1.0)
	var me := local_hero()
	print("COOP guest: dungeon=%s class=%s hp=%d heroes=%d enemies=%d" % [ok, Run.cls, me.hp if me else -1,
		get_tree().get_nodes_in_group("player").size(), get_tree().get_nodes_in_group("enemies").size()])
	var cam := get_viewport().get_camera_2d()
	print("COOP guest: camera of %s (peer %s), me=%s at %s, cam at %s" % [cam.get_parent().name if cam else "-", cam.get_parent().get("peer_id") if cam else "-", me.name if me else "-", me.global_position if me else Vector2.ZERO, cam.get_screen_center_position() if cam else Vector2.ZERO])
	var start: Vector2 = me.global_position if me else Vector2.ZERO
	_set_move(Vector2(1, 0))
	await _wait(1.0)
	_set_move(Vector2.ZERO)
	me = local_hero()
	print("COOP guest: moved %.1f px" % (me.global_position.distance_to(start) if me else -1.0))
	_send_action("attack", true)
	await _wait(3.0)
	_send_action("attack", false)
	_shot("coop_guest_2_fight")
	print("COOP guest: xp=%d level=%d gold=%d" % [Run.xp, Run.level, Run.gold])
	ok = await _wait_for(func() -> bool: return local_hero() != null and local_hero().dead, 20.0)
	await _wait(0.5)
	print("COOP guest: saw own death=%s" % ok)
	_shot("coop_guest_3_dead")
	var depth0 := Run.depth
	ok = await _wait_for(func() -> bool: return Run.depth > depth0 and _scene_name() == "Main" and local_hero() != null and not local_hero().dead, 25.0)
	await _wait(1.0)
	print("COOP guest: next floor=%s depth=%d hp=%d" % [ok, Run.depth, local_hero().hp if local_hero() else -1])
	_shot("coop_guest_4_floor2")
	ok = await _wait_for(func() -> bool: return _scene_name() == "Camp" and local_hero() != null, 30.0)
	await _wait(1.0)
	print("COOP guest: back in camp=%s" % ok)
	_shot("coop_guest_5_camp")
	await _wait(4.0)  # хозяин ещё проверяет лагерь


# --- Тест сохранения героя: `godot --path . -- --herotest` ---
func _herotest() -> void:
	await _wait(1.0)
	Meta.heroes = {}
	Meta.hero_cls = ""
	Meta.levels = {}
	start_run("thief")
	await _wait_for(func() -> bool: return _scene_name() == "Main", 10.0)
	await _wait(0.5)
	print("HERO new: saved=%s cls=%s level=%d" % [Meta.heroes.has("thief"), Meta.hero_cls, Run.level])
	Run.add_xp(400)
	Run.depth = 5
	checkpoint(5)
	var h: Dictionary = Meta.current_hero()
	print("HERO checkpoint: level=%d checkpoint=%d best=%d (run level %d)" % [h["level"], h["checkpoint"], h["best"], Run.level])
	Run.add_xp(3000)
	Run.depth = 7
	var lvl_before_death := Run.level
	return_to_camp(false)
	await _wait_for(func() -> bool: return _scene_name() == "Camp", 10.0)
	h = Meta.current_hero()
	print("HERO after death on 7 (was level %d): saved level=%d best=%d checkpoint=%d" % [lvl_before_death, h["level"], h["best"], h["checkpoint"]])
	print("HERO class change, training 0: '%s'" % Meta.class_change_reason())
	Meta.levels["training"] = 3
	print("HERO class change, training 3: '%s'" % Meta.class_change_reason())
	start_run("thief", [], 5)
	await _wait_for(func() -> bool: return _scene_name() == "Main", 10.0)
	await _wait(0.5)
	print("HERO start from 5: depth=%d level=%d cls=%s points=%d" % [Run.depth, Run.level, Run.cls, Run.points])
	_shot("hero_start5")
	Meta.change_class("acolyte")
	print("HERO changed to %s, hero exists=%s" % [Meta.hero_cls, Meta.current_hero().has("cls")])
	get_tree().quit()


# --- «Зоопарк»: каждый новый монстр и босс рядом с героем (`--zootest --god`) ---
func _zootest() -> void:
	await _wait(1.5)
	var p: Node2D = local_hero()
	p.god = true
	var scenes := ["frost_wisp", "ice_slime", "toad", "lurker", "shade", "necromancer", "demon", "horror"]
	for n: String in scenes:
		var e: Node2D = (load("res://scenes/%s.tscn" % n) as PackedScene).instantiate()
		e.position = p.position + Vector2(50, 0).rotated(randf() * TAU)
		get_tree().current_scene.get_node("Entities").add_child(e)
		await _wait(2.5)
		print("ZOO %s hp=%d/%d alive=%s" % [n, e.hp if is_instance_valid(e) else -1, e.max_hp if is_instance_valid(e) else -1, is_instance_valid(e)])
		_shot("zoo_%s" % n)
		if is_instance_valid(e):
			e.queue_free()
	for n: String in ["ice_queen", "swamp_queen", "shadow_reaper", "abyss_prince", "abyss_lord"]:
		var b: Node2D = (load("res://scenes/%s.tscn" % n) as PackedScene).instantiate()
		b.position = p.position + Vector2(70, 0)
		b.arena = Rect2(p.position - Vector2(200, 150), Vector2(400, 300))
		get_tree().current_scene.get_node("Entities").add_child(b)
		await _wait(0.5)
		b.take_damage(1, p.position)  # разбудить
		await _wait(5.0)
		print("ZOO %s name=%s hp=%d/%d phase=%d" % [n, b.BOSS_NAME, b.hp, b.max_hp, b.phase])
		_shot("zoo_%s" % n)
		b.take_damage(b.hp + 99999, p.position, true, false)
		await _wait(1.5)
	print("ZOO pickups=%d" % get_tree().get_nodes_in_group("pickups").size())
	get_tree().quit()


# --- Сохранения-файлы (`--savetest`): своя папка user://savetest/ ---
func _savetest() -> void:
	await _wait(1.0)
	var id := Meta.new_slot("solo")
	Meta.new_slot("solo")
	Meta.gold = 340
	Meta.save_game()
	Meta.load_slot(id)
	var camp_hud := get_tree().current_scene.get_node_or_null("CampHUD")
	if camp_hud:
		camp_hud.open_building("menu")
		await _wait(0.4)
		_shot("save_menu")
		camp_hud._slot_kind = "solo"
		camp_hud.open_building("slots")
		await _wait(0.4)
		_shot("save_slots")
		camp_hud.close()
	start_run("warrior")
	await _wait_for(func() -> bool: return _scene_name() == "Main", 10.0)
	await _wait(1.0)
	Run.gold = 77
	Run.add_material("gel", 3)
	Run.bag_add(preload("res://scripts/items.gd").make("chain", 1, 2))
	Run.add_xp(300)
	next_floor()
	await _wait(1.5)
	var lvl := Run.level
	local_hero().hp = 42
	save_run()
	print("SAVE run in file: depth=%d players=%s" % [int(Meta.run_save.get("depth", 0)), Meta.run_save.get("players", {}).keys()])
	# «Вышли из игры и зашли снова»: всё забыто, читаем файл.
	Run.reset()
	Meta.load_slot(id)
	print("SAVE slots: %s" % [Meta.list_slots().map(func(s: Dictionary) -> String: return "%s %s run=%d" % [s["id"], s["kind"], s["run_depth"]])])
	continue_run()
	await _wait_for(func() -> bool: return _scene_name() == "Main" and local_hero() != null, 10.0)
	await _wait(1.0)
	var ok: bool = Run.depth == 2 and Run.gold == 77 and Run.bag.size() == 1 and Run.level == lvl and local_hero().hp == 42 and int(Run.materials.get("gel", 0)) == 3
	print("SAVE continued: depth=%d gold=%d bag=%d level=%d(was %d) hp=%d slime=%d -> %s" % [Run.depth, Run.gold, Run.bag.size(), Run.level, lvl, local_hero().hp, int(Run.materials.get("gel", 0)), "OK" if ok else "FAIL"])
	_shot("save_continued")
	pause_menu.open()
	await _wait(0.4)
	_shot("save_pause")
	pause_menu.close()
	await _wait(0.2)
	# Гибель — сохранённый забег пропадает.
	local_hero().take_damage(99999, local_hero().global_position + Vector2(5, 0))
	await _wait(0.5)
	_shot("save_dead")
	Meta.load_slot(id)
	print("SAVE after death: run in file=%s" % (not Meta.run_save.is_empty()))
	var id2 := Meta.new_slot("coop")
	print("SAVE two slots: %d, kinds %s" % [Meta.list_slots().size(), Meta.list_slots().map(func(s: Dictionary) -> String: return s["kind"])])
	Meta.delete_slot(id2)
	print("SAVE after delete: %d" % Meta.list_slots().size())
	get_tree().quit()


# --- Кооп: сохранить забег с гостем и продолжить (`--coopsave --phase=1|2`, хозяин ещё с `--savetest`) ---
func _coopsavetest() -> void:
	var phase := int(_arg("--phase", "1"))
	var key := _arg("--key", "SAVE0%d" % phase)
	if "--nethost" in OS.get_cmdline_user_args():
		await _wait(0.5)
		if phase == 1:
			Meta.new_slot("coop")
		else:
			Meta.load_slot("save1")
			print("CSAVE host: run in file depth=%d players=%s" % [int(Meta.run_save.get("depth", 0)), Meta.run_save.get("players", {}).keys()])
		Net.host_game(key)
		var ok: bool = await _wait_for(func() -> bool: return Net.player_count() >= 2 and str(Net.players.get(2, {}).get("uid", "")) != "", 40.0)
		print("CSAVE host: guest connected=%s uid=%s" % [ok, Net.players.get(2, {}).get("uid", "")])
		if not ok:
			get_tree().quit()
			return
		if phase == 1:
			Net.players[1]["cls"] = "warrior"
			Net.players[1]["ready"] = true
			coop_try_start()
			await _wait_for(func() -> bool: return _scene_name() == "Main" and Net.hero_of(2) != null, 20.0)
			await _wait(1.0)
			Net.hero_of(2).st.add_xp(600)
			Run.gold = 55
			next_floor()
			await _wait_for(func() -> bool: return _scene_name() == "Main" and Net.hero_of(2) != null, 20.0)
			await _wait(1.0)
			save_run()
			print("CSAVE host: saved depth=%d guest level=%d players=%s" % [Run.depth, Net.hero_of(2).st.level, Meta.run_save["players"].keys()])
		else:
			print("CSAVE host: names %s" % run_save_names())
			continue_run()
			ok = await _wait_for(func() -> bool: return _scene_name() == "Main" and Net.hero_of(2) != null, 20.0)
			await _wait(1.0)
			var g := Net.hero_of(2)
			print("CSAVE host: continued=%s depth=%d gold=%d guest cls=%s level=%d" % [ok, Run.depth, Run.gold, g.st.cls if g else "-", g.st.level if g else -1])
			_shot("csave_host")
		await _wait(2.0)
		get_tree().quit()
		return
	# Гость
	await _wait(2.0)
	Net.join_game(key)
	await _wait_for(func() -> bool: return Net._peer_open(1) and _scene_name() == "Camp", 40.0)
	if phase == 1:
		await _wait(1.0)
		Net.send_to(1, "class", {"cls": "archer", "hero": {}})
	var ok2: bool = await _wait_for(func() -> bool: return _scene_name() == "Main" and Net.hero_of(Net.my_id()) != null, 40.0)
	await _wait(0.8)
	print("CSAVE guest: in dungeon=%s scene=%s depth=%d cls=%s level=%d net=%s" % [ok2, _scene_name(), Run.depth, Run.cls, Run.level, Net.status])
	await _wait_for(func() -> bool: return not Net.active(), 30.0)
	get_tree().quit()
