extends "res://scripts/wisp.gd"
## Турель (Механическая кузня): стоит на месте и бьёт очередью из четырёх быстрых пуль.
## Между очередями — пауза: прятаться за колоннами или подбегать в паузу.

var _burst := 0
var _bt := 0.0
var _bdir := Vector2.RIGHT


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.1, 0.95, 0.7)
	knockback_power = 0.0
	fire_cooldown = 2.6
	fire_range = 170.0


func _think(delta: float) -> Vector2:
	super._think(delta)  # отсчёт перезарядки и выстрел (движение турели не нужно)
	if _burst > 0:
		_bt -= delta
		if _bt <= 0.0:
			_bt = 0.12
			_burst -= 1
			var p := nearest_player()
			if p:
				_bdir = (p.global_position - global_position).normalized()
			spawn_shot(_bdir.rotated(randf_range(-0.06, 0.06)), scaled(9), 150.0, Color(1.0, 0.85, 0.4), "bolt")
	return Vector2.ZERO


func _fire(dir: Vector2) -> void:
	_bdir = dir
	_burst = 4
	_bt = 0.0
