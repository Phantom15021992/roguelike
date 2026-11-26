extends "res://scripts/bat.gd"
## Мышь-вампир (Подземелье, 6–10): кусает в броске и лечится на нанесённый урон.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.3, 0.45, 0.5)


func _check_contact() -> void:
	if contact_damage <= 0 or not _is_dangerous():
		return
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead and global_position.distance_to(p.global_position) < contact_radius:
			var before: int = p.hp
			p.take_damage(contact_damage, global_position)
			var got: int = before - p.hp
			if got > 0 and hp < max_hp:
				hp = mini(max_hp, hp + got)
				Game.float_text(global_position + Vector2(0, -20), "+%d" % got, Color(0.5, 1.0, 0.5))
