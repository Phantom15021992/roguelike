extends "res://scripts/wisp.gd"
## Призма (Хрустальные пещеры): её снаряд через полсекунды полёта распадается на три.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.2, 0.9, 1.5)
	fire_cooldown = 2.6


func _fire(dir: Vector2) -> void:
	var id := spawn_shot(dir, scaled(12), 80.0, Color(1.0, 0.8, 1.0)).get_instance_id()
	get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
		# Снаряд мог уже исчезнуть — ищем его по номеру, а не держим ссылку.
		var b: Variant = instance_from_id(id)
		if b == null or not is_instance_valid(b) or b.team != "enemy":
			return
		for a: float in [-0.45, 0.0, 0.45]:
			var s: Area2D = _E_SHOT.new()
			s.direction = b.direction.rotated(a)
			s.damage = b.damage
			s.speed = 95.0
			s.color = Color(1.0, 0.7, 1.0)
			s.style = "bolt"
			s.position = b.global_position
			Game.fx().add_child(s)
		b.queue_free())
