extends "res://scripts/shade.gd"
## Двойник (Теневой лабиринт, 56–60): ранен наполовину — раздваивается: появляются две иллюзии.
## Иллюзии слабые и исчезают через 8 секунд; бить надо настоящего (он ярче).

var illusion := false
var _split := false
var _life := 8.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.75, 0.6, 1.2, 0.9 if not illusion else 0.45)
	if illusion:
		contact_damage = int(contact_damage / 2.0)


func _think(delta: float) -> Vector2:
	if illusion:
		_life -= delta
		if _life <= 0.0:
			_die()
			return Vector2.ZERO
	return super._think(delta)


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	super.take_damage(amount, from, crit, missable)
	if dead or illusion or _split or hp * 2 > max_hp or Net.is_guest():
		return
	_split = true
	var scene: PackedScene = load("res://scenes/mirror_shade.tscn")
	for i in 2:
		var c: Node2D = scene.instantiate()
		c.illusion = true
		c.hp_mult = 0.15
		c.xp_reward = 0
		c.gold_min = 0
		c.gold_max = 0
		c.item_chance = 0.0
		c.mat_chance = 0.0
		c.position = position + Vector2.from_angle(randf() * TAU) * 18.0
		get_parent().add_child.call_deferred(c)
	Game.float_text(global_position + Vector2(0, -22), "Двоится!", Color(0.75, 0.6, 1.2))
