extends RefCounted
## Раскладка лагеря-деревни (прямой 2D-вид сверху-спереди; общая для игры и генератора
## графики tools/gen_camp.gd). Клетка 16 px. Картинки нарисованы в утверждённом стиле
## (tools/camp_art.gd) с детализацией ART = 2 пикселя на пиксель мира.
##
## Три «улицы»: ряд A (основание y = 9), ряд B (y = 20), ряд C (y = 30). Двери смотрят вниз.
## Постоянные постройки — портал, торговец, шахта; остальное игрок строит сам на участках LOTS
## (Meta.plots: номер участка → постройка).

const W := 44
const H := 34
const TILE := 16
const ART := 2
const WIDTH := W * TILE
const HEIGHT := H * TILE

# Постоянные постройки: середина основания (линия фасада) в клетках.
const FIXED := {
	"portal": Vector2(22, 9),
	"merchant": Vector2(13.5, 20),
	"mine": Vector2(38, 30),
}

# Участки: середина основания (клетки). Участок — 6 клеток в ширину, LOT_DEPTH вглубь.
const LOTS := [
	Vector2(7.5, 9), Vector2(14.5, 9), Vector2(30, 9), Vector2(37.5, 9),
	Vector2(6.5, 20), Vector2(30.5, 20),
	Vector2(7, 30), Vector2(14.5, 30), Vector2(30, 30),
]
const LOT_W := 6.0
const LOT_DEPTH := 3.0

# Что можно построить на участке.
const BUILDABLE := ["training", "library", "forge", "infirmary", "treasury", "storage", "workshop", "exchange", "mentor"]

# Мелочи: [картинка (assets/camp/p_<имя>.png), клетка (середина основания), твёрдая?]
const PROPS := [
	["fountain", Vector2(22, 15.5), true],
	["lamp", Vector2(18.6, 9.6), true], ["lamp", Vector2(25.6, 9.6), true],
	["lamp", Vector2(19.8, 22.6), true], ["lamp", Vector2(24.2, 22.6), true],
	["lamp", Vector2(19.8, 29.6), true], ["lamp", Vector2(24.2, 29.6), true],
	["lamp", Vector2(3.6, 13.2), true], ["lamp", Vector2(40.4, 13.2), true],
	["bench", Vector2(18.4, 17.2), true], ["bench", Vector2(25.6, 17.2), true],
	["signpost", Vector2(24.6, 12.6), true],
	["tree_oak_1", Vector2(26.6, 26.2), true], ["tree_fruit_1", Vector2(17.5, 25.0), true],
	["tree_birch_1", Vector2(27.8, 29.0), true], ["tree_pine_1", Vector2(3.4, 25.6), true],
	["tree_autumn_1", Vector2(40.6, 25.0), true], ["tree_birch_0", Vector2(3.0, 17.8), true],
	["tree_oak_0", Vector2(34.2, 14.6), true], ["tree_fruit_0", Vector2(9.6, 14.8), true],
	["bush_flower", Vector2(25.4, 24.0), true], ["bush_green", Vector2(18.6, 22.9), true],
	["bush_berry", Vector2(21.0, 27.6), true], ["bush_green", Vector2(5.0, 14.6), true],
	["bush_flower", Vector2(39.6, 21.6), true], ["bush_dark", Vector2(12.8, 26.0), true],
	["bush_flower", Vector2(10.0, 23.4), true], ["bush_green", Vector2(35.0, 23.4), true],
	["rock_l", Vector2(16.0, 26.6), true], ["rock_m", Vector2(33.0, 26.5), true],
	["rock_m", Vector2(36.6, 21.6), true], ["rock_s", Vector2(6.2, 23.0), true],
	["rock_m", Vector2(41.0, 19.6), true], ["rock_s", Vector2(23.4, 26.0), true],
	["flowers_0", Vector2(23.2, 26.3), false], ["flowers_1", Vector2(19.6, 26.9), false],
	["flowers_2", Vector2(27.6, 23.1), false], ["flowers_0", Vector2(15.8, 15.5), false],
	["flowers_1", Vector2(29.2, 16.3), false], ["flowers_2", Vector2(8.6, 26.1), false],
]

const START := Vector2(22, 17.6)

const GRASS := 0
const STONE := 1      # мостовая
const FOREST := 2     # непроходимо
const WATER := 3      # непроходимо
const DIRT := 4       # участок под стройку
const PATH := 5       # утоптанная земля

const POND := Vector2(38.2, 17.2)
const POND_R := Vector2(2.9, 2.0)
const PLAZA := Vector2(22, 15)
const PLAZA_R := Vector2(6.8, 4.2)


static func _h(x: int, y: int, i: int) -> float:
	return float(hash(Vector3i(x, y, i)) & 1023) / 1023.0


## Номер участка в точке (клетки) или -1.
static func in_lot(fx: float, fy: float) -> int:
	for k in LOTS.size():
		var a: Vector2 = LOTS[k]
		if fx >= a.x - LOT_W / 2.0 and fx < a.x + LOT_W / 2.0 and fy >= a.y - LOT_DEPTH and fy < a.y:
			return k
	return -1


## Вид земли в точке (в клетках, можно дробные — генератор рисует неровные края).
static func kind_at(fx: float, fy: float) -> int:
	var x := int(floor(fx))
	var y := int(floor(fy))
	var edge := 0.0
	if x <= 2 or x >= W - 3 or y <= 3 or y >= H - 3:
		edge = _h(x, y, 1)
	if fx < 2.0 or fx >= W - 2.0 or fy < 2.6 or fy >= H - 2.0:
		return FOREST
	if (fx < 2.6 or fx >= W - 2.6) and edge < 0.45:
		return FOREST
	var dp := Vector2((fx - POND.x) / POND_R.x, (fy - POND.y) / POND_R.y)
	if dp.length() < 1.0:
		return WATER
	var dpl := Vector2((fx - PLAZA.x) / PLAZA_R.x, (fy - PLAZA.y) / PLAZA_R.y)
	if dpl.length() < 1.0:
		return STONE
	if fx >= 3.0 and fx < W - 3.0:
		if (fy >= 9.0 and fy < 11.8) or (fy >= 20.0 and fy < 22.2) or (fy >= 30.0 and fy < 31.8):
			return STONE
	if fx >= 20.2 and fx < 23.8 and fy >= 9.0 and fy < 32.0:
		return STONE
	if fx >= 34.0 and fx < 42.0 and fy >= 27.0 and fy < 30.0:
		return PATH
	return GRASS


## Клетка непроходима (лес, вода).
static func solid(x: int, y: int) -> bool:
	var k := kind_at(x + 0.5, y + 0.5)
	return k == FOREST or k == WATER
