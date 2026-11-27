extends SceneTree
## Иконки снаряжения (assets/items.png, 16x16, номер = "icon" базы в items.gd) и материалов
## (assets/mats.png, 12x12, номер = "icon" в crafting.gd) — пиксель-арт по референсу владельца
## (лист иконок оружия/брони). Свет сверху-слева, тёмная обводка.
##   godot --headless --path . --script res://tools/gen_icons.gd

const Pix := preload("res://tools/pix.gd")

const STEEL := Color8(200, 208, 222)
const IRON := Color8(140, 146, 160)
const GOLD := Color8(236, 184, 70)
const WOOD := Color8(140, 92, 52)
const LEATHER := Color8(150, 96, 56)
const RED := Color8(220, 50, 50)
const BLUE := Color8(70, 120, 230)
const GEM := Color8(90, 220, 240)
const PURPLE := Color8(150, 80, 210)
const WHITE := Color8(245, 245, 250)

var d: Pix = Pix.new()


func _init() -> void:
	var items: Array = [
		_sword, _axe, _dagger, _leather, _chain, _ring, _amulet, _bow, _longbow, _wand,
		_staff, _buckler, _tower, _quiver, _tome, _cap, _helm, _circlet, _cape, _mantle,
		_shoes, _greaves, _band, _talisman, _greataxe, _mace, _hunter_bow, _crossbow, _elem_staff, _sage_book,
		_knife, _stiletto, _cleaver, _katar, _acolyte_rod, _beads, _light_staff, _knuckles,
	]
	var img := Image.create(items.size() * 16, 16, false, Image.FORMAT_RGBA8)
	for i in items.size():
		d.begin(16)
		d.k = 1.0
		(items[i] as Callable).call()
		d.outline()
		img.blit_rect(d.img, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	img.save_png(ProjectSettings.globalize_path("res://assets/items.png"))
	var mats: Array = [
		_m_gel, _m_dust, _m_wing, _m_bone, _m_spore, _m_ore, _m_crown, _m_phylactery, _m_sulfur, _m_obsidian,
		_m_scale, _m_ember_heart, _m_ice, _m_venom, _m_soul, _m_horn, _m_frost_heart, _m_swamp_pearl, _m_shadow_gem, _m_abyss_eye,
		_m_coral, _m_gear, _m_crystal, _m_kraken_ink, _m_machine_core, _m_prism,
	]
	var mi := Image.create(mats.size() * 12, 12, false, Image.FORMAT_RGBA8)
	for i in mats.size():
		d.begin(12)
		d.k = 1.0
		(mats[i] as Callable).call()
		d.outline()
		mi.blit_rect(d.img, Rect2i(0, 0, 12, 12), Vector2i(i * 12, 0))
	mi.save_png(ProjectSettings.globalize_path("res://assets/mats.png"))
	print("gen_icons: %d items, %d mats" % [items.size(), mats.size()])
	quit()


# ---------------- помощники ----------------

## Клинок по диагонали от рукояти a к острию b шириной w.
func _blade(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var dir := (b - a).normalized()
	var n := dir.orthogonal() * w * 0.5
	var p := Pix.pal(c)
	d.poly(PackedVector2Array([a + n, b - dir * w, b, a - n]), p[2])
	d.poly(PackedVector2Array([a + n, b - dir * w, b, a]), p[0])
	d.line(a, b - dir * 0.5, p[1])


func _hilt(at: Vector2, guard: float, c: Color, grip: Color) -> void:
	d.line(at + Vector2(-guard, -guard) * 0.7, at + Vector2(guard, guard) * 0.7, c, 1.5)
	d.line(at, at + Vector2(-3, 3), grip, 1.5)
	d.ell(at.x - 3.5, at.y + 3.5, 1.0, 1.0, c)


func _haft(a: Vector2, b: Vector2, c := WOOD) -> void:
	d.line(a, b, c, 1.4)


# ---------------- оружие ----------------

func _sword() -> void:
	_blade(Vector2(5, 11), Vector2(14, 2), 2.6, STEEL)
	_hilt(Vector2(5.5, 10.5), 2.5, GOLD, LEATHER)


func _dagger() -> void:
	_blade(Vector2(6, 10), Vector2(12, 4), 2.6, STEEL)
	_hilt(Vector2(6.5, 9.5), 2.0, IRON, LEATHER)


func _knife() -> void:
	_blade(Vector2(6, 10), Vector2(12, 3), 2.0, Color8(220, 220, 210))
	d.line(Vector2(6, 10), Vector2(3, 13), WOOD, 1.8)


func _stiletto() -> void:
	_blade(Vector2(6, 10), Vector2(14, 2), 1.6, STEEL)
	_hilt(Vector2(6.5, 9.5), 2.0, Color8(120, 60, 160), Color8(40, 30, 40))


func _cleaver() -> void:
	d.spoly(PackedVector2Array([Vector2(6, 9), Vector2(10, 2), Vector2(15, 4), Vector2(11, 11)]), Pix.pal(STEEL))
	d.line(Vector2(10, 2), Vector2(15, 4), WHITE)
	d.line(Vector2(7, 10), Vector2(3, 14), WOOD, 1.8)


func _katar() -> void:
	d.spoly(PackedVector2Array([Vector2(8, 1), Vector2(10.5, 8), Vector2(5.5, 8)]), Pix.pal(STEEL))
	d.rect(4, 8, 8, 1.5, GOLD)
	d.rect(4, 9, 1.5, 5, GOLD)
	d.rect(10.5, 9, 1.5, 5, GOLD)
	d.rect(5.5, 11.5, 5, 1.2, LEATHER)


func _axe() -> void:
	_haft(Vector2(4, 14), Vector2(11, 3))
	d.spoly(PackedVector2Array([Vector2(9, 3), Vector2(14, 1), Vector2(15, 7), Vector2(11, 7)]), Pix.pal(IRON))
	d.line(Vector2(14, 1), Vector2(15, 7), WHITE)


func _greataxe() -> void:
	_haft(Vector2(3, 15), Vector2(11, 2))
	for s: int in [-1, 1]:
		d.spoly(PackedVector2Array([Vector2(10, 4), Vector2(10 + s * 5, 1 + (0 if s > 0 else 5)), Vector2(10 + s * 5, 7 + (0 if s > 0 else 4)), Vector2(10 + s * 1, 7)]), Pix.pal(Color8(170, 60, 50) if s < 0 else IRON))
	d.ell(10, 5, 1.2, 1.2, GOLD)


func _mace() -> void:
	_haft(Vector2(4, 14), Vector2(10, 6))
	d.ball(11, 5, 3.5, 3.5, Pix.pal(IRON))
	for v: Vector2 in [Vector2(11, 0.8), Vector2(15, 5), Vector2(11, 9), Vector2(7.2, 5)]:
		d.px(v.x, v.y, STEEL)
	d.ell(10, 4, 1, 1, WHITE)


func _bow_shape(c: Color, string: Color, big: bool) -> void:
	var r := 7.0 if big else 6.0
	var pts: Array = []
	for i in 11:
		var a := -PI * 0.75 + PI * 1.0 * i / 10.0
		pts.append(Vector2(4 + cos(a) * r * 0.6 + r * 0.6, 8 + sin(a) * r))
	for i in 10:
		d.line(pts[i], pts[i + 1], c, 1.6)
	d.line(pts[0], pts[10], string)


func _bow() -> void:
	_bow_shape(WOOD, WHITE, false)
	d.line(Vector2(3, 8), Vector2(14, 8), Color8(190, 160, 120))
	d.poly(PackedVector2Array([Vector2(14, 6.5), Vector2(16, 8), Vector2(14, 9.5)]), IRON)


func _longbow() -> void:
	_bow_shape(Color8(110, 70, 40), WHITE, true)
	d.rect(6.5, 7, 1.5, 2, GOLD)


func _hunter_bow() -> void:
	_bow_shape(Color8(80, 120, 60), WHITE, true)
	d.px(9, 2, Color8(200, 60, 60))
	d.px(9, 14, Color8(200, 60, 60))
	d.rect(6.5, 7, 1.5, 2, LEATHER)


func _crossbow() -> void:
	d.line(Vector2(3, 13), Vector2(12, 4), WOOD, 2.0)
	d.line(Vector2(5, 4), Vector2(14, 11), IRON, 1.6)
	d.line(Vector2(5, 4), Vector2(9, 9), WHITE)
	d.line(Vector2(9, 9), Vector2(14, 11), WHITE)
	d.poly(PackedVector2Array([Vector2(12, 2), Vector2(14.5, 1.5), Vector2(14, 4)]), STEEL)


func _wand() -> void:
	_haft(Vector2(4, 13), Vector2(11, 5), Color8(90, 60, 40))
	d.ell(12, 4, 2.2, 2.2, PURPLE)
	d.px(11.5, 3.5, WHITE)
	d.px(14, 1, Color8(220, 180, 255))


func _staff() -> void:
	_haft(Vector2(3, 15), Vector2(12, 4))
	d.line(Vector2(12, 4), Vector2(13, 1.5), WOOD, 1.2)
	d.line(Vector2(12, 4), Vector2(14.5, 3), WOOD, 1.2)
	d.ell(13.2, 2.8, 1.6, 1.6, GEM)


func _elem_staff() -> void:
	_haft(Vector2(3, 15), Vector2(11, 5), Color8(70, 50, 80))
	d.ball(12, 4, 3, 3, Pix.pal(Color8(240, 120, 40)))
	d.ell(11, 3, 1.2, 1.2, Color8(120, 220, 255))
	d.px(15, 1, Color8(255, 240, 150))
	d.px(9, 1, Color8(150, 230, 255))


func _light_staff() -> void:
	_haft(Vector2(3, 15), Vector2(11, 5), Color8(230, 220, 190))
	d.ell(12, 4, 3.2, 3.2, Color(1.0, 0.95, 0.6, 0.35))
	d.ball(12, 4, 2.2, 2.2, Pix.pal(Color8(255, 240, 150)))
	d.rect(10, 3.5, 4, 1, GOLD)


func _acolyte_rod() -> void:
	_haft(Vector2(4, 14), Vector2(11, 5), Color8(200, 180, 140))
	d.rect(9.5, 2, 1.5, 6, GOLD)
	d.rect(8, 3.5, 4.5, 1.5, GOLD)


func _beads() -> void:
	for i in 12:
		var a := TAU * i / 12.0
		d.ball(8 + cos(a) * 4.5, 7 + sin(a) * 4.5, 1.3, 1.3, Pix.pal(Color8(180, 120, 70)))
	d.rect(7.3, 11, 1.5, 4, GOLD)
	d.rect(6, 12.5, 4, 1.2, GOLD)


func _knuckles() -> void:
	d.spoly(PackedVector2Array([Vector2(2, 6), Vector2(14, 6), Vector2(14, 10), Vector2(2, 10)]), Pix.pal(IRON))
	for i in 4:
		d.ell(3.5 + i * 3, 8, 1.1, 1.1, Color8(40, 40, 50))
	d.rect(3, 10, 10, 2.5, LEATHER)
	for i in 4:
		d.px(3.5 + i * 3, 5, STEEL)


func _sage_book() -> void:
	d.spoly(PackedVector2Array([Vector2(3, 3), Vector2(13, 2), Vector2(13, 14), Vector2(3, 14)]), Pix.pal(Color8(60, 90, 160)))
	d.rect(3, 12, 10, 2, Color8(235, 225, 200))
	d.rect(7, 6, 3, 3, GOLD)
	d.px(8, 7, GEM)
	d.rect(3, 3, 1, 11, GOLD)


func _tome() -> void:
	d.spoly(PackedVector2Array([Vector2(3, 3), Vector2(13, 2), Vector2(13, 14), Vector2(3, 14)]), Pix.pal(Color8(120, 40, 60)))
	d.rect(3, 12, 10, 2, Color8(235, 225, 200))
	d.ell(8, 7.5, 2, 2, Color8(210, 190, 120))
	d.ell(8, 7.5, 0.8, 0.8, RED)


# ---------------- вторая рука ----------------

func _buckler() -> void:
	d.ball(8, 8, 6, 6, Pix.pal(WOOD))
	d.ell(8, 8, 6, 6, Color(0, 0, 0, 0))
	for a in 12:
		var v := Vector2(8, 8) + Vector2.from_angle(TAU * a / 12.0) * 5.6
		d.px(v.x, v.y, IRON)
	d.ball(8, 8, 2, 2, Pix.pal(IRON))


func _tower() -> void:
	d.spoly(PackedVector2Array([Vector2(3, 1), Vector2(13, 1), Vector2(13, 10), Vector2(8, 15), Vector2(3, 10)]), Pix.pal(BLUE))
	d.rect(7.3, 2, 1.5, 11, GOLD)
	d.rect(4, 5.5, 8, 1.5, GOLD)


func _quiver() -> void:
	for i in 3:
		d.line(Vector2(6 + i * 2, 6), Vector2(7 + i * 2, 1), Color8(220, 220, 220))
		d.poly(PackedVector2Array([Vector2(5.5 + i * 2, 1.5), Vector2(7 + i * 2, -0.5), Vector2(8.5 + i * 2, 1.5)]), RED)
	d.spoly(PackedVector2Array([Vector2(4, 5), Vector2(12, 5), Vector2(11, 15), Vector2(5, 15)]), Pix.pal(LEATHER))
	d.rect(4, 7, 8, 1, Color8(90, 60, 36))


# ---------------- броня ----------------

func _shirt(c: Color, trim: Color) -> void:
	d.spoly(PackedVector2Array([Vector2(5, 2), Vector2(11, 2), Vector2(15, 5), Vector2(13, 8), Vector2(12, 7), Vector2(12, 14), Vector2(4, 14), Vector2(4, 7), Vector2(3, 8), Vector2(1, 5)]), Pix.pal(c))
	d.rect(6.5, 2, 3, 1.5, trim)


func _leather() -> void:
	_shirt(LEATHER, Color8(90, 60, 36))
	d.rect(4, 10, 8, 1.2, Color8(90, 60, 36))
	d.px(8, 10.5, GOLD)


func _chain() -> void:
	_shirt(IRON, Color8(80, 84, 96))
	for y in range(4, 14, 2):
		for x in range(5, 12, 2):
			d.px(x + (y / 2) % 2, y, Color8(90, 96, 110))


func _cap() -> void:
	d.ball(8, 9, 6, 5, Pix.pal(LEATHER))
	d.rect(2, 10, 12, 2.5, Color8(110, 70, 40))
	d.ell(6, 6, 1.5, 1, Color8(200, 150, 100))


func _helm() -> void:
	d.ball(8, 8, 6, 6.5, Pix.pal(IRON))
	d.rect(2, 9, 12, 5, Color(0, 0, 0, 0))
	d.spoly(PackedVector2Array([Vector2(2, 8), Vector2(14, 8), Vector2(14, 14), Vector2(2, 14)]), Pix.pal(IRON))
	d.rect(4, 9.5, 8, 1.5, Color8(30, 30, 40))
	d.rect(7.5, 9.5, 1, 4, Color8(30, 30, 40))
	d.ell(6, 4.5, 1.5, 1, WHITE)


func _circlet() -> void:
	d.ell(8, 9, 6.5, 3.5, GOLD)
	d.ell(8, 9, 5, 2, Color(0, 0, 0, 0))
	d.img.fill_rect(Rect2i(3, 8, 10, 2), Color(0, 0, 0, 0))
	d.spoly(PackedVector2Array([Vector2(6, 7), Vector2(8, 3), Vector2(10, 7)]), Pix.pal(GOLD))
	d.ell(8, 6, 1.2, 1.2, GEM)


func _cape() -> void:
	d.spoly(PackedVector2Array([Vector2(5, 2), Vector2(11, 2), Vector2(14, 14), Vector2(10, 13), Vector2(8, 15), Vector2(6, 13), Vector2(2, 14)]), Pix.pal(Color8(170, 40, 50)))
	d.rect(5, 2, 6, 1.5, GOLD)


func _mantle() -> void:
	d.spoly(PackedVector2Array([Vector2(4, 2), Vector2(12, 2), Vector2(15, 15), Vector2(1, 15)]), Pix.pal(Color8(70, 70, 150)))
	d.rect(7.5, 3, 1, 12, GOLD)
	d.spoly(PackedVector2Array([Vector2(4, 2), Vector2(12, 2), Vector2(11, 5), Vector2(5, 5)]), Pix.pal(Color8(220, 210, 180)))


func _boot(c: Color, x0: float) -> void:
	d.spoly(PackedVector2Array([Vector2(x0, 2), Vector2(x0 + 4, 2), Vector2(x0 + 4, 11), Vector2(x0 + 7, 12), Vector2(x0 + 7, 15), Vector2(x0, 15)]), Pix.pal(c))


func _shoes() -> void:
	_boot(LEATHER, 2)
	d.rect(2, 4, 4, 1, Color8(90, 60, 36))
	d.rect(2, 13.5, 7, 1.5, Color8(70, 46, 30))


func _greaves() -> void:
	_boot(IRON, 3)
	d.rect(3, 6, 4, 1, WHITE)
	d.rect(3, 9, 4, 1, Color8(90, 96, 110))
	d.rect(3, 13.5, 7, 1.5, Color8(80, 84, 96))


# ---------------- украшения ----------------

func _ring() -> void:
	d.ell(8, 10, 5, 4, GOLD)
	d.ell(8, 10.5, 3, 2.4, Color(0, 0, 0, 0))
	d.img.fill_rect(Rect2i(6, 9, 5, 4), Color(0, 0, 0, 0))
	d.ball(8, 5, 2.3, 2.3, Pix.pal(RED))
	d.px(7, 4, WHITE)


func _band() -> void:
	d.ell(8, 9, 5.5, 4.5, Color8(180, 186, 200))
	d.img.fill_rect(Rect2i(5, 8, 6, 4), Color(0, 0, 0, 0))
	d.rect(3, 7, 10, 1, WHITE)
	d.ball(8, 5.5, 1.8, 1.8, Pix.pal(BLUE))


func _amulet() -> void:
	d.line(Vector2(3, 2), Vector2(8, 9), GOLD)
	d.line(Vector2(13, 2), Vector2(8, 9), GOLD)
	d.ball(8, 11, 3.5, 3.5, Pix.pal(GOLD))
	d.ball(8, 11, 2, 2, Pix.pal(GEM))


func _talisman() -> void:
	d.line(Vector2(4, 1), Vector2(8, 6), Color8(150, 110, 70))
	d.line(Vector2(12, 1), Vector2(8, 6), Color8(150, 110, 70))
	d.spoly(PackedVector2Array([Vector2(8, 5), Vector2(13, 10), Vector2(8, 15), Vector2(3, 10)]), Pix.pal(Color8(90, 170, 110)))
	d.ell(8, 10, 1.3, 1.3, WHITE)


# ---------------- материалы (12x12) ----------------

func _drop(c: Color) -> void:
	d.spoly(PackedVector2Array([Vector2(6, 1), Vector2(10, 7), Vector2(6, 11), Vector2(2, 7)]), Pix.pal(c))
	d.ball(6, 7.5, 4, 3.5, Pix.pal(c), true)


func _gem(c: Color) -> void:
	d.poly(PackedVector2Array([Vector2(6, 1), Vector2(10, 4), Vector2(6, 5)]), c.lightened(0.4))
	d.poly(PackedVector2Array([Vector2(6, 1), Vector2(6, 5), Vector2(2, 4)]), c.lightened(0.15))
	d.poly(PackedVector2Array([Vector2(2, 4), Vector2(6, 5), Vector2(6, 11)]), c)
	d.poly(PackedVector2Array([Vector2(6, 5), Vector2(10, 4), Vector2(6, 11)]), c.darkened(0.3))


func _shard(c: Color) -> void:
	d.spoly(PackedVector2Array([Vector2(5, 0.5), Vector2(8, 4), Vector2(7, 11), Vector2(3, 11), Vector2(2, 5)]), Pix.pal(c))
	d.line(Vector2(5, 1), Vector2(4.5, 10), c.lightened(0.5))
	d.spoly(PackedVector2Array([Vector2(9, 5), Vector2(11, 8), Vector2(10, 11), Vector2(7.5, 11)]), Pix.pal(c.darkened(0.1)))


func _m_gel() -> void: _drop(Color8(100, 210, 90))
func _m_venom() -> void: _drop(Color8(160, 220, 60))
func _m_ice() -> void: _shard(Color8(170, 225, 250))
func _m_crystal() -> void: _shard(Color8(230, 150, 240))
func _m_obsidian() -> void: _shard(Color8(70, 50, 90))
func _m_frost_heart() -> void: _gem(Color8(120, 210, 255))
func _m_shadow_gem() -> void: _gem(Color8(130, 70, 200))
func _m_prism() -> void:
	_gem(Color8(240, 150, 240))
	d.px(4, 3, Color8(150, 240, 255))
	d.px(8, 7, Color8(255, 240, 150))


func _m_dust() -> void:
	for v: Vector2 in [Vector2(3, 3), Vector2(8, 2), Vector2(6, 6), Vector2(2, 9), Vector2(9, 9)]:
		d.ell(v.x, v.y, 1.2, 1.2, Color8(170, 160, 255))
		d.px(v.x, v.y, WHITE)


func _m_soul() -> void:
	d.spoly(PackedVector2Array([Vector2(6, 1), Vector2(9, 5), Vector2(8, 11), Vector2(4, 11), Vector2(3, 5)]), Pix.pal(Color8(150, 200, 255)))
	d.px(5, 6, Color8(30, 40, 80))
	d.px(7, 6, Color8(30, 40, 80))


func _m_wing() -> void:
	d.spoly(PackedVector2Array([Vector2(1, 3), Vector2(11, 1), Vector2(10, 6), Vector2(8, 5), Vector2(7, 8), Vector2(5, 6), Vector2(3, 9)]), Pix.pal(Color8(110, 80, 150)))


func _m_bone() -> void:
	d.line(Vector2(3, 9), Vector2(9, 3), Color8(232, 226, 204), 2.0)
	for v: Vector2 in [Vector2(2, 9), Vector2(3, 10), Vector2(9, 2), Vector2(10, 3)]:
		d.ell(v.x, v.y, 1.2, 1.2, Color8(232, 226, 204))


func _m_horn() -> void:
	d.spoly(PackedVector2Array([Vector2(2, 11), Vector2(6, 9), Vector2(9, 4), Vector2(10, 0.5), Vector2(6, 4), Vector2(2, 7)]), Pix.pal(Color8(150, 60, 50)))


func _m_spore() -> void:
	d.rect(5, 6, 2, 5, Color8(230, 220, 200))
	d.ball(6, 5, 4.5, 3, Pix.pal(Color8(150, 90, 200)))
	d.px(4, 4, WHITE)
	d.px(8, 5, WHITE)


func _m_ore() -> void:
	d.ball(6, 7, 5, 4, Pix.pal(Color8(100, 96, 110)))
	d.px(4, 6, Color8(240, 190, 80))
	d.px(7, 8, Color8(240, 190, 80))
	d.px(8, 5, Color8(240, 190, 80))


func _m_crown() -> void:
	d.spoly(PackedVector2Array([Vector2(1, 10), Vector2(1, 3), Vector2(3.5, 6), Vector2(6, 2), Vector2(8.5, 6), Vector2(11, 3), Vector2(11, 10)]), Pix.pal(GOLD))
	d.px(6, 7, Color8(100, 210, 90))


func _m_phylactery() -> void:
	d.rect(5, 1, 2, 2, Color8(120, 90, 60))
	d.ball(6, 7, 4, 4, Pix.pal(Color8(120, 230, 160)), true)
	d.px(6, 7, Color8(30, 60, 40))


func _m_sulfur() -> void:
	d.ball(6, 7, 5, 3.8, Pix.pal(Color8(240, 210, 60)))
	d.px(4, 6, WHITE)


func _m_scale() -> void:
	for v: Vector2 in [Vector2(4, 4), Vector2(8, 4), Vector2(6, 8)]:
		d.ball(v.x, v.y, 3, 2.6, Pix.pal(Color8(220, 110, 50)))


func _m_ember_heart() -> void:
	d.ball(4, 4.5, 2.8, 2.8, Pix.pal(Color8(255, 110, 40)))
	d.ball(8, 4.5, 2.8, 2.8, Pix.pal(Color8(255, 110, 40)))
	d.spoly(PackedVector2Array([Vector2(1.3, 5), Vector2(10.7, 5), Vector2(6, 11)]), Pix.pal(Color8(255, 110, 40)))
	d.px(6, 6, Color8(255, 240, 150))


func _m_swamp_pearl() -> void:
	d.ball(6, 6.5, 4.5, 4.5, Pix.pal(Color8(150, 220, 140)), true)


func _m_abyss_eye() -> void:
	d.ball(6, 6, 5, 4, Pix.pal(Color8(240, 230, 220)))
	d.ell(6, 6, 2.5, 2.5, Color8(200, 40, 120))
	d.ell(6, 6, 1, 2, Color8(20, 10, 20))


func _m_coral() -> void:
	d.line(Vector2(6, 11), Vector2(6, 3), Color8(240, 110, 100), 1.6)
	d.line(Vector2(6, 7), Vector2(2, 3), Color8(240, 110, 100), 1.4)
	d.line(Vector2(6, 6), Vector2(10, 2), Color8(240, 110, 100), 1.4)
	d.px(2, 2, Color8(255, 180, 170))
	d.px(10, 1, Color8(255, 180, 170))


func _m_gear() -> void:
	for i in 8:
		var a := TAU * i / 8.0
		d.ell(6 + cos(a) * 4.5, 6 + sin(a) * 4.5, 1.1, 1.1, Color8(190, 150, 80))
	d.ball(6, 6, 4, 4, Pix.pal(Color8(190, 150, 80)))
	d.ell(6, 6, 1.5, 1.5, Color8(60, 46, 30))


func _m_kraken_ink() -> void:
	d.rect(4.5, 0.5, 3, 2, Color8(120, 90, 60))
	d.spoly(PackedVector2Array([Vector2(4, 2), Vector2(8, 2), Vector2(10, 7), Vector2(9, 11), Vector2(3, 11), Vector2(2, 7)]), Pix.pal(Color8(50, 60, 140)))
	d.px(4, 6, Color8(160, 180, 255))


func _m_machine_core() -> void:
	d.spoly(PackedVector2Array([Vector2(2, 2), Vector2(10, 2), Vector2(10, 10), Vector2(2, 10)]), Pix.pal(Color8(150, 120, 70)))
	d.ball(6, 6, 2.5, 2.5, Pix.pal(Color8(255, 180, 60)))
	for v: Vector2 in [Vector2(3, 3), Vector2(9, 3), Vector2(3, 9), Vector2(9, 9)]:
		d.px(v.x, v.y, Color8(230, 220, 200))
