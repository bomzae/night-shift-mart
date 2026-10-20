extends "res://tests/prompt1_smoke.gd"
var mart: Node3D
var manager: CustomerManager
var station: Node3D

func setup_mart() -> void:
	if is_instance_valid(main):
		main.free()
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	manager = mart.get_node("Customers")
	manager.spawning_enabled = false
	manager.patience_time = 60
	mart.get_node("Delivery").set_physics_process(false)
	player = mart.get_node("Player")
	interaction = player.get_node("Interaction")
	station = manager.checkout
	await frames(30)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set_physics_process(false)
	player.global_position = station.global_position + Vector3(0, 0.01, 1.25)
	player.rotation = Vector3.ZERO

func stock(type: String, at: Vector3 = Vector3.ZERO) -> GrabbableBody:
	var body: GrabbableBody = load("res://scenes/interactables/products/" + type + ".tscn").instantiate()
	mart.get_node("Products").add_child(body)
	var shelf: StockShelf = mart.get_node("Shelves/" + {"can": "CanShelf", "watermelon": "WatermelonShelf", "appliance": "ApplianceShelf"}[type])
	body.global_position = shelf.to_global(Vector3(at.x, 1.0, at.z))
	await frames(100)
	check(shelf.has_stock(body), "prepare stable physical stock " + type)
	return body

func wait_checkout(customer: BasicCustomer) -> void:
	for tick in range(2200):
		if customer.state == BasicCustomer.State.CHECKOUT:
			break
		await frames(1)
	check(customer.state == BasicCustomer.State.CHECKOUT, "customer walks Entrance -> Store -> Queue -> Checkout")
	print("CUSTOMER reached=", customer.global_position, " state=", customer.state)

func aim_action(action: String) -> void:
	interaction.camera.look_at(station.get_node("Scanner" if action == "scan" else "Payment").global_position)
	await frames(2)
	check(station.aimed_action() == action, "physical " + action + " button ray")
	await press("interact")

func run_checks() -> void:
	await setup_mart()
	var can := await stock("can", Vector3(-0.4, 0, 0))
	var melon := await stock("watermelon")
	var first := manager.spawn_customer([&"can", &"watermelon"])
	check(first != null and first.purchase_types.size() == 2, "customer spawns with purchase list")
	check(is_equal_approx(first.purchase_total, can.price + melon.price), "quote uses actual physical product prices")
	await frames(100)
	check(first.global_position.distance_to(manager.exit_position()) > 1, "customer first visits store instead of teleporting to till")
	var second_can := await stock("can", Vector3(0.4, 0, 0))
	var second := manager.spawn_customer([&"can"])
	check(second != null and second.goods[0] == second_can, "concurrent customer claims different stock")
	# FIFO is arrival order, not spawn order. Across the expanded wings a
	# single-item shopper can overtake a two-shelf shopper. Keep both claims
	# live, then release the second motor after the first physically queues.
	second.set_physics_process(false)
	await wait_checkout(first)
	second.set_physics_process(true)
	for tick in range(2200):
		if manager.queue.size() == 2 and second.global_position.distance_to(manager.queue_position(second)) < 0.4:
			break
		await frames(1)
	check(manager.queue.size() == 2 and manager.queue[0] == first, "FIFO queue order")
	check(first.global_position.distance_to(second.global_position) > 0.65, "queued capsules remain separated")
	check(first.patience_left < first.patience_time, "queue patience decreases")
	await aim_action("pay")
	check(manager.sales == 0 and first.scanned == 0, "payment rejected before scans")
	await aim_action("scan")
	check(first.scanned == 1, "E scans exactly one unit")
	check(not station.use_station("scan"), "scan cooldown prevents input flood")
	player.global_position = Vector3(0, 0.01, 2)
	await frames(35)
	check(not station.use_station("scan") and first.scanned == 1, "walking away prevents remote scan and preserves progress")
	player.global_position = station.global_position + Vector3(0, 0.01, 1.25)
	await aim_action("scan")
	await frames(32)
	check(first.scanned == 2, "all requested units scanned")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p4_checkout.png")
	await frames(2)
	await aim_action("pay")
	check(is_equal_approx(manager.sales, 55), "payment adds sales once")
	check(first.state == BasicCustomer.State.EXIT and not first.unpaid, "paid customer exits")
	check(not is_instance_valid(can) and not is_instance_valid(melon), "sold shelf bodies removed")
	check(mart.get_node("Shelves/CanShelf").stock_count == 0 and mart.get_node("Shelves/WatermelonShelf").stock_count == 0 and second.picked_items.size() == 1, "picked units leave shelves before payment including queued basket")
	check(not manager.finish(first, true) and manager.sales == 55, "duplicate payment cannot double charge")
	await wait_checkout(second)
	check(manager.current_customer() == second and second.scanned == 0, "next customer advances with fresh scan progress")
	second.patience_left = second.patience_time * 0.2
	await frames(1)
	check(second._mood.text == ":!", "low patience changes expression")
	second.patience_left = 0.02
	await frames(5)
	check(second.unpaid and second.state == BasicCustomer.State.EXIT, "expired patience escapes")
	check(manager.unpaid_loss == 5 and manager.sales == 55, "unpaid loss tracked separately exactly once")
	check(not manager.finish(second, false) and manager.unpaid_loss == 5, "escape cannot record the same loss twice")
	check(not is_instance_valid(second_can), "unpaid goods removed from shelf without NPC carrying them")
	for tick in range(1600):
		if manager.customers.is_empty():
			break
		await frames(1)
	check(manager.customers.is_empty() and manager.exited_count == 2, "paid and unpaid customers physically reach exit and despawn")

	await setup_mart()
	var missing := manager.spawn_customer([&"appliance"])
	for tick in range(1300):
		if missing.state == BasicCustomer.State.DISAPPOINTED:
			break
		await frames(1)
	check(missing.state == BasicCustomer.State.DISAPPOINTED and missing._mood.text.contains("X"), "out of stock shows disappointment")
	check(manager.sales == 0 and manager.unpaid_loss == 0, "out of stock causes no sale or unpaid loss")
	await frames(125)
	check(missing.state == BasicCustomer.State.EXIT, "out of stock waits briefly then exits")

	await setup_mart()
	var removable := await stock("can")
	var buyer := manager.spawn_customer([&"can"])
	# Prompt 5.2 moves physical validation from payment to pickup.
	for tick in range(2200):
		await frames(1)
		if buyer.state == BasicCustomer.State.SHOP:
			break
	check(buyer.state == BasicCustomer.State.SHOP, "customer reaches shelf before live stock interference")
	check(buyer.picked_items.is_empty(), "no basket before shopping completes")
	# Same-frame removal must be caught even before Shelf's next physics tick.
	removable.begin_carry(interaction, player)
	check(not manager.pickup_from_shelf(buyer, buyer.shopping_shelf, &"can") and manager.sales == 0, "pickup atomically revalidates live held stock")
	check(buyer.state == BasicCustomer.State.DISAPPOINTED, "player can take reserved goods without lock")
	removable.end_carry()
	check(is_instance_valid(removable), "failed transaction never deletes taken product")

	await setup_mart()
	var pushed_customer := manager.spawn_customer([&"can"])
	pushed_customer.waypoints = [Vector3(0, 0, 3)]
	pushed_customer.global_position = Vector3(0, 0.01, 3)
	pushed_customer.state = BasicCustomer.State.DISAPPOINTED
	pushed_customer._disappointment_left = 20
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 1.2))
	cart.rotation.y = PI
	await frames(2)
	var before := pushed_customer.global_position
	cart.linear_velocity = Vector3(0, 0, 2)
	await frames(35)
	check(pushed_customer.global_position.distance_to(before) > 0.1, "slow cart contact physically nudges customer")
	check(pushed_customer.velocity.length() < 6 and not pushed_customer.has_method("receive_impact"), "customer has bounded push response and no damage handler")
	check(not pushed_customer.has_method("begin_carry"), "normal customer is not grabbable")
	manager.spawning_enabled = true
	manager.spawn_interval_min = 0.15
	manager.spawn_interval_max = 0.15
	manager.max_active_customers = 2
	manager._reset_timer()
	await frames(140)
	check(manager.customers.size() == 2, "timed spawner respects active customer limit")

	await setup_mart()
	for i in range(6):
		var unit: GrabbableBody = load("res://scenes/interactables/products/can.tscn").instantiate()
		mart.get_node("Products").add_child(unit)
		unit.global_position = mart.get_node("Shelves/CanShelf").to_global(Vector3((i % 3 - 1) * 0.6, 1, (i / 3 - 0.5) * 0.5))
	await frames(150)
	for i in range(6):
		var visitor := manager.spawn_customer([&"can"])
		check(visitor != null, "six-customer stress spawn")
		await frames(45)
	for tick in range(2200):
		if manager.queue.size() == 6 and manager.queue.back().global_position.distance_to(manager.queue_position(manager.queue.back())) < 0.4:
			break
		await frames(1)
	check(manager.queue.size() == 6, "six customers reach the queue")
	var minimum_gap := INF
	for i in range(manager.queue.size()):
		for j in range(i + 1, manager.queue.size()):
			minimum_gap = minf(minimum_gap, manager.queue[i].global_position.distance_to(manager.queue[j].global_position))
	check(manager.queue.size() == 6 and minimum_gap > 0.6, "full queue avoids overlapping capsules")
	print("QUEUE full count=", manager.queue.size(), " minimum_gap=", minimum_gap)
	print("Prompt 4 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
