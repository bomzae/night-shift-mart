extends "res://tests/prompt13_1_context.gd"

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	var banner := day.event_banner
	await press("spawn_king_rat")
	check(banner.current==&"boss" and banner.description.text=="상품을 집어 던져 쥐를 공격하세요.","debug R first encounter includes product throw guidance")
	check(banner.description.visible and banner.seen.has(&"boss"),"first encounter recorded in existing session memory")
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size
		await frames(2)
		check(banner.description.size.x>=banner.description.get_minimum_size().x,"guidance text fits banner at "+str(size))
		for control in [day.clock_label,day.economy_hud.sales_label,day.economy_hud.losses_label,station._panel,interaction.weapon_info,interaction.context_prompt]:
			check(not banner.panel.get_global_rect().intersects(control.get_global_rect()),"boss banner separated from HUD at "+str(size))
	await frames(190)
	check(not banner.panel.visible,"first guidance auto hides without pausing")
	mart.get_node("Bosses").boss.queue_free()
	await frames(3)
	await press("spawn_king_rat")
	await frames(35) # Existing half-second inter-banner gap is intentional.
	check(banner.current==&"boss" and not banner.description.visible,"second actual boss has compact title only")
	player.health.current_health=70
	var food := held_food(&"bread")
	await frames(3)
	check(interaction.context_prompt.text.contains("[RMB] THROW") and interaction.context_prompt.text.split("\n").size()<=2,"held product shows Throw within existing two-line prompt")
	interaction.drop_held()
	food.queue_free()
	day.end_day()
	await frames(140)
	day.confirm_result()
	manager.spawning_enabled=false
	day.timeline_enabled=false
	await frames(3)
	await press("spawn_king_rat")
	check(day.day_number==2 and banner.current==&"boss" and not banner.description.visible,"Day 2 retains compact boss introduction")
	print("Prompt 13.3 guidance completed; failures: ",failures)
	quit(1 if failures else 0)
