extends "res://scripts/boss_slime.gd"
## Королева топей (Ядовитые топи, 21–27): Король слизней из болот — быстрее, сгустки замедляют.


func _setup() -> void:
	super._setup()
	BOSS_NAME = "Королева топей"
	tempo = 1.2
	shot_chill = 1.0
	sprite.self_modulate = Color(0.7, 1.15, 0.55)


func _drop_loot() -> void:
	_boss_loot(randi_range(32, 38), [["venom", 6], ["gel", 4], ["swamp_pearl", 1]])
