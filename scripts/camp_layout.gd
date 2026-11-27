extends RefCounted
## Раскладка лагеря-деревни (общая для игры и генератора графики tools/gen_camp.gd).
## Клетка 16 px. Картинки лагеря нарисованы с двойной детализацией (ART = 2 пикселя картинки на 1 пиксель мира).
##
## Три «улицы» (полосы) домов, двери смотрят вниз, на дорогу перед ними:
##   ряд A (основание y = 9): библиотека, плац, портал, кузница, лазарет;
##   ряд B (y = 20): наставник, торговец, [площадь с фонтаном], обменник, пруд;
##   ряд C (y = 30): сокровищница, склад, [сад], мастерская, шахта.

const W := 44
const H := 34
const TILE := 16
const ART := 2

# Где стоит постройка: середина основания (линия двери) в клетках.
# door — смещение двери по x от середины (в пикселях мира).
const BUILDINGS := {
	"library": {"at": Vector2(7.5, 9), "door": 0.0},
	"training": {"at": Vector2(14.5, 9), "door": 0.0},
	"portal": {"at": Vector2(22, 9), "door": 0.0},
	"forge": {"at": Vector2(30, 9), "door": -14.0},
	"infirmary": {"at": Vector2(37.5, 9), "door": 0.0},
	"mentor": {"at": Vector2(6.5, 20), "door": -10.0},
	"merchant": {"at": Vector2(13.5, 20), "door": 0.0},
	"exchange": {"at": Vector2(30.5, 20), "door": 0.0},
	"treasury": {"at": Vector2(7, 30), "door": 0.0},
	"storage": {"at": Vector2(14.5, 30), "door": 0.0},
	"workshop": {"at": Vector2(30, 30), "door": 10.0},
	"mine": {"at": Vector2(38, 30), "door": 0.0},
}

# Мелочи: [картинка, клетка (середина основания), твёрдая?]
const PROPS := [
	["fountain", Vector2(22, 15.6), true],
	["lamp", Vector2(18.2, 9.4), true], ["lamp", Vector2(25.8, 9.4), true],
	["lamp", Vector2(19.8, 22.6), true], ["lamp", Vector2(24.2, 22.6), true],
	["lamp", Vector2(19.8, 29.6), true], ["lamp", Vector2(24.2, 29.6), true],
	["lamp", Vector2(3.6, 13.2), true], ["lamp", Vector2(40.4, 13.2), true],
	["bench", Vector2(18.4, 17.2), true], ["bench", Vector2(25.6, 17.2), true],
	["dummy", Vector2(11.2, 9.2), true], ["dummy", Vector2(17.6, 9.2), true],
	["target", Vector2(18.6, 7.0), true],
	["anvil", Vector2(34.4, 9.6), true], ["barrels", Vector2(25.8, 8.6), true],
	["crates", Vector2(18.6, 29.6), true], ["barrels", Vector2(10.3, 29.4), true],
	["hay", Vector2(18.8, 27.8), true],
	["cart", Vector2(34.2, 30.6), true],
	["crates", Vector2(16.4, 19.4), true], ["barrels", Vector2(9.6, 19.6), true],
	["pot", Vector2(33.6, 19.8), false], ["pot", Vector2(27.4, 19.8), false],
	["pot", Vector2(4.2, 8.8), false], ["pot", Vector2(40.6, 8.8), false],
	["sign", Vector2(24.6, 12.6), true],
	["tree", Vector2(26.6, 26.2), true], ["tree", Vector2(17.5, 25.0), true],
	["tree", Vector2(27.8, 29.0), true], ["tree", Vector2(3.4, 25.6), true],
	["tree", Vector2(40.6, 25.0), true], ["tree", Vector2(3.0, 17.8), true],
	["tree", Vector2(34.2, 14.6), true], ["tree", Vector2(9.6, 14.8), true],
	["bush", Vector2(25.4, 24.0), true], ["bush", Vector2(18.6, 22.9), true],
	["bush", Vector2(21.0, 27.6), false], ["bush", Vector2(5.0, 14.6), false],
	["bush", Vector2(39.6, 21.6), false], ["bush", Vector2(12.8, 26.0), false],
	["flowers", Vector2(23.2, 26.4), false], ["flowers", Vector2(19.6, 27.0), false],
	["flowers", Vector2(27.6, 23.2), false], ["flowers", Vector2(15.8, 15.6), false],
	["flowers", Vector2(29.2, 16.4), false], ["flowers", Vector2(8.6, 26.2), false],
]

# Где появляется герой.
const START := Vector2(22, 17.6)

# Виды земли.
const GRASS := 0
const STONE := 1      # мостовая
const FOREST := 2     # непроходимо
const WATER := 3      # непроходимо
const DIRT := 4

const POND := Vector2(38.2, 17.2)
const POND_R := Vector2(2.9, 2.0)
const PLAZA := Vector2(22, 15)
const PLAZA_R := Vector2(6.8, 4.2)


static func _h(x: int, y: int, i: int) -> float:
	return float(hash(Vector3i(x, y, i)) & 1023) / 1023.0


## Вид земли в точке (в клетках, можно дробные — генератор рисует неровные края).
static func kind_at(fx: float, fy: float) -> int:
	var x := int(floor(fx))
	var y := int(floor(fy))
	# Лес по краям: неровная кромка.
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
	# Утоптанная земля у плаца и у шахты.
	if (fx >= 10.0 and fx < 19.0 and fy >= 6.0 and fy < 9.0) or (fx >= 34.0 and fx < 42.0 and fy >= 27.0 and fy < 30.0):
		return DIRT
	return GRASS


## Клетка непроходима (лес, вода).
static func solid(x: int, y: int) -> bool:
	var k := kind_at(x + 0.5, y + 0.5)
	return k == FOREST or k == WATER
