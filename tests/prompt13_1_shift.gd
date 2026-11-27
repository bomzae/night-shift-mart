extends "res://tests/prompt13_1_events.gd"

func run_checks() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	manager = mart.get_node("Customers")
	player = mart.get_node("Player")
	var day: DayManager = mart.get_node("DayManager")
	day.shift_duration_seconds = 60
	for tick in range(240):
		if day.state == DayManager.State.ACTIVE: break
		await frames(1)
	player.health.max_health = 10000
	player.health.current_health = 10000
	var starts: Array[StringName] = []
	day.event_started.connect(func(type: StringName):
		if type!=&"thief": starts.append(type))
	mart.get_node("Thieves").thief_entered.connect(func(_actor): starts.append(&"thief"))
	var event_age := 0.0
	var observed_customers := 0
	var observed_delivery := false
	var overlap := false
	for tick in range(3601):
		await frames(1)
		observed_customers = maxi(observed_customers, manager.customers.size())
		observed_delivery = observed_delivery or mart.get_node("Delivery").truck_present
		overlap = overlap or day.active_event_count() > 1
		if day.active_event_count() > 0:
			event_age += 1.0 / 60.0
			if event_age >= 4:
				# Fixture simulates resolving each introduction; never bypasses pacing gates.
				await clear_specials()
				event_age = 0
		if tick % 900 == 0:
			print("INTRO SHIFT clock=", day.clock_text(), " events=", starts, " customers=", manager.customers.size())
	check(day.starter_stock_count == 131, "real Day 1 supplies starter before automatic shift")
	check(observed_customers > 0 and observed_delivery, "Day 1 customers and delivery operate with starter inventory")
	check(starts == [&"drunk", &"family", &"thief", &"boss"], "60-second Day 1 introduces events in order then late boss")
	check(not overlap and day.automatic_bosses == 1, "Day 1 automatic introductions do not overlap or duplicate boss")
	await frames(150)
	check(day.state == DayManager.State.RESULT and not day.failed and day.clock_text() == "06:00", "Day 1 reaches normal 06:00 result")
	day.confirm_result()
	check(day.day_number == 2 and day.clock_text() == "22:00", "onboarding shift continues to Day 2")
	print("Prompt 13.1 shift completed; failures: ", failures)
	quit(1 if failures else 0)
