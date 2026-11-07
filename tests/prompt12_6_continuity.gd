extends "res://tests/prompt12_smoke.gd"

func prepare() -> void:
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,19)
	rat.provoke(player)
	rat.update_awareness(0)
	rat.begin_telegraph()

func wait_overlay() -> void:
	for tick in range(60):
		await frames(1)
		if not rat.damage_reaction_active(): return
	check(false, "damage overlay finishes within one second")

func run_checks() -> void:
	await prepare()
	await frames(18)
	var id := rat.attack_instance_id
	var saved := rat.telegraph_remaining
	check(absf(saved-0.35) < 0.02, "0.30 seconds used leaves 0.35 seconds")
	rat.receive_impact(48, Vector3.FORWARD*40, player,0,true)
	check(rat.state == KingRat.State.TELEGRAPH and rat._attack_stagger_left > 0.4, "heavy stagger overlays telegraph instead of replacing it")
	check(not rat.contact_enabled() and rat.mood.text.begins_with("!"), "heavy overlay keeps warning but suppresses contact damage")
	await frames(12)
	check(rat.attack_instance_id == id and rat.telegraph_active and is_equal_approx(saved,rat.telegraph_remaining), "same visible attack pauses during stagger")
	await wait_overlay()
	check(rat.telegraph_resume_count == 1 and is_equal_approx(saved,rat.telegraph_remaining), "heavy resume preserves exact remaining time")
	print("TIMER126 id=",id," before=",saved," after=",rat.telegraph_remaining," starts=",rat.telegraph_start_count," resumes=",rat.telegraph_resume_count)
	await frames(6)
	saved = rat.telegraph_remaining
	rat.receive_impact(22,Vector3.FORWARD*18,player,0,true)
	await wait_overlay()
	check(rat.attack_instance_id == id and is_equal_approx(saved,rat.telegraph_remaining), "second hit preserves same instance and remaining time")
	check(rat.new_attack_commit_count == 1 and rat.telegraph_start_count == 1 and rat.telegraph_resume_count == 2, "one commit one start two resumes")
	for tick in range(60):
		await frames(1)
		if rat.charge_start_count > 0: break
	check(rat.charge_start_count == 1 and rat.attack_instance_id == id and not rat.telegraph_active, "same twice-hit attack launches exactly once")
	print("INSTANCE126 id=",id," commits=",rat.new_attack_commit_count," starts=",rat.telegraph_start_count," resumes=",rat.telegraph_resume_count," charges=",rat.charge_start_count)

	await prepare()
	await frames(37)
	saved = rat.telegraph_remaining
	rat.receive_impact(22,Vector3.FORWARD*18,player,0,true)
	await wait_overlay()
	check(rat.telegraph_active and rat.mood.text == "!" and is_equal_approx(saved,rat.telegraph_remaining), "late hit warning stays visible without adding quarter-second")
	var resumed := Engine.get_physics_frames()
	for tick in range(30):
		await frames(1)
		if rat.charge_start_count > 0: break
	var elapsed := (Engine.get_physics_frames()-resumed)/60.0
	print("LATE126 remaining=",saved," resumed_to_motor=",elapsed)
	check(elapsed >= saved-0.02 and elapsed <= saved+0.04 and rat.charge_start_count == 1, "late resume uses remaining time instead of renewed warning")

	await prepare()
	for tick in range(60):
		await frames(1)
		if rat.charge_start_count > 0: break
	var locked := rat.charge_direction
	await frames(6)
	saved = rat._left
	rat.receive_impact(48,Vector3.LEFT*40,player,0,true)
	check(rat.attack_phase == KingRat.AttackPhase.CHARGE and rat._attack_stagger_left > 0, "charge has physical reaction without changing phase")
	player.position.x = 5
	await frames(10)
	check(is_equal_approx(saved,rat._left) and rat.charge_direction.is_equal_approx(locked), "charge reaction pauses original execution clock and locked direction")
	await wait_overlay()
	var retelegraphed := false
	for tick in range(90):
		await frames(1)
		retelegraphed = retelegraphed or rat.telegraph_active
	check(not retelegraphed and rat.charge_start_count == 1 and rat.telegraph_resume_count == 0 and rat.telegraph_start_count == 1, "charge continues once without retelegraph or resume event")
	check(not rat.attack_committed and rat.charge_direction.is_equal_approx(locked), "paused charge completes without homing or renewing duration")
	print("P126 continuity complete failures=",failures)
	quit(1 if failures else 0)
