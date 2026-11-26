extends RefCounted
## Арены боссов из data/arenas.txt: загрузка, проверка, выбор под босса.
## Арена: {name, bosses: Array[String] (или ["any"]), rows: Array[String]} — 30x15, вход слева (клетки 6–8).

const PATH := "res://data/arenas.txt"
const W := 30
const H := 15
const DOOR_LO := 6
const DOOR_HI := 8

static var _arenas: Array = []


static func all() -> Array:
	if _arenas.is_empty():
		_load()
	return _arenas


## Случайная арена для босса (по имени его скрипта), иногда отражённая сверху вниз.
static func pick(rng: RandomNumberGenerator, boss_id: String) -> Dictionary:
	var fit := all().filter(func(a: Dictionary) -> bool: return boss_id in a["bosses"])
	if fit.is_empty():
		fit = all().filter(func(a: Dictionary) -> bool: return "any" in a["bosses"])
	if fit.is_empty():
		fit = all()
	var a: Dictionary = fit[rng.randi() % fit.size()]
	var rows: Array = a["rows"].duplicate()
	if rng.randf() < 0.5:
		rows.reverse()  # отражение сверху вниз: вход остаётся на месте
	return {"name": a["name"], "rows": rows}


static func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("Не найден файл арен " + PATH)
		return
	var cur: Dictionary = {}
	for raw in f.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.begins_with("="):
			if not cur.is_empty():
				_finish(cur)
			var parts := line.substr(1).strip_edges().split(" ", false)
			var bosses: Array = Array(parts[1].split(",", false)) if parts.size() > 1 else ["any"]
			cur = {"name": parts[0].replace("_", " "), "bosses": bosses, "rows": []}
		elif not cur.is_empty():
			cur["rows"].append(line)
	if not cur.is_empty():
		_finish(cur)


static func _finish(a: Dictionary) -> void:
	var err := _validate(a["rows"])
	if err != "":
		push_error("Арена «%s»: %s — пропущена" % [a["name"], err])
		return
	_arenas.append(a)


static func _validate(rows: Array) -> String:
	if rows.size() != H:
		return "должно быть %d строк, а не %d" % [H, rows.size()]
	var boss := 0
	for y in H:
		var r: String = rows[y]
		if r.length() != W:
			return "строка %d из %d символов, а нужно %d" % [y + 1, r.length(), W]
		for x in W:
			var ch := r[x]
			if not ch in ["#", ".", "D", "B"]:
				return "непонятный символ «%s»" % ch
			var on_edge := x == 0 or y == 0 or x == W - 1 or y == H - 1
			if ch == "D" and not (x == 0 and y >= DOOR_LO and y <= DOOR_HI):
				return "вход D не на месте (%d, %d)" % [x, y]
			if on_edge and ch != "#" and ch != "D":
				return "дыра в краю арены (%d, %d)" % [x, y]
			if ch == "B":
				boss += 1
	for y in range(DOOR_LO, DOOR_HI + 1):
		if rows[y][0] != "D":
			return "вход должен быть в клетках 6–8 левого края"
	if boss != 1:
		return "нужна ровно одна B (босс), а их %d" % boss
	# Связность: от входа заливкой достижим весь пол.
	var seen := {Vector2i(0, DOOR_LO): true}
	var stack: Array[Vector2i] = [Vector2i(0, DOOR_LO)]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or seen.has(n) or rows[n.y][n.x] == "#":
				continue
			seen[n] = true
			stack.append(n)
	for y in H:
		for x in W:
			if rows[y][x] != "#" and not seen.has(Vector2i(x, y)):
				return "клетка пола (%d, %d) отрезана от входа" % [x, y]
	return ""
