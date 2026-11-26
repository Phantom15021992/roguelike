extends "res://scripts/golem.gd"
## Кристалл-отражатель (Хрустальные пещеры): стрелы и магические снаряды героя отскакивают
## от него обратно (с половиной урона). Бить вблизи — оружием или навыками по площади.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.3, 0.85, 1.45)
	speed = 16.0


## Вызывается снарядом героя при попадании: развернуть его обратно.
func reflect_shot(b: Node) -> bool:
	var to_src: Vector2 = (b.source.global_position - global_position) if is_instance_valid(b.source) else -b.direction
	b.team = "enemy"
	b.set_deferred("collision_mask", 1 | 2)
	b.add_to_group("enemy_shots")
	b.direction = to_src.normalized()
	b.damage = maxi(1, int(b.damage * 0.5))
	b.explode_radius = 0.0
	b.pierce = 0
	b.bounce = 0
	b.color = Color(1.0, 0.7, 1.0)
	b._hit = []
	b._t = 0.0
	b.position = global_position + b.direction * 12.0
	Game.float_text(global_position + Vector2(0, -28), "Отражено!", Color(1.0, 0.75, 1.0))
	return true
