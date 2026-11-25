extends "res://scripts/wisp.gd"
## Некромант (Теневой лабиринт, 30+): держится поодаль, стреляет и поднимает скелетов
## (не больше двух своих одновременно).

const SKELETON_SCENE := preload("res://scenes/skeleton.tscn")
var _summon_cd := 4.0
var _minions: Array = []


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.45, 0.95, 0.55)
	shot_color = Color(0.45, 0.95, 0.55)


func _think(delta: float) -> Vector2:
	var v := super._think(delta)
	_summon_cd -= delta
	_minions = _minions.filter(func(m: Node) -> bool: return is_instance_valid(m) and not m.dead)
	var p := nearest_player()
	if _summon_cd <= 0.0 and p and global_position.distance_to(p.global_position) < 160.0 and _minions.size() < 2:
		_summon_cd = 9.0
		var s: Node2D = SKELETON_SCENE.instantiate()
		s.position = position + Vector2(randf_range(-14, 14), randf_range(8, 14))
		s.xp_reward = 2
		s.item_chance = 0.0
		get_parent().add_child(s)
		_minions.append(s)
		Game.burst(s.position + Vector2(0, -6), Color(0.45, 0.95, 0.55), 14)
	return v
