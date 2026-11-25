extends "res://scripts/ember_titan.gd"
## Повелитель бездны — финальный босс 50-го этажа. Огромный, быстрый, с лучами и метеорами.


func _setup() -> void:
	super._setup()
	BOSS_NAME = "Повелитель бездны"
	tempo = 1.5
	scale = Vector2(1.3, 1.3)
	sprite.self_modulate = Color(0.9, 0.35, 1.1)


func _die() -> void:
	super._die()
	Game.banner("Подземелье покорено! Повелитель бездны пал.", 5.0)


func _drop_loot() -> void:
	_boss_loot(randi_range(80, 100), [["horn", 8], ["soul", 6], ["abyss_eye", 2], ["ember_heart", 1]])
