extends "res://tests/prompt11_4_smoke.gd"

func pinned_tool() -> void:
	await setup_thief()
	player.position = Vector3(8, 0.01, -3)
	var mop := preload("res://scenes/interactables/mop.tscn").instantiate()
	mart.add_child(mop)
	mop.position = Vector3(0, 0.18, 2)
	mop.rotation.z = PI / 2
	mop.freeze = true
	for x in [-0.72, 0.72]: Graybox.box(mart, "Corridor", Vector3(0.2, 2, 8), Vector3(x, 1, 2), Color.GRAY)
	var npc := walker(Vector3(0, 0.01, 0.2))
	npc.state = BasicCustomer.State.EXIT
	npc.waypoints = [Vector3(0, 0.01, 7)]
	npc.set_physics_process(true)
	await frames(600)
	check(not is_instance_valid(npc) or npc.position.z > 5, "actual human escapes floor mop obstacle")
	check(not is_instance_valid(npc) or npc.product_recovery.pairs.is_empty(), "tool exception restored")

func run_checks() -> void:
	await pinned_tool()
	await setup_thief()
	player.position = Vector3(8, 0.01, -3)
	var open_tv := load(ProductCatalog.find(&"tv").scene_path).instantiate() as GrabbableBody
	mart.add_child(open_tv)
	open_tv.position = Vector3(0, 0.39, 2)
	open_tv.freeze = true
	var avoiding := walker(Vector3(0, 0.01, 0.2))
	avoiding.state = BasicCustomer.State.EXIT
	avoiding.waypoints = [Vector3(0, 0.01, 8)]
	avoiding.set_physics_process(true)
	var side_distance := 0.0
	for tick in range(600):
		await frames(1)
		side_distance = maxf(side_distance, absf(avoiding.position.x))
		if avoiding.position.z > 5: break
	check(avoiding.position.z > 5 and side_distance > 0.3, "open aisle uses actual side step around pinned product")
	await setup_thief()
	var npc := walker(Vector3(0, 0.01, 1))
	var tv := load(ProductCatalog.find(&"tv").scene_path).instantiate() as GrabbableBody
	mart.add_child(tv)
	tv.position = Vector3(0, 0.39, 2)
	tv.freeze = true
	await frames(3)
	for tick in range(90):
		npc.product_recovery.steer(Vector3.BACK * 2, 1.0 / 60)
		await frames(1)
	check(npc.product_recovery.pairs.size() == 1, "stationary blocked encounter creates one pair")
	tv.begin_carry(interaction, player)
	await frames(2)
	check(npc.product_recovery.pairs.is_empty() and not npc.get_collision_exceptions().has(tv), "player picking up recovery obstacle restores collision")
	tv.end_carry()
	tv.position = Vector3(0, 0.39, 2)
	for tick in range(90):
		npc.product_recovery.steer(Vector3.BACK * 2, 1.0 / 60)
		await frames(1)
	tv.queue_free()
	await frames(2)
	check(npc.product_recovery.pairs.is_empty() and npc.get_collision_exceptions().is_empty(), "deleted obstacle pair cleans before body RID free")
	var shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	mart.get_node("AutoStock").top_up()
	await frames(180)
	check(not npc.product_recovery.on_floor_level(shelf.stocked_objects[0]), "stocked goods never treated as floor obstacles")
	# Switch aim directly between live objects and then to empty space.
	player.position = Vector3(0, 0.01, 4)
	var aimed: Array[GrabbableBody] = []
	for spec in [[&"bread", -0.6], [&"tv", 0.6]]:
		var product := load(ProductCatalog.find(spec[0]).scene_path).instantiate() as GrabbableBody
		mart.add_child(product)
		product.position = interaction.camera.global_position + Vector3(spec[1], 0, -1.8)
		product.freeze = true
		aimed.append(product)
	for product in aimed:
		interaction.camera.look_at(product.global_position)
		await frames(2)
		check(interaction.product_info.visible and interaction.product_info.text.contains(product.display_name), "live A to B aim target updates immediately")
	interaction.camera.rotation.x = 1.2
	await frames(2)
	check(not interaction.product_info.visible, "empty sky hides product detail UI")
	for product in aimed: product.queue_free()
	var rack_camera := Camera3D.new()
	mart.add_child(rack_camera)
	rack_camera.position = shelf.to_global(Vector3(0, 1.6, 3.8))
	rack_camera.look_at(shelf.global_position + Vector3.UP * 1.2)
	rack_camera.current = true
	await frames(2)
	root.get_texture().get_image().save_png("res://.godot/p114_rack.png")
	interaction.camera.current = true
	rack_camera.queue_free()
	# Real tourist AI, scatter in the entrance and the main aisle.
	var bus: TouristBus = mart.get_node("TouristBus")
	bus.tourist_count = 12
	manager._rng.seed = 114
	var clutter: Array[GrabbableBody] = []
	for i in range(12):
		var type: StringName = [&"can", &"bread", &"tv"][i % 3]
		var product := load(ProductCatalog.find(type).scene_path).instantiate() as GrabbableBody
		mart.add_child(product)
		product.position = Vector3((i % 3 - 1) * 0.7, 0.6, 28 + floori(i / 3.0) * 1.4)
		clutter.append(product)
	bus.start_event()
	var progressed := {}
	for tick in range(7200):
		await frames(1)
		for person in bus.passengers:
			if is_instance_valid(person) and not person.visited_types.is_empty(): progressed[person.get_instance_id()] = true
		if progressed.size() >= 10: break
	print("SCATTER RUSH spawned=", bus.spawned_count, " progressed=", progressed.size())
	check(bus.spawned_count == 12 and progressed.size() >= 10, "tourist flow continues through actual floor scatter")
	# Thief uses the same actual BasicCustomer movement with escape state preserved.
	var thief: ThiefCustomer = mart.get_node("Thieves").spawn_thief()
	thief.theft_state = ThiefCustomer.TheftState.ESCAPING
	thief.state = BasicCustomer.State.EXIT
	thief.position = Vector3(0, 0.01, 26)
	thief.waypoints = [Vector3(0, 0.01, 34)]
	thief.move_speed = thief.escape_speed
	for tick in range(600):
		await frames(1)
		if not is_instance_valid(thief) or thief.position.z > 33: break
	check(not is_instance_valid(thief) or thief.position.z > 33, "escaping thief progresses through scattered product lane")
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	drunk.position = Vector3(0, 0.8, 26)
	drunk.wander_direction = Vector3.BACK
	drunk._direction_wait = 100
	for tick in range(900):
		await frames(1)
		if tick % 120 == 0:
			print("DRUNK TRACE ", tick, " pos=", drunk.position, " stuck=", drunk.product_recovery.stuck, " obstacle=", drunk.product_recovery.obstacle, " contacts=", drunk.get_colliding_bodies())
		if drunk.position.z > 33: break
	print("DRUNK SCATTER position=", drunk.position, " velocity=", drunk.linear_velocity, " grounded=", drunk.grounded, " cart=", drunk.supported_by_cart, " recovery=", drunk.product_recovery.recoveries, " direction=", drunk.wander_direction, " timer=", drunk._direction_wait)
	check(drunk.position.z > 33 and drunk.product_recovery != null, "drunk retains wandering movement through scattered goods")
	print("PROMPT 11.4 FLOW failures: ", failures)
	quit(1 if failures else 0)
