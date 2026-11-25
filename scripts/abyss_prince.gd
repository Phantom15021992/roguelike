extends "res://scripts/ember_titan.gd"
## Князь бездны (Бездна, 42–48): Владыка пламени из бездны — быстрее.


func _setup() -> void:
	super._setup()
	BOSS_NAME = "Князь бездны"
	tempo = 1.3
	sprite.self_modulate = Color(1.2, 0.45, 0.55)


func _drop_loot() -> void:
	_boss_loot(randi_range(40, 50), [["horn", 6], ["obsidian", 3], ["abyss_eye", 1]])
