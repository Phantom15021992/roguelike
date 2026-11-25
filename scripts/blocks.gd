extends RefCounted
## Блоки этажей из data/blocks.txt: загрузка, проверка, повороты и отражения.
##
## Блок после загрузки: {name, tag, rows: Array[String], doors: {"N","E","S","W"} -> true}.
## Варианты блока (variants) — все повороты и отражения с уже посчитанными проходами.

const PATH := "res://data/blocks.txt"
const SIZE := 15
const DOOR_LO := 6
const DOOR_HI := 8

static var _blocks: Array = []


static func all() -> Array:
	if _blocks.is_empty():
		_load()
	return _blocks


static func with_tag(tag: String) -> Array:
	return all().filter(func(b: Dictionary) -> bool: return b["tag"] == tag)


static func _load() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("Не найден файл блоков " + PATH)
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
			cur = {"name": parts[0], "tag": parts[1] if parts.size() > 1 else "room", "rows": []}
		elif not cur.is_empty():
			cur["rows"].append(line)
	if not cur.is_empty():
		_finish(cur)


static func _finish(b: Dictionary) -> void:
	var err := _validate(b["rows"])
	if err != "":
		push_error("Блок «%s»: %s — пропущен" % [b["name"], err])
		return
	b["doors"] = doors_of(b["rows"])
	b["variants"] = _variants(b["rows"])
	_blocks.append(b)


## Проверка: размер, проходы только в серединах краёв, все проходы связаны полом.
static func _validate(rows: Array) -> String:
	if rows.size() != SIZE:
		return "должно быть %d строк, а не %d" % [SIZE, rows.size()]
	for r in rows:
		if (r as String).length() != SIZE:
			return "строка «%s» не из %d символов" % [r, SIZE]
	for y in SIZE:
		for x in SIZE:
			var ch: String = rows[y][x]
			if not ch in ["#", ".", "D", "M", "P", "S", "L", "A"]:
				return "непонятный символ «%s»" % ch
			var on_edge := x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1
			var mid := (x >= DOOR_LO and x <= DOOR_HI) or (y >= DOOR_LO and y <= DOOR_HI)
			if ch == "D" and not (on_edge and mid):
				return "проход D не на месте (%d, %d)" % [x, y]
			if on_edge and ch != "#" and ch != "D":
				return "дыра в краю блока (%d, %d)" % [x, y]
	# Связность: от первого прохода заливкой должны достигаться все остальные клетки пола.
	var start := Vector2i(-1, -1)
	var floor_count := 0
	for y in SIZE:
		for x in SIZE:
			if rows[y][x] != "#":
				floor_count += 1
				if rows[y][x] == "D" and start.x < 0:
					start = Vector2i(x, y)
	if start.x < 0:
		return "нет ни одного прохода D"
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for o in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + o
			if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and rows[n.y][n.x] != "#" and not seen.has(n):
				seen[n] = true
				stack.append(n)
	var unreachable_doors := 0
	for y in SIZE:
		for x in SIZE:
			if rows[y][x] == "D" and not seen.has(Vector2i(x, y)):
				unreachable_doors += 1
	if unreachable_doors > 0:
		return "проходы не связаны между собой"
	return ""


## Какие стороны блока имеют проходы.
static func doors_of(rows: Array) -> Dictionary:
	var d := {}
	if rows[0][7] == "D":
		d["N"] = true
	if rows[SIZE - 1][7] == "D":
		d["S"] = true
	if rows[7][0] == "D":
		d["W"] = true
	if rows[7][SIZE - 1] == "D":
		d["E"] = true
	return d


## 4 поворота x 2 отражения, без повторов.
static func _variants(rows: Array) -> Array:
	var out := []
	var seen := {}
	var cur := rows
	for mirror in 2:
		for rot in 4:
			var key := "\n".join(cur)
			if not seen.has(key):
				seen[key] = true
				out.append({"rows": cur, "doors": doors_of(cur)})
			cur = _rotate(cur)
		cur = _mirror(rows)
	return out


static func _rotate(rows: Array) -> Array:
	var out := []
	for y in SIZE:
		var line := ""
		for x in SIZE:
			line += rows[SIZE - 1 - x][y]
		out.append(line)
	return out


static func _mirror(rows: Array) -> Array:
	return rows.map(func(r: String) -> String: return r.reverse())
