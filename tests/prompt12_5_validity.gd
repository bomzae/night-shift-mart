extends "res://tests/prompt12_smoke.gd"

func ready_attack() -> void:
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,19)
	rat.provoke(player)
	rat._charge_wait = 0
	await frames(3)
	check(rat.attack_committed and rat.state == KingRat.State.TELEGRAPH, "normal combat decision commits only ready valid attack")

func run_checks() -> void:
	await ready_attack()
	player.health.receive_damage(1000)
	await frames(2)
	check(not rat.attack_committed and rat.attack_cancel_count == 1 and rat.state != KingRat.State.CHARGE, "downed target cancels pending attack")
	await ready_attack()
	rat.clear_aggro()
	await frames(2)
	check(not rat.attack_committed and not rat.is_aggro and rat.attack_cancel_count == 1, "aggro end cancels intent")
	await ready_attack()
	rat.receive_damage(1000, null, player)
	check(rat.is_defeated and not rat.attack_committed and rat.last_attack_cancel == "defeated", "defeat cancels attack before execution")
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(8,0.01,20)
	var other: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	other.position = Vector3(0,0.01,19)
	mart.add_child(other)
	other.set_physics_process(false)
	rat.provoke(other)
	rat._charge_wait = 0
	await frames(3)
	check(rat.attack_committed, "second valid target commits")
	other.queue_free()
	await frames(3)
	check(not rat.attack_committed and rat.attack_cancel_count == 1, "removed target leaves no stale intent")
	await ready_attack()
	await frames(12)
	var saved := rat.telegraph_remaining
	var wall := Graybox.box(mart, "TemporaryBlock", Vector3(4,2,0.3), Vector3(0,1,16.5), Color.GRAY)
	await frames(12)
	check(rat.attack_committed and rat.telegraph_active and rat.state == KingRat.State.TELEGRAPH and is_equal_approx(saved, rat.telegraph_remaining), "temporary obstruction pauses the same visible warning without losing progress")
	wall.queue_free()
	await frames(2)
	check(rat.state == KingRat.State.TELEGRAPH and rat.mood.text == "!" and rat.telegraph_start_count == 1 and absf(rat.telegraph_remaining-saved) < 0.04, "cleared obstruction continues the same visible warning and remainder")
	var charged := false
	for tick in range(60):
		await frames(1)
		charged = charged or rat.state == KingRat.State.CHARGE
	check(charged and rat.attack_cancel_count == 0, "temporarily blocked committed attack eventually executes")
	await ready_attack()
	wall = Graybox.box(mart, "PersistentBlock", Vector3(4,2,0.3), Vector3(0,1,16.5), Color.GRAY)
	await frames(90)
	check(not rat.attack_committed and rat.last_attack_cancel == "path_blocked" and rat.charge_count == 0, "persistent geometry cancels safely without charge through wall")
	check(rat.is_aggro and rat.state in [KingRat.State.PURSUIT, KingRat.State.REPOSITION, KingRat.State.HOLD], "invalid path returns existing combat recovery")
	await ready_attack()
	rat.position.z = 12.2 # Commit is already valid; a real impulse moves it beyond the normal seven-meter band.
	rat.receive_impact(12, Vector3.FORWARD * 150, player, 0, true)
	var origin := rat.position
	await frames(18)
	check(rat.attack_committed and rat.combat_distance() > rat.charge_range and rat.position.z < origin.z-0.5, "broom force beyond normal range preserves intent at new origin")
	charged = false
	for tick in range(60):
		await frames(1)
		if rat.state == KingRat.State.CHARGE:
			charged = true
			break
	check(charged and rat.attack_cancel_count == 0 and rat.position.z < origin.z, "distance alone never cancels or teleports attack")
	print("P125 validity complete failures=", failures)
	quit(1 if failures else 0)
