extends "res://tests/prompt11_2_smoke.gd"

func run_checks() -> void:
	await setup_thief()
	check(ProductCatalog.ids().size() == 18, "18 canonical definitions plus legacy appliance")
	var floor_shape: BoxShape3D = mart.get_node("StoreFloor/Floor").get_child(1).shape
	check(floor_shape.size.x * floor_shape.size.z >= 648 * 4, "72x36 store area at least four times")
	check(clear_segment(Vector3(0, 0.01, -4), Vector3(0, 0.01, 35), 0.8), "cart route entire rear-to-front spine")
	for x in [-26, -17.5, -9.5, 9.5, 17.5, 26]:
		check(clear_segment(Vector3(x, 0.01, 2), Vector3(x, 0.01, 32), 0.8), "cart side loop " + str(x))
	for z in [21, 27]:
		check(clear_segment(Vector3(-32, 0.01, z), Vector3(32, 0.01, z), 0.8), "full width cross aisle " + str(z))
	for definition: ProductDefinition in ProductCatalog.DEFINITIONS:
		check(definition.price > 0 and definition.weight > 0 and definition.size.length() > 0 and ResourceLoader.exists(definition.scene_path), "complete catalog " + str(definition.id))
	var stock: AutoStock = mart.get_node("AutoStock")
	var added := stock.top_up()
	await frames(180)
	var capacity := 0
	for shelf: StockShelf in mart.get_node("Shelves").get_children():
		capacity += shelf.max_stock
		check(shelf.stock_count == shelf.max_stock, "physical tier stock " + shelf.name)
	check(added == capacity, "all slots physically filled")
	check(stock.top_up() == 0, "repeat auto stock no overfill")
	var base: StockShelf = mart.get_node("Shelves/CanShelf")
	var middle: StockShelf = mart.get_node("Shelves/InstantNoodlesShelf")
	var upper: StockShelf = mart.get_node("Shelves/ChipsShelf")
	check(base.tier_height == 0 and middle.tier_height == 0.55 and upper.tier_height == 0.95, "three real accessible tiers")
	check(upper.shopping_point(1) == base.shopping_point(1), "shared ground shopping points")
	var a := walker(Vector3(0, 0.01, 1))
	var b := walker(Vector3(0, 0.01, 2))
	var pa := upper.reserve_shopping_point(a, upper.global_position)
	var pb := middle.reserve_shopping_point(b, middle.global_position)
	check(pa != pb, "tier occupancy shared")
	upper.release_shopping_point(a)
	middle.release_shopping_point(b)
	var item: GrabbableBody = upper.stocked_objects[0]
	check(not middle.stock_eligible(item) and upper.stock_eligible(item), "wrong tier never counts as stock")
	item.queue_free()
	await frames(3)
	check(stock.top_up() == 1, "tier topup only missing body")
	await frames(100)
	for shelf: StockShelf in [base, middle, upper]:
		player.position = shelf.shopping_point(1)
		var nearest: GrabbableBody = shelf.stocked_objects[0]
		for body: GrabbableBody in shelf.stocked_objects:
			if body.global_position.distance_to(player.position) < nearest.global_position.distance_to(player.position): nearest = body
		var original := nearest.global_transform
		interaction.camera.look_at(nearest.global_position)
		await press("grab")
		check(interaction.held_object == nearest, "actual ray grab tier " + str(shelf.tier_height))
		interaction.drop_held()
		nearest.global_transform = original
		nearest.linear_velocity = Vector3.ZERO
		nearest.angular_velocity = Vector3.ZERO
		await frames(60)
	for type in [&"chips", &"instant_noodles", &"cereal", &"juice", &"rice_bag"]:
		player.health.current_health = 50
		var meal := held_food(type)
		await physical_key(KEY_G)
		check(player.health.current_health == 50 + ProductCatalog.find(type).heal_value and not is_instance_valid(meal), "new food physical G consumes and heals " + str(type))
	# Actual area-driven hit: no direct call to the damage helper.
	player.position = Vector3(0, 0.01, 4)
	player.health.current_health = 100
	var rat: KingRat = mart.get_node("Bosses").spawn_boss()
	check(is_instance_valid(rat), "boss safe spawn")
	rat.position = Vector3(0, 0.01, 4)
	rat.state = KingRat.State.STAGGER
	rat._left = 10
	await frames(5)
	check(rat.get_collision_exceptions().has(player) and player.get_collision_exceptions().has(rat), "player reciprocal movement exception")
	a.position = rat.position
	await frames(5)
	check(rat.get_collision_exceptions().has(a), "human movement exception")
	check(not rat.get_collision_exceptions().has(mart.get_node("Cart")), "cart remains solid")
	var departing := walker(Vector3(0, 0.01, 15))
	var departing_id := departing.get_instance_id()
	rat._sync_character_exceptions()
	departing.queue_free()
	await frames(2)
	check(not rat._character_pairs.has(departing_id) and rat.get_collision_exceptions().has(player), "departing human releases pair before physics RID deletion")
	check(player.health.current_health == 100, "ordinary overlap no damage")
	var contact_start := player.position
	player.set_physics_process(true)
	await frames(30)
	check(player.position.distance_to(contact_start) > 0.1 and player.health.current_health == 100, "ordinary overlap visibly pushes live player without damage")
	player.set_physics_process(false)
	player.position = rat.position
	await frames(2)
	rat.state = KingRat.State.CHARGE
	rat._left = 0.5
	rat.charge_direction = Vector3.BACK
	await frames(3)
	check(player.health.current_health == 70 and player.knockdown.active(), "area charge player damage and knockdown")
	check(a.knockdown.active(), "area charge human knockdown")
	await frames(20)
	check(player.health.current_health == 70, "same charge damages once")
	# Reproduce the old blocking policy with the same capsules and movement query.
	rat.set_physics_process(false)
	rat.position = Vector3(0, 0.01, 8)
	a.position = Vector3(0, 0.01, 9.5)
	rat.remove_collision_exception_with(a)
	a.remove_collision_exception_with(rat)
	rat.collision_mask |= HumanSeparation.HUMAN_LAYER
	await frames(2)
	check(rat.test_move(rat.global_transform, Vector3(0, 0, 3)), "old solid policy reproduces character path blocking")
	rat.collision_mask &= ~HumanSeparation.HUMAN_LAYER
	rat.add_collision_exception_with(a)
	a.add_collision_exception_with(rat)
	await frames(2)
	check(not rat.test_move(rat.global_transform, Vector3(0, 0, 3)), "same path unblocked with separated character hit detection")
	rat.set_physics_process(true)
	# Real motors cross the same position, with a cart still solid nearby.
	rat.state = KingRat.State.CHARGE
	rat._left = 0.8
	rat._hit_targets.clear()
	rat.position = Vector3(0, 0.01, 8)
	rat.charge_direction = Vector3.BACK
	a.knockdown.finish_recovery()
	a.position = Vector3(0, 0.01, 11)
	a.state = BasicCustomer.State.EXIT
	a.waypoints = [Vector3(0, 0.01, 6)]
	a.set_physics_process(true)
	var rat_start := rat.position
	await frames(180)
	check(rat.position.distance_to(rat_start) > 2, "monster progresses through human encounter")
	check(not is_instance_valid(a) or a.position.z < 10, "human recovers and progresses through monster")
	rat.queue_free()
	b.queue_free()
	await frames(2)
	# Full shopping path from each tier through the unchanged scan/pay interface.
	player.knockdown.finish_recovery()
	player.position = manager.checkout.global_position + Vector3(0, 0.01, 1.25)
	manager.patience_time = 180
	for type in [&"can", &"instant_noodles", &"chips"]:
		var buyer := manager.spawn_customer([type])
		check(is_instance_valid(buyer), "tier customer spawn " + str(type))
		if not is_instance_valid(buyer): continue
		for tick in range(5000):
			await frames(1)
			if buyer.state == BasicCustomer.State.CHECKOUT: break
		check(buyer.picked_items.size() == 1 and buyer.visited_types.has(type), "actual tier pickup " + str(type))
		check(buyer.state == BasicCustomer.State.CHECKOUT, "tier customer reaches checkout " + str(type))
		var sales_before: float = manager.sales
		await aim_action("scan")
		await frames(32)
		await aim_action("pay")
		check(manager.sales == sales_before + ProductCatalog.find(type).price, "tier checkout exact price " + str(type))
		await frames(60)
	var upper_food: GrabbableBody = upper.stocked_objects[0]
	var food_price := upper_food.price
	var loss_before: float = mart.get_node("Bosses").boss_product_loss_value
	rat = mart.get_node("Bosses").spawn_boss()
	rat.position = upper.shopping_point(1)
	rat.food = upper_food
	rat._charge_wait = 1000
	rat.state = KingRat.State.EAT
	rat._left = 0.05
	check(rat.can_eat(), "upper tier has a valid physical bite approach")
	await frames(10)
	check(not is_instance_valid(upper_food) and mart.get_node("Bosses").boss_product_loss_value == loss_before + food_price, "upper tier eating consumes real product once")
	var camera := Camera3D.new()
	mart.add_child(camera)
	camera.position = Vector3(0, 40, 49)
	camera.look_at(Vector3(0, 0, 16))
	camera.current = true
	await frames(3)
	root.get_texture().get_image().save_png("res://.godot/p113_store.png")
	print("PROMPT 11.3 failures: ", failures)
	quit(1 if failures else 0)
