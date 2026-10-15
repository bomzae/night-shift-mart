extends "res://tests/prompt8_smoke.gd"
var buses: TouristBus
var spawn_frames: Array[int] = []

func setup_bus() -> void:
	await setup_mart()
	buses = mart.get_node("TouristBus")
	manager._rng.seed = 10
	spawn_frames.clear()
	manager.child_entered_tree.connect(_record_spawn)

func _record_spawn(node: Node) -> void:
	if node is BasicCustomer and node.get_meta("tourist", false):
		spawn_frames.append(Engine.get_physics_frames())

func supply() -> void:
	for type in ["can", "watermelon", "appliance"]:
		var shelf: StockShelf = mart.get_node("Shelves/" + {"can":"CanShelf", "watermelon":"WatermelonShelf", "appliance":"ApplianceShelf"}[type])
		var count: int = {"can":8, "watermelon":4, "appliance":2}[type]
		for i in range(count):
			var product: GrabbableBody = load("res://scenes/interactables/products/" + type + ".tscn").instantiate()
			mart.get_node("Products").add_child(product)
			var columns := 4 if type != "appliance" else 2
			var x := (float(i % columns) - float(columns - 1) / 2) * (0.62 if type != "appliance" else 1.2)
			product.global_position = shelf.to_global(Vector3(x, 1.15, -0.3 + (i / columns) * 0.6))
	await frames(150)
	check(manager.available_goods().size() == 14, "prepare fourteen actual shelf products")

func run_checks() -> void:
	await setup_bus()
	check(InputMap.has_action("debug_tourist_bus") and buses.state == TouristBus.State.IDLE, "B action and idle event")
	await supply()
	manager.max_active_customers = 1
	manager.spawning_enabled = true
	manager._timer = 0.01
	await press("debug_tourist_bus")
	check(buses.state == TouristBus.State.ARRIVING and manager.event_spawn_paused, "B begins arrival and pauses automatic customers")
	check(not buses.start_event(), "duplicate event rejected")
	check(manager.spawning_enabled, "event does not overwrite U preference")
	var start := buses.bus.position
	await frames(65)
	check(buses.bus.position.distance_to(start) > 1 and buses.spawned_count == 0, "visible arrival before unloading")
	await frames(60)
	check(buses.state == TouristBus.State.UNLOADING and buses.tourist_buses_arrived == 1, "arrival counted once and unloading begins")
	check(buses.bus.get_node("Body") is StaticBody3D and buses.door.position.x > -3.4, "solid bus with open passenger door")
	var saved_camera: Transform3D = interaction.camera.transform
	interaction.camera.global_position = Vector3(-3, 5, 10.8)
	interaction.camera.look_at(Vector3(0, 1.2, 15))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p10_bus.png")
	interaction.camera.transform = saved_camera
	var count_changes: Array[int] = []
	var last_count := 0
	var peak_queue := 0
	var peak_active := 0
	var seen_rush := false
	var seen_departure := false
	var served := false
	var unique_claims := true
	var normal_spawn_paused := true
	for tick in range(6500):
		await frames(1)
		if buses.spawned_count != last_count:
			check(buses.spawned_count == last_count + 1, "at most one passenger per spawn tick")
			count_changes.append(Engine.get_physics_frames())
			last_count = buses.spawned_count
		peak_active = maxi(peak_active, manager.customers.size())
		peak_queue = maxi(peak_queue, manager.queue.size())
		seen_rush = seen_rush or buses.state == TouristBus.State.RUSH_ACTIVE
		seen_departure = seen_departure or buses.state == TouristBus.State.DEPARTING
		var ids := {}
		for customer in manager.customers:
			if not customer.get_meta("tourist", false): normal_spawn_paused = false
			for good in customer.goods:
				if is_instance_valid(good):
					if ids.has(good.get_instance_id()): unique_claims = false
					ids[good.get_instance_id()] = true
		if not served and peak_queue >= 3 and manager.current_customer() != null:
			var customer := manager.current_customer()
			var price := manager.basket_total(customer)
			for i in customer.purchase_types.size():
				await aim_action("scan")
				await frames(32)
			await aim_action("pay")
			check(buses.tourist_customers_served == 1 and is_equal_approx(manager.sales, price), "ordinary Scan Pay counts tourist and shared sales")
			check(not manager.finish(customer, true) and buses.tourist_customers_served == 1, "duplicate payment cannot double served")
			served = true
		if buses.state == TouristBus.State.IDLE: break
	print("RUSH measured spawn=", buses.spawned_count, " peak active=", peak_active, " queue=", peak_queue, " exited=", manager.exited_count)
	for customer in manager.customers: print("REMAINING ", customer.global_position, " state=", customer.state, " waypoints=", customer.waypoints)
	check(buses.spawned_count == 10 and count_changes.size() == 10, "all ten passengers spawned sequentially")
	var spaced := true
	print("SPAWN physics frames=", spawn_frames)
	for i in range(1, spawn_frames.size()):
		if spawn_frames[i] - spawn_frames[i - 1] < 24: spaced = false
	check(spaced, "passenger interval respects staggered spawning")
	check(normal_spawn_paused, "bus pauses only normal automatic generation")
	check(peak_active > manager.max_active_customers and peak_active <= manager.absolute_customer_cap, "tourist allowance exceeds normal cap but respects absolute cap")
	check(unique_claims, "crowded customers never share reserved product")
	check(peak_queue >= 3 and served, "rush creates checkout pressure using existing customer flow")
	check(manager.available_goods().size() < 14 and manager.unpaid_loss > 0, "physical pickup pressure and unattended patience loss")
	check(seen_rush and seen_departure and buses.state == TouristBus.State.IDLE, "rush departure idle complete")
	check(not manager.event_spawn_paused and manager.spawning_enabled, "auto ON restored after event")
	check(buses.tourist_customers_served == 1, "OOS and escape are not served")
	manager.max_active_customers = 18
	manager._timer = 0.01
	var before_count := manager.customers.size()
	await frames(2)
	check(manager.customers.size() > before_count, "normal automatic spawn resumes")

	await setup_bus()
	buses.tourist_count = 2
	buses.arrival_time = 0.1
	buses.departure_time = 0.1
	await press("debug_tourist_bus")
	await frames(10)
	check(not manager.spawning_enabled and buses.spawned_count == 1, "U OFF still permits bus passengers")
	var empty := buses.passengers[0]
	check(empty.get_script() == preload("res://scripts/systems/basic_customer.gd") and not empty.purchase_types.is_empty(), "passenger is unchanged BasicCustomer with purchase list")
	await frames(900)
	check(buses.spawned_count == 2 and buses.state == TouristBus.State.IDLE and not manager.spawning_enabled, "OOS passengers resolve event and U OFF persists")
	check(buses.tourist_customers_served == 0 and manager.sales == 0 and manager.unpaid_loss == 0, "empty stock creates no revenue or invented loss")
	await frames(300)
	check(manager.customers.is_empty(), "empty-stock passengers leave the entrance without permanent deadlock")
	check(buses.start_event(), "event can restart after departure")
	await press("toggle_customer_spawn")
	check(manager.spawning_enabled and manager.event_spawn_paused, "U during event changes preference without unpausing")
	buses.max_rush_duration = 0.3
	await frames(40)
	check(manager.spawning_enabled and not manager.event_spawn_paused, "latest U choice survives timeout")

	await setup_bus()
	manager.absolute_customer_cap = 2
	await stock("can")
	for i in range(2):
		var normal := manager.spawn_customer([&"can"])
		normal.global_position = Vector3(7, 0.01, 1 + i)
		normal.set_physics_process(false)
	buses.arrival_time = 0.1
	buses.departure_time = 0.1
	buses.max_rush_duration = 1
	buses.start_event()
	await frames(50)
	check(buses.spawned_count == 0 and manager.customers.size() == 2, "absolute cap blocks tourist spawning")
	await frames(30)
	check(buses.state == TouristBus.State.IDLE and manager.customers.size() == 2, "blocked unloading times out without deleting existing customers")

	await setup_bus()
	await supply()
	buses.tourist_count = 1
	buses.arrival_time = 0.1
	buses.start_event()
	await frames(12)
	var passenger := buses.passengers[0]
	check(passenger.purchase_types.size() >= 2 and passenger.purchase_types.size() <= 4, "tourist purchase uses configured two to four units")
	passenger.global_position = Vector3(0, 0.01, 2)
	passenger.waypoints = [Vector3(0, 0.01, -3)]
	var state_before := passenger.state
	var spills: AccidentManager = mart.get_node("Accidents")
	var spill := spills.create_spill(passenger.global_position)
	await frames(40)
	check(passenger.knockdown.active(), "tourist falls in ordinary spill")
	check(passenger.state == state_before, "fall preserves shopping state")
	spill.queue_free()
	await frames(120)
	check(not passenger.knockdown.active() and passenger.state == state_before, "tourist recovers and resumes shopping")
	var fires: FireManager = mart.get_node("Fires")
	var fire = fires.create_fire(passenger.global_position)
	await frames(4)
	check(passenger.fire_reaction.active(), "tourist uses ordinary fire reaction")
	fire.queue_free()
	await frames(60)
	check(not passenger.fire_reaction.active() and passenger.state == state_before, "fire reaction preserves tourist shopping")
	check(mart.get_node("Drunks").spawn_drunk() != null, "drunk manual spawn during rush")
	check(mart.get_node("LostFamilies").spawn_pair() != null, "lost family manual spawn during rush")
	check(mart.get_node("Thieves").spawn_thief() != null, "thief spawn during rush with U OFF")
	await frames(120)
	var accident: AccidentCustomer = mart.get_node("Accidents").spawn_accident()
	check(accident != null, "accident manual spawn during rush")
	if accident != null: accident.global_position = Vector3(7, 0.01, 2)
	await frames(2)
	check(mart.get_node("Fires").spawn_dangerous() != null, "dangerous manual spawn during rush")
	check(buses.state != TouristBus.State.IDLE, "other events do not cancel rush")
	print("Prompt 10 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
