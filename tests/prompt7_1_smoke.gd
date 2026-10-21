extends "res://tests/prompt7_smoke.gd"

func puddle(at: Vector3 = Vector3(0, 0.01, 2)) -> SpillZone:
	var accidents: AccidentManager = mart.get_node("Accidents")
	return accidents.create_spill(at, [player.get_rid()])

func ready_player() -> SpillZone:
	await setup_mart()
	var zone := puddle()
	player.global_position = Vector3(0, 0.01, 2)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(25)
	return zone

func run_checks() -> void:
	var zone := await ready_player()
	var kd: KnockdownState = player.get_node("Knockdown")
	check(not kd.active(), "stationary character does not fall in core")
	player.global_position = Vector3(1.3, 0.01, 2)
	player.velocity = Vector3(0, 0, -2)
	await frames(4)
	check(SlipState.wet(player) and not kd.active(), "moving edge contact keeps control")
	player.global_position = Vector3(0, 0.01, 2)
	player.velocity = Vector3(0, 0, -0.5)
	await frames(4)
	check(not kd.active(), "core below minimum speed remains upright")
	var head: Node3D = player.get_node("Head")
	var normal_height := head.position.y
	player.velocity = Vector3(0, 0, -2)
	await frames(2)
	check(kd.active() and kd.fall_count == 1, "core plus speed triggers deterministic fall")
	check(player.velocity.z < -2, "fall gives bounded directional slip boost")
	Input.action_press("move_forward")
	Input.action_press("jump")
	var yaw := player.rotation.y
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(30, 0)
	Input.parse_input_event(mouse)
	await frames(20)
	check(player.rotation.y != yaw, "mouse look continues during fall")
	check(head.position.y < normal_height - 0.5 and interaction.camera.rotation.x > 0.15, "camera visibly lowers and pitches backward")
	check(player.velocity.y <= 0.1 and Vector2(player.velocity.x, player.velocity.z).length() < 2, "movement and jump cannot drive downed player")
	root.get_texture().get_image().save_png("res://.godot/p71_player_down.png")
	Input.action_release("move_forward")
	Input.action_release("jump")
	check(not kd.try_start(Vector3.FORWARD) and kd.fall_count == 1, "one active fall cannot stack")
	await frames(70)
	check(not kd.active() and kd.phase == KnockdownState.Phase.IMMUNE, "automatic short recovery enters immunity")
	check(is_equal_approx(head.position.y, normal_height) and interaction.camera.rotation.is_zero_approx(), "camera returns to rest without changing look")
	player.global_position = Vector3(0, 0.01, 2)
	player.velocity = Vector3(0, 0, -2)
	await frames(2)
	check(not kd.active() and kd.fall_count == 1, "core cannot retrigger during immunity")
	Input.action_press("move_right")
	await frames(8)
	Input.action_release("move_right")
	check(player.velocity.x > 0.1, "movement input restores after recovery")
	await frames(80)
	player.global_position = Vector3(0, 0.01, 2)
	player.velocity = Vector3(0, 0, -2)
	await frames(2)
	check(kd.fall_count == 2, "expired immunity permits another core fall")
	await frames(90)
	zone.clean(1)
	await frames(85)
	player.global_position = Vector3(0, 0.01, 2)
	player.velocity = Vector3(0, 0, -3)
	await frames(4)
	check(kd.fall_count == 2 and not SlipState.wet(player), "removed spill has no remaining fall trigger")
	zone = await ready_player()
	Graybox.box(mart, "FallWall", Vector3(4, 2, 0.2), Vector3(0, 1, 1), Color.GRAY)
	player.velocity = Vector3(0, 0, -5)
	await frames(30)
	check(player.knockdown.active() and player.global_position.z > 1.35, "downed player retains world wall collision")

	# Same physical trigger releases every existing ownership type.
	for type in ["product", "child", "cart"]:
		await setup_mart()
		player.global_position = Vector3(0, 0.01, 2)
		var held: RigidBody3D
		if type == "product":
			held = load("res://scenes/interactables/products/can.tscn").instantiate()
			mart.add_child(held)
		elif type == "child":
			held = mart.get_node("LostFamilies").spawn_pair()
		else: held = mart.get_node("Cart")
		await place(held, Vector3(0, 1.3 if type != "cart" else 0.1, 0.4))
		check(held.begin_carry(interaction, player), "prepare owned " + type)
		interaction.held_object = held
		if type == "child": check(not held.knockdown.try_start(Vector3.FORWARD), "held character cannot independently enter knockdown")
		if type != "child":
			var charge := InputEventAction.new()
			charge.action = "throw"
			charge.pressed = true
			Input.parse_input_event(charge)
			await frames(3)
			check(interaction.is_charging, "charge starts before " + type + " fall")
		zone = puddle()
		player.set_physics_process(true)
		player.velocity = Vector3.ZERO
		await frames(25)
		player.velocity = Vector3(0, 0, -3)
		await frames(2)
		check(player.knockdown.active() and interaction.held_object == null and held.holder == null, "fall drops owned " + type)
		check(not interaction.is_charging and interaction.charge_ratio == 0, "fall cancels charge " + type)
		await press("grab")
		check(interaction.held_object == null, "downed player cannot regrab " + type)
		if type == "child": check(held.knockdown.fall_count == 0, "carried child does not independently fall")

	await setup_mart()
	await stock("can")
	var customer: BasicCustomer = manager.spawn_customer([&"can"])
	zone = puddle(Vector3(0, 0.01, 8))
	for tick in range(1200):
		await frames(1)
		if customer.knockdown.active(): break
	check(customer.knockdown.active(), "shopping customer falls crossing actual core")
	var state_before := customer.state
	var path_before := customer.waypoints.duplicate()
	var goods_before := customer.goods.duplicate()
	await frames(20)
	check(customer.state == state_before and customer.waypoints == path_before and customer.goods == goods_before, "fall pauses path and preserves purchase reservations")
	check(absf(customer._mesh.rotation.z) > 1.0, "NPC mesh visibly lies down")
	var camera_pose: Transform3D = interaction.camera.global_transform
	interaction.camera.global_position = customer.global_position + Vector3(2, 1.4, 3)
	interaction.camera.look_at(customer.global_position + Vector3.UP * 0.4)
	await frames(1)
	root.get_texture().get_image().save_png("res://.godot/p71_npc_down.png")
	interaction.camera.global_transform = camera_pose
	zone.clean(1)
	await wait_checkout(customer)
	check(customer.knockdown.fall_count == 1 and customer.picked_items.size() == 1, "customer resumes shopping and reaches checkout")
	var accidents_at_queue: AccidentManager = mart.get_node("Accidents")
	zone = accidents_at_queue.create_spill(customer.global_position, [customer.get_rid()])
	await frames(25)
	customer.velocity = Vector3(2, 0, 0)
	await frames(2)
	var patience_before := customer.patience_left
	check(customer.knockdown.active(), "queued customer can fall after physical motion")
	await frames(15)
	check(customer.state == BasicCustomer.State.CHECKOUT and manager.queue.has(customer) and customer.patience_left == patience_before, "queue place and patience pause during knockdown")
	check(not station.use_station("scan") and customer.scanned == 0, "downed customer cannot be scanned")
	zone.clean(1)
	await frames(120)
	await aim_action("scan")
	await frames(32)
	await aim_action("pay")
	check(manager.sales == 5, "recovered customer completes ordinary payment")

	await setup_mart()
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	zone = puddle()
	await place(drunk, Vector3(0, 0.8, 2))
	await frames(25)
	drunk.linear_velocity = Vector3(0, 0, -1.6)
	for tick in range(10):
		await frames(1)
		if drunk.knockdown.active(): break
	check(drunk.knockdown.active(), "drunk falls at lower speed")
	var direction_count := drunk.direction_changes
	await frames(20)
	check(drunk.direction_changes == direction_count and absf(drunk.get_node("Mesh").rotation.z) > 1, "drunk pauses wander and displays fall")
	zone.clean(1)
	await frames(100)
	check(not drunk.knockdown.active() and drunk.linear_velocity.length() > 0.2, "drunk recovers and resumes wandering")

	await setup_mart()
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	var parent := child.parent_npc as LostParent
	await place(child, parent.global_position + Vector3(0.8, 0.6, 0))
	check(mart.get_node("LostFamilies").try_reunion(child), "prepare reunited family")
	await frames(55)
	var family_accidents: AccidentManager = mart.get_node("Accidents")
	zone = family_accidents.create_spill(parent.global_position, [parent.get_rid(), child.get_rid()])
	for tick in range(100):
		await frames(1)
		if parent.knockdown.fall_count > 0 and child.knockdown.fall_count > 0: break
	check(parent.knockdown.fall_count > 0 and child.knockdown.fall_count > 0, "both departing family members fall in actual spill")
	var family_state := parent.state
	await frames(20)
	check(parent.state == family_state and child.reunited, "family fall preserves exit and follow state")
	check(parent.get_collision_exceptions().has(child) and child.get_collision_exceptions().has(parent), "family exceptions survive fall")
	zone.clean(1)
	for tick in range(1600):
		await frames(1)
		if not is_instance_valid(child): break
	check(not is_instance_valid(child) and not is_instance_valid(parent), "family recovers and completes joint exit")

	await setup_mart()
	await stock("can")
	var accidents: AccidentManager = mart.get_node("Accidents")
	var accident := accidents.spawn_accident([&"can"])
	for tick in range(1200):
		await frames(1)
		if accident.accident_triggered: break
	check(accident.accident_triggered and not accident.knockdown.active(), "new own spill does not cause immediate fall")
	for tick in range(180):
		await frames(1)
		if accident.knockdown.fall_count > 0: break
	check(accident.knockdown.fall_count == 1, "accident customer can fall in own spill after pause")
	await wait_checkout(accident)
	check(accidents.spills_created == 1 and not accident.knockdown.active(), "accident resumes checkout without repeated spill creation")
	print("Prompt 7.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
