extends CanvasLayer
## Интерфейс: HP/SP, уровень и опыт, этаж и золото, панель навыков (1–3),
## подсказка предмета под ногами, окна характеристик (C) и навыков (K),
## выбор класса в начале забега, полоса босса и сообщения.
## Все размеры — в базовых пикселях 320x180.

const Items := preload("res://scripts/items.gd")
const Crafting := preload("res://scripts/crafting.gd")
const Skills := preload("res://scripts/skills.gd")
const DUNGEON := preload("res://scripts/dungeon.gd")
const MINIMAP := preload("res://scripts/minimap.gd")

var _minimap: Control


## M — развернуть/свернуть карту этажа.
func toggle_map() -> void:
	if _minimap:
		_minimap.toggle()
const GOOD := Color(0.45, 0.95, 0.45)
const BAD := Color(1.0, 0.4, 0.4)
const GOLD := Color(1.0, 0.85, 0.3)
const SP_COLOR := Color(0.45, 0.65, 1.0)
const DIM := Color(0.66, 0.63, 0.72)

var _player: Node
var _hp: Label
var _sp: Label
var _level: Label
var _xp_bar: ProgressBar
var _points_hint: Label
var _info: Label
var _message: Label
var _banner: Label
var _skill_bar: Control
var _tooltip: PanelContainer
var _tooltip_text: RichTextLabel
var _had_enemies := false
var _cleared_shown := false
var _banner_time := 2.0

var open_panel := ""  # "", "stats", "skills", "class"
var stats_open: bool:
	get:
		return open_panel != ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hp = _label(8)
	_hp.position = Vector2(4, 1)
	add_child(_hp)
	_sp = _label(6)
	_sp.position = Vector2(4, 11)
	_sp.add_theme_color_override("font_color", SP_COLOR)
	add_child(_sp)
	_level = _label(5)
	_level.position = Vector2(4, 19)
	add_child(_level)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(4, 27)
	_xp_bar.size = Vector2(60, 2)
	_xp_bar.add_theme_stylebox_override("background", _box(Color(0.1, 0.08, 0.14, 0.9), 0))
	_xp_bar.add_theme_stylebox_override("fill", _box(Color(0.5, 0.75, 1.0), 0))
	add_child(_xp_bar)
	_points_hint = _label(5)
	_points_hint.position = Vector2(4, 30)
	_points_hint.add_theme_color_override("font_color", GOLD)
	add_child(_points_hint)

	_info = _label(5)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.position = Vector2(196, 2)
	_info.size = Vector2(120, 16)
	_info.add_theme_constant_override("line_spacing", -2)
	add_child(_info)

	_message = _label(12)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_message)

	_banner = _label(10)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, 36)
	_banner.size = Vector2(320, 20)
	var biome: String = DUNGEON.pool_for(Run.depth)["name"]
	_banner.text = "Этаж %d%s%s" % [Run.depth, (" — " + biome) if biome != "" else "", " — логово босса" if Run.depth % 3 == 0 else ""]
	if Run.depth % 3 == 0:
		_banner.text += "\nРядом портал: можно уйти в лагерь с добычей"
		_banner_time = 4.0
	add_child(_banner)

	_skill_bar = Control.new()
	_skill_bar.position = Vector2(4, 156)
	_skill_bar.size = Vector2(90, 20)
	_skill_bar.draw.connect(_draw_skill_bar)
	add_child(_skill_bar)

	# Миникарта — раньше окон, чтобы окна рисовались поверх неё.
	_minimap = MINIMAP.new()
	add_child(_minimap)
	_build_tooltip()
	_build_boss_bar()
	_build_stats_panel()
	_build_skills_panel()
	_build_class_panel()
	_build_anvil_panel()
	_build_inv_panel()
	_prompt = _label(6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(0, 144)
	_prompt.size = Vector2(320, 10)
	_prompt.add_theme_color_override("font_color", GOLD)
	add_child(_prompt)
	Run.changed.connect(_refresh_panels)
	Run.leveled_up.connect(func(_l: int) -> void:
		if Run.job_pending():
			_open_job_panel.call_deferred())
	if Run.cls == "":
		_open("class")
	elif Run.job_pending():
		_open_job_panel.call_deferred()


# ---------------- Выбор профессии (уровень Skills.JOB_LEVEL) ----------------

func _open_job_panel() -> void:
	if not Run.job_pending() or open_panel == "job":
		return
	var panel: PanelContainer = _panels.get("job")
	if panel == null:
		panel = _panel()
		_panels["job"] = panel
	for c in panel.get_children():
		panel.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var title := _label(9)
	title.text = "Выбери профессию — %s достиг %d уровня" % [Run.class_data()["name"], Run.level]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var hint := _rich(250)
	hint.text = "[color=#a8a0b8]Очки навыков вернутся — распредели их заново по навыкам профессии (K).[/color]"
	v.add_child(hint)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var n := 0
	for job: String in Run.class_data()["jobs"]:
		n += 1
		var j: Dictionary = Skills.JOBS[job]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color(0.12, 0.1, 0.18), 1))
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var t := _rich(118)
		var txt := "[b]%s[/b]\n%s\n\n[b]Навыки:[/b]\n" % [j["name"], j["desc"]]
		for id: String in j["skills"]:
			var s: Dictionary = Skills.SKILLS[id]
			txt += "• %s%s\n" % [s["name"], " (пассивный)" if s["type"] == "passive" else ""]
		t.text = txt
		cv.add_child(t)
		var btn := Button.new()
		btn.text = "Стать: %s (%d)" % [j["name"], n]
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 6)
		btn.pressed.connect(func() -> void: _choose_job(job), CONNECT_DEFERRED)
		cv.add_child(btn)
		h.add_child(card)
	_open("job")
	_center(panel)
	_center.call_deferred(panel)


func _choose_job(job: String) -> void:
	Run.set_job(job)
	_open("")
	show_banner("Профессия: %s — распредели очки навыков (K)" % Skills.JOBS[job]["name"], 3.0)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	return l


func _box(color: Color, border: int, border_color := Color(0.5, 0.45, 0.6)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_border_width_all(border)
	b.border_color = border_color
	b.set_content_margin_all(4)
	return b


func _rich(width: float) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.custom_minimum_size = Vector2(width, 0)
	t.add_theme_font_size_override("normal_font_size", 5)
	t.add_theme_font_size_override("bold_font_size", 6)
	t.add_theme_constant_override("line_separation", -1)
	return t


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.12, 0.96), 1))
	p.visible = false
	add_child(p)
	return p


func _small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 5)
	btn.custom_minimum_size = Vector2(9, 8)
	return btn


func _center(p: Control) -> void:
	p.reset_size()
	p.position = ((Vector2(320, 180) - p.size) / 2.0).round()


# ---------------- Каждый кадр ----------------

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = Game.local_hero()
	if _player == null:
		return

	_hp.text = "HP %d/%d" % [_player.hp, _player.max_hp]
	_hp.add_theme_color_override("font_color", BAD if _player.hp < _player.max_hp * 0.3 else Color.WHITE)
	_sp.text = "SP %d/%d" % [int(_player.sp), _player.max_sp]
	_level.text = "%s, уровень %d   опыт %d/%d" % [Run.title(), Run.level, Run.xp, Run.xp_to_next()]
	_xp_bar.max_value = Run.xp_to_next()
	_xp_bar.value = Run.xp
	var hints: PackedStringArray = []
	if Run.points > 0:
		hints.append("Очки характеристик: %d — C" % Run.points)
	if Run.skill_points > 0:
		hints.append("Очки навыков: %d — K" % Run.skill_points)
	_points_hint.text = "\n".join(hints)
	_info.text = "Этаж %d\nЗолото %d\nМатериалы %d" % [Run.depth, Run.gold, Crafting.common_count(Run.materials)]
	_skill_bar.queue_redraw()

	_banner_time -= delta
	_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)

	var enemies := get_tree().get_nodes_in_group("enemies").size()
	if enemies > 0:
		_had_enemies = true
	if _player.dead and Net.active() and not Game.all_dead():
		_message.text = "Ты пал. Возродишься на следующем этаже,\nесли напарники спустятся по лестнице"
	elif _player.dead and Net.active():
		_message.text = "Пали все. Добыча забега потеряна\nR — вернуться в лагерь"
	elif _player.dead:
		var cp_text := ("Герой вернётся к сохранению на %d этаже" % Run.checkpoint) if Run.checkpoint > 0 else "Герой вернётся к тому, каким был в начале забега"
		_message.text = "Вы погибли на %d этаже (уровень %d)\nПотеряно: %d золота, материалы и снаряжение. %s\nR — вернуться в лагерь" % [Run.depth, Run.level, Run.gold, cp_text]
	elif _had_enemies and enemies == 0 and not _cleared_shown and not get_tree().current_scene.get("is_boss_floor"):
		_cleared_shown = true
		_message.text = ""
		show_banner("Этаж зачищен — ищи лестницу вниз", 3.0)
	else:
		_message.text = ""

	_update_tooltip()
	_update_boss_bar()
	_update_stairs_arrow(enemies)
	var thing: Node2D = null if (_player.dead or stats_open) else _player.nearest_interactable()
	_prompt.text = thing.prompt() if thing else ""


func show_banner(text: String, time: float) -> void:
	_banner.text = text
	_banner_time = time


# ---------------- Панель навыков внизу ----------------

func _draw_skill_bar() -> void:
	if _player == null or Run.cls == "":
		return
	var font := ThemeDB.fallback_font
	var ids := Skills.actives_of(Run.skill_list())
	for i in ids.size():
		var id: String = ids[i]
		var lvl := Run.skill_level(id)
		var r := Rect2(i * 22, 0, 20, 20)
		_skill_bar.draw_rect(r, Color(0.08, 0.06, 0.12, 0.85))
		var cd: float = _player.skill_cd.get(id, 0.0)
		var total: float = Skills.SKILLS[id]["cd"]
		if lvl > 0 and cd > 0.0:
			var k := clampf(cd / total, 0.0, 1.0)
			_skill_bar.draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - k)), Vector2(r.size.x, r.size.y * k)), Color(0, 0, 0, 0.6))
		var ok: bool = lvl > 0 and _player.sp >= Skills.sp_cost(id, lvl)
		var border := Color(0.5, 0.45, 0.6) if lvl == 0 else (Color(0.8, 0.75, 0.9) if ok else SP_COLOR.darkened(0.3))
		_skill_bar.draw_rect(r, border, false, 1.0)
		var text_c := Color.WHITE if lvl > 0 else Color(0.5, 0.48, 0.55)
		_skill_bar.draw_string(font, r.position + Vector2(2, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, GOLD)
		_skill_bar.draw_string(font, r.position + Vector2(1, 13), Skills.SKILLS[id]["abbr"], HORIZONTAL_ALIGNMENT_CENTER, 18, 5, text_c)
		if lvl > 0:
			_skill_bar.draw_string(font, r.position + Vector2(1, 19), "%d" % Skills.sp_cost(id, lvl), HORIZONTAL_ALIGNMENT_RIGHT, 18, 4, SP_COLOR)


# ---------------- Подсказка предмета ----------------

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.12, 0.92), 1))
	_tooltip_text = _rich(100)
	_tooltip.add_child(_tooltip_text)
	_tooltip.visible = false
	add_child(_tooltip)


func _update_tooltip() -> void:
	var map_open: bool = _minimap != null and _minimap.big
	var node: Node2D = null if (_player.dead or stats_open or map_open) else _player.nearest_item()
	if node == null:
		_tooltip.visible = false
		return
	var item: Dictionary = node.item
	var t := "[b][color=#%s]%s[/color][/b]\n" % [Items.color(item).to_html(false), Items.display_name(item)]
	var kind: String = Items.SLOT_NAMES[item["slot"]]
	if Items.is_two_hand(item):
		kind += " (двуручное)"
	t += "[color=#a8a0b8]%s, %s[/color]\n" % [kind, Items.RARITY[item["rarity"]]["name"]]
	t += item_stats_text(item)
	if item.has("set"):
		t += "\n" + set_text(item["set"], Run.equipment)
	var reason := Run.equip_block_reason(item)
	if reason != "":
		t += "\n[color=#%s]Нельзя надеть: %s[/color]" % [BAD.to_html(false), reason]
		t += "\n[color=#%s]E — в сумку[/color]" % GOLD.to_html(false)
	else:
		t += "\n" + _compare_text(item)
		var free: bool = Run.equipment[item["slot"]] == null
		t += "\n[color=#%s]%s[/color]" % [GOLD.to_html(false), "E — надеть" if free else "E — в сумку (надеть — в инвентаре, I)"]
	_tooltip_text.text = t
	_tooltip.visible = true
	_tooltip.reset_size()
	_tooltip.position = Vector2((320 - _tooltip.size.x) / 2.0, 180 - _tooltip.size.y - 4)


## Свойства предмета строками (с заточкой).
static func item_stats_text(item: Dictionary) -> String:
	var s: Dictionary = Crafting.effective_stats(item)
	var lines: PackedStringArray = []
	if s.has("atk_min"):
		lines.append("Урон %d–%d" % [s["atk_min"], s["atk_max"]])
	for k: String in s:
		if k == "atk_min" or k == "atk_max":
			continue
		var line := Items.stat_text(k, s[k])
		if k in Items.SPECIAL:
			line = "[color=#e8a0ff]%s[/color]" % line  # особые свойства — сиреневым
		lines.append(line)
	return "\n".join(lines)


## Описание комплекта: сколько частей надето и какие бонусы.
static func set_text(set_id: String, equip_set: Dictionary) -> String:
	var sd: Dictionary = Items.SETS[set_id]
	var have: int = Run.set_counts(equip_set).get(set_id, 0)
	var t: String = "[color=#66f080]Комплект «%s» (%d/%d)[/color]" % [sd["name"], have, sd["pieces"].size()]
	for need: int in sd["bonus"]:
		var parts: PackedStringArray = []
		for k: String in sd["bonus"][need]:
			parts.append(Items.stat_text(k, sd["bonus"][need][k]))
		var col := "66f080" if have >= need else "777080"
		t += "\n[color=#%s]%d: %s[/color]" % [col, need, ", ".join(parts)]
	return t


## Что изменится в характеристиках героя, если надеть предмет.
func _compare_text(item: Dictionary) -> String:
	var now := Run.derived()
	var then := Run.derived_with(item)
	var lines: PackedStringArray = []
	var avg_now: float = (now["atk_min"] + now["atk_max"]) / 2.0
	var avg_then: float = (then["atk_min"] + then["atk_max"]) / 2.0
	if avg_now != avg_then:
		lines.append(_diff_line("Урон", "%d–%d" % [now["atk_min"], now["atk_max"]], "%d–%d" % [then["atk_min"], then["atk_max"]], avg_then > avg_now))
	for spec in [["max_hp", "HP", ""], ["max_sp", "SP", ""], ["crit", "Крит", "%"], ["aspd", "Скор. атаки", "%"],
			["speed", "Скор. бега", "%"], ["dr", "Защита", "%"], ["eva", "Уклонение", "%"], ["cast", "Скор. каста", "%"],
			["lifesteal", "Вампиризм", "%"], ["burn", "Поджог", "%"], ["thorns", "Шипы", "%"], ["stun", "Оглушение", "%"],
			["boss", "Урон боссам", "%"], ["pierce", "Пробивание", ""]]:
		var k: String = spec[0]
		if not is_equal_approx(float(now[k]), float(then[k])):
			lines.append(_diff_line(spec[1], "%d%s" % [now[k], spec[2]], "%d%s" % [then[k], spec[2]], then[k] > now[k]))
	if Items.is_two_hand(item) and Run.equipment["offhand"] != null:
		lines.append("[color=#%s]Снимет: %s[/color]" % [BAD.to_html(false), Items.display_name(Run.equipment["offhand"])])
	if lines.is_empty():
		return "[color=#a8a0b8]Характеристики не изменятся[/color]"
	return "[color=#a8a0b8]Если надеть:[/color]\n" + "\n".join(lines)


func _diff_line(title: String, a: String, b: String, better: bool) -> String:
	return "%s: %s → [color=#%s]%s[/color]" % [title, a, (GOOD if better else BAD).to_html(false), b]


# ---------------- Окна: общее ----------------

var _panels := {}


func toggle_panel(which: String) -> void:
	if open_panel in ["class", "job"]:
		return  # класс и профессию нужно выбрать обязательно
	_open("" if open_panel == which else which)


func toggle_stats() -> void:
	toggle_panel("stats")


func _open(which: String) -> void:
	open_panel = which
	for k: String in _panels:
		_panels[k].visible = k == which
	_anvil_result = ""
	_refresh_panels()
	if which != "":
		get_tree().paused = not Net.active()  # в коопе игра не останавливается
	else:
		# Снимаем паузу в конце кадра — иначе то же нажатие E сразу откроет окно снова.
		get_tree().set_deferred("paused", false)


func _refresh_panels() -> void:
	if _panels.is_empty():
		return
	_refresh_stats_panel()
	_refresh_skills_panel()
	if _panels.has("anvil"):
		_refresh_anvil_panel()
	if _panels.has("inv"):
		_refresh_inv_panel()


# ---------------- Наковальня (заточка в подземелье) ----------------

var _prompt: Label
var _anvil_box: VBoxContainer
var _anvil_result := ""


func _build_anvil_panel() -> void:
	var panel := _panel()
	_panels["anvil"] = panel
	_anvil_box = VBoxContainer.new()
	_anvil_box.add_theme_constant_override("separation", 3)
	panel.add_child(_anvil_box)


func _refresh_anvil_panel() -> void:
	if open_panel != "anvil":
		return
	for c in _anvil_box.get_children():
		_anvil_box.remove_child(c)
		c.queue_free()
	var bonus: float = Run.derived()["craft"]
	var head := _rich(220)
	head.text = "[b]Наковальня — заточка[/b]\nЗолото %d   Материалы %d   Бонус Удачи [color=#%s]+%d%%[/color] к шансу\n[color=#a8a0b8]Каждый уровень +10%% к свойствам предмета. До +4 — без риска; неудача снимает 1 уровень.[/color]" % [
		Run.gold, Crafting.common_count(Run.materials), GOOD.to_html(false), int(bonus)]
	_anvil_box.add_child(head)
	var n := 0
	for slot: String in Items.SLOTS:
		var item: Variant = Run.equipment[slot]
		if item == null:
			continue
		n += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var cost := Crafting.refine_cost(item)
		var can := Crafting.can_pay_refine(item, Run.gold, Run.materials)
		var btn := _small_button("%d" % n)
		btn.custom_minimum_size = Vector2(14, 8)
		btn.disabled = not can
		btn.pressed.connect(func() -> void: _do_refine(item, bonus), CONNECT_DEFERRED)
		row.add_child(btn)
		var t := _rich(200)
		if Crafting.refine_level(item) >= Crafting.REFINE_MAX:
			t.text = "[color=#%s]%s[/color] — максимум" % [Items.color(item).to_html(false), Items.display_name(item)]
		else:
			t.text = "[color=#%s]%s[/color] → +%d   шанс [b]%d%%[/b]   цена: %d зол. и %d материалов" % [
				Items.color(item).to_html(false), Items.display_name(item), Crafting.refine_level(item) + 1,
				Crafting.refine_chance(item, bonus), cost["gold"], cost["mats"]]
		row.add_child(t)
		_anvil_box.add_child(row)
	if _anvil_result != "":
		var r := _rich(220)
		r.text = _anvil_result
		_anvil_box.add_child(r)
	var hint := _label(4)
	hint.text = "Клавиши 1–3 или кнопки   E — закрыть"
	hint.add_theme_color_override("font_color", DIM)
	_anvil_box.add_child(hint)
	_center(_panels["anvil"])
	_center.call_deferred(_panels["anvil"])


# ---------------- Инвентарь (I) ----------------

var _inv_box: VBoxContainer


func _build_inv_panel() -> void:
	var panel := _panel()
	_panels["inv"] = panel
	_inv_box = VBoxContainer.new()
	_inv_box.add_theme_constant_override("separation", 1)
	panel.add_child(_inv_box)


func _short_item(item: Dictionary) -> String:
	var s := Crafting.effective_stats(item)
	var parts: PackedStringArray = []
	if s.has("atk_min"):
		parts.append("урон %d–%d" % [s["atk_min"], s["atk_max"]])
	for k: String in s:
		if k != "atk_min" and k != "atk_max":
			parts.append(Items.stat_text(k, s[k]))
	return ", ".join(parts)


func _inv_scroll(height: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(285, height)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_inv_box.add_child(sc)
	return v


func _inv_button(text: String, enabled: bool, on_press: Callable) -> Button:
	var b := _small_button(text)
	b.custom_minimum_size = Vector2(26, 8)
	b.disabled = not enabled
	b.pressed.connect(on_press, CONNECT_DEFERRED)
	return b


func _refresh_inv_panel() -> void:
	if open_panel != "inv":
		return
	for c in _inv_box.get_children():
		_inv_box.remove_child(c)
		c.queue_free()
	var head := _rich(280)
	head.text = "[b]Снаряжение и сумка[/b]   [color=#a8a0b8]сумка %d/%d — в лагерь попадёт только через портал[/color]" % [Run.bag.size(), Meta.bag_max()]
	_inv_box.add_child(head)
	var eq_list := _inv_scroll(58)
	for slot: String in Items.SLOTS:
		var it: Variant = Run.equipment[slot]
		if it == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var s: String = slot
		row.add_child(_inv_button("Снять", not it.get("starter", false) and Run.bag.size() < Meta.bag_max(), func() -> void:
			if _player:
				_player.inv("unequip", s)))
		var t := _rich(250)
		t.text = "%s: [color=#%s]%s[/color] [color=#a8a0b8]%s[/color]" % [Items.SLOT_NAMES[slot], Items.color(it).to_html(false), Items.display_name(it), _short_item(it)]
		row.add_child(t)
		eq_list.add_child(row)
	var sub := _rich(280)
	sub.text = "[b]Сумка[/b]" + ("  [color=#a8a0b8]пусто[/color]" if Run.bag.is_empty() else "")
	_inv_box.add_child(sub)
	var bag_list := _inv_scroll(62)
	for i in Run.bag.size():
		var it: Dictionary = Run.bag[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var idx := i
		var reason: String = Run.equip_block_reason(it)
		row.add_child(_inv_button("%d Надеть" % (i + 1) if i < 9 else "Надеть", reason == "", func() -> void:
			if _player:
				_player.inv("equip", idx)))
		row.add_child(_inv_button("Бросить", true, func() -> void:
			if _player:
				_player.inv("drop", idx)))
		var t := _rich(222)
		var better := ""
		if reason == "":
			var now: Dictionary = Run.derived()
			var then: Dictionary = Run.derived_with(it)
			var gain: float = (then["atk_max"] - now["atk_max"]) * 2.0 + (then["max_hp"] - now["max_hp"]) * 0.3 + (then["dr"] - now["dr"]) * 2.0 + (then["crit"] - now["crit"]) + (then["aspd"] - now["aspd"]) * 0.5
			better = " [color=#%s]▲[/color]" % GOOD.to_html(false) if gain > 0.5 else (" [color=#%s]▼[/color]" % BAD.to_html(false) if gain < -0.5 else "")
		else:
			better = " [color=#%s](%s)[/color]" % [BAD.to_html(false), reason]
		t.text = "[color=#%s]%s[/color]%s [color=#a8a0b8]%s — %s[/color]" % [Items.color(it).to_html(false), Items.display_name(it), better, Items.SLOT_NAMES[it["slot"]], _short_item(it)]
		row.add_child(t)
		bag_list.add_child(row)
	var hint := _label(4)
	hint.text = "1–6 — надеть из сумки   ▲ — лучше надетого   I или E — закрыть"
	hint.add_theme_color_override("font_color", DIM)
	_inv_box.add_child(hint)
	_center(_panels["inv"])
	_center.call_deferred(_panels["inv"])


func _do_refine(item: Dictionary, bonus: float) -> void:
	if not Crafting.can_pay_refine(item, Run.gold, Run.materials):
		return
	var cost := Crafting.refine_cost(item)
	Run.gold -= cost["gold"]
	Crafting.take_common(Run.materials, cost["mats"])
	var ok := Crafting.try_refine(item, bonus)
	_anvil_result = ("[color=#%s]Успех! %s[/color]" if ok else "[color=#%s]Неудача… %s[/color]") % [
		(GOOD if ok else BAD).to_html(false), Items.display_name(item)]
	Run.changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if open_panel == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not open_panel in ["class", "job"] and event.physical_keycode in [KEY_E, KEY_ESCAPE]:
		_open("")
		get_viewport().set_input_as_handled()
		return
	var idx: int = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6].find(event.physical_keycode)
	if idx < 0:
		return
	match open_panel:
		"inv":
			if _player and idx < Run.bag.size():
				_player.inv("equip", idx)
		"anvil":
			var items := []
			for slot: String in Items.SLOTS:
				if Run.equipment[slot] != null:
					items.append(Run.equipment[slot])
			if idx < items.size():
				_do_refine(items[idx], Run.derived()["craft"])
		"stats":
			if idx < Run.STAT_KEYS.size():
				Run.add_stat(Run.STAT_KEYS[idx])
		"skills":
			var ids: Array = Run.skill_list()
			if idx < ids.size():
				Run.learn_skill(ids[idx])
		"class":
			var keys := Skills.CLASSES.keys()
			if idx < keys.size():
				_choose_class(keys[idx])
		"job":
			var jobs: Array = Run.class_data()["jobs"]
			if idx < jobs.size():
				_choose_job(jobs[idx])
	get_viewport().set_input_as_handled()


# ---------------- Окно характеристик (C) ----------------

var _stats_text: RichTextLabel
var _stat_rows := {}


func _build_stats_panel() -> void:
	var panel := _panel()
	_panels["stats"] = panel
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	hbox.add_child(left)
	var title := _label(7)
	title.text = "Характеристики"
	left.add_child(title)
	for key: String in Run.STAT_KEYS:
		var row := HBoxContainer.new()
		var btn := _small_button("+")
		btn.pressed.connect(func() -> void: Run.add_stat(key), CONNECT_DEFERRED)
		row.add_child(btn)
		var l := _label(5)
		l.custom_minimum_size = Vector2(130, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", -3)
		row.add_child(l)
		_stat_rows[key] = [btn, l]
		left.add_child(row)
	var hint := _label(4)
	hint.text = "Клавиши 1–6 или «+»   C — закрыть"
	hint.add_theme_color_override("font_color", DIM)
	left.add_child(hint)

	_stats_text = _rich(140)
	hbox.add_child(_stats_text)


func _refresh_stats_panel() -> void:
	for key: String in _stat_rows:
		var btn: Button = _stat_rows[key][0]
		var l: Label = _stat_rows[key][1]
		btn.disabled = Run.points <= 0
		var primary: bool = Run.class_data()["primary"] == key
		var from_items: int = Run.derived()["stats"][key] - Run.stats[key]
		l.text = "%s %d%s\n(%s)" % [Run.STAT_NAMES[key], Run.stats[key], (" (+%d)" % from_items) if from_items > 0 else "", Run.stat_hint(key)]
		l.add_theme_color_override("font_color", GOLD if primary else Color.WHITE)

	var d := Run.derived()
	var t := "[b]Свободных очков: [color=#%s]%d[/color][/b]\n" % [GOLD.to_html(false), Run.points]
	var attack_kind: String = "ближний бой" if Run.cls == "thief" or Run.job == "monk" else {"str": "ближний бой", "agi": "ближний бой", "dex": "дальний бой", "int": "магия"}[Run.class_data()["primary"]]
	t += "Атака %d–%d (%s)\nHP %d (+%.1f/с)   SP %d (+%.1f/с)\nКрит %d%%, сила крита %d%%\nСкор. атаки %+d%%   бега %+d%%\nЗащита %.1f%%   Точность %d\nПерезарядка −%d%%   Скор. каста +%d%%\nДроп +%d%%   Крафт +%d\n" % [
		d["atk_min"], d["atk_max"], attack_kind, d["max_hp"], d["hp_regen"], d["max_sp"], d["sp_regen"],
		d["crit"], int(d["crit_mult"] * 100), d["aspd"], d["speed"], d["dr"], d["accuracy"], d["cdr"], d["cast"], d["drop"], d["craft"]]
	# Особые свойства снаряжения.
	var sp_parts: PackedStringArray = []
	if d["eva"] > 0:
		sp_parts.append("уклонение %d%%" % d["eva"])
	for k in ["lifesteal", "burn", "thorns", "stun", "boss", "pierce"]:
		if d[k] > 0:
			sp_parts.append(Items.stat_text(k, d[k]))
	if not sp_parts.is_empty():
		t += "[color=#e8a0ff]%s[/color]\n" % ", ".join(sp_parts)
	t += "[b]Снаряжение[/b]\n"
	for slot: String in Items.SLOTS:
		var item: Variant = Run.equipment[slot]
		if item == null:
			var busy := slot == "offhand" and Items.is_two_hand(Run.equipment["weapon"])
			t += "%s: [color=#777080]%s[/color]\n" % [Items.SLOT_NAMES[slot], "занята двуручным" if busy else "пусто"]
		else:
			t += "%s: [color=#%s]%s[/color]\n" % [Items.SLOT_NAMES[slot], Items.color(item).to_html(false), Items.display_name(item)]
	for sid: String in Run.set_counts():
		t += set_text(sid, Run.equipment) + "\n"
	_stats_text.text = t
	_center(_panels["stats"])


# ---------------- Окно навыков (K) ----------------

var _skills_box: VBoxContainer
var _skills_title: Label


func _build_skills_panel() -> void:
	var panel := _panel()
	_panels["skills"] = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	_skills_title = _label(7)
	v.add_child(_skills_title)
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 3)
	v.add_child(_skills_box)
	var hint := _label(4)
	hint.text = "Клавиши 1–4 или «+» — изучить   K — закрыть   В бою навыки на 1, 2, 3"
	hint.add_theme_color_override("font_color", DIM)
	v.add_child(hint)


func _refresh_skills_panel() -> void:
	if Run.cls == "":
		return
	_skills_title.text = "Навыки: %s   (свободных очков: %d)" % [Run.title(), Run.skill_points]
	for c in _skills_box.get_children():
		_skills_box.remove_child(c)
		c.queue_free()
	var key_n := 0
	for id: String in Run.skill_list():
		var s: Dictionary = Skills.SKILLS[id]
		var lvl := Run.skill_level(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var btn := _small_button("+")
		var reason := Run.learn_block_reason(id)
		btn.disabled = reason != ""
		btn.pressed.connect(func() -> void: Run.learn_skill(id), CONNECT_DEFERRED)
		row.add_child(btn)
		var t := _rich(200)
		var slot := ""
		if s["type"] == "active":
			key_n += 1
			slot = "[color=#%s][%d][/color] " % [GOLD.to_html(false), key_n]
		var head := "%s[b]%s[/b]  ур. %d/%d" % [slot, s["name"], lvl, Skills.MAX_LEVEL]
		if s["type"] == "active":
			head += "  [color=#%s]SP %d, перезарядка %s с[/color]" % [SP_COLOR.to_html(false), Skills.sp_cost(id, lvl), Skills._num(s["cd"])]
			if s.has("cast"):
				head += "  [color=#%s]каст %.1f с[/color]" % [GOLD.to_html(false), Skills.cast_time(id, Run.derived()["cast"])]
		var body := Skills.describe(id, lvl)
		if lvl > 0 and lvl < Skills.MAX_LEVEL:
			body += "\n[color=#%s]Следующий уровень: %s[/color]" % [DIM.to_html(false), Skills.describe(id, lvl + 1)]
		if reason != "" and reason != "нет очков навыков" and lvl < Skills.MAX_LEVEL:
			body += "\n[color=#%s](%s)[/color]" % [BAD.to_html(false), reason]
		t.text = head + "\n" + body
		row.add_child(t)
		_skills_box.add_child(row)
	_center(_panels["skills"])
	_center.call_deferred(_panels["skills"])  # после раскладки текста размер точнее


# ---------------- Выбор класса ----------------

func _build_class_panel() -> void:
	var panel := _panel()
	_panels["class"] = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var title := _label(9)
	title.text = "Выбери класс героя"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	var n := 0
	for cls: String in Skills.CLASSES:
		n += 1
		var c: Dictionary = Skills.CLASSES[cls]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color(0.12, 0.1, 0.18), 1))
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var t := _rich(56)
		var txt := "[b]%s[/b]\n%s\n[color=#a8a0b8]HP %d, SP %d[/color]" % [c["name"], c["desc"], c["hp"], c["sp"]]
		t.text = txt
		cv.add_child(t)
		var btn := Button.new()
		btn.text = "Выбрать (%d)" % n
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 6)
		btn.pressed.connect(func() -> void: _choose_class(cls), CONNECT_DEFERRED)
		cv.add_child(btn)
		h.add_child(card)
	_center(panel)


func _choose_class(cls: String) -> void:
	Run.set_class(cls)
	_open("")
	show_banner(Run.class_data()["name"], 2.0)


# ---------------- Полоса здоровья босса ----------------

var _boss_box: Control
var _boss_name: Label
var _boss_bar: ProgressBar


func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.position = Vector2(100, 160)
	_boss_box.size = Vector2(160, 16)
	_boss_name = _label(6)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.size = Vector2(160, 8)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.position = Vector2(0, 10)
	_boss_bar.size = Vector2(160, 5)
	_boss_bar.add_theme_stylebox_override("background", _box(Color(0.1, 0.08, 0.14, 0.9), 1, Color(0.05, 0.03, 0.07)))
	_boss_bar.add_theme_stylebox_override("fill", _box(Color(0.75, 0.2, 0.25), 0))
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false
	add_child(_boss_box)


# ---------------- Стрелка к лестнице (удобство) ----------------
# Когда этаж зачищен, а лестница за краем экрана — у края экрана стрелка в её сторону.

var _arrow: Control
var _arrow_pos := Vector2.ZERO
var _arrow_dir := Vector2.ZERO


func _update_stairs_arrow(enemies: int) -> void:
	if _arrow == null:
		_arrow = Control.new()
		_arrow.size = Vector2(320, 180)
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arrow.draw.connect(_draw_arrow)
		add_child(_arrow)
	var scene := get_tree().current_scene
	var stairs: Variant = scene.get("stairs_pos") if scene else null
	_arrow_dir = Vector2.ZERO
	if stairs != null and enemies == 0 and stairs.x > -1000 and _player and not _player.dead:
		var screen: Vector2 = get_viewport().get_canvas_transform() * (stairs as Vector2)
		var vp := get_viewport().get_visible_rect().size
		var k := 320.0 / vp.x
		var p := screen * k
		if p.x < 0 or p.y < 0 or p.x > 320 or p.y > 180:
			var c := Vector2(160, 90)
			_arrow_dir = (p - c).normalized()
			_arrow_pos = c + _arrow_dir * Vector2(148, 76).length() * 0.6
			_arrow_pos = _arrow_pos.clamp(Vector2(10, 22), Vector2(310, 150))
	_arrow.queue_redraw()


func _draw_arrow() -> void:
	if _arrow_dir == Vector2.ZERO:
		return
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
	var tip := _arrow_pos + _arrow_dir * 6.0
	var side := _arrow_dir.orthogonal() * 4.0
	var base := _arrow_pos - _arrow_dir * 2.0
	_arrow.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(1.0, 0.85, 0.3, pulse))


func _update_boss_bar() -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	if boss == null or not boss.awake or boss.dead:
		_boss_box.visible = false
		return
	_boss_box.visible = true
	_boss_name.text = "%s — фаза %d%s" % [boss.BOSS_NAME, boss.phase, "   ЩИТ: разбей кристаллы" if boss.get("shielded") else ""]
	_boss_bar.max_value = boss.max_hp
	_boss_bar.value = boss.hp
