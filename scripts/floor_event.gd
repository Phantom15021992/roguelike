extends Node2D
## Случайное событие на этаже (реиграбельность): стоит в одной из комнат, E — воспользоваться.
##   altar    — Алтарь крови: −30% здоровья, зато +15% урона до конца забега.
##   chest    — Сундук: золото и предмет… или мимик (элитный монстр).
##   traveler — Раненый путник: отдай золото — он отдаст редкую вещь.
##   fountain — Фонтан: полностью лечит HP и SP всем героям.
## Срабатывает один раз. В кооперативе — для того героя, кто нажал.

const Items := preload("res://scripts/items.gd")
const KINDS := ["altar", "chest", "traveler", "fountain"]
const NAMES := {"altar": "Алтарь крови", "chest": "Сундук", "traveler": "Раненый путник", "fountain": "Фонтан"}

var kind := "chest"
var used := false
var bait := false   # приманка комнаты-ловушки: сундук без мимика
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")


func net_props() -> Array:
	return ["kind", "used"]


func net_state() -> Array:
	return [used]


func net_apply(a: Array) -> void:
	used = a[0]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func map_color() -> Color:
	return Color(0.5, 0.5, 0.5) if used else Color(1.0, 0.95, 0.4)


func interact_point() -> Vector2:
	return global_position + Vector2(0, 4)


func _cost() -> int:
	return 20 + Run.depth * 3


## Приманка ловушки: пока в комнате бой, пользоваться нельзя.
func _locked() -> bool:
	if not bait:
		return false
	var s := get_tree().current_scene
	return s != null and str(s.get("_trap_state")) != "done"


func prompt() -> String:
	if _locked() and str(get_tree().current_scene.get("_trap_state")) == "fight":
		return "Сначала перебей всех в комнате"
	if used:
		return NAMES[kind] + (" — спасибо, путник ушёл" if kind == "traveler" else " — уже использован")
	match kind:
		"altar":
			return "E — Алтарь крови: отдать 30% здоровья за +15% урона до конца забега"
		"chest":
			return "E — открыть сундук (а вдруг мимик?)"
		"traveler":
			return "E — Раненый путник: отдать %d золота — он отдаст редкую вещь" % _cost()
		"fountain":
			return "E — Фонтан: вылечить всех героев"
	return ""


func interact(hero: Node) -> void:
	if used:
		return
	if _locked() and str(get_tree().current_scene.get("_trap_state")) == "fight":
		Game.hint_to(hero, "Сначала перебей всех в комнате")
		return
	var st: Node = hero.st
	match kind:
		"altar":
			hero.hp = maxi(1, hero.hp - int(hero.max_hp * 0.3))
			st.run_dmg += 15
			st.changed.emit()
			Game.float_text(global_position + Vector2(0, -24), "+15% урона до конца забега", Color(1.0, 0.4, 0.4))
			Game.burst(global_position + Vector2(0, -8), Color(0.9, 0.15, 0.2), 20)
		"chest":
			if not bait and randf() < 0.3:
				_mimic()
			else:
				for i in randi_range(5, 9):
					_drop("gold", {})
				var hs: Node = Game.random_hero_state()
				_drop("item", Items.make(Items.random_base(hs.cls, hs.job), 2 if randf() < 0.4 else 1, Run.depth))
				Game.burst(global_position + Vector2(0, -8), Color(1.0, 0.85, 0.3), 16)
		"traveler":
			if Run.gold < _cost():
				Game.hint_to(hero, "Нужно %d золота" % _cost())
				return
			Run.gold -= _cost()
			Run.changed.emit()
			_drop("item", Items.make(Items.random_base(st.cls, st.job), 2, Run.depth))
			Game.float_text(global_position + Vector2(0, -24), "Спасибо, добрый путник!", Color(0.9, 0.9, 0.7))
		"fountain":
			for h in get_tree().get_nodes_in_group("player"):
				if not h.dead:
					h.hp = h.max_hp
					h.sp = h.max_sp
			Game.ring(global_position, 40.0, Color(0.5, 0.8, 1.0))
			Game.float_text(global_position + Vector2(0, -24), "Силы восстановлены", Color(0.6, 0.85, 1.0))
	used = true
	Game.quest_progress("events")


func _mimic() -> void:
	var scene := get_tree().current_scene
	var pool: Array = scene.monsters_for(Run.depth) if scene and scene.has_method("monsters_for") else [["s", 1]]
	var letter: String = pool[randi() % pool.size()][0]
	var e: Node2D = scene.SPAWNS[letter].instantiate()
	e.elite = true
	e.elite_kind = ["armored", "swift", "explosive", "regen"].pick_random()
	e.position = position + Vector2(0, 8)
	scene.get_node("Entities").add_child.call_deferred(e)
	Game.banner("Мимик!", 1.5)
	Game.shake(3.0, 0.3)


func _drop(k: String, item: Dictionary) -> void:
	var p: Node2D = preload("res://scripts/pickup.gd").new()
	p.kind = k
	p.value = Run.depth
	p.item = item
	p.position = position + Vector2(0, 10)
	get_parent().add_child.call_deferred(p)


func _draw() -> void:
	draw_circle(Vector2(0, 0), 6.0, Color(0, 0, 0, 0.3))
	var dim := 0.5 if used else 1.0
	match kind:
		"altar":
			draw_rect(Rect2(-7, -10, 14, 10), Color(0.4, 0.35, 0.4) * dim)
			draw_rect(Rect2(-5, -12, 10, 3), Color(0.55, 0.5, 0.55) * dim)
			if not used:
				draw_circle(Vector2(0, -16 + sin(_t * 3.0)), 2.5, Color(0.95, 0.15, 0.2))
		"chest":
			draw_rect(Rect2(-7, -9, 14, 9), Color(0.55, 0.35, 0.18) * dim)
			draw_rect(Rect2(-7, -11, 14, 3), Color(0.7, 0.45, 0.22) * dim)
			draw_rect(Rect2(-1, -8, 2, 3), Color(1.0, 0.85, 0.3) * dim)
		"traveler":
			draw_rect(Rect2(-3, -12, 6, 9), Color(0.45, 0.4, 0.55) * dim)
			draw_circle(Vector2(0, -15), 3.0, Color(0.9, 0.75, 0.6) * dim)
			if not used:
				draw_line(Vector2(-4, -6), Vector2(4, -9), Color(0.9, 0.2, 0.2), 1.0)
		"fountain":
			draw_circle(Vector2(0, -3), 8.0, Color(0.45, 0.45, 0.5) * dim)
			draw_circle(Vector2(0, -3), 6.0, Color(0.3, 0.6, 1.0, 0.9) * dim)
			if not used:
				draw_circle(Vector2(0, -8 - absf(sin(_t * 4.0)) * 3.0), 1.5, Color(0.7, 0.9, 1.0))
