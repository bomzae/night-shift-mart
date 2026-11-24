extends "res://tests/prompt6_1_smoke.gd"
func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	day.set_physics_process(false)
	day._intro_step = 2 # Prior introductions have actually happened in the long Main fixture.
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	check(await reunite_at(child,Vector3(0,0.65,0.7)),"real drop triggers reunion")
	var parent: LostParent = child.parent_npc
	# Controlled slow-exit fixture isolates goal resolution from physical departure.
	parent.set_physics_process(false)
	day.event_banner.clear_pending()
	day.shift_elapsed_seconds = 600
	day._tick_timeline()
	print("EVENT135 BEFORE clock=",day.clock_text()," active=",day.active_event_count()," exclusive=",day.introduction_event_count()," reunion=",child.reunited," parent_state=",parent.state," step=",day._intro_step," wait=",day._intro_cooldown)
	check(day.automatic_events == 1,"resolved family does not block eligible thief")
	await frames(1800) # Empty-stock thief follows its actual exit route before the next event.
	day.shift_elapsed_seconds = 900
	day._intro_cooldown = 0
	day.event_banner.clear_pending()
	day._tick_timeline()
	print("EVENT135 BOSS clock=",day.clock_text()," active=",day.active_event_count()," exclusive=",day.introduction_event_count()," boss=",day.automatic_bosses)
	check(day.automatic_bosses > 0,"resolved slow family cannot suppress late boss")
	quit(1 if failures else 0)