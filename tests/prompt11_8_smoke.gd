extends "res://tests/prompt11_8_observation.gd"

func combat_at(distance: float, wait: float = 0) -> void:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 14)
	player.position = Vector3(0, 0.01, 14 + distance)
	player.health.max_health = 10000
	player.health.current_health = 10000
	rat._charge_wait = wait
	rat.provoke(player)
	await frames(2)

func run_checks() -> void:
	check(CombatDecision.choose(1, true, true, 2.5, 7) == CombatDecision.Action.REPOSITION, "too close selects spacing")
	check(CombatDecision.choose(5, true, true, 2.5, 7) == CombatDecision.Action.ATTACK, "mid range selects attack")
	check(CombatDecision.choose(15, true, true, 2.5, 7) == CombatDecision.Action.APPROACH, "far selects approach")
	check(CombatDecision.choose(5, false, true, 2.5, 7) == CombatDecision.Action.APPROACH, "blocked attack lane selects route")
	check(CombatDecision.choose(5, true, false, 2.5, 7) == CombatDecision.Action.REPOSITION, "cooldown makes an attack position")
	await combat_at(5)
	check(rat.state == KingRat.State.TELEGRAPH, "aggro mid range has no discovery wait")
	var direction := rat.charge_direction
	player.position.x += 4
	await frames(42)
	check(rat.state == KingRat.State.CHARGE and rat.charge_direction.is_equal_approx(direction), "telegraph and dodge direction lock preserved")
	await frames(95)
	check(rat.state in [KingRat.State.PURSUIT, KingRat.State.REPOSITION, KingRat.State.TELEGRAPH], "miss recovery returns active decision")
	await combat_at(15)
	var start := rat.position
	await frames(30)
	check(rat.state == KingRat.State.PURSUIT and rat.position.distance_to(start) > 2, "far combat approaches at combat speed")
	var telegraphed := false
	for tick in range(180):
		player.position.z += 0.01
		await frames(1)
		if rat.state == KingRat.State.TELEGRAPH:
			telegraphed = true
			break
	check(telegraphed, "moving target triggers attack when range closes")
	await combat_at(1, 4)
	check(rat.state == KingRat.State.REPOSITION, "close target immediately repositions")
	await frames(90)
	check(rat.combat_distance() >= 3 and rat.separation_push_count <= 1, "close combat opens space without body push follow")
	await combat_at(5, 4)
	start = rat.position
	await frames(60)
	check(rat.state == KingRat.State.REPOSITION and rat.position.distance_to(start) > 1, "cooldown actively changes attack angle")
	check(rat.combat_distance() > 2.5 and rat.combat_distance() < 7, "cooldown movement stays in attack band")
	rat.receive_impact(60, Vector3.FORWARD * 18, player)
	await frames(10)
	check(rat.state == KingRat.State.STAGGER and rat._recoil_left > 0, "strong hit retains movement priority")
	await frames(80)
	check(rat.state in [KingRat.State.PURSUIT, KingRat.State.REPOSITION, KingRat.State.TELEGRAPH, KingRat.State.CHARGE], "hit recovery resumes active combat")
	var observed := await observe_combat()
	check(observed.entries.get("TELEGRAPH", 0) >= 6 and observed.entries.get("CHARGE", 0) >= 6, "thirty second fight sustains readable repeated attacks")
	check(observed.longest_idle < 1 and observed.idle_total < 2, "no long motionless follow during active combat")
	check(observed.inactive == 0 and observed.recovery_gap < 1, "attack recovery quickly connects to a meaningful combat action")
	check(observed.hp < 10000, "active charge still damages player")
	check(not rat.is_defeated and rat.is_aggro, "combat observation remains live")
	quit(0 if failures == 0 else 1)
