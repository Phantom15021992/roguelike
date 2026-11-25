extends "res://scripts/bone_lord.gd"
## Ледяная королева (Ледяные пещеры, 12–18): Повелитель костей во льду — копья замедляют.


func _setup() -> void:
	super._setup()
	BOSS_NAME = "Ледяная королева"
	shot_chill = 1.5
	tempo = 1.1
	sprite.self_modulate = Color(0.7, 0.95, 1.4)


func _drop_loot() -> void:
	_boss_loot(randi_range(28, 34), [["ice", 6], ["ore", 3], ["frost_heart", 1]])
