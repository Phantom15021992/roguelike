extends "res://scripts/ember_titan.gd"
## Финальный босс биома (10-й, 20-й, … этаж) — 4 фазы по здоровью: 75 / 50 / 25%.
##
## Фаза 1: метеоритный дождь, дыхание сектором (после него — передышка, +50% урона),
##   призыв монстров своего биома.
## Фаза 2: + волна лавы на половину арены; появляется мини-копия босса 3-го этажа биома.
## Фаза 3: + вращающиеся лучи; мини-копии боссов 3-го и 6-го этажей.
## Фаза 4 «Ярость»: быстрее, лучи чаще; мини-копии всех трёх боссов биома.
## Копии слабее (20% здоровья, 60% урона), но со своими приёмами — их можно бить первыми,
## а можно игнорировать и давить босса (с его смертью исчезают все призванные).

const Roster := preload("res://scripts/boss_roster.gd")


func _setup() -> void:
	super._setup()
	BOSS_NAME = BOSS_NAME if BOSS_NAME != "Владыка пламени" else "Финальный босс"


func _log(msg: String) -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		print("  FINAL: " + msg)


func _phase_for(ratio: float) -> int:
	return 1 if ratio > 0.75 else (2 if ratio > 0.5 else (3 if ratio > 0.25 else 4))


func _on_phase(p: int) -> void:
	if is_mini:
		return
	if p == 4:
		tempo *= 1.3
		beam_cooldown = 7.0
		Game.banner("Ярость!", 2.0)
	_summon_minis.call_deferred(p - 1)  # фаза меняется в момент удара — добавлять монстров только после


## Мини-копии первых боссов биома: 2-я фаза — одна, 3-я — две, 4-я — все три.
func _summon_minis(n: int) -> void:
	var cfgs: Array = Roster.ROSTER[Roster.biome_of(Run.depth)]
	var p := nearest_player()
	var inner := arena.grow(-30.0)
	for i in mini(n, 3):
		var e: Node2D = Roster.make(cfgs[i], Run.depth, true)
		e.arena = arena
		var spot := inner.get_center()
		for k in 20:
			var cand := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
			if (p == null or cand.distance_to(p.global_position) > 70.0) and open_spot(cand) == cand:
				spot = cand
				break
		e.position = open_spot(spot)
		get_parent().add_child(e)
		Game.burst(e.position + Vector2(0, -8), Color(1.0, 0.85, 0.4), 18)
		_log("summon mini %s" % cfgs[i]["name"])
	Game.float_text(global_position + Vector2(0, -48), "Призыв копий боссов!", Color(1.0, 0.85, 0.4))


func _die() -> void:
	var last := Run.depth >= Roster.MAX_DEPTH
	super._die()
	if is_mini:
		return
	if last:
		Game.banner("Подземелье покорено! %s пал." % BOSS_NAME, 6.0)
	else:
		Game.banner("Биом пройден! %s пал." % BOSS_NAME, 4.0)
