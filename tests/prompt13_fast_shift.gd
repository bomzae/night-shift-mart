extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	var delivery: DeliveryManager = mart.get_node("Delivery")
	day.shift_duration_seconds = 30
	day.ending_duration = 2
	day.timeline_enabled = true
	day.day_number = 2 # Preserve the original free-pacing contract; Day 1 has a dedicated onboarding test.
	day.start_day()
	delivery.set_physics_process(true)
	manager._rng.seed = 13
	manager.spawn_interval_min = 2
	manager.spawn_interval_max = 3
	manager._reset_timer()
	manager.patience_time = 90
	mart.get_node("AutoStock").top_up() # Day 2 does not refill; this fixture supplies inventory.
	player.health.max_health = 10000
	player.health.current_health = 10000
	var observed_customers := 0
	var observed_delivery := false
	var observed_boss := false
	var phase_samples: Array[String] = []
	for tick in range(1801):
		await frames(1)
		observed_customers = maxi(observed_customers, manager.customers.size())
		observed_delivery = observed_delivery or delivery.truck_present
		if tick < 1340: check_no_early_boss(day)
		if is_instance_valid(mart.get_node("Bosses").boss): observed_boss = true
		if tick % 450 == 0:
			phase_samples.append(day.clock_text())
			print("FAST SHIFT tick=", tick, " clock=", day.clock_text(), " phase=", day.timeline_phase(), " customers=", manager.customers.size(), " events=", day.automatic_events, " auto_boss=", day.automatic_bosses)
	check(observed_customers > 0 and observed_delivery, "30-second Main shift runs customers and physical delivery")
	check(day.automatic_events >= 1 and day.automatic_events <= 5, "timeline invokes existing events without spam")
	check(observed_boss and day.automatic_bosses == 1, "late shift spawns exactly one automatic boss")
	check(day.state == DayManager.State.ENDING and day.clock_text() == "06:00", "unskipped 30 seconds reaches normal end")
	await frames(140)
	check(day.state == DayManager.State.RESULT and not day.failed, "full shift reaches complete result")
	check(manager.customers.is_empty() and mart.get_node("Bosses").boss == null and not delivery.truck_present, "full shift cleanup before next day")
	day.confirm_result()
	check(day.day_number == 3 and day.clock_text() == "22:00", "full cycle next day starts at 22")
	await frames(10)
	# Existing manual debug R remains usable during early shift; no duplicate auto boss.
	await press("spawn_king_rat")
	var boss = mart.get_node("Bosses").boss
	check(is_instance_valid(boss), "manual boss key remains usable early")
	if is_instance_valid(boss):
		await frames(2)
		boss.queue_free()
		await frames(2)
	day.shift_elapsed_seconds = 22.5
	await frames(10)
	check(day.boss_spawned_today and day.automatic_bosses == 0 and not is_instance_valid(mart.get_node("Bosses").boss), "manual boss consumes daily automatic allowance")
	var before := day.elapsed_hours()
	var skip := InputEventKey.new()
	skip.physical_keycode = KEY_J
	skip.pressed = true
	Input.parse_input_event(skip)
	await frames(2)
	skip = InputEventKey.new()
	skip.physical_keycode = KEY_J
	Input.parse_input_event(skip)
	check(day.elapsed_hours() > before + 0.99 and day.elapsed_hours() < before + 1.1, "J adds one game hour without InputMap rewrite")
	print("Prompt 13 fast shift completed; failures: ", failures)
	quit(0 if failures == 0 else 1)

func check_no_early_boss(day: DayManager) -> void:
	if day.automatic_bosses > 0:
		check(false, "boss must not auto spawn before 04:00")
		day.timeline_enabled = false
