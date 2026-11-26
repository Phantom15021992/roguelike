extends "res://scripts/slime.gd"
## Слизень-делитель (Подземелье, 6–10): после смерти распадается на двух маленьких слизней.

var splits := true


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.55, 1.0, 0.8)


func _die() -> void:
	if splits and not Net.is_guest():
		var scene: PackedScene = load("res://scenes/slime_splitter.tscn")
		for i in 2:
			var s: Node2D = scene.instantiate()
			s.splits = false
			s.size = 0.65
			s.hp_mult = 0.35
			s.xp_reward = 2
			s.item_chance = 0.0
			s.gold_max = 1
			s.position = position + Vector2(-8 + 16 * i, randf_range(-4, 4))
			get_parent().add_child.call_deferred(s)
	super._die()
