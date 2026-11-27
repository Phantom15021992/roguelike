extends RefCounted
## Раскладка лагеря-деревни в изометрии (общая для игры и генератора графики tools/gen_camp.gd).
##
## Сетка N x N клеток (i, j). Клетка на экране — ромб 32x16 пикселей мира:
##   экран = (ORIGIN_X + (i - j) * 16, (i + j) * 8).
## Ось i идёт вправо-вниз, ось j — влево-вниз. Видимые стены построек — «+j» (левая, освещённая)
## и «+i» (правая, в тени). Картинки нарисованы с детализацией ART = 4 пикселя на пиксель мира.
##
## Постройки (кроме портала, торговца и шахты) стоят на участках LOTS: игрок сам выбирает,
## что строить и где (Meta.plots: номер участка → постройка).

const N := 26
const ART := 4
const HALF_W := 16.0     # половина ширины ромба клетки, пиксели мира
const HALF_H := 8.0
const ORIGIN_X := N * 16.0
const WIDTH := N * 32    # размер всей карты в пикселях мира
const HEIGHT := N * 16

# Участок: угол (i, j), размер 4x4; постройка 3x3 в середине. face — где дверь: "y" (стена +j)
# или "x" (стена +i).
const LOTS := [
	{"at": Vector2(7, 7), "face": "y"},
	{"at": Vector2(3, 7), "face": "y"},
	{"at": Vector2(7, 3), "face": "x"},
	{"at": Vector2(15, 3), "face": "y"},
	{"at": Vector2(19, 7), "face": "y"},
	{"at": Vector2(7, 15), "face": "x"},
	{"at": Vector2(7, 19), "face": "x"},
	{"at": Vector2(3, 15), "face": "y"},
	{"at": Vector2(15, 15), "face": "y"},
	{"at": Vector2(19, 15), "face": "y"},
]
const LOT_SIZE := 4

# Постоянные постройки: угол клетки, размер (клетки), сторона двери.
const FIXED := {
	"portal": {"at": Vector2(11.5, 2.6), "size": Vector2(3, 1.4), "face": "y"},
	"merchant": {"at": Vector2(15.5, 8), "size": Vector2(3, 3), "face": "y"},
	"mine": {"at": Vector2(19.5, 2.4), "size": Vector2(3, 3), "face": "y"},
}

# Что можно построить на участке.
const BUILDABLE := ["training", "library", "forge", "infirmary", "treasury", "storage", "workshop", "exchange", "mentor"]

# Мелочи: [картинка, клетка (i, j) — точка на земле, твёрдая?]
const PROPS := [
	["fountain", Vector2(13, 13), true],
	["lamp", Vector2(10.4, 11.6), true], ["lamp", Vector2(15.6, 14.4), true],
	["lamp", Vector2(11.7, 5.4), true], ["lamp", Vector2(14.3, 5.4), true],
	["lamp", Vector2(3.2, 11.7), true], ["lamp", Vector2(22.8, 14.3), true],
	["lamp", Vector2(11.7, 22.8), true],
	["bench", Vector2(15.6, 12.4), true], ["bench", Vector2(10.4, 13.6), true],
	["barrels", Vector2(18.9, 11.6), true], ["crates", Vector2(15.2, 11.6), true],
	["cart", Vector2(22.6, 6.4), true],
	["tree", Vector2(11.2, 18.6), true], ["tree2", Vector2(15.0, 21.4), true],
	["tree", Vector2(21.6, 21.0), true], ["tree2", Vector2(18.2, 22.6), true],
	["tree3", Vector2(2.6, 14.6), true], ["tree3", Vector2(22.8, 11.2), true],
	["bush", Vector2(11.4, 7.4), false], ["bush", Vector2(14.6, 18.0), false],
	["bush", Vector2(23.4, 17.0), false], ["bush", Vector2(6.6, 14.6), false],
	["flowers", Vector2(16.4, 14.4), false], ["flowers", Vector2(9.8, 11.5), false],
	["flowers", Vector2(14.6, 20.6), false], ["flowers", Vector2(20.4, 20.6), false],
	["sign", Vector2(11.4, 6.6), true],
]

const START := Vector2(13, 15.6)

const GRASS := 0
const STONE := 1      # мостовая
const FOREST := 2     # непроходимо
const WATER := 3      # непроходимо
const DIRT := 4       # участок под стройку
const PATH := 5       # тропинка

const POND := Vector2(5.2, 21.2)
const POND_R := 1.9
const PLAZA := Vector2(13, 13)
const PLAZA_R := 2.8
const INNER0 := 2
const INNER1 := N - 2


## Клетка (дробная) → точка на экране (мир).
static func to_screen(c: Vector2) -> Vector2:
	return Vector2(ORIGIN_X + (c.x - c.y) * HALF_W, (c.x + c.y) * HALF_H)


## Точка на экране → клетка (дробная).
static func to_cell(p: Vector2) -> Vector2:
	var u := (p.x - ORIGIN_X) / HALF_W
	var v := p.y / HALF_H
	return Vector2((v + u) * 0.5, (v - u) * 0.5)


static func _h(x: int, y: int, i: int) -> float:
	return float(hash(Vector3i(x, y, i)) & 1023) / 1023.0


static func in_lot(fi: float, fj: float) -> int:
	for k in LOTS.size():
		var a: Vector2 = LOTS[k]["at"]
		if fi >= a.x and fi < a.x + LOT_SIZE and fj >= a.y and fj < a.y + LOT_SIZE:
			return k
	return -1


## Вид земли в точке (в клетках, можно дробные).
static func kind_at(fi: float, fj: float) -> int:
	if fi < INNER0 or fj < INNER0 or fi >= INNER1 or fj >= INNER1:
		return FOREST
	if Vector2(fi, fj).distance_to(POND) < POND_R:
		return WATER
	if in_lot(fi, fj) >= 0:
		return DIRT
	if Vector2(fi, fj).distance_to(PLAZA) < PLAZA_R:
		return STONE
	if (fj >= 12.0 and fj < 14.0 and fi >= INNER0) or (fi >= 12.0 and fi < 14.0 and fj >= 4.0):
		return STONE
	# Тропинки к шахте и к участкам за торговцем.
	if fj >= 6.0 and fj < 7.0 and fi >= 14.0 and fi < 23.0:
		return PATH
	if fi >= 18.6 and fi < 19.6 and fj >= 7.0 and fj < 12.0:
		return PATH
	if fj >= 19.0 and fj < 20.0 and fi >= 14.0 and fi < 23.0:
		return PATH
	if fi >= 2.0 and fi < 7.0 and fj >= 19.0 and fj < 19.8:
		return PATH
	return GRASS


## Клетка непроходима (лес, вода).
static func solid(i: int, j: int) -> bool:
	var k := kind_at(i + 0.5, j + 0.5)
	return k == FOREST or k == WATER


## Угол участка/постройки и размер → ромб основания в пикселях мира (относительно середины).
static func footprint(at: Vector2, size: Vector2) -> PackedVector2Array:
	var c := to_screen(at + size / 2.0)
	return PackedVector2Array([to_screen(at) - c, to_screen(at + Vector2(size.x, 0)) - c,
		to_screen(at + size) - c, to_screen(at + Vector2(0, size.y)) - c])
