extends "res://tests/prompt9_smoke.gd"

func walker(at: Vector3) -> BasicCustomer:
	var npc := BasicCustomer.new()
	npc.manager = manager
	npc.position = at
	npc.state = BasicCustomer.State.EVENT_WAIT
	mart.add_child(npc)
	npc.set_physics_process(false)
	return npc

func run_checks() -> void:
	await setup_thief()
	var a := walker(Vector3(-1, 0.01, 1))
	var b := walker(Vector3(1, 0.01, 1))
	for tick in range(180):
		a.velocity = Vector3(2, -0.2, 0)
		b.velocity = Vector3(-2, -0.2, 0)
		a.move_and_slide()
		b.move_and_slide()
		await frames(1)
	print("HEAD ON positions ", a.position, " / ", b.position)
	check(a.position.x > 0.5 and b.position.x < -0.5, "human bodies cross instead of physical deadlock")
	a.position = Vector3(-0.2, 0.01, 1)
	b.position = Vector3(0.2, 0.01, 1)
	var left := a.human_separation.correction(a, Vector3.ZERO)
	var right := b.human_separation.correction(b, Vector3.ZERO)
	check(left.x < 0 and right.x > 0, "close neighbors separate outward")
	b.position.x = 3
	check(a.human_separation.correction(a, Vector3.ZERO) == Vector3.ZERO, "outside radius has no influence")
	b.position.x = 0.2
	var side_a := a.human_separation.correction(a, Vector3.RIGHT * 2)
	var side_b := b.human_separation.correction(b, Vector3.LEFT * 2)
	check(side_a.z * side_b.z < 0, "head-on deterministic right-side bias is reciprocal")
	check(a.human_separation.correction(a, Vector3.RIGHT * 2).is_equal_approx(side_a), "side choice does not jitter between samples")
	var crowded: Array[BasicCustomer] = []
	for i in range(18): crowded.append(walker(Vector3(0.01 * i, 0.01, 1)))
	var correction := a.human_separation.correction(a, Vector3.RIGHT * 2)
	check(correction.length() <= a.human_separation.max_separation_speed + 0.001, "dense crowd correction bounded")
	check((Vector3.RIGHT * 2 + correction).x >= 1.7, "separation preserves at least 85 percent forward progress")
	for npc in crowded: npc.queue_free()
	await frames(2)
	a.position = Vector3(-1, 0.01, 1)
	b.position = Vector3(1, 0.01, 1)
	for tick in range(110):
		a.velocity = Vector3(2, -0.2, 0) + a.human_separation.correction(a, Vector3.RIGHT * 2)
		b.velocity = Vector3(-2, -0.2, 0) + b.human_separation.correction(b, Vector3.LEFT * 2)
		a.move_and_slide()
		b.move_and_slide()
		await frames(1)
	check(a.position.x > 1 and b.position.x < -1, "steered head-on crossing progresses")
	a.queue_free()
	b.queue_free()
	await frames(2)
	# Every current human subtype inherits the same policy, including tourist metadata.
	var humans: Array[PhysicsBody3D] = []
	for script in [BasicCustomer, BasicCustomer, AccidentCustomer, DangerousCustomer, ThiefCustomer, LostParent]:
		var npc: BasicCustomer = script.new()
		npc.manager = manager
		npc.position = Vector3(0, 0.01, 1)
		npc.state = BasicCustomer.State.EVENT_WAIT
		mart.add_child(npc)
		npc.set_physics_process(false)
		humans.append(npc)
	humans[1].set_meta("tourist", true)
	for scene in ["drunk_customer", "lost_child"]:
		var npc: CarryableCharacter = load("res://scenes/interactables/" + scene + ".tscn").instantiate()
		npc.position = Vector3(0, 0.8, 1)
		mart.add_child(npc)
		npc.freeze = true
		npc.set_physics_process(false)
		humans.append(npc)
	for npc in humans:
		check(npc.collision_layer == HumanSeparation.HUMAN_LAYER and npc.collision_mask == (1 | HumanSeparation.MONSTER_LAYER), "human policy: " + str(npc.get_script().resource_path))
	var no_collision := true
	for first in humans:
		for second in humans:
			if first != second and ((first.collision_mask & second.collision_layer) != 0 or (second.collision_mask & first.collision_layer) != 0): no_collision = false
	check(no_collision, "all human subtype pairs have no physical collision")
	for body in [player, mart.get_node("Cart"), mart.get_node("Mop")]:
		check((body.collision_mask & HumanSeparation.HUMAN_LAYER) != 0 and (body.collision_layer & 1) != 0, "nonhuman body preserves reciprocal collision: " + str(body.name))
	var product := await stock("can")
	check((product.collision_mask & HumanSeparation.HUMAN_LAYER) != 0, "product hits human layer")
	var child := humans.back() as LostChild
	child.begin_carry(interaction, player)
	check(child.human_separation.correction(child, Vector3.RIGHT) == Vector3.ZERO, "carried human receives no separation")
	child.end_carry()
	for npc in humans: npc.queue_free()
	await frames(2)
	# Actual NPC motor still collides with world and Player, without human pair exceptions.
	a = walker(Vector3(0, 0.01, 1))
	var wall := Graybox.box(mart, "CrowdWall", Vector3(0.2, 2, 2), Vector3(1, 1, 1), Color.GRAY)
	await frames(2)
	check(a.test_move(a.global_transform, Vector3.RIGHT * 2), "world blocks human motor")
	wall.queue_free()
	player.global_position = Vector3(1, 0.01, 1)
	await frames(2)
	check(a.test_move(a.global_transform, Vector3.RIGHT * 2), "player blocks human motor")
	check(player.test_move(player.global_transform, Vector3.LEFT * 2), "human blocks player motor")
	a.queue_free()
	# Full stocked bus with ordinary routes, no teleporting or custom crowd paths.
	await setup_thief()
	mart.get_node("AutoStock").top_up()
	await frames(180)
	manager._rng.seed = 102
	var bus: TouristBus = mart.get_node("TouristBus")
	bus.tourist_count = 12
	bus.start_event()
	var progressed := {}
	var queued := {}
	var types := {}
	var reservation_ok := true
	var peak_queue := 0
	for tick in range(7200):
		await frames(1)
		var claimed := {}
		for npc in manager.customers:
			for good in npc.goods:
				if not is_instance_valid(good): continue
				if claimed.has(good.get_instance_id()): reservation_ok = false
				claimed[good.get_instance_id()] = true
		for npc in bus.passengers:
			if not is_instance_valid(npc): continue
			if not npc.visited_types.is_empty(): progressed[npc.get_instance_id()] = true
			for type in npc.visited_types: types[type] = true
			if npc.state == BasicCustomer.State.QUEUE or npc.state == BasicCustomer.State.CHECKOUT: queued[npc.get_instance_id()] = true
		peak_queue = maxi(peak_queue, manager.queue.size())
		if bus.state == TouristBus.State.IDLE and bus.spawned_count > 0: break
	print("SOFT RUSH spawned=", bus.spawned_count, " shoppers=", progressed.size(), " queued=", queued.size(), " types=", types.size(), " peak_queue=", peak_queue)
	check(bus.spawned_count == 12, "twelve passengers unload without entrance deadlock")
	check(progressed.size() >= 10 and types.size() >= 5, "crowd reaches multiple real shopping shelves")
	check(queued.size() >= 8 and peak_queue >= 3, "majority progress through shopping to queue")
	check(reservation_ok, "rush preserves unique physical stock reservations")
	check(bus.state == TouristBus.State.IDLE, "rush finishes without permanent blocking")
	print("Prompt 10.2 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
