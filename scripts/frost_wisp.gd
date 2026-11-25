extends "res://scripts/wisp.gd"
## Морозный дух (Ледяные пещеры, 10+): как дух, но ледяные сгустки замедляют героя.


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.65, 0.9, 1.35)
	shot_chill = 1.5
	shot_color = Color(0.6, 0.85, 1.0)
