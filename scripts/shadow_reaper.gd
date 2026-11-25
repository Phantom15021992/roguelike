extends "res://scripts/bone_lord.gd"
## Теневой жнец (Теневой лабиринт, 30–39): Повелитель костей из тени — заметно быстрее.


func _setup() -> void:
	super._setup()
	BOSS_NAME = "Теневой жнец"
	tempo = 1.35
	sprite.self_modulate = Color(0.6, 0.45, 1.0)


func _drop_loot() -> void:
	_boss_loot(randi_range(36, 44), [["soul", 6], ["bone", 4], ["shadow_gem", 1]])
