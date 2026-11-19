extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	manager = mart.get_node("Customers")
	player = mart.get_node("Player")
	interaction = player.get_node("Interaction")
	station = manager.checkout
	var day: DayManager = mart.get_node("DayManager")
	check(day.state == DayManager.State.PRE_DAY and manager.customers.is_empty(), "starter preparation blocks customer activity")
	check(manager.spawn_customer() == null, "PRE_DAY cannot admit a customer before starter stock")
	for tick in range(240):
		if day.state == DayManager.State.ACTIVE: break
		await frames(1)
	manager.spawning_enabled = false
	day.timeline_enabled = false
	mart.get_node("Delivery").set_physics_process(false)
	check(day.state == DayManager.State.ACTIVE and day.clock_text() == "22:00", "starter ready then Day 1 starts 22:00")
	var products: Node = mart.get_node("Products")
	var count := products.get_child_count()
	var capacity := 0
	var settled := 0
	var foods := {}
	var weights := [false, false, false]
	var zones := {"left": 0, "center": 0, "right": 0}
	for shelf: StockShelf in mart.get_node("Shelves").get_children():
		capacity += shelf.max_stock
		var goal := mini(shelf.max_stock, maxi(1, roundi(shelf.max_stock * mart.initial_fill_ratio)))
		check(shelf.stock_count == goal, "partial settled starter tier " + shelf.name)
		settled += shelf.stock_count
		var zone := "left" if shelf.position.x < -10 else ("right" if shelf.position.x > 10 else "center")
		zones[zone] += shelf.stock_count
	for item: GrabbableBody in products.get_children():
		foods[item.product_type] = true
		weights[0 if item.weight <= 1.5 else (1 if item.weight < 8 else 2)] = true
		check(item.position.is_finite() and item.linear_velocity.length() < 0.6, "starter physical body settled " + str(item.product_type))
	check(count == settled and count == day.starter_stock_count and count > 0 and count < capacity, "partial starter consists entirely of actual shelf products")
	check(foods.has(&"bread") and foods.has(&"milk") and foods.has(&"watermelon"), "starter contains all healing foods")
	check(weights == [true, true, true], "starter contains light medium heavy physics goods")
	print("STARTER131 count=", count, " capacity=", capacity, " ratio=", float(count)/capacity, " zones=", zones)
	# Ordinary customer can immediately shop without I or delivery being required.
	var customer := manager.spawn_customer([&"bread"])
	check(customer != null and not customer.goods.is_empty(), "normal customer reserves real starter bread")
	customer.set_physics_process(false)
	customer.waypoints.clear()
	customer.continue_shopping()
	customer.state = BasicCustomer.State.SHOP
	check(manager.pickup_from_shelf(customer, customer.shopping_shelf, &"bread"), "customer picks up starter stock through existing shopping path")
	await frames(2)
	var before_end := products.get_child_count()
	day.end_day()
	await frames(140)
	day.confirm_result()
	manager.spawning_enabled = false
	await frames(2)
	check(day.day_number == 2 and products.get_child_count() == before_end, "Day 2 preserves remaining stock without starter refill")
	await press("debug_auto_stock")
	await frames(90)
	check(products.get_child_count() == capacity, "I still fills missing stock to full capacity")
	var delivery: DeliveryManager = mart.get_node("Delivery")
	delivery.arrive()
	check(delivery.truck_present and delivery.shipment.size() == 6, "physical delivery still arrives after starter stock")
	print("Prompt 13.1 stock completed; failures: ", failures)
	quit(1 if failures else 0)
