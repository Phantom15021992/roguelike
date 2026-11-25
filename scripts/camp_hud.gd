extends CanvasLayer
## Интерфейс лагеря: золото, материалы и рекорды, подсказка «E — ...», окна построек
## (улучшение, шахта, мастерская: создание / склад / заточка), выбор класса и снаряжения
## у портала, итоги прошлого забега.

const Skills := preload("res://scripts/skills.gd")
const Items := preload("res://scripts/items.gd")
const Crafting := preload("res://scripts/crafting.gd")
const MATS_TEX := preload("res://assets/mats.png")
const GOLD := Color(1.0, 0.85, 0.3)
const GOOD := Color(0.45, 0.95, 0.45)
const BAD := Color(1.0, 0.4, 0.4)
const DIM := Color(0.66, 0.63, 0.72)

var _player: Node
var _info: Label
var _prompt: Label
var _banner: Label
var _banner_time := 0.0
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _open_id := ""
var _tab := "craft"           # вкладка мастерской: craft, stash, upgrade
var _portal_cls := ""         # выбранный класс (шаг 2 портала — снаряжение)
var _loadout := {}            # слот -> индекс на складе
var _result := ""             # итог последнего действия в мастерской


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_info = _label(6)
	_info.position = Vector2(4, 2)
	add_child(_info)
	_prompt = _label(6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(0, 166)
	_prompt.size = Vector2(320, 10)
	_prompt.add_theme_color_override("font_color", GOLD)
	add_child(_prompt)
	_banner = _label(7)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, 30)
	_banner.size = Vector2(320, 20)
	add_child(_banner)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.06, 0.12, 0.96)
	box.set_border_width_all(1)
	box.border_color = Color(0.5, 0.45, 0.6)
	box.set_content_margin_all(5)
	_panel.add_theme_stylebox_override("panel", box)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 3)
	_panel.add_child(_panel_box)
	_panel.visible = false
	add_child(_panel)

	if not Meta.last_run.is_empty():
		var r: Dictionary = Meta.last_run
		var outcome := ""
		if r.get("alive", false):
			outcome = "Вернулся живым: %d золота, %d материалов, снаряжение на складе (%d)." % [
				r.get("gold", 0), r.get("mats", 0), r.get("kept", 0)]
		else:
			outcome = "Погиб: потеряно %d золота, %d материалов и %d предметов." % [
				r.get("gold_lost", 0), r.get("mats_lost", 0), r.get("lost", 0)]
		_banner.text = "Забег окончен: %s, %d этаж, %d уровень.\n%s" % [r["class"], r["depth"], r["level"], outcome]
		_banner_time = 6.0
		Meta.last_run = {}
	Meta.changed.connect(_reopen)


func _reopen() -> void:
	if _open_id != "":
		_refill()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08))
	return l


func _rich(width: float, text: String) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.custom_minimum_size = Vector2(width, 0)
	t.add_theme_font_size_override("normal_font_size", 5)
	t.add_theme_font_size_override("bold_font_size", 7)
	t.add_theme_constant_override("line_separation", -1)
	t.text = text
	return t


func _button(text: String, on_press: Callable, enabled := true, size := 6) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.disabled = not enabled
	# Отложенно: обработчик часто перестраивает окно и удаляет саму кнопку —
	# удалять кнопку, пока она ещё «нажимается», нельзя (Godot падает).
	b.pressed.connect(on_press, CONNECT_DEFERRED)
	return b


## Список с прокруткой фиксированной высоты.
func _scroll(height: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, height)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_panel_box.add_child(sc)
	return v


func _hc(sep := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	Meta.update_mine()
	var mine := ""
	if Meta.level("mine") > 0:
		mine = "\nВ шахте: %d / %d зол., %d руды" % [int(Meta.mine_stored), Meta.mine_cap(), int(Meta.ore_stored)]
	_info.text = "Лагерь   Золото: %d   Материалы: %d   Склад: %d/%d\nРекорд: %d этаж   Забегов: %d%s" % [
		Meta.gold, Crafting.common_count(Meta.materials), Meta.stash.size(), Meta.STASH_MAX, Meta.best_depth, Meta.runs, mine]
	_banner_time -= delta
	_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)
	var thing: Node2D = null
	if _player and _open_id == "":
		thing = _player.nearest_interactable()
	_prompt.text = thing.prompt() if thing else ""


func _unhandled_input(event: InputEvent) -> void:
	if _open_id == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE, KEY_E:
			close()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3:
			if _open_id == "portal" and _portal_cls == "":
				var keys := Skills.CLASSES.keys()
				_pick_class(keys[[KEY_1, KEY_2, KEY_3].find(event.physical_keycode)])
				get_viewport().set_input_as_handled()


func close() -> void:
	_open_id = ""
	_portal_cls = ""
	_loadout = {}
	_result = ""
	_panel.visible = false
	# Снимаем паузу в конце кадра — иначе то же нажатие E сразу откроет окно снова.
	get_tree().set_deferred("paused", false)


func _clear() -> void:
	for c in _panel_box.get_children():
		_panel_box.remove_child(c)
		c.queue_free()  # не free(): элемент может быть занят (кнопка в момент нажатия)


func open_building(id: String) -> void:
	_open_id = id
	_portal_cls = ""
	_loadout = {}
	_result = ""
	_tab = "craft" if Meta.level("workshop") > 0 else "upgrade"
	_refill()
	_panel.visible = true
	get_tree().paused = true


func _refill() -> void:
	_clear()
	match _open_id:
		"portal":
			if _portal_cls == "":
				_fill_portal()
			else:
				_fill_loadout()
		"workshop":
			_fill_workshop()
		_:
			_fill_upgrade(_open_id)
	_recenter()
	_recenter.call_deferred()


func _recenter() -> void:
	_panel.reset_size()
	_panel.position = ((Vector2(320, 180) - _panel.size) / 2.0).round()


# ---------------- Постройки ----------------

func _fill_upgrade(id: String) -> void:
	var u: Dictionary = Meta.UPGRADES[id]
	var lvl := Meta.level(id)
	var t := "[b]%s[/b]   уровень %d/%d\n%s\n" % [u["name"], lvl, u["max"], u["desc"]]
	t += "\nСейчас: %s" % (Meta.effect(id, lvl) if lvl > 0 else "[color=#777080]не построено[/color]")
	if not Meta.is_max(id):
		t += "\nПосле улучшения: [color=#%s]%s[/color]" % [GOOD.to_html(false), Meta.effect(id, lvl + 1)]
	_panel_box.add_child(_rich(170, t))
	if id == "mine" and lvl > 0:
		var stored := int(Meta.mine_stored)
		var ore := int(Meta.ore_stored)
		_panel_box.add_child(_button("Собрать %d золота и %d руды" % [stored, ore], func() -> void:
			var got: Array = Meta.collect_mine()
			_banner.text = "Из шахты: +%d золота, +%d руды" % [got[0], got[1]]
			_banner_time = 2.0, stored > 0 or ore > 0))
	if Meta.is_max(id):
		_panel_box.add_child(_rich(170, "[color=#%s]Максимальный уровень[/color]" % GOLD.to_html(false)))
	else:
		var verb := "Построить" if lvl == 0 else "Улучшить"
		var price := Meta.cost(id)
		var b := _button("%s — %d золота (у тебя %d)" % [verb, price, Meta.gold], func() -> void: Meta.upgrade(id), Meta.can_upgrade(id))
		_panel_box.add_child(b)
	_panel_box.add_child(_button("Закрыть (E)", close))


# ---------------- Мастерская ----------------

func _fill_workshop() -> void:
	if Meta.level("workshop") == 0:
		_fill_upgrade("workshop")
		return
	var tabs := _hc(2)
	for spec in [["craft", "Создание"], ["stash", "Склад %d/%d" % [Meta.stash.size(), Meta.STASH_MAX]], ["upgrade", "Улучшение"]]:
		var id: String = spec[0]
		var b := _button(("▶ " if _tab == id else "") + spec[1], func() -> void:
			_tab = id
			_result = ""
			_refill(), true, 6)
		tabs.add_child(b)
	_panel_box.add_child(tabs)
	_panel_box.add_child(_materials_bar(Meta.materials, Meta.gold))
	match _tab:
		"craft":
			_fill_craft()
		"stash":
			_fill_stash()
		"upgrade":
			_fill_upgrade("workshop")
			return
	if _result != "":
		_panel_box.add_child(_rich(250, _result))
	_panel_box.add_child(_button("Закрыть (E)", close))


## Строка с иконками и количеством материалов.
func _materials_bar(mats: Dictionary, gold: int) -> Control:
	var h := _hc(3)
	var g := _label(5)
	g.text = "Золото %d" % gold
	g.add_theme_color_override("font_color", GOLD)
	h.add_child(g)
	for id: String in Crafting.MATERIALS:
		var icon := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = MATS_TEX
		at.region = Rect2(Crafting.MATERIALS[id]["icon"] * 8, 0, 8, 8)
		icon.texture = at
		icon.tooltip_text = Crafting.mat_name(id)
		h.add_child(icon)
		var l := _label(5)
		l.text = str(mats.get(id, 0))
		h.add_child(l)
	return h


func _fill_craft() -> void:
	var rare := ""
	for id in Crafting.RARE:
		if Meta.materials.get(id, 0) > 0:
			rare = id
	var hint := "[color=#a8a0b8]Предметы создаются на склад. ★ — с редким материалом босса (%s): гарантированно редкий.[/color]" % (
		Crafting.mat_name(rare) + " есть" if rare != "" else "пока нет ни одного")
	_panel_box.add_child(_rich(250, hint))
	var list := _scroll(96)
	for base: String in Crafting.RECIPES:
		var b: Dictionary = Items.BASES[base]
		var can := Crafting.can_craft(base, Meta.gold, Meta.materials) and Meta.stash.size() < Meta.STASH_MAX
		var row := _hc()
		row.add_child(_button("Создать", func() -> void: _craft(base, ""), can, 5))
		row.add_child(_button("★", func() -> void: _craft(base, rare), can and rare != "", 5))
		var who := ""
		if b["slot"] == "weapon":
			who = " (%s)" % Skills.CLASSES[b["class"]]["name"]
		row.add_child(_rich(190, "[b]%s[/b]%s — %s" % [b["name"], who, Crafting.recipe_text(base)]))
		list.add_child(row)


func _craft(base: String, rare: String) -> void:
	if not Crafting.can_craft(base, Meta.gold, Meta.materials) or Meta.stash.size() >= Meta.STASH_MAX:
		return
	var r: Dictionary = Crafting.RECIPES[base]
	Meta.gold -= r["gold"]
	for id: String in r["mats"]:
		Meta.materials[id] -= r["mats"][id]
	if rare != "":
		Meta.materials[rare] -= 1
	var item := Crafting.craft(base, Meta.level("workshop"), rare)
	Meta.stash_add(item)
	_result = "Создано: [color=#%s]%s[/color] (%s)" % [Items.color(item).to_html(false), Items.display_name(item), _short_stats(item)]
	Meta.save_game()
	Meta.changed.emit()


func _fill_stash() -> void:
	var bonus := Meta.level("workshop") * 3
	_panel_box.add_child(_rich(250, "[color=#a8a0b8]Заточка в мастерской: +%d%% к шансу (уровень мастерской). Разбор возвращает часть материалов.[/color]" % bonus))
	if Meta.stash.is_empty():
		_panel_box.add_child(_rich(250, "Склад пуст. Создай предмет или вернись из подземелья через портал после босса."))
		return
	var list := _scroll(96)
	for i in Meta.stash.size():
		var item: Dictionary = Meta.stash[i]
		var row := _hc()
		var can_ref := Crafting.can_pay_refine(item, Meta.gold, Meta.materials)
		var cost := Crafting.refine_cost(item)
		var ref_text := "+%d: %d%%, %d зол., %d мат." % [Crafting.refine_level(item) + 1, Crafting.refine_chance(item, bonus), cost["gold"], cost["mats"]]
		if Crafting.refine_level(item) >= Crafting.REFINE_MAX:
			ref_text = "максимум"
		row.add_child(_button("Заточить", func() -> void: _refine_stash(item, bonus), can_ref, 5))
		row.add_child(_button("Разобрать", func() -> void: _salvage(i), true, 5))
		row.add_child(_rich(170, "[color=#%s]%s[/color] — %s\n[color=#a8a0b8]%s[/color]" % [
			Items.color(item).to_html(false), Items.display_name(item), _short_stats(item), ref_text]))
		list.add_child(row)


func _refine_stash(item: Dictionary, bonus: float) -> void:
	if not Crafting.can_pay_refine(item, Meta.gold, Meta.materials):
		return
	var cost := Crafting.refine_cost(item)
	Meta.gold -= cost["gold"]
	Crafting.take_common(Meta.materials, cost["mats"])
	var ok := Crafting.try_refine(item, bonus)
	_result = ("[color=#%s]Успех! %s[/color]" if ok else "[color=#%s]Неудача… %s[/color]") % [
		(GOOD if ok else BAD).to_html(false), Items.display_name(item)]
	Meta.save_game()
	Meta.changed.emit()


func _salvage(i: int) -> void:
	if i >= Meta.stash.size():
		return
	var item: Dictionary = Meta.stash[i]
	var got := Crafting.salvage(item)
	Meta.stash.remove_at(i)
	Meta.add_materials(got)
	var parts: PackedStringArray = []
	for id: String in got:
		parts.append("%s ×%d" % [Crafting.mat_name(id), got[id]])
	_result = "Разобрано: %s → %s" % [Items.display_name(item), ", ".join(parts)]
	Meta.save_game()
	Meta.changed.emit()


func _short_stats(item: Dictionary) -> String:
	var s := Crafting.effective_stats(item)
	var parts: PackedStringArray = []
	if s.has("atk_min"):
		parts.append("урон %d–%d" % [s["atk_min"], s["atk_max"]])
	for k: String in s:
		if k != "atk_min" and k != "atk_max":
			parts.append(Items.stat_text(k, s[k]))
	var b: Dictionary = Items.BASES[item["base"]]
	if b.has("job"):
		parts.append("[color=#a8a0b8]только %s[/color]" % Skills.JOBS[b["job"]]["name"])
	if item.has("set"):
		parts.append("[color=#66f080]комплект «%s»[/color]" % Items.SETS[item["set"]]["name"])
	return ", ".join(parts)


# ---------------- Портал: класс и снаряжение ----------------

func _fill_portal() -> void:
	_panel_box.add_child(_rich(250, "[b]Вход в подземелье[/b]\nВыбери класс героя. Бонусы лагеря действуют на весь забег."))
	var h := _hc(4)
	_panel_box.add_child(h)
	var n := 0
	for cls: String in Skills.CLASSES:
		n += 1
		var c: Dictionary = Skills.CLASSES[cls]
		var card := VBoxContainer.new()
		var txt := "[b]%s[/b]\n%s\n[color=#a8a0b8]HP %d, SP %d[/color]" % [c["name"], c["desc"], c["hp"], c["sp"]]
		card.add_child(_rich(80, txt))
		card.add_child(_button("Выбрать (%d)" % n, func() -> void: _pick_class(cls)))
		h.add_child(card)
	_panel_box.add_child(_button("Закрыть (E)", close))


func _pick_class(cls: String) -> void:
	# Если на складе нет ничего подходящего — сразу в путь.
	var any := false
	for it: Dictionary in Meta.stash:
		if Items.fits(it, cls, ""):
			any = true
	if not any:
		Game.start_run(cls)
		return
	_portal_cls = cls
	_loadout = {}
	_refill()


func _fill_loadout() -> void:
	var cls_name: String = Skills.CLASSES[_portal_cls]["name"]
	_panel_box.add_child(_rich(250, "[b]Снаряжение в забег — %s[/b]\nПо одному предмету на слот. [color=#%s]При смерти теряется всё: взятое снаряжение, найденные золото и материалы[/color] — вынести их можно только через портал у логова босса (до или после боя)." % [
		cls_name, BAD.to_html(false)]))
	var list := _scroll(90)
	for i in Meta.stash.size():
		var item: Dictionary = Meta.stash[i]
		# Оружие профессии в забег не взять: профессия выбирается только на 5-м уровне.
		if not Items.fits(item, _portal_cls, ""):
			continue
		var slot: String = item["slot"]
		var taken: bool = _loadout.get(slot, -1) == i
		var two_hand_weapon: bool = _loadout.has("weapon") and Items.is_two_hand(Meta.stash[_loadout["weapon"]])
		var blocked := slot == "offhand" and two_hand_weapon and not taken
		var row := _hc()
		row.add_child(_button("Снять" if taken else "Взять", func() -> void:
			if taken:
				_loadout.erase(slot)
			else:
				_loadout[slot] = i
				if Items.is_two_hand(item):
					_loadout.erase("offhand")  # двуручное занимает вторую руку
			_refill(), not blocked, 5))
		row.add_child(_rich(200, "%s[color=#%s]%s[/color] (%s) — %s" % [
			"✔ " if taken else "", Items.color(item).to_html(false), Items.display_name(item),
			Items.SLOT_NAMES[slot], _short_stats(item)]))
		list.add_child(row)
	var h := _hc(4)
	h.add_child(_button("В путь!", _go))
	h.add_child(_button("Назад", func() -> void:
		_portal_cls = ""
		_refill()))
	_panel_box.add_child(h)


func _go() -> void:
	var items := []
	var idx: Array = _loadout.values()
	idx.sort()
	idx.reverse()  # удаляем с конца, чтобы индексы не съехали
	for i: int in idx:
		items.append(Meta.stash[i])
		Meta.stash.remove_at(i)
	Game.start_run(_portal_cls, items)
