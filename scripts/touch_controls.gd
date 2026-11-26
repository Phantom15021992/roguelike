extends CanvasLayer
## Сенсорное управление для телефона (включается само на телефоне, переключатель — в меню паузы).
## Слева — джойстик (палец в любом месте левой части экрана), справа — атака, навыки 1–3 и E,
## сверху — меню, сумка, характеристики, навыки, карта (в лагере — кооператив, после гибели — «В лагерь»).
## Нажатия превращаются в те же действия и клавиши, что и на клавиатуре (Input.parse_input_event).

const Skills := preload("res://scripts/skills.gd")
const STICK_HOME := Vector2(46, 128)
const STICK_RADIUS := 22.0
const BUTTONS := {
	"attack": {"pos": Vector2(290, 146), "r": 17.0, "text": "Удар"},
	"skill_1": {"pos": Vector2(254, 162), "r": 11.0, "text": "1"},
	"skill_2": {"pos": Vector2(257, 130), "r": 11.0, "text": "2"},
	"skill_3": {"pos": Vector2(286, 110), "r": 11.0, "text": "3"},
	"skill_4": {"pos": Vector2(226, 134), "r": 11.0, "text": "4"},
	"interact": {"pos": Vector2(222, 164), "r": 10.0, "text": "E"},
}
const BAR_Y := 1.0
const BAR_H := 11.0
const BAR_W := 30.0

var _touches := {}             # номер касания -> что держит ("stick", "attack", ...)
var _stick_center := STICK_HOME
var _stick_vec := Vector2.ZERO
var _font: Font
var _canvas: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)


func _process(_delta: float) -> void:
	visible = Game.touch_enabled() and _scene_kind() != ""
	if visible:
		_canvas.queue_redraw()
	elif not _touches.is_empty():
		_release_all()


## "dungeon", "camp" или "" (меню загрузки и т.п. — управление не нужно).
func _scene_kind() -> String:
	var s := get_tree().current_scene
	if s == null:
		return ""
	if s.get_node_or_null("HUD"):
		return "dungeon"
	if s.get_node_or_null("CampHUD"):
		return "camp"
	return ""


## Верхняя строка кнопок: [подпись, клавиша].
func _bar() -> Array:
	var out: Array = [["Меню", KEY_ESCAPE]]
	var hero := Game.local_hero()
	if _scene_kind() == "dungeon":
		out += [["Сумка", KEY_I], ["Хар-ки", KEY_C], ["Навыки", KEY_K], ["Карта", KEY_M]]
		if hero and hero.dead and (not Net.active() or Game.all_dead()):
			out.append(["В лагерь", KEY_R])
	else:
		out.append(["Игра", KEY_TAB])  # сохранения / кооператив
	return out


func _bar_rect(i: int, n: int) -> Rect2:
	var total := n * (BAR_W + 2.0) - 2.0
	# В лагере слева сверху — строка золота и склада, поэтому кнопки справа.
	var x0 := 320.0 - total - 2.0 if _scene_kind() == "camp" else (320.0 - total) / 2.0
	return Rect2(Vector2(x0 + i * (BAR_W + 2.0), BAR_Y), Vector2(BAR_W, BAR_H))


## Какие круглые кнопки нужны: в лагере драться не с кем — только E.
func _buttons() -> Array:
	if _scene_kind() == "camp":
		return ["interact"]
	var out: Array = BUTTONS.keys()
	if _skill_names().size() < 4:
		out.erase("skill_4")  # четвёртый навык (бросок) — только у ближников
	return out


## Окно открыто — джойстик и кнопки боя спрятаны (палец нажимает кнопки окна).
func _fight_hidden() -> bool:
	var hero := Game.local_hero()
	return Game.ui_blocks_input() or hero == null or hero.dead


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag and _touches.get(event.index, "") == "stick":
		_move_stick(event.position)


func _on_press(idx: int, pos: Vector2) -> void:
	var bar := _bar()
	for i in bar.size():
		if _bar_rect(i, bar.size()).grow(2.0).has_point(pos):
			_key(bar[i][1])
			_touches[idx] = "bar"
			get_viewport().set_input_as_handled()
			return
	if _fight_hidden():
		return
	for id: String in _buttons():
		var b: Dictionary = BUTTONS[id]
		if pos.distance_to(b["pos"]) <= b["r"] + 4.0:
			_touches[idx] = id
			_action(id, true)
			get_viewport().set_input_as_handled()
			return
	if pos.x < 160.0 and pos.y > 20.0:
		_touches[idx] = "stick"
		_stick_center = pos
		_move_stick(pos)
		get_viewport().set_input_as_handled()


func _on_release(idx: int) -> void:
	var what: String = _touches.get(idx, "")
	_touches.erase(idx)
	if what == "stick":
		_stick_vec = Vector2.ZERO
		_stick_center = STICK_HOME
		_send_move()
	elif BUTTONS.has(what):
		_action(what, false)


func _release_all() -> void:
	for idx: int in _touches.keys():
		_on_release(idx)


func _move_stick(pos: Vector2) -> void:
	var d := pos - _stick_center
	if d.length() > STICK_RADIUS:
		_stick_center = pos - d.normalized() * STICK_RADIUS  # джойстик «едет» за пальцем
		d = pos - _stick_center
	var v := d / STICK_RADIUS
	_stick_vec = v if v.length() > 0.2 else Vector2.ZERO
	_send_move()


func _send_move() -> void:
	_action("move_left", _stick_vec.x < 0.0, maxf(0.0, -_stick_vec.x))
	_action("move_right", _stick_vec.x > 0.0, maxf(0.0, _stick_vec.x))
	_action("move_up", _stick_vec.y < 0.0, maxf(0.0, -_stick_vec.y))
	_action("move_down", _stick_vec.y > 0.0, maxf(0.0, _stick_vec.y))


func _action(action: String, pressed: bool, strength := 1.0) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength if pressed else 0.0
	Input.parse_input_event(ev)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


# ---------------- Рисование ----------------

func _draw_controls() -> void:
	var c := _canvas
	var win := Vector2(get_window().size)
	if win.y > win.x:
		# Телефон держат вертикально — картинка крошечная.
		c.draw_rect(Rect2(0, 70, 320, 40), Color(0, 0, 0, 0.75))
		_text(Vector2(160, 88), "Поверни телефон горизонтально", 10, Color(1.0, 0.85, 0.4))
		_text(Vector2(160, 102), "и включи полный экран: Меню » Полный экран", 6, Color.WHITE)
	var bar := _bar()
	for i in bar.size():
		var r := _bar_rect(i, bar.size())
		c.draw_rect(r, Color(0.08, 0.06, 0.12, 0.75))
		c.draw_rect(r, Color(0.6, 0.55, 0.7, 0.9), false, 1.0)
		_text(r.get_center() + Vector2(0, 2), bar[i][0], 5, Color.WHITE)
	if _fight_hidden():
		return
	# Джойстик.
	c.draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.08))
	c.draw_arc(_stick_center, STICK_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 1.0)
	c.draw_circle(_stick_center + _stick_vec * STICK_RADIUS, 8.0, Color(1, 1, 1, 0.35))
	# Кнопки.
	var names := _skill_names()
	for id: String in _buttons():
		var b: Dictionary = BUTTONS[id]
		var held: bool = id in _touches.values()
		c.draw_circle(b["pos"], b["r"], Color(1, 1, 1, 0.3 if held else 0.14))
		c.draw_arc(b["pos"], b["r"], 0.0, TAU, 32, Color(1, 1, 1, 0.45), 1.0)
		var label: String = b["text"]
		if id.begins_with("skill_"):
			var n := int(id.right(1)) - 1
			_text(b["pos"] + Vector2(0, -1), label, 6, Color(1.0, 0.85, 0.4))
			if n < names.size():
				_text(b["pos"] + Vector2(0, 6), names[n], 4, Color.WHITE)
		else:
			_text(b["pos"] + Vector2(0, 2), label, 7 if id == "attack" else 6, Color.WHITE)


## Короткие названия навыков (как на панели навыков внизу).
func _skill_names() -> Array:
	var out: Array = []
	if Run.cls == "":
		return out
	for id: String in Skills.actives_of(Run.skill_list()):
		out.append(Skills.SKILLS[id]["abbr"])
	return out


func _text(center: Vector2, text: String, size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := center - Vector2(w / 2.0, 0)
	_canvas.draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0.05, 0.03, 0.08))
	_canvas.draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
