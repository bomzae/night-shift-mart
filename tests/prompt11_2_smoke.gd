extends "res://tests/prompt11_1_smoke.gd"

func physical_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func clear_segment(from: Vector3, to: Vector3, radius: float = 0.35) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.8
	query.shape = capsule
	query.margin = 0.01
	query.transform.origin = from + Vector3.UP
	query.motion = to - from
	query.exclude = [player.get_rid(), mart.get_node("Cart").get_rid()]
	return mart.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty() and mart.get_world_3d().direct_space_state.cast_motion(query)[0] >= 0.999

func layout_checks() -> void:
	await setup_thief()
	for shelf: StockShelf in mart.get_node("Shelves").get_children():
		var at := shelf.global_position
		var route: Array[Vector3] = [shelf.to_global(Vector3(0, 0.01, -1.65))]
		if absf(at.x) > 20:
			route.append_array(StoreRoutes.via_main(route[0], Vector3(0, 0.01, 21)))
		elif at.z >= 22:
			route.append(Vector3(0, 0.01, route[0].z))
		elif absf(at.x) > 10:
			var gap := 6.0 if at.z < 12 else 12.0
			route.append(Vector3(route[0].x, 0.01, gap))
			route.append(Vector3(signf(at.x) * 10.5, 0.01, gap))
			route.append(Vector3(signf(at.x) * 10.5, 0.01, 9 if gap == 6 else 15))
			route.append(Vector3(0, 0.01, route[-1].z))
		else:
			route.append(Vector3(0, 0.01, route[0].z))
		var clear := true
		for i in range(route.size() - 1): clear = clear_segment(route[i], route[i + 1]) and clear
		check(clear, "capsule walk-out route behind " + shelf.name)
		for index in range(shelf.shopping_point_count):
			var point := shelf.shopping_point(index)
			var approach: Array[Vector3] = [Vector3(0, 0.01, point.z)]
			approach.append_array(StoreRoutes.via_main(approach[0], point))
			var approach_clear := true
			for step in range(approach.size() - 1): approach_clear = clear_segment(approach[step], approach[step + 1]) and approach_clear
			check(approach_clear, "shopping approach clear " + shelf.name + str(index))
	check(clear_segment(Vector3(0, 0.01, -4), Vector3(0, 0.01, 17), 0.8), "loaded cart straight rear delivery to combat aisle")
	check(clear_segment(Vector3(-4, 0.01, 2), Vector3(4, 0.01, 2), 0.8), "boss spawn and lateral dodge clearance")
	for x in [-10.5, 10.5]:
		check(clear_segment(Vector3(x, 0.01, 1), Vector3(x, 0.01, 14.3), 0.8), "cart-sized secondary loop " + str(x))
	check(player.jump_velocity == 4.5, "jump unchanged; recovery uses layout")
	check(manager.checkout.position == Vector3(11, 0, 34), "checkout in front side bay")
	for i in range(18):
		var npc := walker(Vector3(0, 0.01, 1))
		manager.queue.append(npc)
		var point := manager.queue_position(npc)
		check(point.x >= 0.9 and point.z >= 31.3 and point.z <= 32.7, "queue stays outside main delivery/combat spine " + str(i))
	for npc in manager.queue: npc.queue_free()
	manager.queue.clear()
	await frames(2)
	await physical_key(KEY_I)
	await frames(150)
	for shelf: StockShelf in mart.get_node("Shelves").get_children():
		check(shelf.stock_count == shelf.max_stock, "expanded layout auto stock " + shelf.name)
	check(mart.get_node("AutoStock").top_up() == 0, "expanded auto stock no overfill")
	# Use real stocked products, live Player movement, a ray grab and physical keys.
	for type in [&"bread", &"milk", &"watermelon"]:
		var shelf: StockShelf = mart.get_node("Shelves/" + ProductCatalog.find(type).shelf_name)
		var food: GrabbableBody = shelf.stocked_objects[0]
		player.position = shelf.shopping_point(1)
		player.velocity = Vector3.ZERO
		player.head.rotation = Vector3.ZERO
		player.health.current_health = 100
		player.set_physics_process(true)
		interaction.camera.look_at(food.global_position)
		await physical_key(KEY_H)
		check(player.health.current_health == 70, "physical H actual main health " + type)
		await press("grab")
		var grabbed: GrabbableBody = interaction.held_object
		check(is_instance_valid(grabbed) and grabbed.product_type == type, "stocked ray grab live player " + type)
		player.health.current_health = 50
		var cost_before: float = mart.get_node("TeamLife").consumed_product_value
		await physical_key(KEY_G)
		check(player.health.current_health == 50 + ProductCatalog.find(type).heal_value and interaction.held_object == null, "stocked food physical G live heal " + type)
		check(mart.get_node("TeamLife").consumed_product_value == cost_before + ProductCatalog.find(type).price, "consumption loss once " + type)
		player.set_physics_process(false)
	await setup_thief()
	player.position = Vector3(0, 0.01, 3)
	for type in [&"bread", &"milk", &"watermelon", &"tv"]:
		player.health.current_health = 100 if type != &"tv" else 50
		var food := held_food(type)
		var before: float = player.health.current_health
		await physical_key(KEY_G)
		check(is_instance_valid(food) and interaction.held_object == food and player.health.current_health == before, "full HP or nonfood input preserves product " + type)
		interaction.drop_held()
		food.queue_free()
		await frames(2)

func run_checks() -> void:
	await setup_thief()
	player.position = Vector3(0, 0.02, 3)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	for type in [&"bread", &"milk", &"watermelon"]:
		player.health.current_health = 50
		interaction.camera.rotation = Vector3.ZERO
		var food := load(ProductCatalog.find(type).scene_path).instantiate() as GrabbableBody
		mart.add_child(food)
		await place(food, interaction.camera.global_position + Vector3.FORWARD * 1.5)
		await press("grab")
		check(interaction.held_object == food, "real ray grab " + type)
		interaction.camera.rotation.x = 1.0 # No aimed teammate or shelf required.
		print("FOOD INPUT team=", player.health.team, " health node=", player.get_node_or_null("PlayerHealth"), " definition=", ProductCatalog.find(type).is_food)
		await physical_key(KEY_G)
		check(player.health.current_health == 50 + ProductCatalog.find(type).heal_value, "physical G heals " + type)
		check(not is_instance_valid(food), "physical G consumes " + type)
		interaction.drop_held()
		if is_instance_valid(food): food.queue_free()
		await frames(2)
	var teammate := dummy_at(Vector3(0, 0.01, 1.5))
	await frames(3)
	player.health.current_health = 50
	var bread := held_food(&"bread")
	interaction.camera.look_at(teammate.global_position + Vector3.UP * 0.7)
	await physical_key(KEY_G)
	check(player.health.current_health == 65, "alive aim target must not block self heal")
	interaction.drop_held()
	if is_instance_valid(bread): bread.queue_free()
	teammate.health.enter_downed()
	await frames(2)
	player.health.current_health = 50
	bread = held_food(&"bread")
	await physical_key(KEY_G)
	check(not teammate.health.is_downed and teammate.health.current_health == 30 and player.health.current_health == 50, "physical G prioritizes downed teammate over self")
	await layout_checks()
	await setup_thief()
	mart.get_node("AutoStock").top_up()
	await frames(150)
	manager._rng.seed = 112
	manager.patience_time = 90
	var bus: TouristBus = mart.get_node("TouristBus")
	bus.tourist_count = 12
	bus.start_event()
	var visited := {}
	var peak_queue := 0
	for tick in range(4200):
		await frames(1)
		for customer in bus.passengers:
			if is_instance_valid(customer):
				for type in customer.visited_types: visited[type] = true
		peak_queue = maxi(peak_queue, manager.queue.size())
		if bus.spawned_count == 12 and visited.size() >= 5 and peak_queue >= 4: break
	print("EXPANDED RUSH spawned=", bus.spawned_count, " visited=", visited.keys(), " queue=", peak_queue)
	check(bus.spawned_count == 12, "twelve tourists enter expanded store")
	check(visited.size() >= 5 and peak_queue >= 4, "rush progresses through varied shelves into side queue")
	# Add combat and physical clutter without stopping the ongoing business.
	var bosses: KingRatManager = mart.get_node("Bosses")
	var boss := bosses.spawn_boss()
	check(is_instance_valid(boss), "boss can spawn during twelve-person rush")
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(2.5, 0.05, 8))
	var second_cart := preload("res://scenes/interactables/shopping_cart.tscn").instantiate()
	mart.add_child(second_cart)
	await place(second_cart, Vector3(-2.5, 0.05, 8))
	var before: Vector3 = boss.global_position
	await frames(600)
	print("COMBINED boss travel=", boss.global_position.distance_to(before), " customers=", manager.customers.size(), " queue=", manager.queue.size())
	check(boss.global_position.distance_to(before) > 0.5, "boss makes progress with two carts and rush")
	check((cart.collision_mask & HumanSeparation.HUMAN_LAYER) != 0 and (boss.collision_mask & HumanSeparation.HUMAN_LAYER) == 0, "cart stays solid; monster human movement separated")
	if not boss.route.is_empty():
		var target: Vector3 = boss.route[-1]
		await place(cart, Vector3(signf(target.x) * 3.5, 0.05, target.z))
		var crossing := walker(Vector3(signf(target.x) * 5.5, 0.01, target.z))
		crossing.state = BasicCustomer.State.EXIT
		crossing.waypoints = [Vector3(0, 0.01, target.z)]
		crossing.set_physics_process(true)
		var boss_before := boss.global_position
		await frames(600)
		print("CART RAT HUMAN ENCOUNTER boss displacement=", boss.global_position.distance_to(boss_before), " human=", crossing.global_position if is_instance_valid(crossing) else "completed", " cart=", cart.global_position)
		check(boss.global_position.is_finite() and cart.global_position.is_finite(), "forced cart rat human encounter stays finite")
	interaction.camera.global_position = Vector3(0, 30, 29)
	interaction.camera.look_at(Vector3(0, 0, 7))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p112_store.png")
	print("PROMPT 11.2 failures: ", failures)
	quit(1 if failures else 0)
