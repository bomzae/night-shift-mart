extends "res://tests/prompt12_9_economy.gd"

func run_checks() -> void:
	var customer := await basket_fixture()
	var day: DayManager = mart.get_node("DayManager")
	var team: TeamLifeManager = mart.get_node("TeamLife")
	var source_id: int = customer.picked_items[0].source_id
	var stock_remaining: GrabbableBody = customer.goods[0]
	var basket_value := manager.basket_total(customer)
	day.end_day()
	check(not day.failed and day.state == DayManager.State.ENDING, "normal end starts cleanup grace")
	check(customer.picked_items.size() == 1 and is_instance_valid(customer), "basket and actor survive grace until accounting")
	check(manager.spawn_customer() == null and mart.get_node("Drunks").spawn_drunk() == null and mart.get_node("LostFamilies").spawn_pair() == null, "ending blocks normal drunk and family spawns")
	check(mart.get_node("Thieves").spawn_thief() == null and mart.get_node("Accidents").spawn_accident() == null and mart.get_node("Fires").spawn_dangerous() == null, "ending blocks new special customers")
	check(not mart.get_node("TouristBus").start_event() and mart.get_node("Delivery/WeaponDelivery").order() == null, "ending blocks bus and weapon orders")
	# Completion already won the transition. Later grace-window damage cannot rewrite it.
	player.health.receive_damage(200)
	check(not day.failed and not team.day_failed_active, "late grace damage cannot overwrite complete end reason")
	await frames(140)
	check(day.state == DayManager.State.RESULT and not day.result.failed, "normal end remains complete after grace damage")
	check(day.result.returns == 1 and day.result.return_value == basket_value, "closing basket snapshot settled once as neutral return")
	check(manager.sales == 0 and manager.unpaid_loss == 0 and day.result.net == 0, "closing does not mint sales or impose unpaid loss")
	check(not is_instance_id_valid(source_id) and is_instance_valid(stock_remaining), "picked item not duplicated and unpicked shelf goods preserved")
	check(manager._claims.is_empty() and not is_instance_valid(customer), "closing releases reservations before deleting actor")
	var state_before := day.state
	await press("debug_damage_player")
	await press("spawn_king_rat")
	check(day.state == state_before and not is_instance_valid(mart.get_node("Bosses").boss), "RESULT consumes gameplay debug input")
	day.confirm_result()
	check(player.knockdown.phase == KnockdownState.Phase.UPRIGHT and team.alive_count() == 1, "next day starts upright without leftover recovery immunity")
	check(day.baseline.returns == 1 and day.baseline.return_value == basket_value, "closing neutral accounting baseline rolls forward")
	# Event cap and closing phase prevent dispatch, independently of actor spawn geometry.
	day.shift_elapsed_seconds = day.shift_duration_seconds * 0.5
	day.max_active_events = 0
	day._next_event_hour = 0
	day._tick_timeline()
	check(day.automatic_events == 0, "event cap blocks automatic dispatch")
	day.max_active_events = 2
	day.shift_elapsed_seconds = day.shift_duration_seconds * 0.95
	day._next_event_hour = 0
	day._tick_timeline()
	check(day.automatic_events == 0 and day.automatic_bosses == 0, "closing segment starts no new auto events or boss")
	print("Prompt 13 closing policy completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
