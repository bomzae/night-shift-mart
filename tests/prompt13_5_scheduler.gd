extends "res://tests/prompt6_1_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	day.set_physics_process(false)
	day._intro_step = 2
	day.shift_elapsed_seconds = 600
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	day._record_intro_attempt("family",child,"")
	day.event_banner.clear_pending()
	day._tick_timeline()
	check(day.introduction_event_count() == 1 and day.automatic_events == 0,"unresolved family still owns exclusive slot")
	check(await reunite_at(child,Vector3(0,0.65,0.7)),"actual carried-child drop completes reunion")
	child.parent_npc.set_physics_process(false)
	day._refresh_intro_states()
	check(day.intro_states.family == "RESOLVED" and day.active_event_count() == 1 and day.introduction_event_count() == 0,"goal resolved while physical family still exits: slot released")
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,2,2)
	collider.shape = box
	blocker.add_child(collider)
	mart.add_child(blocker)
	blocker.global_position = manager.exit_position()+Vector3.UP*0.85
	await frames(3)
	day._tick_timeline()
	check(day._intro_step == 2 and day.intro_states.thief == "FAILED_TO_SPAWN","blocked entrance does not consume scheduled thief")
	check(day.intro_spawn_failure == "thief:entrance_blocked","failed spawn reports actual collision gate")
	blocker.queue_free()
	await frames(3)
	day.shift_elapsed_seconds = 601
	day._tick_timeline()
	check(day.automatic_events == 0,"failed spawn respects retry interval")
	day.shift_elapsed_seconds = 616
	day._tick_timeline()
	check(day.automatic_events == 1 and day.intro_states.thief == "ACTIVE" and day._intro_step == 3,"clear entrance retries actual thief successfully")
	check(day._intro_cooldown == 12,"successful spawn keeps minimum event spacing")
	await frames(1800)
	day._refresh_intro_states()
	check(day.intro_states.thief == "RESOLVED","empty-stock thief physically exits and releases event")
	day.shift_elapsed_seconds = 900
	day._intro_cooldown = 0
	day.event_banner.clear_pending()
	day._tick_timeline()
	check(day.automatic_bosses == 1 and is_instance_valid(mart.get_node("Bosses").boss),"late boss remains eligible after retry and slow family exit")
	check(child.reunited and is_instance_valid(child.parent_npc),"scheduler release does not delete reunited family")
	day.end_day()
	day._finish_day()
	await frames(4)
	day.confirm_result()
	check(day.day_number == 2 and day._intro_actors.is_empty() and day.intro_states.family == "NOT_STARTED","Day 2 clears introduction diagnostics and weak references")
	quit(1 if failures else 0)
