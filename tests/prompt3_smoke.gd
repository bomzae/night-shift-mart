extends "res://tests/prompt1_smoke.gd"

var mart: Node3D
var delivery: DeliveryManager

func run_checks() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	mart.get_node("Customers").spawning_enabled = false # Isolate delivery/stock regression from autonomous buyers.
	player = mart.get_node("Player")
	interaction = player.get_node("Interaction")
	delivery = mart.get_node("Delivery")
	delivery.truck_wait_time = 600 # Leave time to exercise every task independently.
	for region in ["LoadingArea", "Backroom", "StoreFloor", "Entrance"]:
		check(mart.has_node(region), "Mart region: " + region)
	check(not delivery.truck_present, "truck initially absent")
	await frames(330)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(delivery.truck_present and delivery.delivered == 6, "timed arrival delivers six physical products")
	var types: Dictionary = {}
	var goods := delivery.shipment.duplicate()
	for body in goods:
		types[body.product_type] = body
		check(body.mass == body.weight and body.price > 0 and not body.freeze, "delivered product price/weight/physics: " + body.display_name)
	check(types.size() == 3, "three reusable product types")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p3_loading.png")
	await frames(2) # Return from render callback before arranging physics fixtures.
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(types[&"can"], cart.to_global(Vector3(-0.3, 0.95, 0)))
	await place(types[&"appliance"], cart.to_global(Vector3(0.3, 1.05, 0)))
	await frames(90)
	cart.refresh_load()
	print("LOAD count=", cart.cargo.size(), " weight=", cart.loaded_weight, " can=", cart.to_local(types[&"can"].global_position), " appliance=", cart.to_local(types[&"appliance"].global_position))
	check(cart.cargo.size() == 2 and is_equal_approx(cart.loaded_weight, 9), "new product shapes load physically; cart sums 9kg")
	player.set_physics_process(false)
	player.global_position = cart.global_position + Vector3(0, 0.01, -2.3)
	interaction.camera.look_at(cart.get_node("HandleArea").global_position)
	await frames(2)
	await press("grab")
	check(interaction.held_object == cart, "mart cart handle uses existing grab")
	player.set_physics_process(true)
	var route_ok := true
	for waypoint in [Vector3(0, 0, 3)]:
		var reached := false
		for tick in range(450):
			var offset: Vector3 = waypoint - cart.global_position
			offset.y = 0
			if offset.length() < 0.85:
				reached = true
				break
			var target_yaw := atan2(-offset.x, -offset.z)
			player.rotation.y = rotate_toward(player.rotation.y, target_yaw, 0.025)
			if absf(angle_difference(player.rotation.y, target_yaw)) < 0.35:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			await frames(1)
		Input.action_release("move_forward")
		await frames(20)
		route_ok = route_ok and reached
		print("ROUTE waypoint=", waypoint, " cart=", cart.global_position, " reached=", reached)
	check(route_ok and interaction.held_object == cart, "loaded cart route passes directly through wide rear door")
	check(cart.cargo.size() > 0, "route preserves loose physical cargo")
	interaction.drop_held()
	player.set_physics_process(false)
	player.global_position = Vector3(-3, 0.01, 2)
	for type in types:
		var shelf_name: String = {&"can": "CanShelf", &"watermelon": "WatermelonShelf", &"appliance": "ApplianceShelf"}[type]
		var shelf: StockShelf = mart.get_node("Shelves/" + shelf_name)
		await place(types[type], shelf.to_global(Vector3(0, 1.1, 0)))
	await frames(180)
	for shelf in mart.get_node("Shelves").get_children():
		check(shelf.stock_count == 1, "correct stable stock: " + String(shelf.accepted_type))
	var can: GrabbableBody = types[&"can"]
	var can_shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	player.global_position = Vector3(-5, 0.01, 4.2)
	interaction.camera.look_at(can.global_position)
	await frames(2)
	await press("grab")
	await frames(3)
	check(interaction.held_object == can and can_shelf.stock_count == 0, "grab stocked product removes stock and keeps interaction")
	await press("throw")
	check(interaction.held_object == null and can.linear_velocity.length() > 1, "stocked product still supports charge throw")
	var wrong_shelf: StockShelf = mart.get_node("Shelves/WatermelonShelf")
	await place(can, wrong_shelf.to_global(Vector3(0.85, 1, 0)))
	await frames(120)
	check(wrong_shelf.stock_count == 1 and is_instance_valid(can) and not can.freeze, "wrong stock remains physical and uncounted")
	# Nine cans physically fit, while only eight count. No slot locking/deletion.
	for index in range(9):
		var extra: GrabbableBody = load("res://scenes/interactables/products/can.tscn").instantiate()
		mart.get_node("Products").add_child(extra)
		extra.global_position = can_shelf.to_global(Vector3((index % 3 - 1) * 0.65, 0.95, (index / 3 - 1) * 0.4))
	await frames(150)
	check(can_shelf.stock_count == 8 and can_shelf.zone.get_overlapping_bodies().size() >= 9, "max stock caps count without removing excess goods")
	# Return one delivery item to the pallet; stocked/unloaded goods must survive.
	await place(goods[0], delivery.to_global(Vector3(0, 0.8, 0)))
	await frames(30)
	await place(goods[1], delivery.to_global(Vector3(0, 0.8, 0.6)))
	player.global_position = delivery.to_global(Vector3(0, 0.01, 2.3))
	interaction.camera.look_at(goods[1].global_position)
	await frames(2)
	await press("grab")
	check(interaction.held_object == goods[1], "grab shipment directly from dispatch pallet")
	delivery.depart()
	await frames(3)
	check(is_instance_valid(goods[1]) and interaction.held_object == goods[1], "departure never deletes held shipment")
	interaction.drop_held()
	check(not delivery.truck_present, "truck departure hides truck and releases its collision")
	check(delivery.last_result["Left Behind"] > 0 and delivery.last_result["Unloaded"] > 0, "departure logs unloaded and left-behind goods")
	check(is_instance_valid(types[&"appliance"]), "unloaded stocked body survives truck departure")
	check(delivery.last_result["Delivered"] == delivery.last_result["Unloaded"] + delivery.last_result["Left Behind"], "shipment counts reconcile")
	# New short cycle exercises timed departure and repeat arrival through exports.
	delivery.first_delivery_delay = 0.1
	delivery.truck_wait_time = 0.3
	delivery.delivery_interval = 0.6
	delivery.arrive()
	var cycle := delivery.delivery_number
	await frames(23)
	check(not delivery.truck_present, "time window departs automatically")
	await frames(20)
	check(delivery.delivery_number > cycle, "delivery interval repeats")
	player.global_position = Vector3(0, 0.01, 1.5)
	interaction.camera.look_at(Vector3(0, 1, 6))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p3_store.png")
	print("Prompt 3 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
