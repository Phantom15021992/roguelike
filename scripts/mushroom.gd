extends "res://scripts/enemy.gd"
## Гриб-споровик: стоит на месте. Если герой рядом — набухает и выпускает облако ядовитых спор.
## Лучше бить издалека или между выдохами.

const SHEET := preload("res://assets/mushroom.png")
const PUDDLE := preload("res://scripts/puddle.gd")
const WINDUP := 0.7

@export var trigger_range := 60.0
@export var cloud_damage := 7
@export var cooldown := 3.0

var state := "idle"
var _t := 0.0


func _setup() -> void:
	knockback_power = 0.0
	sprite.sprite_frames = make_frames(SHEET, {"idle": [[0], 1.0], "puff": [[0, 1], 8.0]})
	sprite.play("idle")
	_t = randf_range(0.5, cooldown)
	cloud_damage = int(round(cloud_damage * (1.0 + 0.15 * (Run.depth - 1))))


func _think(delta: float) -> Vector2:
	_t -= delta
	var p := nearest_player()
	match state:
		"idle":
			if _t <= 0.0 and p and global_position.distance_to(p.global_position) < trigger_range:
				state = "windup"
				_t = WINDUP
				sprite.play("puff")
		"windup":
			if _t <= 0.0:
				_release_cloud()
				state = "idle"
				_t = cooldown
				sprite.play("idle")
	return Vector2.ZERO


## Облако спор (наследники меняют: морозный гриб — холод).
func _release_cloud() -> void:
	spawn_puddle(global_position, 26.0, 3.5, cloud_damage, Color(0.6, 0.4, 0.75))
	Game.burst(global_position + Vector2(0, -10), Color(0.7, 0.5, 0.85), 14)


func _extra_flash() -> float:
	return 0.5 if state == "windup" else 0.0
