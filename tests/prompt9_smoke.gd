extends "res://tests/prompt8_smoke.gd"
var thieves: ThiefManager

func setup_thief() -> void:
	await fire_setup()
	thieves = mart.get_node("Thieves")
	player.global_position = Vector3(5, 0.01, 11.25)

func wait_theft(thief: ThiefCustomer) -> void:
	for tick in range(1400):
		await frames(1)
		if not is_instance_valid(thief) or thief.theft_state == ThiefCustomer.TheftState.ESCAPING: break
	check(is_instance_valid(thief) and thief.theft_state == ThiefCustomer.TheftState.ESCAPING, "thief walks to real shelf and steals")

func contact_fixture() -> ThiefCustomer:
	await setup_thief()
	await stock("can")
	await place(mart.get_node("Cart"), Vector3(6, 0.05, -3))
	var thief := thieves.spawn_thief()
	# The full entrance route is tested above; isolate contacts after a real pickup.
	thief.global_position = thief.waypoints.back()
	thief.waypoints.clear()
	await frames(45)
	check(thief.capturable(), "prepare physical contact fixture with real stolen stock")
	thief.global_position = Vector3(0, 0.01, -1)
	thief.waypoints = [Vector3(0, 0.01, -4)]
	thief.move_speed = 0
	await frames(5)
	return thief

func run_checks() -> void:
	await setup_thief()
	check(InputMap.has_action("debug_spawn_thief"), "T debug action exists")
	check(thieves.stock_candidates().is_empty(), "no fabricated target in empty store")
	await press("debug_spawn_thief")
	var thief: ThiefCustomer = thieves.get_children().filter(func(n): return n is ThiefCustomer)[0]
	check(thief.theft_state == ThiefCustomer.TheftState.LEAVING and thief.stolen_item.is_empty(), "empty-stock thief leaves without theft")
	await frames(200)
	check(not is_instance_valid(thief) and thieves.stolen_goods_value == 0, "empty exit creates no loss")

	await setup_thief()
	var product := await stock("appliance")
	product.price = 537
	product.weight = 7.5
	product.carry_radius = 0.57
	product.flammable = false
	var source_id := product.get_instance_id()
	var reserved := manager.spawn_customer([&"appliance"])
	reserved.global_position = Vector3(5, 0.01, 7)
	reserved.set_physics_process(false)
	await frames(3)
	await press("debug_spawn_thief")
	thief = thieves.get_children().filter(func(n): return n is ThiefCustomer)[0]
	check(thief.target_product == product and not manager.spawning_enabled, "T while OFF selects actual reserved stock")
	check(not manager.customers.has(thief) and not manager.queue.has(thief), "thief never enters customer queue")
	await wait_theft(thief)
	check(not is_instance_valid(product) and mart.get_node("Shelves/ApplianceShelf").stock_count == 0, "theft removes physical product and immediate stock")
	check(thief.stolen_item.source_id == source_id and thief.stolen_item.price == 537 and thief.stolen_item.weight == 7.5, "loot preserves original identity price and weight")
	check(thief.loot_icon.visible and thief._mood.text == "!!", "escaping thief shows goods and alert")
	var camera_pose: Transform3D = interaction.camera.transform
	interaction.camera.global_position = thief.global_position + Vector3(2, 2, 3)
	interaction.camera.look_at(thief.global_position + Vector3.UP * 1.4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p9_theft.png")
	interaction.camera.transform = camera_pose
	check(thief.move_speed > 2.2 and thief.move_speed < player.move_speed, "escape is faster than customer and catchable by player")
	reserved.set_physics_process(true)
	await frames(2)
	check(reserved.state == BasicCustomer.State.DISAPPOINTED and manager.sales == 0 and manager.unpaid_loss == 0, "reservation theft uses existing out-of-stock without billing")
	thief.set_physics_process(false)
	player.global_position = thief.global_position + Vector3(0, 0, 3)
	check(not thief.capture(player), "capture rejects excessive distance")
	player.global_position = thief.global_position + Vector3(0, 0, 1.3)
	interaction.camera.look_at(thief.global_position + Vector3.UP)
	await frames(2)
	check(interaction.find_candidate() == thief, "ordinary grab ray identifies escaping thief")
	await press("grab")
	check(thieves.thieves_caught == 1 and thief.theft_state == ThiefCustomer.TheftState.CAPTURED, "left click captures immediately")
	check(not is_instance_valid(interaction.held_object) and thief._mood.text == "✓" and not thief.loot_icon.visible, "capture is resolution not character carry")
	check(not thief.capture(player) and thieves.thieves_caught == 1 and thieves.stolen_goods_value == 0, "capture cannot duplicate reward or loss")
	var recovered := thieves.last_recovered
	check(is_instance_valid(recovered) and recovered.product_type == &"appliance" and recovered.price == 537 and recovered.weight == 7.5, "recovery spawns original product data")
	check(is_equal_approx(recovered.carry_radius, 0.57) and not recovered.flammable and recovered.mass == 7.5, "recovery preserves exported grabbable settings")
	check(recovered.get_instance_id() != source_id and not recovered.get_meta("stolen", false), "recovery is a fresh interactable physical instance")
	thief.set_physics_process(true)
	await frames(50)
	check(not is_instance_valid(thief), "captured thief cleans up after short feedback")
	player.global_position = Vector3(0, 0.01, 3)
	await place(recovered, Vector3(0, 1.4, 1.6))
	interaction.camera.look_at(recovered.global_position)
	await press("grab")
	check(interaction.held_object == recovered, "recovered goods can be grabbed")
	await press("throw")
	check(recovered.linear_velocity.length() > 1 and not is_instance_valid(interaction.held_object), "recovered goods charge throw")
	await place(recovered, mart.get_node("Shelves/ApplianceShelf").to_global(Vector3(0, 1, 0)))
	await frames(120)
	check(mart.get_node("Shelves/ApplianceShelf").has_stock(recovered), "recovered goods restock normally")
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(recovered, cart.global_position + Vector3.UP * 1.2)
	await frames(100)
	check(cart.loaded_weight >= 7.4, "recovered goods load into physical cart")

	await setup_thief()
	await stock("can")
	thief = thieves.spawn_thief()
	await wait_theft(thief)
	for tick in range(1200):
		await frames(1)
		if not is_instance_valid(thief): break
	check(not is_instance_valid(thief) and thieves.stolen_goods_value == 5, "outside escape records stolen price")
	await frames(90)
	check(thieves.stolen_goods_value == 5 and manager.unpaid_loss == 0 and fire_manager.fire_damage_value == 0, "escaped loot loss counted only once")

	await setup_thief()
	product = await stock("watermelon")
	thief = thieves.spawn_thief()
	product.queue_free()
	await frames(3)
	check(thief.theft_state == ThiefCustomer.TheftState.LEAVING and thief.stolen_item.is_empty(), "missing target exits without fake loot")
	check(thieves.stolen_goods_value == 0, "target lost before theft has no stolen loss")

	await setup_thief()
	await stock("can")
	thief = thieves.spawn_thief()
	thief.global_position = Vector3(-6, 0.01, 9)
	await frames(3)
	var second := thieves.spawn_thief()
	check(second != null and thieves.spawn_thief() == null, "debug thieves bounded to two")
	second.queue_free()
	await wait_theft(thief)
	thief.global_position = Vector3(0, 0.01, 2)
	thief.waypoints = [Vector3(0, 0.01, -2), thieves.escape_position()]
	var accidents: AccidentManager = mart.get_node("Accidents")
	var zone := accidents.create_spill(thief.global_position, [thief.get_rid()])
	await frames(25)
	thief.global_position = Vector3(0, 0.01, 2)
	thief.velocity = Vector3(0, 0, -3.8)
	for tick in range(10):
		await frames(1)
		if thief.knockdown.active(): break
	check(thief.knockdown.active() and thief.capturable(), "escaping thief slips and remains capturable")
	zone.clean(1)
	await frames(110)
	check(not thief.knockdown.active() and thief.theft_state == ThiefCustomer.TheftState.ESCAPING, "spill recovery preserves escape")
	thief.global_position = Vector3(0, 0.01, -1)
	thief.waypoints = [Vector3(0, 0.01, 3), thieves.escape_position()]
	var fire := fire_manager.create_fire(thief.global_position, [thief.get_rid()])
	await frames(10)
	check(thief.fire_reaction.active() and thief.capturable(), "thief uses shared fire panic")
	fire.suppress(2)
	await frames(50)
	check(not thief.fire_reaction.active() and thief.theft_state == ThiefCustomer.TheftState.ESCAPING and not thief.stolen_item.is_empty(), "fire recovery keeps stolen loot and escape")

	thief = await contact_fixture()
	player.global_position = Vector3(0, 0.01, 3)
	await grab_tool()
	interaction.camera.look_at(thief.global_position + Vector3.UP)
	var before := thief.global_position
	Input.action_press("use_tool")
	await frames(40)
	Input.action_release("use_tool")
	print("THIEF SPRAY displacement=", thief.global_position.distance_to(before))
	check(thief.global_position.distance_to(before) > 0.05 and thief._push.length() > 0, "actual extinguisher spray pushes thief")
	check(thief.capturable() and thieves.thieves_caught == 0 and not thief.knockdown.active(), "spray does not auto-capture or stun")
	interaction.drop_held()
	thief.move_speed = thief.escape_speed
	await frames(8)
	print("SPRAY RECOVERY position=", thief.global_position, " velocity=", thief.velocity, " route=", thief.waypoints, " contacts=", thief.get_slide_collision_count())
	for i in range(thief.get_slide_collision_count()): print("RECOVERY collider=", thief.get_slide_collision(i).get_collider())
	check(thief.velocity.z < -1, "escape motor resumes after spray")

	thief = await contact_fixture()
	var mop: GrabbableBody = preload("res://scenes/interactables/mop.tscn").instantiate()
	mart.add_child(mop)
	await place(mop, Vector3(0, 1.1, 0.2))
	before = thief.global_position
	mop.linear_velocity = Vector3(0, 0, -4)
	await frames(25)
	print("THIEF MOP displacement=", thief.global_position.distance_to(before))
	check(thief.global_position.distance_to(before) > 0.03 and thief.capturable(), "moving physical mop pushes without capture")

	thief = await contact_fixture()
	cart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 1.0))
	before = thief.global_position
	cart.linear_velocity = Vector3(0, 0, -3)
	await frames(40)
	print("THIEF CART displacement=", thief.global_position.distance_to(before))
	check(thief.global_position.distance_to(before) > 0.05 and thief.capturable() and thieves.thieves_caught == 0, "physical cart contact pushes without auto-capture")

	thief = await contact_fixture()
	player.global_position = Vector3(0, 0.01, 0.4)
	player.rotation = Vector3.ZERO
	player.set_physics_process(true)
	before = thief.global_position
	Input.action_press("move_forward")
	await frames(45)
	Input.action_release("move_forward")
	check(thief.global_position.distance_to(before) > 0.05 and thieves.thieves_caught == 0, "player body push is not automatic capture")
	player.set_physics_process(false)
	thief.set_physics_process(false)
	thief.knockdown.try_start(Vector3.FORWARD)
	player.global_position = thief.global_position + Vector3(0, 0, 1.3)
	interaction.camera.look_at(thief.global_position + Vector3.UP)
	var wall := Graybox.box(mart, "CaptureWall", Vector3(2, 2.5, 0.1), thief.global_position + Vector3(0, 1.25, 0.6), Color.GRAY)
	await frames(2)
	await press("grab")
	check(thieves.thieves_caught == 0, "capture cannot pass through a wall")
	wall.queue_free()
	await frames(2)
	await press("grab")
	check(thieves.thieves_caught == 1, "fallen thief can be captured by actual grab")

	await setup_thief()
	product = await stock("can")
	thief = thieves.spawn_thief()
	thief.global_position = Vector3(-6, 0.01, 8)
	await frames(3)
	second = thieves.spawn_thief()
	check(second != null and thief.target_product == second.target_product, "two thieves may target the same real stock")
	thief.global_position = thief.waypoints.back()
	thief.waypoints.clear()
	await frames(45)
	await frames(2)
	check(thief.stolen_item.size() > 0 and second.stolen_item.is_empty() and second.theft_state == ThiefCustomer.TheftState.LEAVING, "only first thief owns stock and second aborts without duplication")
	var families = mart.get_node("LostFamilies")
	var child: LostChild = families.spawn_pair()
	await place(child, child.parent_npc.global_position + Vector3(0.7, 0.6, 0))
	check(families.try_reunion(child), "family resolves alongside thief")
	await frames(2)
	check(thief.get_collision_exceptions().has(child) and child.get_collision_exceptions().has(thief), "departing family exception includes preexisting thief")
	print("Prompt 9 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
