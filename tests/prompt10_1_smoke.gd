extends "res://tests/prompt9_smoke.gd"
var auto_stock: AutoStock

func stocked_setup() -> void:
	await setup_thief()
	auto_stock = mart.get_node("AutoStock")
	await press("debug_auto_stock")
	await frames(180)

func run_checks() -> void:
	await setup_thief()
	auto_stock = mart.get_node("AutoStock")
	check(InputMap.has_action("debug_auto_stock") and not auto_stock.auto_stock_on_start, "I action and opt-in startup stocking")
	check(ProductCatalog.ids().size() == 9 and ProductCatalog.find(&"appliance").legacy, "nine primary definitions plus compatible appliance")
	var expected_total := 0
	for definition: ProductDefinition in ProductCatalog.DEFINITIONS:
		var product: GrabbableBody = load(definition.scene_path).instantiate()
		check(product.price == definition.price and product.weight == definition.weight and product.product_type == definition.id, "scene uses catalog values " + String(definition.id))
		var shelf: StockShelf = mart.get_node("Shelves/" + definition.shelf_name)
		check(shelf.accepted_type == definition.id and shelf.max_stock == definition.shelf_capacity and shelf.shopping_point_count >= 2, "shelf section and shopping points " + String(definition.id))
		check(definition.stock_slots().size() >= shelf.max_stock, "placement points cover capacity " + String(definition.id))
		expected_total += shelf.max_stock
		product.free()
	check(ProductCatalog.find(&"bread").weight < ProductCatalog.find(&"can").weight and ProductCatalog.find(&"tv").weight > ProductCatalog.find(&"microwave").weight, "light and heavy prototype values")
	await press("debug_auto_stock")
	check(auto_stock.last_added == expected_total and mart.get_node("Products").get_child_count() == expected_total, "I creates real physical products for every empty shelf")
	check(auto_stock.top_up() == 0 and auto_stock.top_up() == 0, "unsettled goods and repeated same-frame I cannot duplicate")
	await frames(180)
	for shelf: StockShelf in mart.get_node("Shelves").get_children():
		print("STOCK ", shelf.accepted_type, "=", shelf.stock_count, "/", shelf.max_stock)
		check(shelf.stock_count == shelf.max_stock, "stable physical full stock " + String(shelf.accepted_type))
	check(auto_stock.top_up() == 0, "settled full shelves do not overfill")
	var camera_pose: Transform3D = interaction.camera.transform
	interaction.camera.global_position = Vector3(0, 15, 16)
	interaction.camera.look_at(Vector3(0, 0, 4))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p101_store.png")
	interaction.camera.transform = camera_pose
	var milk_shelf: StockShelf = mart.get_node("Shelves/MilkShelf")
	var removed: GrabbableBody = milk_shelf.stocked_objects[0]
	var old_position := removed.global_position
	removed.queue_free()
	await frames(3)
	var wrong: GrabbableBody = load(ProductCatalog.find(&"tv").scene_path).instantiate()
	mart.get_node("Products").add_child(wrong)
	await place(wrong, old_position)
	await frames(2)
	auto_stock.top_up()
	check(is_instance_valid(wrong) and milk_shelf.stock_count < milk_shelf.max_stock, "wrong stock is preserved and occupied slots are skipped")
	await place(wrong, Vector3(0, 1, -1))
	await frames(3)
	var missing := milk_shelf.max_stock - auto_stock.physical_count(milk_shelf)
	check(auto_stock.top_up() == missing, "top up only missing unblocked goods")
	await frames(150)
	check(milk_shelf.stock_count == milk_shelf.max_stock, "normal stock returns after obstacle removed")
	# Every canonical ID reserves actual stock, without duplicating purchase logic.
	for id in ProductCatalog.ids():
		var customer := manager.spawn_customer([id])
		check(customer != null and manager.valid_goods(customer) and customer.goods[0].product_type == id, "customer can purchase catalog id " + String(id))
		manager.remove_customer(customer)
		await frames(2)
	var buyer := manager.spawn_customer([&"bread", &"tv"])
	for tick in range(4000):
		await frames(1)
		if buyer.state == BasicCustomer.State.CHECKOUT: break
	print("BUYER position=", buyer.global_position, " state=", buyer.state, " visits=", buyer.visited_types)
	check(buyer.state == BasicCustomer.State.CHECKOUT and buyer.visited_types.has(&"bread") and buyer.visited_types.has(&"tv"), "customer walks to both new wings then checkout")
	check(buyer.picked_items.size() == 2 and buyer.goods.is_empty(), "new product physical pickup uses logical basket")
	await aim_action("scan")
	await frames(32)
	await aim_action("scan")
	await frames(32)
	await aim_action("pay")
	check(manager.sales == 810, "new products settle actual prices")
	await frames(2)
	check(auto_stock.top_up() == 2, "picked goods can be replenished without touching customer basket")
	# Auto stock remains ordinary grabbable cargo.
	var bread: GrabbableBody = mart.get_node("Shelves/BreadShelf").stocked_objects[0]
	player.global_position = Vector3(0, 0.01, 3)
	await place(bread, Vector3(0, 1.4, 1.6))
	interaction.camera.look_at(bread.global_position)
	await press("grab")
	check(interaction.held_object == bread, "auto-stock bread grabs normally")
	await press("throw")
	check(not is_instance_valid(interaction.held_object) and bread.linear_velocity.length() > 1, "auto-stock bread throws normally")
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(bread, cart.global_position + Vector3.UP * 1.0)
	await frames(100)
	cart.refresh_load()
	check(cart.cargo.has(bread) and cart.loaded_weight >= 0.5, "auto-stock goods are actual cart cargo")
	for x in [-8.2, 8.2]:
		for z in [2.0, 4.0, 8.0]:
			var query := PhysicsShapeQueryParameters3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.4, 1.4, 1.4)
			query.shape = shape
			query.transform.origin = Vector3(x, 1, z)
			check(mart.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "cart-sized clearance in expanded aisle")

	await setup_thief()
	var tv: GrabbableBody = load(ProductCatalog.find(&"tv").scene_path).instantiate()
	mart.get_node("Products").add_child(tv)
	var tv_shelf: StockShelf = mart.get_node("Shelves/TVShelf")
	await place(tv, tv_shelf.to_global(Vector3(0, 1.05, 0)))
	await frames(120)
	var thief := thieves.spawn_thief()
	check(thief != null and thief.target_product == tv, "thief targets actual high-value new stock")
	await wait_theft(thief)
	thief.set_physics_process(false)
	player.global_position = thief.global_position + Vector3(-1.2, 0, 0)
	interaction.camera.look_at(thief.global_position + Vector3.UP)
	await frames(2)
	await press("grab")
	var recovered := thieves.last_recovered
	check(is_instance_valid(recovered) and recovered.price == 800 and recovered.weight == 10 and recovered.definition.id == &"tv", "TV capture restores definition and physical price weight")
	check(thieves.thieves_caught == 1 and thieves.stolen_goods_value == 0, "TV capture counts success not loss")
	if is_instance_valid(recovered):
		await place(recovered, Vector3(0, 0.6, -1))
		fire_manager.burn_exposure = 0.6
		var fire := fire_manager.create_fire(Vector3(0, 0.01, -1), [recovered.get_rid()])
		fire.intensity = 1
		await frames(140)
		check(not is_instance_valid(recovered) and fire_manager.fire_damage_value == 800, "TV fire uses exact catalog price once")
		await frames(80)
		check(fire_manager.fire_damage_value == 800, "burn loss is not duplicated")
	check(not ProductCatalog.find(&"frying_pan").flammable and not ProductCatalog.find(&"watermelon").flammable and ProductCatalog.find(&"bread").flammable, "catalog flammable distinctions")

	await stocked_setup()
	manager._rng.seed = 101
	var bus: TouristBus = mart.get_node("TouristBus")
	bus.start_event()
	var types := {}
	var peak_queue := 0
	for tick in range(5000):
		await frames(1)
		for passenger in bus.passengers:
			if is_instance_valid(passenger):
				for id in passenger.purchase_types: types[id] = true
		peak_queue = maxi(peak_queue, manager.queue.size())
		if bus.spawned_count == 10 and peak_queue >= 3: break
	print("CATALOG RUSH types=", types.keys(), " queue=", peak_queue)
	for customer in manager.customers: print("RUSH NPC ", customer.global_position, " state=", customer.state, " visits=", customer.visited_types)
	check(bus.spawned_count == 10 and types.size() >= 5, "tourist rush buys across expanded catalog")
	check(peak_queue >= 3, "new shelf routes still create checkout pressure")

	await setup_thief()
	var delivery: DeliveryManager = mart.get_node("Delivery")
	var delivered_types := {}
	for cycle in range(4):
		delivery.arrive()
		check(delivery.delivered == 6, "six spaced physical products per catalog shipment")
		for product in delivery.shipment:
			delivered_types[product.product_type] = true
			check(product.definition != null and is_equal_approx(product.mass, product.weight), "delivery uses shared definition and physics")
		await frames(100)
		delivery.depart()
		await frames(5)
	check(delivered_types.size() == 10, "delivery cycle covers nine products plus legacy appliance")
	await setup_thief()
	auto_stock = mart.get_node("AutoStock")
	auto_stock.auto_stock_on_start = true
	auto_stock._stock_after_physics()
	await frames(180)
	check(mart.get_node("Products").get_child_count() == expected_total, "startup opt-in uses same real stocking path")
	print("Prompt 10.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
