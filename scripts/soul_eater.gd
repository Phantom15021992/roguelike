extends "res://scripts/wisp.gd"
## Пожиратель душ (Бездна, 66–70): раз в 4 секунды лечит монстров вокруг (зелёное кольцо).
## Его надо убивать первым.

var _heal_cd := 3.0


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.95, 0.5, 1.3)


func _think(delta: float) -> Vector2:
	_heal_cd -= delta
	if _heal_cd <= 0.0:
		_heal_cd = 4.0
		var healed := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and not e.dead and e.hp < e.max_hp and e.global_position.distance_to(global_position) < 90.0:
				var add := int(e.max_hp * 0.2)
				e.hp = mini(e.max_hp, e.hp + add)
				Game.float_text(e.global_position + Vector2(0, -22), "+%d" % add, Color(0.5, 1.0, 0.5))
				healed += 1
		if healed > 0:
			Game.ring(global_position, 90.0, Color(0.5, 1.0, 0.5))
	return super._think(delta)
