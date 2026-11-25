extends "res://scripts/slime.gd"
## Ледяной слизень (Ледяные пещеры, 10+): крепче обычного, после смерти оставляет ледяную
## лужу — кто в неё зайдёт, замедлится.

const ICE_PUDDLE := preload("res://scripts/puddle.gd")


func _setup() -> void:
	super._setup()
	sprite.self_modulate = Color(0.75, 0.95, 1.35)


func _die() -> void:
	var p: Node2D = ICE_PUDDLE.new()
	p.team = "enemy"
	p.damage = 0
	p.chill = 1.2
	p.radius = 18.0
	p.lifetime = 6.0
	p.color = Color(0.6, 0.85, 1.0)
	p.position = position
	Game.ground().add_child(p)
	super._die()
