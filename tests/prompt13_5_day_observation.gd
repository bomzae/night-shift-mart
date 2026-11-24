extends "res://tests/prompt4_smoke.gd"
func flow_name() -> String:
	return "resolved"

func run_checks() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	player = mart.get_node("Player")
	interaction = player.get_node("Interaction")
	manager = mart.get_node("Customers")
	var day: DayManager = mart.get_node("DayManager")
	while day.state != DayManager.State.ACTIVE: await frames(1)
	player.health.max_health = 10000
	player.health.current_health = 10000
	var stamps := {}
	var starts := {}
	day.event_started.connect(func(kind):
		stamps[kind] = day.clock_text()
		starts[kind] = day.shift_elapsed_seconds
		print("DAY135 EVENT ",kind," time=",day.clock_text()," seconds=",day.shift_elapsed_seconds))
	var drunk_done := false
	var family_done := false
	var previous_gate := ""
	for tick in range(72300):
		await frames(1)
		if flow_name() != "late_drunk" and starts.has(&"drunk") and not drunk_done and day.shift_elapsed_seconds > starts[&"drunk"] + 30:
			for body in mart.get_node("Drunks").get_children():
				if body is DrunkCustomer:
					# Position only the carried actor at the real delivery trigger;
					# never edit event flags, scheduler clocks, counters or completion.
					body.begin_carry(interaction,player)
					interaction.held_object = body
					await place(body,mart.get_node("Drunks/ExitRemovalZone").global_position)
					interaction.drop_held(true)
					drunk_done = true
					print("DAY135 DRUNK EXIT DELIVERY ",day.clock_text())
		if starts.has(&"family") and not family_done and day.shift_elapsed_seconds > starts[&"family"] + 30:
			for pair in mart.get_node("LostFamilies").pairs:
				pair.child.begin_carry(interaction,player)
				interaction.held_object = pair.child
				await place(pair.child,pair.parent.position+Vector3(0,0.65,0.7))
				interaction.drop_held(true)
				family_done = pair.child.reunited
				if flow_name() == "slow_exit": pair.parent.set_physics_process(false)
				print("DAY135 FAMILY DROP ",day.clock_text()," reunited=",family_done)
		if tick % 1800 == 0:
			var families := []
			for pair in mart.get_node("LostFamilies").pairs:
				families.append({"reunited":pair.child.reunited,"parent":pair.parent.position,"state":pair.parent.state,"waypoints":pair.parent.waypoints,"exit":pair.parent.exit_arrived})
			var report := {"time":day.clock_text(),"active":day.active_event_count(),"exclusive":day.introduction_event_count(),"step":day._intro_step,"retry":day._intro_retry_hour,"spacing":day._intro_cooldown,"drunks":day._drunk_slots.size(),"families":families,"boss":is_instance_valid(mart.get_node("Bosses").boss),"banner":day.event_banner.current}
			if day.has_method("introduction_status"): report["scheduler"] = day.introduction_status()
			print("DAY135 STATE ",JSON.stringify(report))
		if day.state == DayManager.State.RESULT:
			print("DAY135 RESULT ",day.clock_text()," ticks=",tick," stamps=",stamps)
			break
	check(day.shift_duration_seconds == 1200 and Engine.time_scale == 1,"default twenty-minute clock and real scheduler delta unchanged")
	check((drunk_done or flow_name() == "late_drunk") and family_done,"real delivery/drop resolves selected introductory goals")
	if flow_name() == "late_drunk":
		check(day.drunk_slot_release_count == 1 and mart.get_node("Drunks").drunks_removed == 0,"unresolved drunk lease releases once without fake completion")
	check(stamps.has(&"thief") and stamps.has(&"boss"),"normal Main reaches thief and boss after family")
	check(day.state == DayManager.State.RESULT and not day.failed,"full default shift reaches normal result")
	day.confirm_result()
	check(day.day_number == 2 and day.clock_text() == "22:00","default full day resets to Day 2")
	print("Full day observation completed")
	quit(1 if failures else 0)
