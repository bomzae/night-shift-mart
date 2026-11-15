extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	var delivery: DeliveryManager = mart.get_node("Delivery")
	day.set_physics_process(false)
	day.shift_duration_seconds = 30
	day.shift_elapsed_seconds = 0
	check(day.state == DayManager.State.ACTIVE and day.day_number == 1 and day.clock_text() == "22:00", "day one ACTIVE starts 22:00")
	for sample in [[7.5,"00:00"],[15.0,"02:00"],[22.5,"04:00"],[30.0,"06:00"]]:
		day.shift_elapsed_seconds = sample[0]
		check(day.clock_text() == sample[1], "clock mapping midnight rollover " + sample[1])
	day.shift_elapsed_seconds = 0
	check(day.timeline_phase() == "NORMAL WORK", "early timeline normal work")
	day.shift_elapsed_seconds = 7.5
	check(day.timeline_phase() == "LIGHT EVENTS", "midnight light events")
	day.shift_elapsed_seconds = 15
	check(day.timeline_phase() == "LATE EVENTS", "02 increased event window")
	day.shift_elapsed_seconds = 28.125
	check(day.timeline_phase() == "CLOSING", "05:30 closing window")
	# Real stock pickup/payment establishes daily deltas without minting products.
	manager.sales = 50
	manager.unpaid_loss = 7
	day.baseline = day._stats()
	var can := await stock("can")
	var price := can.price
	var customer := manager.spawn_customer([&"can"])
	check(customer != null, "ACTIVE admits customer")
	await wait_checkout(customer)
	await aim_action("scan")
	await frames(35)
	await aim_action("pay")
	check(manager.sales == 50 + price, "real checkout updates cumulative sales")
	manager.unpaid_loss += 3
	var retained := await stock("watermelon")
	var loose: GrabbableBody = load("res://scenes/interactables/products/can.tscn").instantiate()
	mart.get_node("Products").add_child(loose)
	loose.position = Vector3(0, 0.5, 14)
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	check(child != null, "family runtime exists before cleanup")
	var fire: FireZone = mart.get_node("Fires").create_fire(Vector3(5,0,18))
	var spill: SpillZone = mart.get_node("Accidents").create_spill(Vector3(-3,0,20))
	var boss: KingRat = mart.get_node("Bosses").spawn_boss()
	check(boss != null and fire != null and spill != null, "boss fire spill runtime assembled")
	var weapon := WeaponBody.new()
	weapon.weapon = preload("res://data/weapons/broom.tres")
	mart.add_child(weapon)
	weapon.position = Vector3(6, 1, -2)
	await frames(2)
	weapon.durability -= 1
	var durability := weapon.durability
	var weapon_home: Transform3D = day._homes[weapon.get_instance_id()].transform
	weapon.position += Vector3(2, 0, 0)
	var cart: ShoppingCart = mart.get_node("Cart")
	var cart_home: Transform3D = day._homes[cart.get_instance_id()].transform
	cart.position += Vector3(4, 0, 0)
	delivery.arrive()
	check(delivery.truck_present, "delivery active during ACTIVE")
	day.shift_elapsed_seconds = 30
	day.set_physics_process(true)
	await frames(2)
	check(day.state == DayManager.State.ENDING and not day.failed, "06:00 enters normal ENDING")
	check(not delivery.truck_present and delivery.last_result.size() > 0, "ending settles current delivery")
	check(manager.spawn_customer() == null and mart.get_node("Bosses").spawn_boss() == null, "ENDING rejects new actors")
	check(is_instance_valid(boss), "grace window retains existing boss briefly")
	await frames(140)
	check(day.state == DayManager.State.RESULT and day.result_panel.visible, "normal shift reaches visible RESULT")
	check(day.result.sales == price and day.result.unpaid == 3, "daily deltas exclude prior cumulative totals")
	check(day.result.served == 1 and day.result.net == price - 3, "result paid count and prototype net correct")
	check(not day.result.failed and day.result.time == "06:00", "complete result distinct from failure")
	check(manager.customers.is_empty() and manager.queue.is_empty() and manager._claims.is_empty(), "customer queues reservations cleared")
	check(not is_instance_valid(child) and mart.get_node("LostFamilies").pairs.is_empty(), "family actor and state cleanup")
	check(not is_instance_valid(boss) and not is_instance_valid(fire) and not is_instance_valid(spill), "boss fire spill cleanup")
	check(not is_instance_valid(loose) and is_instance_valid(retained), "floor scatter removed shelf stock persists")
	var delivery_count := delivery.delivery_number
	delivery.set_physics_process(true)
	await frames(100)
	check(delivery.delivery_number == delivery_count and manager.spawn_customer() == null, "RESULT blocks delivery scheduling and customers")
	check(mart.get_node("TouristBus").state == TouristBus.State.IDLE, "bus runtime reset")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p13_result.png")
	check(not day.clock_label.get_global_rect().intersects(mart.get_node("Delivery/WeaponDelivery").order_info.get_global_rect()), "day clock does not overlap weapon order HUD")
	check(not day.clock_label.get_global_rect().intersects(manager._spawn_label.get_global_rect()), "day clock does not overlap event stats")
	await press("interact")
	check(day.day_number == 2 and day.state == DayManager.State.ACTIVE and day.clock_text() == "22:00", "E confirms next day once at 22:00")
	check(player.health.current_health == 100 and not player.health.is_downed and not player.knockdown.active(), "next day resets HP and downed pose")
	check(player.position.distance_to(player.health.spawn_transform.origin) < 0.1, "next day restores player spawn")
	check(cart.position.distance_to(cart_home.origin) < 0.15 and weapon.position.distance_to(weapon_home.origin) < 0.2, "same cart weapon return to their home transforms")
	check(weapon.durability == durability and is_instance_valid(retained), "durability and shelf goods not replenished")
	check(day.baseline.sales == manager.sales and not day.boss_spawned_today, "next-day baseline and boss allowance reset")
	# Single-player failure must not reuse the obsolete automatic two-second reset.
	day.timeline_enabled = false
	player.health.receive_damage(200)
	check(day.state == DayManager.State.ENDING and day.failed and day.elapsed_hours() < 8, "all downed fails immediately before 06")
	await frames(150)
	check(day.state == DayManager.State.RESULT and day.day_number == 2 and player.health.current_health == 0, "failure waits at RESULT instead of direct reset")
	check(day.result.failed and day.result_label.text.contains("ALL WORKERS DOWN"), "failure cause displayed")
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await frames(2)
	enter = InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	Input.parse_input_event(enter)
	check(day.day_number == 3 and player.health.current_health == 100, "Enter confirms failed shift and restores player")
	print("Prompt 13 day smoke completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
