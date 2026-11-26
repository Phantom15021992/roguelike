extends "res://scripts/bat.gd"
## Болотная мошкара (Ядовитые топи, 46–50): маленькие и хрупкие, но всегда роем по трое.

var swarm_child := false


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.75, 1.0, 0.5)
	speed *= 1.3
	if not swarm_child and not Net.is_guest():
		var scene: PackedScene = load("res://scenes/gnat.tscn")
		for i in 2:
			var g: Node2D = scene.instantiate()
			g.swarm_child = true
			g.position = position + Vector2.from_angle(TAU * i / 2.0) * 10.0
			get_parent().add_child.call_deferred(g)
