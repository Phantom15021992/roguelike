extends "res://scripts/golem.gd"
## Костяной щитоносец (Катакомбы, 16–20): почти неуязвим спереди (щит), зато быстрее голема.
## Заходи сбоку и сзади — или бей броском, пока он разворачивается.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(1.15, 1.1, 0.95)
	speed = 34.0


func take_damage(amount: int, from: Vector2, crit := false, missable := true) -> void:
	var dir := from - global_position
	if dir.length() > 1.0 and absf(facing.angle_to(dir)) < FRONT_ARC:
		amount = maxi(1, int(round(amount * 0.25)))  # вместе с блоком голема — 10% урона
	super.take_damage(amount, from, crit, missable)
