extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	day.set_physics_process(false)
	day.shift_elapsed_seconds = 150
	var drunks = mart.get_node("Drunks")
	var drunk: DrunkCustomer = drunks.spawn_drunk()
	check(day.introduction_event_count() == 1,"unresolved drunk initially owns exclusive slot")
	day.shift_elapsed_seconds += day.shift_duration_seconds / 8 * (day.drunk_exclusive_hours-0.01)
	check(day.introduction_event_count() == 1 and day.drunk_slot_release_count == 0,"full resolution grace window retained")
	day.shift_elapsed_seconds += day.shift_duration_seconds / 8 * 0.02
	check(day.introduction_event_count() == 0 and day.active_event_count() == 1,"scheduler release leaves real world event active")
	day.introduction_event_count()
	check(day.drunk_slot_release_count == 1 and drunks.drunks_removed == 0,"lease expiry is finite and never success")
	check(is_instance_valid(drunk) and drunk.is_physics_processing(),"unresolved drunk still simulates normally")
	check(day.event_banner.description.text.contains("출구"),"first drunk guidance states exit goal")
	await place(drunk,drunks.get_node("ExitRemovalZone").global_position)
	await frames(5)
	check(not is_instance_valid(drunk) and drunks.drunks_removed == 1,"late physical exit resolves once after slot release")
	check(day.introduction_event_count() == 0 and day._drunk_slots.is_empty(),"resolved lease references removed")
	quit(1 if failures else 0)