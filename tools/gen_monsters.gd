extends SceneTree
## Новая графика обычных монстров (пиксель-арт, чиби, обводка) — по референсам владельца
## (concepts/refs/monsters_items). Каждый монстр — лист assets/mon/<сцена>.png:
## 3 ряда (вниз, вбок-вправо, вверх) x столько кадров, сколько у старого листа его семейства
## (анимации скриптов не меняются). Кадр 24x24, низ ног — нижняя строка.
##   godot --headless --path . --script res://tools/gen_monsters.gd
## Плюс shots/monsters_gallery.png — все монстры крупно (для показа владельцу).

const Pix := preload("res://tools/pix.gd")

const RED := Color8(255, 70, 60)
const YEL := Color8(255, 220, 90)
const GRN := Color8(120, 255, 140)
const CYN := Color8(120, 230, 255)
const PNK := Color8(255, 120, 220)
const WHT := Color8(250, 250, 255)
const INK := Color8(30, 20, 40)
const BONE := Color8(232, 226, 204)
const STEEL := Color8(160, 168, 186)
const GOLD := Color8(236, 184, 70)
const WOOD := Color8(130, 86, 50)

var d: Pix = Pix.new()
var gallery: Array = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/mon"))
	_all()
	_bosses()
	_save_gallery("res://shots/monsters_gallery.png", gallery.filter(func(e: Array) -> bool: return not (e[0] as String).begins_with("boss_")), 24, 6)
	_save_gallery("res://shots/bosses_gallery.png", gallery.filter(func(e: Array) -> bool: return (e[0] as String).begins_with("boss_")), 48, 4)
	print("gen_monsters: %d sheets" % gallery.size())
	quit()


func make(name: String, cols: int, size: int, f: Callable) -> void:
	var sheet := Image.create(cols * size, size * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		for col in cols:
			d.begin(size)
			f.call(row, col)
			d.outline()
			sheet.blit_rect(d.img, Rect2i(0, 0, size, size), Vector2i(col * size, row * size))
	sheet.save_png(ProjectSettings.globalize_path("res://assets/mon/%s.png" % name))
	gallery.append([name, sheet, size])


## Все монстры: имя сцены, кадров, функция с настройками.
func _all() -> void:
	# --- Слизни (кадры: покой, покой-приплюснут, прыжок) ---
	make("slime", 3, 24, _slime.bind({"c": Color8(96, 200, 90)}))
	make("slime_splitter", 3, 24, _slime.bind({"c": Color8(140, 210, 80), "extra": "split"}))
	make("fire_slime", 3, 24, _slime.bind({"c": Color8(240, 120, 50), "extra": "flame", "eye": Color8(90, 20, 10)}))
	make("ice_slime", 3, 24, _slime.bind({"c": Color8(150, 215, 245), "extra": "ice", "eye": Color8(30, 60, 110)}))
	make("poison_slime", 3, 24, _slime.bind({"c": Color8(150, 90, 200), "extra": "poison"}))
	make("shadow_slime", 3, 24, _slime.bind({"c": Color8(84, 54, 130), "extra": "shadow", "eye": PNK, "es": "glow"}))
	make("demon_slime", 3, 24, _slime.bind({"c": Color8(200, 50, 50), "extra": "horns", "eye": YEL, "es": "glow"}))
	make("crystal_slime", 3, 24, _slime.bind({"c": Color8(230, 140, 230), "extra": "crystal", "eye": Color8(80, 20, 90)}))
	make("spider_mech", 3, 24, _spider)
	# --- Летуны (кадры: крылья вверх, вниз) ---
	make("bat", 2, 24, _bat.bind({"c": Color8(110, 80, 150), "w": Color8(80, 56, 112), "eye": YEL}))
	make("vampire_bat", 2, 24, _bat.bind({"c": Color8(150, 40, 60), "w": Color8(100, 24, 44), "eye": RED, "fangs": true}))
	make("snow_bat", 2, 24, _bat.bind({"c": Color8(220, 235, 250), "w": Color8(150, 190, 225), "eye": Color8(40, 110, 200)}))
	make("shard_bat", 2, 24, _bat.bind({"c": Color8(170, 120, 200), "w": Color8(240, 150, 230), "eye": CYN, "crystal": true}))
	make("ghost", 2, 24, _ghost.bind({"c": Color8(220, 236, 255)}))
	make("gnat", 2, 24, _gnat)
	make("miner", 2, 24, _miner)
	make("saw", 2, 24, _saw)
	make("shade", 2, 24, _shade.bind({"c": Color8(46, 34, 70), "eye": WHT}))
	make("mirror_shade", 2, 24, _shade.bind({"c": Color8(170, 190, 215), "eye": CYN, "mirror": true}))
	# --- Парящие (2 кадра покоя) ---
	make("wisp", 2, 24, _wisp.bind({"c": Color8(110, 120, 255), "eye": WHT}))
	make("fire_wisp", 2, 24, _wisp.bind({"c": Color8(255, 130, 40), "eye": Color8(255, 250, 200)}))
	make("frost_wisp", 2, 24, _wisp.bind({"c": Color8(150, 225, 255), "eye": Color8(30, 80, 160), "snow": true}))
	make("jellyfish", 2, 24, _jelly)
	make("necromancer", 2, 24, _necro)
	make("prism", 2, 24, _prism)
	make("skeleton_archer", 2, 24, _human_idle.bind({"bony": true, "head": "skull", "weapon": "bow", "eye": RED, "cloth": Color8(90, 70, 60)}))
	make("soul_eater", 2, 24, _soul_eater)
	make("turret", 2, 24, _turret)
	make("crystal", 1, 24, _shield_crystal)
	# --- Грибы и «стоячие» (покой, выброс) ---
	make("mushroom", 2, 24, _shroom.bind({"c": Color8(150, 90, 200), "spots": Color8(230, 210, 255), "puff": Color8(200, 160, 255)}))
	make("bomb_shroom", 2, 24, _shroom.bind({"c": Color8(220, 50, 40), "spots": WHT, "puff": Color8(255, 150, 60), "fuse": true}))
	make("frost_shroom", 2, 24, _shroom.bind({"c": Color8(140, 200, 240), "spots": WHT, "puff": Color8(200, 240, 255), "ice": true}))
	make("glow_shroom", 2, 24, _shroom.bind({"c": Color8(230, 230, 80), "spots": Color8(255, 255, 210), "puff": Color8(255, 255, 160), "glow": true}))
	make("lurker", 2, 24, _lurker)
	make("tentacle", 2, 24, _tentacle)
	make("whirlpool", 2, 24, _whirl)
	# --- Ходячие (покой, шаг) ---
	make("skeleton", 2, 24, _human.bind({"bony": true, "head": "skull", "weapon": "sword", "eye": RED, "cloth": Color8(96, 72, 56)}))
	make("rot_skeleton", 2, 24, _human.bind({"bony": true, "skin": Color8(176, 170, 120), "head": "rot", "weapon": "axe", "eye": GRN, "cloth": Color8(70, 90, 50)}))
	make("demon", 2, 24, _human.bind({"skin": Color8(200, 60, 50), "cloth": Color8(60, 30, 40), "head": "horns", "weapon": "axe", "eye": YEL, "wings": true}))
	make("drowned", 2, 24, _human.bind({"skin": Color8(70, 160, 150), "cloth": Color8(60, 90, 120), "head": "fish", "weapon": "trident", "eye": YEL}))
	make("phantom_knight", 2, 24, _human.bind({"skin": Color8(120, 130, 160), "cloth": Color8(90, 100, 135), "head": "helmet", "weapon": "lance", "eye": CYN, "plume": Color8(80, 200, 255)}))
	make("flamer", 2, 24, _human.bind({"skin": Color8(190, 130, 70), "cloth": Color8(150, 100, 60), "head": "robot", "weapon": "flamer", "eye": Color8(255, 150, 40)}))
	make("mirror", 2, 24, _mirror)
	make("crab", 2, 24, _crab)
	# --- Тяжёлые (покой, шаг) ---
	make("golem", 2, 24, _golem.bind({"c": Color8(90, 74, 70), "glow": Color8(255, 120, 30)}))
	make("ice_golem", 2, 24, _golem.bind({"c": Color8(150, 200, 235), "glow": Color8(220, 250, 255), "ice": true}))
	make("mech_golem", 2, 24, _golem.bind({"c": Color8(176, 120, 64), "glow": RED, "metal": true}))
	make("reflector", 2, 24, _golem.bind({"c": Color8(200, 130, 210), "glow": CYN, "crystal": true}))
	make("bone_guard", 2, 24, _human.bind({"bony": true, "head": "skull", "weapon": "tower", "eye": RED, "cloth": Color8(90, 70, 60)}))
	make("horror", 2, 24, _beast.bind({"kind": "horror", "c": Color8(60, 40, 90), "eye": PNK}))
	# --- Мелкие демоны и жабы (2 кадра покоя) ---
	make("imp", 2, 24, _imp.bind({"c": Color8(220, 70, 50), "eye": YEL}))
	make("toad", 2, 24, _toad.bind({"c": Color8(110, 150, 70)}))
	# --- Звери (покой, бег) ---
	make("salamander", 2, 24, _beast.bind({"kind": "lizard", "c": Color8(235, 110, 50), "eye": YEL}))
	make("hellhound", 2, 24, _beast.bind({"kind": "hound", "c": Color8(110, 36, 36), "eye": YEL}))
	make("sea_serpent", 2, 24, _beast.bind({"kind": "serpent", "c": Color8(60, 140, 190), "eye": YEL}))
	make("bomber_imp", 2, 24, _imp.bind({"c": Color8(240, 90, 60), "eye": YEL, "bomb": true}))


# ======================= СЛИЗНИ =======================

func _slime(dir: int, fr: int, p: Dictionary) -> float:
	var c: Color = p["c"]
	var pl := Pix.pal(c)
	var rx: float = [8.0, 9.0, 6.5][fr]
	var ry: float = [6.5, 5.6, 8.0][fr]
	var lift := 2.5 if fr == 2 else 0.0
	var cy := 23.0 - ry - lift
	var ex: String = p.get("extra", "")
	if ex == "shadow":
		for i in 4:
			var a := TAU * i / 4.0 + fr * 0.6
			d.ell(12 + cos(a) * 10.0, cy + sin(a) * 4.0, 0.8, 0.8, (pl[0] as Color).lightened(0.2))
	if fr != 2:
		d.ell(12, 22.4, rx + 0.8, 1.4, pl[2])
	d.ball(12, cy, rx, ry, pl, true)
	var top := cy - ry
	match ex:
		"split":
			d.line(Vector2(12, top + 1.5), Vector2(12, cy + ry - 1.5), pl[3])
			d.ell(9, cy + 2.0, 1.2, 1.2, pl[0])
			d.ell(15, cy + 2.0, 1.2, 1.2, pl[0])
		"flame":
			var h := 4.0 + fr
			for i in 3:
				var x := 8.5 + i * 3.5
				var hh := h + (1.5 if i == 1 else 0.0)
				d.poly(PackedVector2Array([Vector2(x - 1.8, top + 2), Vector2(x + (0.6 if fr == 1 else -0.4), top + 1 - hh), Vector2(x + 1.8, top + 2)]), Color8(255, 170, 40))
				d.poly(PackedVector2Array([Vector2(x - 0.8, top + 2), Vector2(x, top + 2 - hh * 0.6), Vector2(x + 0.8, top + 2)]), Color8(255, 240, 140))
		"ice":
			for i in 3:
				var x := 8.0 + i * 4.0
				d.spoly(PackedVector2Array([Vector2(x - 1.3, top + 2), Vector2(x, top - 3.0 - (1.5 if i == 1 else 0.0)), Vector2(x + 1.3, top + 2)]), Pix.pal(Color8(220, 245, 255)))
		"poison":
			d.ell(8.5, cy - 1.5, 1.2, 1.2, Color8(200, 255, 120))
			d.ell(15.5, cy + 1.0, 0.9, 0.9, Color8(200, 255, 120))
			d.ell(13.5, top + 0.5, 1.0, 1.0, Color8(170, 240, 110))
			d.rect(16, cy + ry - 1, 1, 2 + fr, Color8(170, 240, 110))
		"horns":
			for s: int in [-1, 1]:
				d.spoly(PackedVector2Array([Vector2(12 + s * 2.5, top + 1.5), Vector2(12 + s * 6.5, top - 3.5), Vector2(12 + s * 5.0, top + 2.5)]), Pix.pal(Color8(70, 30, 30)))
		"crystal":
			for i in 3:
				var x := 8.5 + i * 3.5
				d.spoly(PackedVector2Array([Vector2(x - 1.4, top + 2.5), Vector2(x + (i - 1) * 0.8, top - 2.5 - (2.0 if i == 1 else 0.0)), Vector2(x + 1.4, top + 2.5)]), Pix.pal(Color8(180, 240, 255)))
		"shadow":
			pass
	var ec: Color = p.get("eye", INK)
	d.eyes(12 + (2.0 if dir == 1 else 0.0), cy + 0.5, 2.8, dir, ec, p.get("es", "cute"))
	if dir == 0 and ex != "shadow" and ex != "horns":
		d.rect(11.5, cy + 3.0, 1, 0.8, pl[3])
	return top


## Паук-механизм (живёт на «слизневом» скрипте: покой, покой, прыжок).
func _spider(dir: int, fr: int) -> void:
	var body := Pix.pal(Color8(150, 110, 70))
	var lift := 3.0 if fr == 2 else 0.0
	var cy := 15.0 - lift
	var legc := Color8(90, 80, 80)
	for s: int in [-1, 1]:
		for i in 3:
			var sx := 12 + s * 4.0
			var kx := 12 + s * (8.0 + i)
			var fy := 22.0 - (1.0 if (i + fr) % 2 == 0 else 0.0) - lift * 0.3
			var ky := cy - 3.0 + i * 1.5
			d.line(Vector2(sx, cy + i - 1), Vector2(kx, ky), legc, 1.2)
			d.line(Vector2(kx, ky), Vector2(12 + s * (6.0 + i * 2.0), fy), legc, 1.2)
	d.ball(12, cy, 6, 4.5, body, true)
	d.rect(7, cy - 0.5, 10, 1, Pix.pal(Color8(150, 110, 70))[3])
	if dir != 2:
		var ex := 14.0 if dir == 1 else 12.0
		d.ell(ex, cy + 1.0, 2.0, 1.6, Color8(40, 30, 30))
		d.ell(ex, cy + 1.0, 1.0, 0.9, RED)
	else:
		d.ell(12, cy - 1.0, 2.0, 1.5, Color8(110, 110, 120))
		d.line(Vector2(12, cy - 2.5), Vector2(12, cy - 5.0), Color8(110, 110, 120))


# ======================= ЛЕТУНЫ =======================

func _bat(dir: int, fr: int, p: Dictionary) -> void:
	var c: Color = p["c"]
	var w: Color = p["w"]
	var wp := Pix.pal(w)
	var tip := Vector2(1.5, 4.0) if fr == 0 else Vector2(2.0, 17.0)
	for s: int in [-1, 1]:
		var pts := PackedVector2Array()
		for q: Vector2 in [Vector2(9.5, 9.5), Vector2(6.0, (tip.y + 9.0) / 2.0 - 1.0), tip, Vector2(3.5, tip.y + 2.5 if fr == 0 else tip.y - 1.0), Vector2(5.5, 12.5 if fr == 0 else 15.0), Vector2(7.5, 13.0), Vector2(9.5, 13.0)]:
			pts.append(Vector2(12 + (q.x - 12) * s, q.y))
		if dir == 1 and s < 0:
			d.spoly(pts, Pix.pal(w.darkened(0.3)))
		else:
			d.spoly(pts, wp)
		if p.get("crystal", false):
			d.line(Vector2(12 + (9.0 - 12) * s, 10.5), Vector2(12 + (tip.x - 12) * s, tip.y), (wp[0] as Color).lightened(0.4))
		else:
			d.line(Vector2(12 + (9.0 - 12) * s, 10.5), Vector2(12 + (tip.x + 1.0 - 12) * s, tip.y + (1.0 if fr == 0 else -1.0)), wp[3])
	var cp := Pix.pal(c)
	for s: int in [-1, 1]:
		d.poly(PackedVector2Array([Vector2(12 + s * 1.5, 8.0), Vector2(12 + s * 3.5, 3.5), Vector2(12 + s * 4.2, 8.0)]), cp[2])
	d.ball(12, 11, 4.4, 4.2, cp, true)
	var ex := 12.0 + (1.5 if dir == 1 else 0.0)
	d.eyes(ex, 10.5, 1.8, dir, p["eye"], "glow")
	if p.get("fangs", false) and dir != 2:
		d.px(ex - 1, 13, WHT)
		d.px(ex + 1 if dir == 0 else ex + 2.5, 13, WHT)


func _ghost(dir: int, fr: int, p: Dictionary) -> void:
	var pl := Pix.pal(p["c"])
	var sway := 1.0 if fr == 1 else -1.0
	var hem := PackedVector2Array([Vector2(6.5, 11), Vector2(17.5, 11), Vector2(18, 18), Vector2(16 + sway, 21), Vector2(14, 19), Vector2(12 + sway, 22), Vector2(10, 19), Vector2(8 + sway, 21), Vector2(6, 18)])
	if dir == 1:
		hem = PackedVector2Array([Vector2(7, 11), Vector2(17.5, 11), Vector2(17, 17), Vector2(13, 19), Vector2(8, 21 + sway), Vector2(3, 21), Vector2(6, 17)])
	d.spoly(hem, pl)
	d.ball(12, 10, 5.8, 5.6, pl, true)
	if dir != 2:
		var ex := 12.0 + (2.0 if dir == 1 else 0.0)
		for x: float in ([ex - 2.3, ex + 2.3] if dir == 0 else [ex + 1.5]):
			d.ell(x, 10, 1.2, 1.8, INK)
		d.ell(ex + (0.0 if dir == 0 else 1.5), 13.5, 1.0, 1.2, INK)


func _gnat(_dir: int, fr: int) -> void:
	var spots: Array = [Vector2(8, 9), Vector2(16, 7), Vector2(12, 15)] if fr == 0 else [Vector2(7, 11), Vector2(15, 9), Vector2(13, 14)]
	for v: Vector2 in spots:
		d.ell(v.x - 1.5, v.y - 1.5 - fr, 1.6, 1.0, Color(0.85, 0.95, 1.0, 0.75))
		d.ell(v.x + 1.5, v.y - 1.5 - fr, 1.6, 1.0, Color(0.85, 0.95, 1.0, 0.75))
		d.ell(v.x, v.y, 1.8, 1.4, Color8(120, 150, 60))
		d.ell(v.x + 1.5, v.y - 0.3, 1.0, 1.0, Color8(80, 100, 40))
		d.px(v.x + 2.0, v.y - 0.5, RED)
		d.line(Vector2(v.x - 1.5, v.y + 0.5), Vector2(v.x - 3.0, v.y + 1.5), Color8(80, 100, 40))


func _miner(dir: int, fr: int) -> void:
	var cu := Pix.pal(Color8(184, 116, 70))
	# Пропеллер.
	d.rect(12, 3, 1, 3, Color8(90, 90, 100))
	if fr == 0:
		d.rect(6, 3, 13, 1, Color8(200, 200, 210))
	else:
		d.rect(9, 2.5, 7, 1.5, Color8(200, 200, 210))
	d.ball(12, 11, 6, 5, cu, true)
	d.rect(6.5, 12, 11, 1, cu[3])
	# Мина снизу.
	d.line(Vector2(12, 16), Vector2(12, 18), Color8(90, 90, 100))
	d.ball(12, 20, 2.5, 2.2, Pix.pal(Color8(70, 70, 80)))
	d.px(12, 18.5, RED if fr == 0 else YEL)
	if dir != 2:
		var ex := 12.0 if dir == 0 else 15.0
		d.ell(ex, 10, 2.0, 1.8, Color8(40, 40, 50))
		d.ell(ex, 10, 1.0, 1.0, RED)


func _saw(_dir: int, fr: int) -> void:
	var r := 8.0
	var teeth := 10
	for i in teeth:
		var a := TAU * i / teeth + fr * PI / teeth
		var b := a + PI / teeth
		d.poly(PackedVector2Array([Vector2(12 + cos(a) * (r - 1), 13 + sin(a) * (r - 1)), Vector2(12 + cos(a + 0.12) * (r + 2), 13 + sin(a + 0.12) * (r + 2)), Vector2(12 + cos(b) * (r - 1), 13 + sin(b) * (r - 1))]), Color8(200, 206, 220))
	d.ball(12, 13, r, r, Pix.pal(STEEL))
	for i in 3:
		var a := TAU * i / 3.0 + fr * 0.5
		d.line(Vector2(12, 13) + Vector2.from_angle(a) * 2.5, Vector2(12, 13) + Vector2.from_angle(a) * 6.0, Color8(110, 116, 130))
	d.ball(12, 13, 2.2, 2.2, Pix.pal(Color8(200, 60, 50)))


func _shade(dir: int, fr: int, p: Dictionary) -> void:
	var pl := Pix.pal(p["c"])
	var sway := 1.5 if fr == 1 else -1.0
	var tail := PackedVector2Array([Vector2(6, 10), Vector2(18, 10), Vector2(16, 17), Vector2(12 + sway, 23), Vector2(9, 17)])
	if dir == 1:
		tail = PackedVector2Array([Vector2(7, 9), Vector2(18, 10), Vector2(14, 17), Vector2(5 + sway, 22), Vector2(6, 15)])
	d.spoly(tail, pl)
	d.ball(12, 9.5, 6, 5.5, pl, p.get("mirror", false))
	# Капюшон: тёмный провал лица.
	if dir != 2:
		var fx := 12.0 if dir == 0 else 14.5
		d.ell(fx, 10.5, 3.6, 3.0, Color8(10, 6, 18))
		d.eyes(fx, 10.5, 1.6, dir, p["eye"], "glow")
	if p.get("mirror", false):
		d.line(Vector2(8, 13), Vector2(11, 8), WHT)


# ======================= ПАРЯЩИЕ =======================

func _wisp(dir: int, fr: int, p: Dictionary) -> void:
	var c: Color = p["c"]
	var pl := Pix.pal(c)
	var fl := 1.0 if fr == 1 else 0.0
	d.poly(PackedVector2Array([Vector2(7, 12), Vector2(9 - fl, 3 + fl), Vector2(11, 7), Vector2(13 + fl, 1.5), Vector2(15, 7), Vector2(17, 4 - fl), Vector2(17, 12)]), (pl[0] as Color).lightened(0.1))
	d.ball(12, 13, 6, 5.5, pl, true)
	d.ell(12, 13.5, 3.5, 3.0, (pl[0] as Color).lightened(0.35))
	if p.get("snow", false):
		for v: Vector2 in [Vector2(4, 8), Vector2(20, 11), Vector2(6, 19)]:
			d.px(v.x, v.y + fr, WHT)
	d.eyes(12 + (1.5 if dir == 1 else 0.0), 13, 2.2, dir, p["eye"], "dot" if dir == 1 else "cute")


func _jelly(dir: int, fr: int) -> void:
	var pl := Pix.pal(Color8(220, 120, 220))
	for i in 4:
		var x := 8.0 + i * 2.7
		var w := 1.0 if (i + fr) % 2 == 0 else -1.0
		d.line(Vector2(x, 13), Vector2(x + w, 17), Color8(240, 160, 240))
		d.line(Vector2(x + w, 17), Vector2(x, 21), Color8(200, 110, 210))
	d.ball(12, 11, 7, 6 - fr * 0.5, pl, true)
	d.rect(5, 12, 14, 2, Color(0, 0, 0, 0))
	for x in range(5, 19):
		d.px(x, 12 + (x % 2), pl[2])
	d.ell(10, 8, 1.5, 1.0, Color8(255, 220, 255))
	if dir != 2:
		d.eyes(12 + (1.5 if dir == 1 else 0.0), 10, 2.0, dir, Color8(80, 20, 90), "dot")


func _necro(dir: int, fr: int) -> void:
	var robe := Pix.pal(Color8(70, 50, 100))
	var bob := float(fr)
	if dir == 2:
		_staff(Vector2(6, 21 + bob), Vector2(6, 6 + bob), GRN)
	var hem := PackedVector2Array([Vector2(9, 9 + bob), Vector2(15, 9 + bob), Vector2(18, 21 + bob), Vector2(16, 20 + bob), Vector2(14, 22 + bob), Vector2(12, 20 + bob), Vector2(10, 22 + bob), Vector2(8, 20 + bob), Vector2(6, 21 + bob)])
	d.spoly(hem, robe)
	d.rect(9, 15 + bob, 6, 1, Color8(200, 170, 80))
	d.ball(12, 8 + bob, 5, 4.8, robe)
	if dir != 2:
		var fx := 12.0 if dir == 0 else 14.0
		d.ell(fx, 9 + bob, 3.0, 2.8, Color8(10, 6, 18))
		d.eyes(fx, 9 + bob, 1.4, dir, GRN, "glow")
		_staff(Vector2(18, 21 + bob), Vector2(18, 6 + bob), GRN)
		d.ell(17.5, 15 + bob, 1.2, 1.2, Color8(200, 220, 190))


func _staff(a: Vector2, b: Vector2, orb: Color) -> void:
	d.line(a, b, WOOD, 1.2)
	d.ell(b.x, b.y - 1.0, 1.8, 1.8, orb)
	d.px(b.x - 0.5, b.y - 1.5, orb.lightened(0.6))


func _prism(_dir: int, fr: int) -> void:
	var top := Vector2(12, 2)
	var bot := Vector2(12, 21)
	var l := Vector2(5, 11)
	var r := Vector2(19, 11)
	var mid := Vector2(10.0 + fr * 3.0, 12)
	d.poly(PackedVector2Array([top, l, mid]), Color8(250, 200, 255))
	d.poly(PackedVector2Array([top, mid, r]), Color8(200, 140, 235))
	d.poly(PackedVector2Array([l, bot, mid]), Color8(150, 110, 220))
	d.poly(PackedVector2Array([mid, bot, r]), Color8(100, 80, 190))
	d.line(top, mid, WHT)
	d.px(8 + fr * 7, 4, WHT)
	d.px(4 + fr * 15, 17, CYN)


func _soul_eater(dir: int, fr: int) -> void:
	var pl := Pix.pal(Color8(90, 150, 230))
	var s := 1.0 if fr == 1 else -1.0
	for i in 3:
		d.line(Vector2(9 + i * 3, 16), Vector2(8 + i * 4 + s, 22), pl[1], 1.3)
	d.line(Vector2(7, 11), Vector2(3, 14 + s), pl[1], 1.4)
	d.line(Vector2(17, 11), Vector2(21, 14 - s), pl[1], 1.4)
	d.ball(12, 11, 6, 6.5, pl, true)
	if dir != 2:
		var fx := 12.0 if dir == 0 else 14.0
		d.ell(fx, 13, 2.8, 2.0 + fr * 0.6, Color8(10, 8, 30))
		for i in 3:
			d.px(fx - 1.5 + i * 1.5, 12, WHT)
		d.eyes(fx, 8.5, 2.0, dir, CYN, "glow")


func _turret(dir: int, fr: int) -> void:
	var base := Pix.pal(Color8(120, 100, 80))
	var brass := Pix.pal(Color8(200, 150, 70))
	d.spoly(PackedVector2Array([Vector2(5, 18), Vector2(19, 18), Vector2(20, 23), Vector2(4, 23)]), base)
	d.rect(5, 19.5, 14, 0.8, base[3])
	var rec := 1.0 if fr == 1 else 0.0
	if dir == 2:
		d.rect(11, 4 + rec, 2.5, 8, Color8(70, 70, 80))
	d.ball(12, 13, 6, 5.5, brass, true)
	if dir == 0:
		d.ell(12, 15 - rec, 2.6, 2.6, Color8(60, 60, 70))
		d.ell(12, 15 - rec, 1.4, 1.4, Color8(20, 20, 24) if fr == 0 else Color8(255, 200, 80))
	elif dir == 1:
		d.rect(15 - rec, 11.5, 7, 3, Color8(80, 80, 90))
		d.rect(21 - rec, 11, 1.5, 4, Color8(60, 60, 70))
		if fr == 1:
			d.ell(23, 13, 1.2, 1.5, YEL)
	if dir != 2:
		d.ell(9.5 if dir == 0 else 13.5, 11, 1.0, 1.0, RED)


func _shield_crystal(_dir: int, _fr: int) -> void:
	var cp := Pix.pal(Color8(160, 120, 240))
	d.spoly(PackedVector2Array([Vector2(12, 2), Vector2(17, 9), Vector2(15, 22), Vector2(9, 22), Vector2(7, 9)]), cp)
	d.spoly(PackedVector2Array([Vector2(6, 12), Vector2(8, 15), Vector2(8, 22), Vector2(4, 22), Vector2(3, 16)]), Pix.pal(Color8(130, 100, 220)))
	d.spoly(PackedVector2Array([Vector2(18, 11), Vector2(21, 16), Vector2(20, 22), Vector2(16, 22), Vector2(16, 14)]), Pix.pal(Color8(130, 100, 220)))
	d.line(Vector2(12, 3), Vector2(11, 20), Color8(235, 220, 255))


# ======================= ГРИБЫ И СТОЯЧИЕ =======================

func _shroom(dir: int, fr: int, p: Dictionary) -> void:
	var cp := Pix.pal(p["c"])
	var stem := Pix.pal(Color8(236, 226, 206))
	var sq := 1.2 if fr == 1 else 0.0
	d.spoly(PackedVector2Array([Vector2(9, 14), Vector2(15, 14), Vector2(16, 23), Vector2(8, 23)]), stem)
	if dir != 2:
		var fx := 12.0 + (1.5 if dir == 1 else 0.0)
		d.eyes(fx, 18, 1.8, dir, INK, "dot")
		if fr == 1:
			d.ell(fx, 20.5, 1.0, 0.8, INK)
	var cy := 11.0 + sq
	if p.get("glow", false):
		d.ell(12, cy, 11, 8, Color(1.0, 1.0, 0.6, 0.18))
	d.ball(12, cy, 9 + sq * 0.6, 6 - sq * 0.5, cp, true)
	d.ell(12, cy + 4.5 - sq * 0.4, 7.5, 1.3, cp[3])
	var sc: Color = p["spots"]
	for v: Vector2 in [Vector2(8, cy - 1), Vector2(13, cy - 3), Vector2(16, cy), Vector2(11, cy + 1.5)]:
		d.ell(v.x, v.y, 1.2, 0.9, sc)
	if p.get("ice", false):
		for x: int in [6, 9, 15, 18]:
			d.poly(PackedVector2Array([Vector2(x - 1, cy + 5), Vector2(x, cy + 8), Vector2(x + 1, cy + 5)]), Color8(220, 245, 255))
	if p.get("fuse", false):
		d.line(Vector2(12, cy - 5.5), Vector2(13.5, cy - 8.5), Color8(80, 60, 40))
		d.ell(14, cy - 9, 1.2 + fr * 0.5, 1.2 + fr * 0.5, YEL)
	if fr == 1:
		var pc: Color = p["puff"]
		for v: Vector2 in [Vector2(3, 8), Vector2(21, 9), Vector2(5, 16), Vector2(19, 17), Vector2(12, 2)]:
			d.ell(v.x, v.y, 1.6, 1.4, Color(pc.r, pc.g, pc.b, 0.85))


func _lurker(dir: int, fr: int) -> void:
	var pl := Pix.pal(Color8(40, 44, 60))
	d.line(Vector2(12, 14), Vector2(14, 6), Color8(60, 64, 80), 1.2)
	d.line(Vector2(14, 6), Vector2(17, 5), Color8(60, 64, 80), 1.2)
	d.ell(18, 6, 2.2 + fr * 0.4, 2.2 + fr * 0.4, Color8(255, 250, 170))
	d.ball(12, 18, 9, 5, pl, true)
	if dir != 2:
		var mx := 12.0 if dir == 0 else 14.0
		d.ell(mx, 19.5, 5.5, 1.0 + fr * 1.5, Color8(15, 8, 20))
		for i in 5:
			d.px(mx - 4 + i * 2, 18.5 + (0 if fr == 0 else -0.5), WHT)
		d.eyes(mx, 15.5, 3.0, dir, YEL, "glow")


func _tentacle(_dir: int, fr: int) -> void:
	d.ell(12, 21, 9, 2.5, Color8(40, 60, 100))
	d.ell(12, 21, 6, 1.5, Color8(20, 30, 60))
	var pl := Pix.pal(Color8(170, 80, 160))
	var bend := 3.0 if fr == 1 else -2.0
	var pts: Array = [Vector2(12, 21), Vector2(13, 16), Vector2(12 + bend * 0.5, 11), Vector2(12 + bend, 6), Vector2(12 + bend * 1.5, 3)]
	for i in range(pts.size() - 1):
		d.line(pts[i], pts[i + 1], pl[1], 4.0 - i * 0.8)
	for i in range(1, 4):
		var v: Vector2 = pts[i]
		d.px(v.x + 1, v.y, pl[0])
		d.px(v.x - 1, v.y + 1, Color8(240, 190, 220))


func _whirl(_dir: int, fr: int) -> void:
	for i in 3:
		var r := 10.0 - i * 3.0
		d.ell(12, 16, r, r * 0.45, [Color8(40, 90, 160), Color8(60, 130, 200), Color8(90, 170, 230)][i])
	for i in 6:
		var a := TAU * i / 6.0 + fr * 0.5 + i * 0.3
		var rr := 3.0 + i * 1.2
		d.px(12 + cos(a) * rr, 16 + sin(a) * rr * 0.45, WHT)
	d.ell(12, 16, 1.5, 0.8, Color8(15, 30, 60))


# ======================= ГУМАНОИДЫ =======================

func _human_idle(dir: int, fr: int, p: Dictionary) -> void:
	_human(dir, 0, p, 1.0 if fr == 1 else 0.0)


func _human(dir: int, fr: int, p: Dictionary, bob := 0.0) -> void:
	var skin: Color = p.get("skin", BONE)
	var cloth: Color = p.get("cloth", Color8(90, 70, 60))
	var bony: bool = p.get("bony", false)
	var weapon: String = p.get("weapon", "none")
	var sp := Pix.pal(skin)
	var cp := Pix.pal(cloth)
	var step := 1.0 if fr == 1 else 0.0
	if p.get("wings", false):
		for s: int in [-1, 1]:
			d.spoly(PackedVector2Array([Vector2(12 + s * 3, 12), Vector2(12 + s * 10, 7 - step), Vector2(12 + s * 9, 14), Vector2(12 + s * 4, 16)]), Pix.pal(Color8(90, 30, 40)))
	if dir == 2:
		_weapon(weapon, dir, step)
	var leg: Color = sp[1] if bony else cp[2]
	if dir == 1:
		d.rect(10 - step, 19, 2, 4, leg.darkened(0.25))
		d.rect(12.5 + step, 19, 2, 4, leg)
	else:
		d.rect(9.5, 19, 2, 4 - step, leg)
		d.rect(12.5, 19, 2, 4 - (1.0 - step) * 0.0, leg)
		d.rect(9.5, 22 - step, 2, 1, Color8(50, 40, 40))
		d.rect(12.5, 22, 2, 1, Color8(50, 40, 40))
	var tx0 := 8.5 if dir != 1 else 9.5
	var tx1 := 15.5 if dir != 1 else 14.5
	if bony:
		d.rect(11.5, 12.5 - bob, 1, 6.5, sp[2])
		for i in 3:
			d.rect(tx0 + 1, 13.0 + i * 1.8 - bob, tx1 - tx0 - 2, 1, sp[1])
		d.rect(10, 18 - bob, 4, 2, cp[1])
	else:
		d.spoly(PackedVector2Array([Vector2(tx0, 12.5 - bob), Vector2(tx1, 12.5 - bob), Vector2(tx1 + 0.5, 19.5), Vector2(tx0 - 0.5, 19.5)]), cp)
		d.rect(tx0, 17, tx1 - tx0, 1, cp[3])
	var arm: Color = sp[1] if bony else cp[1]
	if dir == 1:
		d.line(Vector2(12.5, 13.5 - bob), Vector2(15, 17 - step - bob), arm, 1.6)
		d.px(15, 17 - step - bob, sp[1])
	else:
		d.line(Vector2(8.2, 13.5 - bob), Vector2(7.2, 17.5 - bob), arm, 1.6)
		d.line(Vector2(15.8, 13.5 - bob), Vector2(16.8, 17.5 - bob), arm, 1.6)
		d.px(7, 17.5 - bob, sp[1])
		d.px(16.6, 17.5 - bob, sp[1])
	_head(p.get("head", "skull"), dir, p, sp, cp, bob)
	if dir != 2:
		_weapon(weapon, dir, step)


func _head(kind: String, dir: int, p: Dictionary, sp: Array, cp: Array, bob: float) -> void:
	var eye: Color = p.get("eye", RED)
	var hy := 8.0 - bob
	var fx := 12.0 if dir == 0 else 13.5
	match kind:
		"skull", "rot":
			d.ball(12, hy, 4.8, 4.4, sp)
			d.rect(10, hy + 3.0, 4, 1.6, sp[1])
			if kind == "rot":
				d.ell(9.5, hy - 2.5, 2.0, 1.2, Color8(90, 130, 60))
				d.ell(14.5, hy + 3.5, 1.5, 0.8, Color8(90, 130, 60))
			if dir != 2:
				for x: float in ([fx - 2.0, fx + 2.0] if dir == 0 else [fx + 1.5]):
					d.rect(x - 1, hy - 0.5, 2, 2, INK)
					d.px(x - 0.5, hy, eye)
				d.line(Vector2(fx - 1.5, hy + 3.6), Vector2(fx + 1.5, hy + 3.6), sp[3])
		"horns":
			d.ball(12, hy, 4.6, 4.3, sp)
			var hp := Pix.pal(Color8(60, 30, 30))
			for s: int in ([-1, 1] if dir != 1 else [1]):
				d.spoly(PackedVector2Array([Vector2(12 + s * 2.5, hy - 3), Vector2(12 + s * 6, hy - 7.5), Vector2(12 + s * 4.5, hy - 2)]), hp)
			if dir != 2:
				d.eyes(fx, hy + 0.5, 1.8, dir, eye, "glow")
				d.rect(fx - 1.5, hy + 2.5, 3, 0.8, Color8(60, 20, 20))
		"fish":
			d.spoly(PackedVector2Array([Vector2(9, hy - 3), Vector2(12, hy - 8), Vector2(15, hy - 3)]), Pix.pal(Color8(240, 150, 90)))
			d.ball(12, hy, 5.2, 4.6, sp)
			if dir == 0:
				for s: int in [-1, 1]:
					d.ell(12 + s * 3.2, hy - 0.5, 1.6, 1.6, eye)
					d.px(12 + s * 3.2, hy - 0.5, INK)
				d.rect(9.5, hy + 2.5, 5, 0.8, sp[3])
			elif dir == 1:
				d.ell(14.5, hy - 1, 1.6, 1.6, eye)
				d.px(15, hy - 1, INK)
				d.rect(14, hy + 2.5, 3, 0.8, sp[3])
				d.line(Vector2(10, hy), Vector2(10, hy + 2), sp[3])
		"helmet":
			var plume: Color = p.get("plume", RED)
			d.spoly(PackedVector2Array([Vector2(11, hy - 4), Vector2(14, hy - 7), Vector2(9 if dir == 1 else 15, hy - 2)]), Pix.pal(plume))
			d.ball(12, hy, 4.8, 4.6, Pix.pal(STEEL))
			if dir == 0:
				d.rect(9, hy, 6, 1.2, Color8(20, 20, 30))
				d.rect(10, hy, 1.5, 1, eye)
				d.rect(12.5, hy, 1.5, 1, eye)
			elif dir == 1:
				d.rect(12.5, hy, 4.5, 1.2, Color8(20, 20, 30))
				d.rect(14.5, hy, 1.5, 1, eye)
		"hood":
			d.ball(12, hy, 5, 4.8, cp)
			if dir != 2:
				d.ell(fx, hy + 0.8, 3.0, 2.6, Color8(10, 6, 18))
				d.eyes(fx, hy + 0.8, 1.4, dir, eye, "glow")
		"face", "mask", "hag":
			if kind == "hag":
				d.ball(12, hy, 5.2, 5, cp)
				if dir != 2:
					d.ball(fx, hy + 1, 3.4, 3.0, sp)
					d.eyes(fx, hy + 0.5, 1.4, dir, eye, "glow")
					d.rect(fx + (0.0 if dir == 0 else 2.5), hy + 1.5, 1, 2, sp[2])
			else:
				d.ball(12, hy, 4.6, 4.4, sp, kind == "mask")
				if dir != 2:
					if kind == "mask":
						d.eyes(fx, hy, 1.8, dir, eye, "glow")
						d.rect(fx - 0.5, hy + 1.5, 1, 2, sp[3])
					else:
						d.eyes(fx, hy + 0.5, 1.8, dir, eye, "cute")
						d.rect(fx - 0.5, hy + 3.0, 1.5, 0.6, Color8(190, 70, 90))
		"robot":
			d.line(Vector2(13, hy - 4), Vector2(14, hy - 7), Color8(90, 90, 100))
			d.px(14, hy - 7.5, eye)
			d.ball(12, hy, 4.8, 4.2, Pix.pal(Color8(150, 150, 160)), true)
			if dir == 0:
				d.rect(8.5, hy - 0.5, 7, 2, Color8(30, 30, 40))
				d.rect(9.5, hy, 5, 1, eye)
			elif dir == 1:
				d.rect(12.5, hy - 0.5, 4.5, 2, Color8(30, 30, 40))
				d.rect(14, hy, 2.5, 1, eye)


func _weapon(kind: String, dir: int, step: float) -> void:
	var hx := 17.0 if dir == 0 else (15.0 if dir == 1 else 7.0)
	var hy := 17.5 - step * (1.0 if dir == 1 else 0.0)
	match kind:
		"sword":
			if dir == 1:
				d.line(Vector2(hx, hy), Vector2(hx + 6, hy - 6), Color8(210, 220, 235), 1.5)
				d.rect(hx - 1, hy - 0.5, 2, 1.2, GOLD)
			else:
				d.line(Vector2(hx, hy), Vector2(hx, hy - 8), Color8(210, 220, 235), 1.5)
				d.rect(hx - 1.5, hy - 0.5, 3, 1, GOLD)
		"axe":
			d.line(Vector2(hx, hy + 2), Vector2(hx + (3.0 if dir == 1 else 0.0), hy - 7), WOOD, 1.2)
			var top := Vector2(hx + (3.0 if dir == 1 else 0.0), hy - 6)
			d.spoly(PackedVector2Array([top, top + Vector2(3.5, -2), top + Vector2(4, 3), top + Vector2(0, 2)]), Pix.pal(STEEL))
		"bow":
			var x := hx + (1.0 if dir == 1 else 0.5)
			var pts: Array = []
			for i in 9:
				var t := float(i) / 8.0
				pts.append(Vector2(x + sin(t * PI) * 3.0, hy - 9 + t * 11))
			for i in 8:
				d.line(pts[i], pts[i + 1], WOOD, 1.3)
			d.line(pts[0], pts[8], Color8(230, 230, 230))
		"trident", "lance":
			d.line(Vector2(hx, hy + 4), Vector2(hx + (2.0 if dir == 1 else 0.0), hy - 13), WOOD if kind == "trident" else STEEL, 1.2)
			var tip := Vector2(hx + (2.0 if dir == 1 else 0.0), hy - 13)
			if kind == "trident":
				d.rect(tip.x - 2, tip.y, 5, 1, GOLD)
				for o: int in [-2, 0, 2]:
					d.line(Vector2(tip.x + o, tip.y), Vector2(tip.x + o, tip.y - 3), GOLD)
			else:
				d.poly(PackedVector2Array([tip + Vector2(-1.5, 2), tip + Vector2(0, -4), tip + Vector2(1.5, 2)]), Color8(220, 230, 240))
		"flamer":
			if dir == 1:
				d.rect(hx - 1, hy - 2, 7, 2.5, Color8(90, 90, 100))
				d.rect(hx + 5, hy - 2.5, 2, 3.5, Color8(255, 150, 40))
			elif dir == 0:
				d.rect(hx - 1, hy - 3, 2.5, 6, Color8(90, 90, 100))
				d.rect(hx - 1, hy + 2.5, 2.5, 1.5, Color8(255, 150, 40))
			else:
				d.ball(12, 14, 3.5, 4.5, Pix.pal(Color8(200, 80, 50)))
		"tower":
			if dir == 0:
				d.spoly(PackedVector2Array([Vector2(6.5, 11), Vector2(17.5, 11), Vector2(17.5, 19), Vector2(12, 23), Vector2(6.5, 19)]), Pix.pal(Color8(110, 90, 70)))
				d.rect(11, 13, 2, 7, Color8(200, 190, 160))
				d.rect(8.5, 15, 7, 2, Color8(200, 190, 160))
			elif dir == 1:
				d.spoly(PackedVector2Array([Vector2(15, 10), Vector2(18.5, 11), Vector2(18.5, 21), Vector2(15, 22)]), Pix.pal(Color8(110, 90, 70)))
			else:
				d.spoly(PackedVector2Array([Vector2(8, 12), Vector2(16, 12), Vector2(16, 19), Vector2(8, 19)]), Pix.pal(Color8(90, 72, 56)))


func _mirror(dir: int, fr: int) -> void:
	var step := 1.0 if fr == 1 else 0.0
	d.rect(9, 19, 2, 4 - step, Color8(150, 110, 40))
	d.rect(13, 19, 2, 4, Color8(150, 110, 40))
	var w := 7.0 if dir != 1 else 4.0
	d.ball(12, 11, w, 8.5, Pix.pal(GOLD))
	if dir != 2:
		d.ball(12, 11, w - 1.8, 6.8, Pix.pal(Color8(190, 210, 235)), true)
		d.line(Vector2(9, 15), Vector2(13, 6), WHT)
		d.eyes(12, 10, 2.0, dir, Color8(120, 40, 180), "glow")
	else:
		d.ball(12, 11, w - 2, 7, Pix.pal(Color8(120, 80, 40)))
	d.ell(12, 2.5, 1.5, 1.5, Color8(230, 80, 120))


func _crab(dir: int, fr: int) -> void:
	var pl := Pix.pal(Color8(220, 90, 60))
	var step := 1.0 if fr == 1 else 0.0
	for s: int in [-1, 1]:
		for i in 3:
			var y := 18.0 + i * 1.5
			d.line(Vector2(12 + s * 5, y - 1), Vector2(12 + s * (9.0 + i), y + 2 - (step if (i % 2 == 0) else 0.0)), pl[2], 1.1)
	d.ball(12, 16, 7.5, 5, pl, true)
	for s: int in [-1, 1]:
		d.line(Vector2(12 + s * 6, 14), Vector2(12 + s * 8, 10 - step), pl[1], 1.4)
		d.ball(12 + s * 8.5, 8.5 - step, 2.8, 2.4, pl)
		d.rect(12 + s * 8.5 - 0.5, 6 - step, 1, 2.5, Color(0, 0, 0, 0))
	if dir != 2:
		for x: float in ([10.0, 14.0] if dir == 0 else [15.0]):
			d.line(Vector2(x, 12), Vector2(x, 10), pl[2])
			d.ell(x, 9.5, 1.0, 1.0, WHT)
			d.px(x, 9.5, INK)
		d.rect(10.5, 17.5, 3, 0.8, pl[3])


# ======================= ТЯЖЁЛЫЕ =======================

func _golem(dir: int, fr: int, p: Dictionary) -> void:
	var c: Color = p["c"]
	var pl := Pix.pal(c)
	var glow: Color = p["glow"]
	var step := 1.0 if fr == 1 else 0.0
	if p.get("metal", false) and dir != 0:
		d.rect(15, 1, 2.5, 6, Color8(70, 70, 76))
		d.ell(16, 0.8, 2, 1, Color(0.8, 0.8, 0.8, 0.7))
	d.ball(9, 21, 2.8, 2.4 - step * 0.4, pl)
	d.ball(15, 21 - step, 2.8, 2.4, pl)
	if dir == 1:
		d.ball(9, 14, 3, 4, Pix.pal(c.darkened(0.25)))
	d.ball(12, 13.5, 7.5, 6.5, pl, p.get("ice", false) or p.get("crystal", false))
	if p.get("crystal", false):
		for v: Vector2 in [Vector2(8, 8), Vector2(16, 9)]:
			d.spoly(PackedVector2Array([v + Vector2(-1.5, 2), v + Vector2(0, -4), v + Vector2(1.5, 2)]), Pix.pal(Color8(250, 190, 250)))
	# Трещины / заклёпки.
	if dir != 2 or true:
		if p.get("metal", false):
			for v: Vector2 in [Vector2(8, 12), Vector2(16, 12), Vector2(8, 16), Vector2(16, 16)]:
				d.px(v.x, v.y, pl[0])
			d.rect(9, 14, 6, 1, pl[3])
		else:
			d.line(Vector2(9, 11), Vector2(11, 14), glow)
			d.line(Vector2(11, 14), Vector2(10, 17), glow)
			d.line(Vector2(14, 12), Vector2(16, 15), glow)
	d.ball(12 + (1.5 if dir == 1 else 0.0), 6.5, 3.8, 3.2, pl)
	if dir != 2:
		d.eyes(12 + (1.5 if dir == 1 else 0.0), 6.8, 1.6, dir, glow, "glow")
	if dir == 1:
		d.ball(15, 15 + step * 0.5, 3.2, 4.5, pl)
		d.ball(15.5, 19.5 + step * 0.5, 2.6, 2.2, pl)
	else:
		for s: int in [-1, 1]:
			d.ball(12 + s * 7.8, 14 + (step if s < 0 else 0.0), 3, 4, pl)
			d.ball(12 + s * 8.2, 18.5 + (step if s < 0 else 0.0), 2.6, 2.2, pl)
	if p.get("crystal", false) and dir == 0:
		d.spoly(PackedVector2Array([Vector2(8, 13), Vector2(16, 13), Vector2(15, 20), Vector2(9, 20)]), Pix.pal(Color8(200, 235, 255)))
		d.line(Vector2(10, 18), Vector2(13, 14), WHT)


# ======================= МЕЛКИЕ ДЕМОНЫ, ЖАБЫ =======================

func _imp(dir: int, fr: int, p: Dictionary) -> void:
	var pl := Pix.pal(p["c"])
	var flap := 2.0 if fr == 1 else 0.0
	for s: int in [-1, 1]:
		d.spoly(PackedVector2Array([Vector2(12 + s * 3, 13), Vector2(12 + s * 9, 8 + flap), Vector2(12 + s * 8, 15), Vector2(12 + s * 4, 16)]), Pix.pal(Color8(110, 30, 40)))
	if dir != 0:
		d.line(Vector2(10, 19), Vector2(5, 21), pl[2], 1.2)
		d.poly(PackedVector2Array([Vector2(4, 20), Vector2(5.5, 22.5), Vector2(3, 22.5)]), pl[2])
	d.rect(10, 19, 1.6, 4, pl[2])
	d.rect(12.6, 19, 1.6, 4, pl[2])
	d.ball(12, 16, 4, 3.8, pl)
	d.ball(12 + (1.0 if dir == 1 else 0.0), 10, 4.8, 4.4, pl, true)
	for s: int in ([-1, 1] if dir != 1 else [1]):
		d.poly(PackedVector2Array([Vector2(12 + s * 2.5, 6.5), Vector2(12 + s * 4.5, 2.5), Vector2(12 + s * 4.5, 7.0)]), Color8(250, 230, 200))
	d.eyes(12 + (1.5 if dir == 1 else 0.0), 10, 2.0, dir, p["eye"], "glow")
	if dir == 0:
		d.rect(11, 12.5, 2, 0.8, Color8(70, 20, 20))
	if p.get("bomb", false):
		d.ball(12, 1.5 + 0.0, 3, 2.6, Pix.pal(Color8(60, 60, 70)), true)
		d.px(14, -0.5 + fr, YEL)


func _toad(dir: int, fr: int, p: Dictionary) -> void:
	var pl := Pix.pal(p["c"])
	for s: int in [-1, 1]:
		d.ball(12 + s * 7, 21, 3, 2, pl)
	d.ball(12, 16, 8.5, 6.5, pl, true)
	d.ball(12, 18, 5.5, 3.5, Pix.pal(Color8(230, 220, 160)))
	for v: Vector2 in [Vector2(7, 14), Vector2(16, 12), Vector2(10, 11)]:
		d.ell(v.x, v.y, 1.1, 0.9, pl[3])
	if fr == 1 and dir != 2:
		d.ball(12, 20, 4, 2.6, Pix.pal(Color8(250, 210, 200)))
	if dir != 2:
		for x: float in ([7.5, 16.5] if dir == 0 else [15.5]):
			d.ball(x, 10, 2.6, 2.6, pl)
			d.ell(x, 10, 1.4, 1.4, YEL)
			d.rect(x - 0.3, 9.5, 0.8, 1.6, INK)
		d.line(Vector2(8 if dir == 0 else 12, 15.5), Vector2(16 if dir == 0 else 19, 15.5), pl[3])
	else:
		for x: int in [7.5, 16.5]:
			d.ball(x, 10, 2.6, 2.6, pl)


# ======================= ЗВЕРИ =======================

func _beast(dir: int, fr: int, p: Dictionary) -> void:
	var kind: String = p["kind"]
	var pl := Pix.pal(p["c"])
	var eye: Color = p["eye"]
	var run := 1.0 if fr == 1 else 0.0
	match kind:
		"lizard":
			if dir == 1:
				d.poly(PackedVector2Array([Vector2(1, 18), Vector2(8, 16), Vector2(8, 20)]), pl[2])
				for i in 4:
					var x := 7.0 + i * 3.0
					var o := run * (1.0 if i % 2 == 0 else -1.0)
					d.line(Vector2(x, 19), Vector2(x + o, 22), pl[2], 1.2)
				d.ball(11, 18, 6.5, 3.2, pl, true)
				d.ball(18, 16, 3.6, 2.8, pl)
				d.eyes(18, 15.5, 1.0, 1, eye, "dot")
				for x: int in [8, 11, 14]:
					d.px(x, 16, Color8(255, 220, 80))
			else:
				var hy := 20.0 if dir == 0 else 9.0
				var ty := 6.0 if dir == 0 else 22.0
				d.line(Vector2(12, 15), Vector2(12 + run, ty), pl[2], 2.0)
				for s: int in [-1, 1]:
					d.line(Vector2(12, 12), Vector2(12 + s * 6, 11 + run * s), pl[2], 1.2)
					d.line(Vector2(12, 17), Vector2(12 + s * 6, 18 - run * s), pl[2], 1.2)
				d.ball(12, 14.5, 3.5, 5.5, pl, true)
				d.ball(12, hy, 3.2, 2.8, pl)
				if dir == 0:
					d.eyes(12, hy, 1.6, 0, eye, "dot")
		"hound":
			var mane := Color8(255, 140, 40)
			if dir == 1:
				d.line(Vector2(4, 13), Vector2(1, 10 - run), mane, 1.4)
				for i in 4:
					var x := 6.0 + i * 3.0
					var o := run * (1.5 if i % 2 == 0 else -1.5)
					d.line(Vector2(x, 16), Vector2(x + o, 22.5), pl[2], 1.5)
				d.ball(10.5, 15, 6.5, 3.6, pl, true)
				for i in 3:
					d.poly(PackedVector2Array([Vector2(8 + i * 3, 12), Vector2(9 + i * 3 - run, 8 - (i % 2)), Vector2(10 + i * 3, 12)]), mane)
				d.ball(18, 11.5, 3.6, 3.2, pl)
				d.rect(20, 12, 3, 2, pl[1])
				d.poly(PackedVector2Array([Vector2(16, 9), Vector2(16.5, 5.5), Vector2(18.5, 8.5)]), pl[2])
				d.px(19, 10.5, eye)
				d.px(21.5, 13.5, WHT)
			else:
				var hy := 10.5 if dir == 0 else 9.0
				for s: int in [-1, 1]:
					d.line(Vector2(12 + s * 3, 16), Vector2(12 + s * 3.5, 22.5 - (run if s < 0 else 0.0)), pl[2], 1.6)
				d.ball(12, 16, 5.5, 4.5, pl, true)
				for i in 3:
					d.poly(PackedVector2Array([Vector2(8 + i * 3, 13), Vector2(9 + i * 3, 8.5 - run), Vector2(10 + i * 3, 13)]), mane)
				d.ball(12, hy, 4.2, 3.8, pl)
				for s: int in [-1, 1]:
					d.poly(PackedVector2Array([Vector2(12 + s * 2, hy - 3), Vector2(12 + s * 4, hy - 6.5), Vector2(12 + s * 4.2, hy - 1.5)]), pl[2])
				if dir == 0:
					d.eyes(12, hy - 0.5, 1.8, 0, eye, "glow")
					d.rect(10.5, hy + 2, 3, 1.5, pl[3])
					d.px(11, hy + 3.5, WHT)
					d.px(13, hy + 3.5, WHT)
				else:
					d.line(Vector2(12, 20), Vector2(12 + run, 23), pl[2], 1.3)
		"serpent":
			if dir == 1:
				var pts: Array = []
				for i in 9:
					var t := float(i) / 8.0
					pts.append(Vector2(2 + t * 14, 19 + sin(t * TAU + run * PI) * 2.5))
				for i in 8:
					d.line(pts[i], pts[i + 1], pl[1], 4.0 - i * 0.2)
					d.px((pts[i] as Vector2).x, (pts[i] as Vector2).y - 1.5, pl[0])
				d.line(pts[8], Vector2(17, 12), pl[1], 3.2)
				d.ball(18.5, 11, 3.8, 2.8, pl, true)
				d.poly(PackedVector2Array([Vector2(14, 9), Vector2(16, 5), Vector2(18, 8.5)]), Color8(240, 150, 90))
				d.px(19.5, 10, eye)
			else:
				for i in 3:
					d.ell(12, 20 - i * 2.2, 8 - i * 1.6, 2.4, pl[1 + (i % 2)])
				d.ball(12, 10.5 + (0.0 if dir == 0 else -1.0), 4.0, 3.4, pl, true)
				d.poly(PackedVector2Array([Vector2(9, 8), Vector2(12, 3 - run), Vector2(15, 8)]), Color8(240, 150, 90))
				if dir == 0:
					d.eyes(12, 10.5, 2.0, 0, eye, "dot")
					d.rect(11.5, 13.5, 1, 1.5, Color8(220, 60, 80))
		"horror":
			var tw := run
			for s: int in [-1, 1]:
				for i in 2:
					var x := 12 + s * (4.0 + i * 4.0)
					d.line(Vector2(x, 13), Vector2(x + s * 2, 22.5 - (tw if (i + (1 if s > 0 else 0)) % 2 == 0 else 0.0)), pl[2], 2.0)
			d.ball(12, 13, 9, 6.5, pl, true)
			for i in 5:
				d.poly(PackedVector2Array([Vector2(5 + i * 3.5, 9), Vector2(6 + i * 3.5 + tw, 3.5 + (i % 2) * 1.5), Vector2(7.5 + i * 3.5, 9)]), pl[3])
			if dir != 2:
				var fx := 12.0 if dir == 0 else 15.0
				d.ell(fx, 15, 4, 1.5 + tw * 0.5, Color8(10, 4, 16))
				for i in 4:
					d.px(fx - 3 + i * 2, 14.5, WHT)
				d.eyes(fx, 11, 2.6, dir, eye, "glow")


# ======================= ГАЛЕРЕЯ =======================

func _save_gallery(path: String, list: Array, cell: int, cols: int) -> void:
	var per_row := 3
	var rows := int(ceil(list.size() / float(cols)))
	var g := Image.create(cols * per_row * cell, rows * cell, false, Image.FORMAT_RGBA8)
	g.fill(Color8(52, 50, 72))
	for i in list.size():
		var e: Array = list[i]
		var sheet: Image = e[1]
		var fsz: int = e[2]
		var gx := (i % cols) * per_row * cell
		var gy := int(i / cols) * cell
		for r in 3:
			var fr := Image.create(fsz, fsz, false, Image.FORMAT_RGBA8)
			fr.blit_rect(sheet, Rect2i(0, r * fsz, fsz, fsz), Vector2i.ZERO)
			if fsz != cell:
				fr.resize(cell, cell, Image.INTERPOLATE_NEAREST)
			g.blend_rect(fr, Rect2i(0, 0, cell, cell), Vector2i(gx + r * cell, gy))
	g.resize(g.get_width() * (3 if cell == 24 else 2), g.get_height() * (3 if cell == 24 else 2), Image.INTERPOLATE_NEAREST)
	g.save_png(ProjectSettings.globalize_path(path))


# ======================= БОССЫ (кадр 48) =======================
# boss_<биом>_<номер>: 0 — король-слизень (кадры: покой, приплюснут, вытянут), 1 — колдун/королева,
# 2 — титан, 3 — финальный босс биома (по 1 кадру).

func _bosses() -> void:
	var kings: Array = [
		{"c": Color8(96, 200, 90), "crown": "gold"},
		{"c": Color8(170, 190, 80), "extra": "poison", "crown": "rust"},
		{"c": Color8(240, 100, 40), "extra": "flame", "eye": Color8(90, 20, 10), "crown": "gold"},
		{"c": Color8(150, 215, 245), "extra": "ice", "eye": Color8(30, 60, 110), "crown": "ice"},
		{"c": Color8(90, 170, 90), "crown": "flower"},
		{"c": Color8(84, 54, 130), "extra": "shadow", "eye": PNK, "es": "glow", "crown": "dark"},
		{"c": Color8(200, 50, 50), "extra": "horns", "eye": YEL, "es": "glow", "crown": "dark"},
		{"c": Color8(60, 160, 190), "crown": "coral"},
		{"c": Color8(230, 150, 70), "extra": "flame", "eye": INK, "crown": "gear"},
		{"c": Color8(230, 140, 230), "extra": "crystal", "eye": Color8(80, 20, 90), "crown": "crystal"},
	]
	var casters: Array = [
		{"robe": Color8(90, 60, 130), "head": "skull", "eye": Color8(200, 120, 255), "crown": "bone", "weapon": "staff", "orb": Color8(200, 120, 255)},
		{"robe": Color8(50, 80, 60), "head": "hood", "eye": GRN, "weapon": "staff", "orb": GRN, "cloth_head": Color8(40, 64, 48)},
		{"robe": Color8(170, 50, 40), "head": "mask", "skin": GOLD, "eye": YEL, "weapon": "staff", "orb": Color8(255, 140, 40), "crown": "flame"},
		{"robe": Color8(190, 220, 245), "head": "face", "skin": Color8(220, 235, 250), "eye": Color8(40, 120, 200), "hair": Color8(245, 250, 255), "crown": "ice", "weapon": "staff", "orb": CYN},
		{"robe": Color8(80, 100, 60), "head": "hag", "skin": Color8(150, 180, 100), "eye": YEL, "weapon": "crook", "orb": Color8(200, 255, 120), "cloth_head": Color8(70, 60, 50)},
		{"robe": Color8(30, 24, 44), "head": "hood", "eye": WHT, "weapon": "scythe", "cloth_head": Color8(26, 20, 38)},
		{"robe": Color8(60, 30, 40), "head": "horns", "skin": Color8(200, 50, 50), "eye": YEL, "weapon": "sword", "wings": "demon"},
		{"robe": Color8(50, 110, 120), "head": "fish", "skin": Color8(70, 160, 150), "eye": YEL, "weapon": "trident", "crown": "coral"},
		{"robe": Color8(120, 80, 50), "head": "skull", "eye": Color8(255, 150, 40), "weapon": "wrench", "goggles": true},
		{"robe": Color8(240, 225, 235), "head": "face", "skin": Color8(250, 225, 225), "eye": Color8(200, 40, 70), "hair": Color8(196, 110, 160), "crown": "crystal", "weapon": "none", "wings": "crystal"},
	]
	var titans: Array = [
		{"c": Color8(90, 74, 70), "glow": Color8(255, 120, 30), "horns": true},
		{"c": Color8(220, 214, 190), "glow": RED, "skull": true},
		{"c": Color8(80, 50, 40), "glow": Color8(255, 150, 40), "horns": true, "flames": true},
		{"c": Color8(150, 200, 235), "glow": Color8(220, 250, 255), "ice": true, "spikes": true},
		{"c": Color8(100, 120, 70), "glow": YEL, "moss": true},
		{"beast": "horror", "kind": "horror", "c": Color8(40, 30, 70), "eye": WHT},
		{"c": Color8(140, 40, 90), "glow": YEL, "horns": true, "wings": "demon"},
		{"beast": "serpent", "kind": "serpent", "c": Color8(40, 110, 170), "eye": YEL},
		{"c": Color8(176, 120, 64), "glow": RED, "metal": true, "drill": true},
		{"c": Color8(200, 130, 210), "glow": CYN, "crystal": true},
	]
	for b in 10:
		make("boss_%d_0" % b, 3, 48, _king.bind(kings[b]))
		make("boss_%d_1" % b, 1, 48, _caster.bind(casters[b]))
		var t: Dictionary = titans[b]
		if t.has("beast"):
			make("boss_%d_2" % b, 1, 48, _beast.bind(t))
		else:
			make("boss_%d_2" % b, 1, 48, _titan.bind(t))
	make("boss_0_3", 1, 48, _titan.bind({"c": Color8(110, 116, 140), "glow": CYN, "crown": "stone"}))
	make("boss_1_3", 1, 48, _caster.bind({"robe": Color8(40, 44, 90), "head": "skull", "eye": CYN, "crown": "gold", "weapon": "greatsword", "cape": Color8(120, 20, 30)}))
	make("boss_2_3", 1, 48, _titan.bind({"c": Color8(70, 36, 30), "glow": Color8(255, 170, 40), "horns": true, "wings": "demon", "flames": true}))
	make("boss_3_3", 1, 48, _caster.bind({"robe": Color8(200, 230, 250), "head": "face", "skin": Color8(200, 225, 245), "eye": Color8(40, 120, 200), "beard": Color8(250, 252, 255), "crown": "ice", "weapon": "staff", "orb": CYN, "cape": Color8(80, 140, 210)}))
	make("boss_4_3", 1, 48, _toad_queen)
	make("boss_5_3", 1, 48, _shadow_prince)
	make("boss_6_3", 1, 48, _titan.bind({"c": Color8(110, 30, 120), "glow": PNK, "horns": true, "wings": "demon4", "crown": "dark"}))
	make("boss_7_3", 1, 48, _kraken)
	make("boss_8_3", 1, 48, _machine)
	make("boss_9_3", 1, 48, _heart)


func _crown(kind: String, cx: float, top: float, w: float) -> void:
	var col: Color = {"gold": GOLD, "rust": Color8(170, 110, 60), "ice": Color8(200, 240, 255), "flower": Color8(240, 130, 180),
		"dark": Color8(60, 40, 80), "coral": Color8(240, 110, 100), "gear": Color8(190, 170, 120), "crystal": Color8(240, 150, 230),
		"bone": BONE, "flame": Color8(255, 150, 40), "stone": Color8(150, 156, 170)}.get(kind, GOLD)
	var cp := Pix.pal(col)
	if kind == "flower":
		for i in 3:
			var x := cx - w * 0.5 + i * w * 0.5
			d.ball(x, top - 0.5, 1.6, 1.4, cp)
			d.px(x, top - 0.5, YEL)
		return
	d.rect(cx - w * 0.5, top - 1.2, w, 1.6, cp[1])
	var n := 3 if w < 8 else 5
	for i in n:
		var x := cx - w * 0.5 + w * i / (n - 1)
		var h := 2.5 + (1.5 if i == n / 2 else 0.0)
		if kind == "coral":
			d.line(Vector2(x, top - 1), Vector2(x + 0.5, top - 1 - h), cp[1], 1.0)
			d.px(x + 1, top - h, cp[0])
		else:
			d.spoly(PackedVector2Array([Vector2(x - 0.9, top - 1), Vector2(x, top - 1 - h), Vector2(x + 0.9, top - 1)]), cp)
	if kind in ["gold", "dark", "crystal", "ice"]:
		d.px(cx, top - 0.8, RED if kind == "gold" else (PNK if kind == "dark" else CYN))


func _king(dir: int, fr: int, p: Dictionary) -> void:
	var top: float = _slime(dir, fr, p)
	_crown(p.get("crown", "gold"), 12, top + 1.5, 7.0)


func _caster(dir: int, _fr: int, p: Dictionary) -> void:
	var robe: Color = p["robe"]
	var rp := Pix.pal(robe)
	var skin: Color = p.get("skin", BONE)
	var sp := Pix.pal(skin)
	var weapon: String = p.get("weapon", "staff")
	var wings: String = p.get("wings", "")
	if wings == "demon":
		for s: int in [-1, 1]:
			d.spoly(PackedVector2Array([Vector2(12 + s * 3, 10), Vector2(12 + s * 11.5, 2), Vector2(12 + s * 11, 13), Vector2(12 + s * 4, 15)]), Pix.pal(Color8(90, 24, 36)))
			d.line(Vector2(12 + s * 4, 11), Vector2(12 + s * 11, 3), Color8(50, 10, 20))
	elif wings == "crystal":
		for s: int in [-1, 1]:
			for i in 3:
				d.spoly(PackedVector2Array([Vector2(12 + s * 4, 11 + i), Vector2(12 + s * (9.0 + i * 1.5), 1.5 + i * 4.5), Vector2(12 + s * (8.0 + i), 9 + i * 3)]), Pix.pal(Color8(220, 40, 70)))
	if p.has("cape"):
		d.spoly(PackedVector2Array([Vector2(8, 10), Vector2(16, 10), Vector2(19.5, 23), Vector2(4.5, 23)]), Pix.pal(p["cape"]))
	if dir == 2:
		_big_weapon(weapon, dir, p)
	d.spoly(PackedVector2Array([Vector2(9, 10), Vector2(15, 10), Vector2(19, 23), Vector2(5, 23)]), rp)
	d.rect(5.5, 22, 13, 1, rp[3])
	d.rect(11.5, 11, 1, 11, (rp[0] as Color).lightened(0.2))
	for s: int in [-1, 1]:
		d.ball(12 + s * 3.8, 11.2, 2.4, 2.0, rp)
	if dir != 2:
		d.line(Vector2(8, 12), Vector2(6.5, 16.5), rp[1], 2.0)
		d.line(Vector2(16, 12), Vector2(17.5, 16.5), rp[1], 2.0)
		d.ell(6.5, 17, 1.0, 1.0, sp[1])
		d.ell(17.5, 17, 1.0, 1.0, sp[1])
	if p.has("hair"):
		# Волосы: копна за головой и пряди до плеч (со спины — до пояса).
		var hpal := Pix.pal(p["hair"])
		d.ball(12, 7, 5.8, 5.4, hpal)
		for sd: int in [-1, 1]:
			d.spoly(PackedVector2Array([Vector2(12 + sd * 5.6, 6), Vector2(12 + sd * 6.4, 17 if dir != 2 else 19), Vector2(12 + sd * 3.0, 15 if dir != 2 else 19), Vector2(12 + sd * 3.5, 8)]), hpal)
	var hp := p.duplicate()
	if p.has("cloth_head"):
		_head(p["head"], dir, hp, sp, Pix.pal(p["cloth_head"]), 1.0)
	else:
		_head(p["head"], dir, hp, sp, rp, 1.0)
	if p.has("hair") and dir != 2:
		var hpal2 := Pix.pal(p["hair"])
		d.ell(12 + (1.0 if dir == 1 else 0.0), 4.2, 4.8, 1.9, hpal2[1])
		d.ell(10.5, 3.8, 1.6, 0.7, hpal2[0])
		if dir == 0:
			d.px(9, 5.5, hpal2[2])
			d.px(15, 5.5, hpal2[2])
	if p.has("beard") and dir != 2:
		d.spoly(PackedVector2Array([Vector2(9, 9), Vector2(15, 9), Vector2(12, 15)]), Pix.pal(p["beard"]))
	if p.get("goggles", false) and dir != 2:
		d.rect(8, 5.5, 8, 1, Color8(90, 70, 50))
		d.ell(10, 6, 1.4, 1.4, Color8(255, 200, 80))
		d.ell(14, 6, 1.4, 1.4, Color8(255, 200, 80))
	if p.has("crown"):
		_crown(p["crown"], 12, 3.2, 7.0)
	if dir != 2:
		_big_weapon(weapon, dir, p)


func _big_weapon(kind: String, dir: int, p: Dictionary) -> void:
	var hx := 18.0 if dir != 2 else 6.0
	match kind:
		"staff", "crook":
			d.line(Vector2(hx, 22), Vector2(hx, 4), WOOD, 1.3)
			if kind == "crook":
				d.line(Vector2(hx, 4), Vector2(hx + 2, 2.5), WOOD, 1.3)
				d.line(Vector2(hx + 2, 2.5), Vector2(hx + 3, 4.5), WOOD, 1.3)
			var orb: Color = p.get("orb", CYN)
			d.ell(hx, 3, 2.0, 2.0, orb)
			d.ell(hx, 3, 3.5, 3.5, Color(orb.r, orb.g, orb.b, 0.25))
			d.px(hx - 0.7, 2.3, orb.lightened(0.7))
		"scythe":
			d.line(Vector2(hx, 23), Vector2(hx - 1, 3), WOOD, 1.2)
			var pts := PackedVector2Array([Vector2(hx - 1, 3), Vector2(hx - 9, 4.5), Vector2(hx - 11, 8), Vector2(hx - 7, 5.5), Vector2(hx - 1, 5)])
			d.spoly(pts, Pix.pal(Color8(200, 210, 230)))
		"trident":
			d.line(Vector2(hx, 23), Vector2(hx, 4), GOLD, 1.0)
			d.rect(hx - 2.5, 4, 5, 1, GOLD)
			for o: int in [-2, 0, 2]:
				d.line(Vector2(hx + o, 4), Vector2(hx + o, 0.5), GOLD)
		"sword", "greatsword":
			var l := 14.0 if kind == "greatsword" else 10.0
			d.line(Vector2(hx, 18), Vector2(hx, 18 - l), Color8(210, 220, 235), 1.6 if kind == "greatsword" else 1.3)
			d.rect(hx - 2, 17.5, 4, 1, GOLD)
			if p.get("head", "") == "horns":
				d.line(Vector2(hx + 0.6, 17), Vector2(hx + 0.6, 18 - l), Color8(255, 140, 40))
		"wrench":
			d.line(Vector2(hx, 21), Vector2(hx, 9), STEEL, 1.4)
			d.ball(hx, 8, 2.4, 2.0, Pix.pal(STEEL))
			d.rect(hx - 0.6, 5.5, 1.2, 2.5, Color(0, 0, 0, 0))
			d.ell(hx, 7, 0.8, 1.4, Color8(30, 30, 40))


func _titan(dir: int, _fr: int, p: Dictionary) -> void:
	var wings: String = p.get("wings", "")
	if wings != "":
		var n := 2 if wings == "demon4" else 1
		for j in n:
			for s: int in [-1, 1]:
				var yo := j * 5.0
				d.spoly(PackedVector2Array([Vector2(12 + s * 4, 10 + yo), Vector2(12 + s * 12, 1 + yo * 1.4), Vector2(12 + s * 11.5, 12 + yo), Vector2(12 + s * 5, 15 + yo)]), Pix.pal(Color8(80, 20, 40) if j == 0 else Color8(60, 16, 50)))
	_golem(dir, 0, p)
	var glow: Color = p.get("glow", RED)
	var hx := 12.0 + (1.5 if dir == 1 else 0.0)
	if p.get("horns", false):
		for s: int in ([-1, 1] if dir != 1 else [1]):
			d.spoly(PackedVector2Array([Vector2(hx + s * 2.5, 4.5), Vector2(hx + s * 6.5, 0.5), Vector2(hx + s * 4.5, 5.5)]), Pix.pal(Color8(60, 40, 40)))
	if p.get("skull", false) and dir != 2:
		d.rect(hx - 2.5, 8.2, 5, 1.2, Color8(60, 50, 40))
		for i in 4:
			d.px(hx - 2 + i * 1.3, 8.5, BONE)
		for i in 3:
			d.rect(8.5, 11.5 + i * 2, 7, 0.8, Color8(150, 140, 120))
	if p.get("flames", false):
		for i in 3:
			var x := hx - 3 + i * 3
			d.poly(PackedVector2Array([Vector2(x - 1.2, 4), Vector2(x, 0.5 - (i % 2)), Vector2(x + 1.2, 4)]), Color8(255, 170, 40))
	if p.get("spikes", false):
		for v: Vector2 in [Vector2(5, 10), Vector2(19, 10), Vector2(9, 7.5), Vector2(15, 7.5)]:
			d.spoly(PackedVector2Array([v + Vector2(-1.2, 1.5), v + Vector2(0, -3.5), v + Vector2(1.2, 1.5)]), Pix.pal(Color8(230, 248, 255)))
	if p.get("moss", false):
		for v: Vector2 in [Vector2(8, 10), Vector2(15, 12), Vector2(11, 16), Vector2(5, 13)]:
			d.ell(v.x, v.y, 1.8, 1.0, Color8(80, 140, 60))
		d.rect(9, 18, 1, 3, Color8(120, 170, 80))
	if p.get("drill", false):
		var dx := 21.0 if dir != 2 else 3.0
		d.spoly(PackedVector2Array([Vector2(dx - 2.5, 14), Vector2(dx + 2.5, 14), Vector2(dx, 23)]), Pix.pal(STEEL))
		for i in 3:
			d.line(Vector2(dx - 2 + i * 0.6, 15.5 + i * 2), Vector2(dx + 1.5 - i * 0.6, 16.5 + i * 2), Color8(90, 90, 100))
	if p.has("crown"):
		_crown(p["crown"], hx, 3.6, 6.0)
	if glow != RED and dir != 2 and p.get("crown", "") == "stone":
		for v: Vector2 in [Vector2(9, 13), Vector2(15, 15), Vector2(12, 11)]:
			d.px(v.x, v.y, glow)


func _toad_queen(dir: int, fr: int) -> void:
	_toad(dir, fr, {"c": Color8(90, 140, 70)})
	d.ell(12, 6.2, 6, 1.4, Color8(60, 150, 70))
	_crown("flower", 12, 5.5, 6)


func _shadow_prince(dir: int, fr: int) -> void:
	for i in 4:
		var a := -0.6 + i * 0.4
		d.line(Vector2(12, 14), Vector2(12, 14) + Vector2.from_angle(PI / 2 + a * 2.0) * 10.0, Color8(30, 20, 50), 1.6)
	_shade(dir, fr, {"c": Color8(36, 26, 60), "eye": Color8(255, 80, 200)})
	_crown("dark", 12, 4.3, 7)


func _kraken(dir: int, _fr: int) -> void:
	var pl := Pix.pal(Color8(90, 80, 170))
	for i in 6:
		var a := PI * (0.1 + 0.8 * i / 5.0)
		var base := Vector2(12, 14)
		var mid := base + Vector2(cos(a) * 7, sin(a) * 4 + 3)
		var tip := mid + Vector2(cos(a) * 4 + (1.5 if i % 2 == 0 else -1.5), 5)
		d.line(base, mid, pl[2], 2.6)
		d.line(mid, tip, pl[2], 1.6)
		d.px(mid.x, mid.y, Color8(230, 180, 220))
	d.ball(12, 9, 8, 7.5, pl, true)
	for v: Vector2 in [Vector2(8, 5), Vector2(15, 4), Vector2(17, 9)]:
		d.ell(v.x, v.y, 0.9, 0.9, pl[0])
	if dir != 2:
		var fx := 12.0 if dir == 0 else 14.0
		for x: float in ([fx - 3.5, fx + 3.5] if dir == 0 else [fx + 3.0]):
			d.ell(x, 11, 2.0, 1.6, YEL)
			d.rect(x - 1.5, 10.8, 3, 0.6, INK)


func _machine(dir: int, _fr: int) -> void:
	var brass := Pix.pal(Color8(190, 140, 70))
	var iron := Pix.pal(Color8(90, 92, 104))
	d.rect(13.5, 1, 3, 6, iron[2])
	d.ell(15, 1, 2.5, 1.0, Color(0.8, 0.8, 0.8, 0.6))
	for x: int in [5, 12, 19]:
		d.ball(x, 20, 3.2, 3.2, iron)
		d.ell(x, 20, 1.0, 1.0, brass[1])
	d.spoly(PackedVector2Array([Vector2(3, 8), Vector2(21, 8), Vector2(22, 19), Vector2(2, 19)]), brass)
	d.rect(3, 12.5, 18, 1, brass[3])
	for x in range(5, 21, 4):
		d.px(x, 9.5, brass[0])
	if dir != 2:
		var fx := 12.0 if dir == 0 else 17.0
		d.ball(fx, 15.5, 3.5, 2.6, iron)
		d.ell(fx, 15.5, 2.2, 1.4, Color8(255, 120, 40))
		d.ell(fx, 15.5, 1.0, 0.6, YEL)
		if dir == 1:
			d.spoly(PackedVector2Array([Vector2(21, 14), Vector2(24, 19), Vector2(20, 19)]), iron)


func _heart(_dir: int, _fr: int) -> void:
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var v := Vector2(12, 12) + Vector2(cos(a) * 10.0, sin(a) * 6.0)
		d.spoly(PackedVector2Array([v + Vector2(-1, 1.5), v + Vector2(0, -2.5), v + Vector2(1, 1.5)]), Pix.pal(Color8(230, 170, 255)))
	var hp := Pix.pal(Color8(220, 60, 140))
	d.ball(9, 9, 4.5, 4.5, hp, true)
	d.ball(15, 9, 4.5, 4.5, hp, true)
	d.spoly(PackedVector2Array([Vector2(4.6, 10), Vector2(19.4, 10), Vector2(12, 21)]), hp)
	d.line(Vector2(8, 7), Vector2(10, 14), Color8(255, 210, 240))
	d.line(Vector2(15, 7), Vector2(13, 15), Color8(170, 40, 110))
	d.ell(12, 12, 2.0, 2.0, Color8(255, 230, 250))
