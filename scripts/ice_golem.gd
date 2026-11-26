extends "res://scripts/golem.gd"
## Ледяной голем (Ледяные пещеры, 36–40): после удара по земле остаётся ледяное поле — замедляет.

const ICE := Color(0.6, 0.85, 1.0)


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.7, 0.95, 1.45)


func _think(delta: float) -> Vector2:
	var before := state
	var v := super._think(delta)
	if before == "windup" and state == "recover":
		spawn_puddle(global_position, SLAM_RADIUS + 6.0, 4.0, 0, ICE, 1.5)
	return v
