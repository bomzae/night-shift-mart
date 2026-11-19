extends "res://tests/prompt4_smoke.gd"

func clear_specials() -> void:
	mart.get_node("LostFamilies")._release_exceptions(null, null, true)
	mart.get_node("LostFamilies").pairs.clear()
	for node in mart.find_children("*", "Node3D", true, false):
		if node is DrunkCustomer or node is LostChild or node is LostParent or node is ThiefCustomer: node.queue_free()
	await frames(3)

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	var banner := day.event_banner
	day.set_physics_process(false)
	day.shift_elapsed_seconds = day.shift_duration_seconds * 0.12
	day._tick_timeline()
	check(day.automatic_events == 0 and day.automatic_bosses == 0, "Day 1 first hour is normal work without events or boss")
	day.shift_elapsed_seconds = day.shift_duration_seconds / 8
	day._tick_timeline()
	check(day.automatic_events == 1 and day.active_event_count() == 1, "23:00 first automatic event starts alone")
	check(banner.current == &"drunk" and banner.description.visible, "real Drunk start emits explanatory notification")
	check(not paused and Engine.time_scale == 1, "event introduction never pauses gameplay")
	day.shift_elapsed_seconds = day.shift_duration_seconds * 0.4
	day._tick_timeline()
	check(day.automatic_events == 1, "next introduction cannot overlap active special")
	await clear_specials()
	banner.clear_pending()
	day._tick_timeline()
	check(day.automatic_events == 1 and day._intro_cooldown > 0, "time skip cannot bypass real introduction cooldown")
	day.set_physics_process(true)
	day.timeline_enabled = false
	await frames(730)
	day.set_physics_process(false)
	day._tick_timeline()
	check(day.automatic_events == 2 and banner.current == &"family", "next event starts only after previous event and cooldown")
	check(banner.description.text.contains("부모"), "Lost Child explains reunion")
	day.shift_elapsed_seconds = day.shift_duration_seconds * 0.76
	day._tick_timeline()
	check(day.automatic_bosses == 0, "late boss does not stack onto unresolved Day 1 introduction")
	await clear_specials()
	banner.clear_pending()
	day._intro_cooldown = 0
	day._tick_timeline()
	check(day.automatic_bosses == 1 and banner.current == &"boss" and banner.title.modulate == Color.GOLD, "late boss introduced once after room is available")
	check(banner.description.text.contains("상품"), "KING RAT introduction states product threat")
	await frames(190)
	check(not banner.panel.visible, "notification automatically hides")
	var boss: KingRat = mart.get_node("Bosses").boss
	boss.queue_free()
	await frames(3)
	day._tick_timeline()
	check(day.automatic_bosses == 1, "late automatic boss quota retained")
	# Actual hazard creation and actual debug entry points share the same signal path.
	banner.clear_pending()
	var fire: FireZone = mart.get_node("Fires").create_fire(Vector3(5,0,18))
	check(fire != null and banner.current == &"fire" and banner.description.text.contains("소화기"), "actual fire emits extinguishing instruction")
	banner.clear_pending()
	await press("debug_spawn_thief")
	check(banner.current == &"thief" and banner.description.text.contains("붙잡"), "debug thief gets capture instruction")
	await clear_specials()
	banner.clear_pending()
	await press("debug_tourist_bus")
	check(banner.current == &"tourist" and banner.description.visible, "real tourist bus announces incoming customers")
	banner.clear_pending()
	await press("debug_spawn_drunk")
	check(banner.current == &"drunk" and not banner.description.visible and banner.remaining <= 2.0, "session repeat event uses compact title")
	check(not banner.panel.get_global_rect().intersects(day.clock_label.get_global_rect()), "banner does not overlap day clock")
	check(not banner.panel.get_global_rect().intersects(manager._spawn_label.get_global_rect()), "banner does not overlap event statistics")
	check(not banner.panel.get_global_rect().intersects(station._panel.get_global_rect()), "banner does not overlap checkout panel")
	check(not banner.panel.get_global_rect().intersects(interaction.context_prompt.get_global_rect()), "banner does not overlap crosshair prompt")
	check(not banner.panel.get_global_rect().intersects(mart.get_node("Bosses").health_bar.get_global_rect()), "banner does not overlap boss HP bar")
	for hud in [mart.get_node("Delivery")._hud, mart.get_node("TeamLife").label, interaction.weapon_info]:
		check(not banner.panel.get_global_rect().intersects(hud.get_global_rect()) and not interaction.context_prompt.get_global_rect().intersects(hud.get_global_rect()), "banner and context preserve delivery HP weapon HUD " + str(hud.name))
	day.end_day()
	day.set_physics_process(true)
	await frames(140)
	check(not banner.panel.visible and banner.pending.is_empty(), "ending clears notifications before Result")
	day.confirm_result()
	manager.spawning_enabled = false
	day.timeline_enabled = false
	day.set_physics_process(false)
	day.shift_elapsed_seconds = day.shift_duration_seconds * 0.25
	day._tick_timeline()
	check(day.day_number == 2 and day.automatic_events == 1 and day._next_event_hour == 3.0, "Day 2 retains original free timeline")
	check(banner.seen.has(&"drunk"), "event experience memory survives next day without save system")
	print("Prompt 13.1 events completed; failures: ", failures)
	quit(1 if failures else 0)
