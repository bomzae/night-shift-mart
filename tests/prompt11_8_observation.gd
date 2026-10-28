extends "res://tests/prompt11_smoke.gd"

func observe_combat() -> Dictionary:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 14)
	player.position = Vector3(0, 0.01, 19)
	player.health.max_health = 10000
	player.health.current_health = 10000
	rat._charge_wait = 0
	rat.receive_damage(1, null, player)
	var seconds := {}
	var entries := {}
	var previous := -1
	var idle := 0.0
	var longest_idle := 0.0
	var idle_total := 0.0
	var inactive := 0.0
	var recovery_gap := 0.0
	var max_recovery_gap := 0.0
	for tick in range(1800):
		await frames(1)
		var label: String = KingRat.State.keys()[rat.state]
		seconds[label] = seconds.get(label, 0.0) + 1.0 / 60
		if previous != rat.state: entries[label] = entries.get(label, 0) + 1
		previous = rat.state
		if rat.state not in [KingRat.State.PURSUIT, KingRat.State.TELEGRAPH, KingRat.State.CHARGE, KingRat.State.CHARGE_RECOVERY, KingRat.State.REPOSITION, KingRat.State.RECOIL, KingRat.State.STAGGER]: inactive += 1.0 / 60
		if rat.state == KingRat.State.CHARGE_RECOVERY:
			recovery_gap += 1.0 / 60
			max_recovery_gap = maxf(max_recovery_gap, recovery_gap)
		else: recovery_gap = 0
		var moving := Vector2(rat.velocity.x, rat.velocity.z).length() > 0.25
		if rat.state in [KingRat.State.PURSUIT, KingRat.State.REPOSITION] and not moving:
			idle += 1.0 / 60
			idle_total += 1.0 / 60
			longest_idle = maxf(longest_idle, idle)
		else: idle = 0
	var result := {"seconds": seconds, "entries": entries, "idle_total": idle_total, "longest_idle": longest_idle, "inactive": inactive, "recovery_gap": max_recovery_gap, "hp": player.health.current_health}
	print("COMBAT_30S ", result)
	return result

func run_checks() -> void:
	await observe_combat()
	quit(0)
