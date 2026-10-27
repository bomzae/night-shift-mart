extends "res://tests/prompt11_3_smoke.gd"

func floor_crossing(type: StringName, pinned: bool, count: int = 1) -> Dictionary:
	await setup_thief()
	player.position = Vector3(8, 0.01, -3)
	var products: Array[GrabbableBody] = []
	for i in range(count):
		var item := load(ProductCatalog.find(type).scene_path).instantiate() as GrabbableBody
		mart.add_child(item)
		item.position = Vector3(0, ProductCatalog.find(type).size.y / 2 + 0.02, 2 + i * 2)
		item.freeze = pinned
		products.append(item)
	if pinned:
		for x in [-0.72, 0.72]: Graybox.box(mart, "Corridor", Vector3(0.2, 2, 12), Vector3(x, 1, 4), Color.GRAY)
	var npc := walker(Vector3(0, 0.01, 0.2))
	npc.state = BasicCustomer.State.EXIT
	npc.waypoints = [Vector3(0, 0.01, 6 + count * 2)]
	npc.set_physics_process(true)
	var side_motion := 0.0
	for tick in range(900):
		await frames(1)
		side_motion = maxf(side_motion, absf(npc.position.x))
		if npc.position.z > 4 + count * 2: break
	print("FLOOR RECOVERY ", type, " pinned=", pinned, " z=", npc.position.z, " recoveries=", npc.product_recovery.recoveries)
	return {"z": npc.position.z, "pairs": npc.product_recovery.pairs.size(), "recoveries": npc.product_recovery.recoveries, "pushed": products[0].position.distance_to(Vector3(0, ProductCatalog.find(type).size.y / 2 + 0.02, 2)), "side": side_motion}

func measure_rat(speed: float) -> Array[float]:
	await setup_thief()
	var rat: KingRat = mart.get_node("Bosses").spawn_boss()
	rat.move_speed = speed
	rat.position = Vector3(-30, 0.01, 21)
	rat._charge_wait = 1000
	rat.destination_zone = 2
	rat.state = KingRat.State.TRAVEL_ZONE
	rat.route = [Vector3(30, 0.01, 21)]
	var start := rat.position
	await frames(300)
	var five := rat.position.distance_to(start)
	await frames(300)
	return [five, rat.position.distance_to(start)]

func run_checks() -> void:
	var light := await floor_crossing(&"can", false)
	check(light.z > 6 and light.pushed > 0.4 and light.recoveries == 0, "light floor product physically pushed without ghosting")
	var heavy := await floor_crossing(&"tv", true, 2)
	check(heavy.z > 8 and heavy.recoveries >= 2, "actual customer escapes successive pinned floor products")
	check(heavy.pairs == 0, "temporary product pairs restore after passage")
	await setup_thief()
	var npc := walker(Vector3(0, 0.01, 1))
	var tool := preload("res://scenes/interactables/mop.tscn").instantiate()
	mart.add_child(tool)
	tool.position = Vector3(0, 0.5, 2)
	check(npc.product_recovery.eligible(tool), "floor tool eligible")
	tool.begin_carry(interaction, player)
	check(not npc.product_recovery.eligible(tool), "held tool never eligible")
	tool.end_carry()
	tool.queue_free()
	check(npc.cart_recovery != null and npc.product_recovery != null, "cart and product recovery independent")
	var old_distance := await measure_rat(2.4)
	var new_distance := await measure_rat(3.6)
	print("RAT FREE DISTANCE old5/10=", old_distance, " new5/10=", new_distance)
	check(new_distance[0] > old_distance[0] * 1.4 and new_distance[1] > old_distance[1] * 1.4, "actual rat free motion faster at five and ten seconds")
	await setup_thief()
	var stock: AutoStock = mart.get_node("AutoStock")
	var added := stock.top_up()
	await frames(240)
	var rack_counts := {}
	var total := 0
	for shelf: StockShelf in mart.get_node("Shelves").get_children():
		total += shelf.max_stock
		var owner_id := shelf.point_owner.get_instance_id() if is_instance_valid(shelf.point_owner) else shelf.get_instance_id()
		rack_counts[owner_id] = rack_counts.get(owner_id, 0) + 1
		check(shelf.stock_count == shelf.max_stock, "dense actual stock " + shelf.name)
		check(not shelf._label.text.contains("/") and shelf._label.text.length() > 0, "name only shelf tag " + shelf.name)
	var multi := 0
	var triple := 0
	for number in rack_counts.values():
		if number >= 2: multi += 1
		if number >= 3: triple += 1
	print("DENSITY multi=", multi, " triple=", triple, " capacity=", total, " spawned=", added)
	check(multi >= 12 and triple >= 5 and total >= 250 and total <= 350, "multiple zones have dense two and three tier racks")
	check(added == total and stock.top_up() == 0, "dense auto stock complete and no duplicates")
	var sleeping_count := 0
	var fastest := 0.0
	for product: GrabbableBody in mart.get_node("Products").get_children():
		if product.sleeping: sleeping_count += 1
		fastest = maxf(fastest, product.linear_velocity.length())
		check(not product.get_node("Label").visible, "product world detail hidden " + String(product.product_type))
	print("PHYSICS SETTLED sleeping=", sleeping_count, "/", added, " max_speed=", fastest)
	check(sleeping_count > added * 0.8 and fastest < 1, "dense stock sleeps without physics explosion")
	# Real grab-target ray drives HUD; no direct UI helper call.
	player.position = Vector3(0, 0.01, 3)
	interaction.camera.rotation = Vector3.ZERO
	for type in [&"bread", &"tv"]:
		var item := load(ProductCatalog.find(type).scene_path).instantiate() as GrabbableBody
		mart.add_child(item)
		item.position = interaction.camera.global_position + Vector3.FORWARD * 1.5
		item.freeze = true
		interaction.camera.look_at(item.global_position)
		await frames(3)
		check(interaction.product_info.visible and interaction.product_info.text.contains(item.display_name) and interaction.product_info.text.contains("$%.0f" % item.price) and interaction.product_info.text.contains("%.1f kg" % item.weight), "actual aim UI exact data " + String(type))
		check(interaction.product_info.text.contains("+15 HP") == (type == &"bread"), "food-only heal display " + String(type))
		if type == &"bread":
			await frames(2)
			root.get_texture().get_image().save_png("res://.godot/p114_aim.png")
		item.queue_free()
		await frames(3)
		check(not interaction.product_info.visible, "aim info hides after target deletion")
	var rat: KingRat = mart.get_node("Bosses").spawn_boss()
	check(rat.move_speed == 3.6 and rat.food_search_radius == 42, "large store mobility defaults")
	rat._charge_wait = 1000
	player.position = Vector3(0, 0.01, -5)
	var travelled := 0.0
	var last := rat.position
	for tick in range(3600):
		await frames(1)
		travelled += rat.position.distance_to(last)
		last = rat.position
	print("RAT 60 SECOND COVERAGE visited=", rat.visited_zones, " distance=", travelled, " loss=", mart.get_node("Bosses").boss_product_loss_value, " state=", rat.state, " pos=", rat.position)
	check(rat.visited_zones.size() >= 3 and travelled > 45, "sixty second rat coverage reaches three real zones")
	check(mart.get_node("Bosses").boss_product_loss_value > 0, "zone roaming still eats actual stock")
	player.position = rat.position + Vector3.RIGHT * 3
	rat.provoke(player) # Charge regression explicitly provokes the neutral creature.
	rat._charge_wait = 0
	await frames(2)
	check(rat.state == KingRat.State.TELEGRAPH, "zone travel retains nearby player charge pressure")
	var camera := Camera3D.new()
	mart.add_child(camera)
	camera.position = Vector3(0, 40, 49)
	camera.look_at(Vector3(0, 0, 16))
	camera.current = true
	await frames(3)
	root.get_texture().get_image().save_png("res://.godot/p114_store.png")
	print("PROMPT 11.4 failures: ", failures)
	quit(1 if failures else 0)
