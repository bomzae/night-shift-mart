extends "res://tests/prompt4_smoke.gd"

func deliver(child: LostChild, parent: LostParent, voluntary: bool = true) -> void:
	player.global_position = parent.global_position + Vector3(2.1, 0.01, 0)
	await place(child, parent.global_position + Vector3(1.1, 0.65, 0))
	interaction.camera.look_at(child.global_position)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	child.begin_carry(interaction, player)
	interaction.held_object = child
	if voluntary:
		await frames(3)
		if child.family_id == parent.family_id:
			check(parent.handoff_ready, "matching parent shows ready check while carried")
		await press("grab")
	else:
		interaction.drop_held()
	await frames(2)

func run_checks() -> void:
	await setup_mart()
	var families: Node = mart.get_node("LostFamilies")
	await press("debug_spawn_lost_child")
	check(families.pairs.size() == 1, "L creates child and parent pair")
	if families.pairs.is_empty():
		quit(1)
		return
	var child: LostChild = families.pairs[0].child
	var parent: LostParent = families.pairs[0].parent
	check(child is CarryableCharacter and parent is BasicCustomer, "reuses character carry and basic customer base")
	check(child.family_id == parent.family_id and child.parent_npc == parent, "family identity connected")
	check(child.family_symbol.text == parent.family_symbol.text and child.family_symbol.modulate == parent.family_symbol.modulate, "matching color and shape on both characters")
	check(child.global_position.distance_to(parent.global_position) > 6, "pair spawns separated inside store")
	check(manager.queue.is_empty() and manager.customers.is_empty(), "event actors never join shopping manager or queue")
	var other: LostChild = families.spawn_pair()
	check(other != null and other.family_id != child.family_id, "second pair has unique family id")
	check(other.family_symbol.text != child.family_symbol.text, "simultaneous pairs have distinct symbols")
	check(families.spawn_pair() == null, "two event cap enforced")
	var idle := child.global_position
	await frames(120)
	check(child.global_position.distance_to(idle) < 0.5 and parent.state == BasicCustomer.State.EVENT_WAIT, "child cries in small area and parent waits without patience")
	player.global_position = Vector3(-3, 0.01, 4)
	await place(child, Vector3(-3, 0.6, 2.3))
	interaction.camera.look_at(child.global_position)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(3)
	await press("grab")
	check(interaction.held_object == child, "left click grabs lost child")
	check(child.get_collision_exceptions().has(player), "carry collision exception shared")
	await press("throw")
	check(interaction.held_object == child and not interaction.is_charging, "child cannot charge throw")
	check(child.carrier_speed_multiplier == 0.98, "child carrier multiplier 98 percent")
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	check(drunk != null and child.carrier_speed_multiplier > drunk.carrier_speed_multiplier, "child less restrictive than drunk carry")
	drunk.wander_speed = 0
	await place(drunk, Vector3(7, 0.8, 2)) # Keep the shared exit free in this route fixture.
	player.set_physics_process(true)
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	interaction.camera.rotation = Vector3.ZERO
	var before := player.global_position
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(player.global_position.distance_to(before) > 1 and interaction.held_object == child, "player moves normally while carrying child")
	player.set_physics_process(false)
	var wall_z := player.global_position.z - 3.0
	var carry_wall := Graybox.box(mart, "ChildCarryWall", Vector3(3, 3, 0.2), Vector3(player.global_position.x, 1.5, wall_z), Color.GRAY)
	player.global_position.z -= 0.9
	await frames(45)
	check(child.global_position.z > wall_z + 0.2 and child.linear_velocity.length() < 8, "child carry respects wall with bounded speed")
	carry_wall.queue_free()
	await frames(2)
	await press("grab")
	check(child.holder == null and child.gravity_scale == 1 and not child.reunited, "ordinary drop keeps event active")
	check(families.lost_children_found == 0 and manager.unpaid_loss == 0, "abandonment has no count or money penalty")
	await deliver(child, other.parent_npc)
	check(not child.reunited and families.lost_children_found == 0, "wrong parent drop rejected without deleting child")
	await deliver(child, parent, false)
	check(not child.reunited, "forced safety release is not a voluntary handoff")
	# A wall must block handoff even at a matching distance.
	var wall := Graybox.box(mart, "HandoffWall", Vector3(0.1, 3, 2), parent.global_position + Vector3(0.55, 1.5, 0), Color.GRAY)
	await frames(2)
	check(not families.can_reunite(child, parent), "handoff does not cross a wall")
	wall.queue_free()
	await frames(2)
	await deliver(child, parent)
	check(child.reunited and parent.reunited and families.lost_children_found == 1, "correct parent voluntary drop reunites once")
	check(not families.try_reunion(child) and families.lost_children_found == 1, "reunion cannot double count")
	check(child.get_node("Mood").text == "♥" and parent._mood.text == "♥", "reunion heart feedback on both")
	check(not child.begin_carry(interaction, player), "reunited child exits instead of restarting carry")
	player.global_position = Vector3(0, 0.01, 2)
	interaction.camera.look_at(parent.global_position + Vector3.UP)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p6_reunion.png")
	for tick in range(1500):
		await frames(1)
		if not is_instance_valid(child): break
	if is_instance_valid(child):
		print("EXIT DIAGNOSTIC child=", child.global_position, " sleeping=", child.sleeping, " grounded=", child.grounded, " parent=", parent.global_position, " state=", parent.state, " route=", parent.waypoints)
	check(not is_instance_valid(child) and not is_instance_valid(parent), "parent and child physically reach exit then despawn")
	check(families.pairs.size() == 1 and is_instance_valid(other), "other event remains active")
	# Drunk removal zone must never remove an unmatched child.
	await place(other, Vector3(-3, 0.6, 14))
	await frames(20)
	check(is_instance_valid(other) and families.lost_children_found == 1, "drunk exit removal ignores lost child")
	var cart: ShoppingCart = mart.get_node("Cart")
	player.global_position = Vector3(4, 0.01, 2)
	await place(cart, Vector3(0, 0.1, 2))
	await place(other, Vector3(0, 2, 2))
	other.begin_carry(interaction, player)
	other.end_carry()
	await frames(100)
	print("CHILD CART child=", other.global_position, " cart=", cart.global_position, " supported=", other.supported_by_cart)
	check(other.supported_by_cart, "child rests on physical cart floor without seat")
	before = other.global_position
	cart.apply_central_impulse(Vector3(0, 0, 30))
	await frames(60)
	check(other.global_position.z > before.z + 0.15 and other.global_position.distance_to(cart.global_position) < 2, "cart transports child without attachment")
	await deliver(other, other.parent_npc)
	check(other.reunited and families.lost_children_found == 2, "second family matches only its own parent")
	await place(cart, Vector3(0, 0.1, -3)) # Park the riding fixture away from the shopping aisle.
	var waiting: LostChild = families.spawn_pair()
	# Regular shopping/payment and delivery remain live while events exist.
	player.global_position = station.global_position + Vector3(0, 0.01, 1.25)
	var product := await stock("can")
	var buyer := manager.spawn_customer([&"can"])
	await wait_checkout(buyer)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await aim_action("scan")
	await frames(32)
	await aim_action("pay")
	check(manager.sales == 5 and not is_instance_valid(product) and is_instance_valid(drunk) and is_instance_valid(waiting) and not waiting.reunited, "checkout works alongside family and drunk systems")
	mart.get_node("Delivery").set_physics_process(true)
	await frames(330)
	check(mart.get_node("Products").get_child_count() > 0, "delivery continues during events")
	print("Prompt 6 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
