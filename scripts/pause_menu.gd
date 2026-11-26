extends CanvasLayer
## Меню по Esc: продолжить, управление, настройки, сдаться (в лагерь), выйти из игры.
## В одиночной игре ставит паузу, в кооперативе — нет (мир у всех общий).

var _panel: PanelContainer
var _box: VBoxContainer
var _page := "main"


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.05, 0.11, 0.97)
	st.set_border_width_all(1)
	st.border_color = Color(0.55, 0.5, 0.65)
	st.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", st)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	_panel.add_child(_box)
	add_child(_panel)
	visible = false


func is_open() -> bool:
	return visible


func open(page := "main") -> void:
	_page = page
	visible = true
	if not Net.active():
		get_tree().paused = true
	_fill()


func close() -> void:
	visible = false
	if not Net.active():
		get_tree().set_deferred("paused", false)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_F1]:
		if _page != "main" and event.physical_keycode == KEY_ESCAPE:
			_page = "main"
			_fill()
		else:
			close()
		get_viewport().set_input_as_handled()


func _label(text: String, size := 6) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.custom_minimum_size = Vector2(230, 0)
	t.add_theme_font_size_override("normal_font_size", size)
	t.add_theme_font_size_override("bold_font_size", size + 2)
	t.add_theme_constant_override("line_separation", -1)
	t.text = text
	return t


func _button(text: String, on_press: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 6)
	b.pressed.connect(on_press, CONNECT_DEFERRED)  # окно перестраивается — кнопку удалять только отложенно
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent else _box).add_child(b)
	return b


## Ряд из двух кнопок (меню не должно вылезать за экран).
func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	_box.add_child(h)
	return h


func _fill() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	if _page == "help":
		_box.add_child(_label(HELP, 5))
		_button("Назад", func() -> void:
			_page = "main"
			_fill())
	else:
		_box.add_child(_label("[b]Пауза[/b]" if not Net.active() else "[b]Меню[/b]  [color=#a8a0b8](в кооперативе игра не останавливается)[/color]"))
		var r1 := _row()
		_button("Продолжить (Esc)", close, r1)
		_button("Управление (F1)", func() -> void:
			_page = "help"
			_fill(), r1)
		var r2 := _row()
		_button("Тряска экрана: %s" % ("вкл" if Meta.setting("shake") else "выкл"), func() -> void:
			Meta.set_setting("shake", not Meta.setting("shake"))
			_fill(), r2)
		_button("Цифры урона: %s" % ("вкл" if Meta.setting("numbers") else "выкл"), func() -> void:
			Meta.set_setting("numbers", not Meta.setting("numbers"))
			_fill(), r2)
		var r3 := _row()
		_button("Сенсорное управление: %s" % ("вкл" if Game.touch_enabled() else "выкл"), func() -> void:
			Meta.set_setting("touch", not Game.touch_enabled())
			_fill(), r3)
		_button("Полный экран: %s" % ("вкл" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "выкл"), func() -> void:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			_fill.call_deferred(), r3)
		var in_dungeon :=get_tree().current_scene != null and get_tree().current_scene.name == "Main"
		if in_dungeon and not Net.is_guest():
			_button("Сдаться — в лагерь (добыча забега потеряется)", func() -> void:
				close()
				Game.return_to_camp(false))
		var hint := "забег сохранится — продолжишь с этого этажа" if in_dungeon and not Net.is_guest() else "игра сохранится"
		if Net.is_guest():
			hint = "выйти из кооператива"
		_button("В главное меню (%s)" % hint, func() -> void:
			close()
			Game.to_main_menu())
		if not OS.has_feature("web"):
			_button("Выйти из игры", func() -> void:
				Game.save_run()
				Meta.save_game()
				get_tree().quit())
	_panel.reset_size()
	_panel.position = ((Vector2(320, 180) - _panel.size) / 2.0).round()
	_recenter.call_deferred()


func _recenter() -> void:
	_panel.reset_size()
	_panel.position = ((Vector2(320, 180) - _panel.size) / 2.0).round()


const HELP := """[b]Управление[/b]
WASD / стрелки — ходьба
Пробел / J — атака в сторону взгляда, ЛКМ — в сторону курсора (можно зажать)
1–4 — навыки (4 — бросок у ближников; целятся в курсор, если недавно двигали мышью)
E — взаимодействие: подобрать предмет, лестница, постройка, портал
I — снаряжение и сумка    C — характеристики    K — навыки
M — большая карта этажа    Esc — это меню    F11 — полный экран
R — в лагерь после гибели
В лагере: Tab — меню кооператива
Телефон: левая часть экрана — джойстик; справа — удар (сам целится в ближайшего), навыки 1–3, E

[b]Подсказки[/b]
• Предмет под ногами: E — надеть (если слот пуст) или в сумку; надеть из сумки — I.
• После каждого убитого босса герой сохраняется — следующий забег можно начать со следующего этажа.
• На этажах бывают модификаторы (Тьма, Орда…), элитные монстры (золотое кольцо, богатая добыча) и события — жёлтая точка на карте.
• В лагере: Торговец (товар меняется после забега), Наставник (поручения с наградой), Обменник.
• Игра сохраняется сама (каждый этаж и раз в 20 с). Вышел посреди забега — выбери то же
  сохранение в главном меню и продолжишь с того же этажа (этаж будет сгенерирован заново).
• Вынести добычу можно только через портал у логова босса.
• На миникарте: жёлтое — лестница, оранжевое — наковальня, точки — предметы."""
