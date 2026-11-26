extends Node2D
## Каменная колонна в пещере (вид 3/4): столб из каменных блоков с верхушкой, тень на полу.
## Точка узла — нижний край колонны (по ней сортируется с героями и монстрами: кто стоит
## за колонной, тот прячется за ней). Твёрдость даёт карта (клетки колонны заняты).

const SHADOW := Color8(8, 8, 18, 150)
const LIGHT := Color8(78, 86, 128)
const MID := Color8(52, 56, 88)
const DARK := Color8(32, 33, 56)
const DEEP := Color8(20, 20, 38)
const JOINT := Color8(24, 24, 44)
const CAP := Color8(66, 72, 110)
const CAP_HI := Color8(104, 116, 164)
const CYAN := Color8(90, 200, 240)
const CYAN_HI := Color8(200, 245, 255)
const MOSS := Color8(46, 92, 96)

var cells := Vector2i.ONE   # размер колонны в клетках
var seed_v := 0


func _n(i: int) -> float:
	return float(hash(Vector2i(seed_v, i)) & 1023) / 1023.0


func _draw() -> void:
	var w := cells.x * 16 - 2
	var fh := cells.y * 16
	var face_h := 14 + cells.y * 2
	var cap_h := int(fh * 0.5) + 2
	var x0 := -w / 2
	# Тень на полу.
	var sh := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		sh.append(Vector2(cos(a) * (w / 2.0 + 4), -2 + sin(a) * 4.0))
	draw_colored_polygon(sh, SHADOW)
	# Цоколь — на пиксель шире.
	draw_rect(Rect2(x0 - 1, -3, w + 2, 3), DARK)
	draw_rect(Rect2(x0 - 1, -3, w + 2, 1), MID)
	# Ствол: свет слева, тень справа, каменные блоки.
	var top := -face_h
	for x in w:
		var t := float(x) / maxf(1.0, w - 1.0)
		var c := LIGHT if t < 0.18 else (MID if t < 0.6 else (DARK if t < 0.88 else DEEP))
		draw_rect(Rect2(x0 + x, top, 1, face_h - 3), c)
	var row_h := 5
	var r := 0
	var y := top + row_h
	while y < -4:
		draw_rect(Rect2(x0, y, w, 1), JOINT)
		# Вертикальные швы — со сдвигом через ряд.
		var step := 7 if w < 20 else 9
		var off := (r % 2) * (step / 2) + int(_n(r) * 3.0)
		var jx := off + 2
		while jx < w - 2:
			draw_rect(Rect2(x0 + jx, y - row_h + 1, 1, row_h - 1), JOINT)
			jx += step
		r += 1
		y += row_h
	# Трещинки и мох.
	for i in 2 + cells.x:
		var cx := x0 + 2 + int(_n(10 + i) * (w - 4))
		var cy := top + 2 + int(_n(20 + i) * (face_h - 8))
		if _n(30 + i) < 0.5:
			draw_rect(Rect2(cx, cy, 1, 2), DEEP)
		else:
			draw_rect(Rect2(cx, cy, 2, 1), MOSS)
	# Верхушка: срез столба, скошенные углы, светлая кромка спереди.
	var ct := top - cap_h
	for yy in cap_h:
		var inset := 0
		if yy == 0 or yy == cap_h - 1:
			inset = 2
		elif yy == 1 or yy == cap_h - 2:
			inset = 1
		draw_rect(Rect2(x0 + inset, ct + yy, w - inset * 2, 1), CAP)
	draw_rect(Rect2(x0 + 2, ct, w - 4, 1), CAP_HI)
	draw_rect(Rect2(x0 + 1, ct + 1, 1, cap_h - 2), CAP_HI)
	draw_rect(Rect2(x0 + 1, top - 1, w - 2, 1), CAP_HI)
	draw_rect(Rect2(x0, top, w, 1), DEEP)
	# Камни-сколы на верхушке.
	for i in cells.x + 1:
		var px := x0 + 3 + int(_n(40 + i) * (w - 6))
		var py := ct + 2 + int(_n(50 + i) * maxf(1.0, cap_h - 4.0))
		draw_rect(Rect2(px, py, 2, 1), MID)
	# Кристаллы на верхушке (не у всех колонн).
	if cells.x >= 2 or _n(60) < 0.4:
		var n := 2 + cells.x
		var bx := x0 + w / 2.0 + (_n(61) - 0.5) * (w * 0.4)
		var by := ct + cap_h * 0.6
		for i in n:
			var ang := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.42 + (_n(70 + i) - 0.5) * 0.2
			var length := 5.0 + _n(80 + i) * 5.0 + cells.x * 1.5 - absf(i - (n - 1) / 2.0) * 1.5
			var dir := Vector2.from_angle(ang)
			var base := Vector2(bx + (i - (n - 1) / 2.0) * 2.0, by)
			for k in int(length):
				var f := float(k) / length
				var p := (base + dir * k).floor()
				draw_rect(Rect2(p, Vector2(2 if f < 0.6 else 1, 1)), CYAN.lerp(CYAN_HI, f))
			draw_rect(Rect2((base + dir * length).floor(), Vector2.ONE), CYAN_HI)
