extends "res://tests/prompt4_smoke.gd"

func make_spill(at: Vector3 = Vector3(0, 0.01, 2)) -> SpillZone:
	var system: AccidentManager = mart.get_node("Accidents")
	var zone := system.create_spill(at, [player.get_rid()])
	# Prompt 7 measures the underlying wet modifier independently of 7.1 falls.
	# Default core/activation and actual knockdowns are covered by prompt7_1.
	zone.activation_delay = 60.0
	return zone

func player_response(wet_floor: bool, turn: bool = false) -> Vector3:
	await setup_mart()
	if wet_floor: make_spill()
	player.global_position = Vector3(0, 0.01, 2)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(8)
	check(SlipState.wet(player) == wet_floor, "player detects floor wet=" + str(wet_floor))
	player.velocity = Vector3(0, 0, -5)
	var start := player.global_position
	if turn: Input.action_press("move_right")
	await frames(10 if turn else 30)
	Input.action_release("move_right")
	player.set_physics_process(false)
	return player.velocity if turn else player.global_position - start

func product_slide(wet_floor: bool) -> float:
	await setup_mart()
	if wet_floor: make_spill()
	var can: GrabbableBody = load("res://scenes/interactables/products/can.tscn").instantiate()
	mart.add_child(can)
	can.lock_rotation = true # Isolate sliding friction from random rolling orientation.
	await place(can, Vector3(0, 0.35, 2))
	await frames(30)
	check(SlipState.wet(can) == wet_floor, "physical can surface wet=" + str(wet_floor))
	var start := can.global_position
	can.apply_central_impulse(Vector3(2.8, 0, 0))
	await frames(45)
	return can.global_position.distance_to(start)

func run_checks() -> void:
	await setup_mart()
	check(InputMap.has_action("debug_spawn_accident"), "O debug action exists")
	var accidents: AccidentManager = mart.get_node("Accidents")
	await stock("can")
	await stock("watermelon")
	var customer: AccidentCustomer = accidents.spawn_accident([&"can", &"watermelon"])
	check(customer != null and customer is BasicCustomer, "accident scene reuses BasicCustomer")
	for tick in range(1400):
		await frames(1)
		if customer.accident_triggered: break
	check(customer.accident_triggered and accidents.spills_created == 1, "first shelf shopping triggers one spill")
	check(customer.picked_items.size() == 1 and customer.visited_types.size() == 1, "accident retains physical pickup and basket")
	check(customer._mood.text.contains(":O"), "brief embarrassment feedback")
	var spill: SpillZone
	for child in accidents.get_children():
		if child is SpillZone: spill = child
	check(spill != null and absf(spill.global_position.y) < 0.05, "spill lies on actual floor")
	check(spill.visual != null and spill.get_child(0) is CollisionShape3D, "spill has visible footprint and detection volume")
	await wait_checkout(customer)
	check(accidents.spills_created == 1 and is_instance_valid(spill), "no repeated accident or automatic cleanup")
	await aim_action("scan")
	await frames(32)
	await aim_action("scan")
	await frames(32)
	await aim_action("pay")
	check(manager.sales == 55 and customer.picked_items.is_empty(), "accident customer checkout preserves sales and basket consumption")
	await frames(500)
	check(not is_instance_valid(customer), "accident customer exits normally")
	# Debug cap uses the ordinary manager's spawn/reservation path.
	await stock("can")
	await press("debug_spawn_accident")
	check(manager.customers.size() == 1 and manager.customers[0] is AccidentCustomer, "O actually spawns accident customer")
	manager.customers[0].global_position = Vector3(-7, 0.01, 9)
	var second: AccidentCustomer = accidents.spawn_accident([&"can"])
	check(second != null and accidents.spawn_accident() == null, "two active accident limit")

	await setup_mart()
	accidents = mart.get_node("Accidents")
	spill = make_spill()
	var overlap := make_spill()
	var can: GrabbableBody = load("res://scenes/interactables/products/can.tscn").instantiate()
	mart.add_child(can)
	var original := can.physics_material_override
	var original_damp := can.linear_damp
	await place(can, Vector3(0, 0.3, 2))
	await frames(30)
	check(is_equal_approx(SlipState.control(can), 0.3), "overlapping spills do not stack strength")
	check(can.physics_material_override != original and can.physics_material_override.friction <= 0.04, "per-body wet material lowers friction")
	check(original.friction > 0.04, "shared dry material is not mutated")
	spill.queue_free()
	await frames(4)
	check(SlipState.wet(can), "leaving one overlapping source preserves slip")
	overlap.clean(1)
	await frames(4)
	check(not SlipState.wet(can) and can.physics_material_override == original and is_equal_approx(can.linear_damp, original_damp), "last source cleanup restores exact dry settings")
	check(accidents.spills_created == 2 and accidents.spills_cleaned == 1, "created and cleaned count separately and once")

	var dry_stop := await player_response(false)
	var wet_stop := await player_response(true)
	check(wet_stop.length() > dry_stop.length() * 1.4, "wet player braking distance increases")
	var dry_turn := await player_response(false, true)
	var wet_turn := await player_response(true, true)
	check(wet_turn.x > 0 and absf(wet_turn.z) > absf(dry_turn.z) + 0.5, "wet player can steer while retaining old momentum")
	player.global_position = Vector3(5, 0.01, 2)
	await frames(5)
	check(not SlipState.wet(player), "player leaving spill restores dry state")
	var dry_slide := await product_slide(false)
	var wet_slide := await product_slide(true)
	print("SLIP MEASURE player dry=", dry_stop.length(), " wet=", wet_stop.length(), " can dry=", dry_slide, " wet=", wet_slide)
	check(wet_slide > dry_slide + 0.2, "1kg product slides farther on spill with equal impulse")

	await setup_mart()
	var cart: ShoppingCart = mart.get_node("Cart")
	var dry_brake := cart.braking_acceleration()
	var dry_steer := cart.steering_acceleration()
	var dry_drive := cart.push_acceleration()
	spill = make_spill()
	await place(cart, Vector3(0, 0.1, 2))
	await frames(30)
	check(SlipState.wet(cart), "cart wheels contact slippery floor")
	check(cart.braking_acceleration() < dry_brake and cart.steering_acceleration() < dry_steer, "wet cart reduces brake and steering assistance")
	check(cart.push_acceleration() >= dry_drive * 0.8, "wet cart retains responsive forward acceleration")
	var cart_start := cart.global_position
	cart.apply_central_impulse(Vector3(0, 0, -24))
	await frames(25)
	check(cart.global_position.distance_to(cart_start) > 0.4, "unheld cart rolls physically across spill")
	spill.queue_free()
	await frames(4)
	check(is_equal_approx(cart.braking_acceleration(), dry_brake), "dry cart tuning restored")
	# The same area state reaches physical drunk and non-shopping event parent.
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	spill = make_spill(Vector3(4, 0.01, 2))
	await place(drunk, Vector3(4, 0.8, 2))
	await frames(15)
	check(SlipState.wet(drunk) and drunk.wet_wobble_multiplier > 1 and drunk.linear_velocity.length() > 0.1, "drunk moves with reduced control and larger sway")
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	var family_spills: AccidentManager = mart.get_node("Accidents")
	family_spills.create_spill(child.parent_npc.global_position, [child.parent_npc.get_rid(), player.get_rid()]).activation_delay = 60.0
	await frames(8)
	check(SlipState.wet(child.parent_npc), "Lost Parent receives shared floor modifier")
	var parent := child.parent_npc
	var peak_npc_speed := 0.0
	for tick in range(30):
		# Exercise the existing cart reaction velocity repeatedly on wet ground.
		parent._push = Vector3(2, 0, 0)
		await frames(1)
		peak_npc_speed = maxf(peak_npc_speed, Vector2(parent.velocity.x, parent.velocity.z).length())
	check(peak_npc_speed > 0.1 and peak_npc_speed < 2.1, "wet NPC push responds without repeatedly accumulating velocity")

	await setup_mart()
	accidents = mart.get_node("Accidents")
	spill = make_spill(Vector3(0, 0.01, 2.6))
	var mop: Mop = mart.get_node("Mop")
	player.global_position = Vector3(0, 0.01, 3)
	await place(mop, Vector3(0, 1.6, 1.5))
	await press("grab")
	check(interaction.held_object == mop, "mop uses ordinary ray grab")
	await frames(30)
	check(spill.clean_progress == 0, "airborne mop does not clean below it")
	player.rotation.y = PI
	await frames(8)
	player.rotation.y = 0
	await frames(30)
	check(interaction.held_object == mop, "compound mop retains rapid-turn hold")
	interaction.camera.rotation.x = deg_to_rad(-65)
	await frames(80)
	check(mop.get_node("CleaningHead").get_overlapping_areas().has(spill), "held mop head reaches spill through normal hold control")
	root.get_texture().get_image().save_png("res://.godot/p7_mop.png")
	var resting_progress := spill.clean_progress
	await frames(70)
	check(absf(spill.clean_progress - resting_progress) < 0.02, "stationary held mop does not clean")
	var ticks := 0
	var shrinking := false
	while is_instance_valid(spill) and ticks < 240:
		# Sweep the held tool across the visible puddle, without walking away
		# from its shrinking footprint. Normal physics hold drives the head.
		player.rotation.y = sin(ticks / 60.0 * TAU * 1.5) * 0.8
		await frames(1)
		ticks += 1
		if is_instance_valid(spill) and spill.visual.scale.x < 0.95: shrinking = true
	player.rotation.y = 0
	player.set_physics_process(false)
	check(shrinking, "actual mop strokes shrink visible spill")
	check(not is_instance_valid(spill) and accidents.spills_cleaned == 1, "active physical mop strokes remove spill and count once")
	print("MOP cleaning active seconds=", ticks / 60.0, " head=", mop.get_node("CleaningHead").global_position)
	await frames(5)
	check(not SlipState.wet(player), "cleaning removes player slip modifier")
	await press("grab")
	check(mop.holder == null and mop.gravity_scale == 1, "mop drops as a physical body")
	check(mop.product_type == &"" and not manager.available_goods().has(mop), "mop is not a sale product")
	# Free tool stays wherever it lands, with real head contact pushing a can.
	player.global_position = Vector3(5, 0.01, 11.25)
	# Isolate head contact from a free upright handle toppling away first.
	mop.lock_rotation = true
	await place(mop, Vector3(-0.5, 0.85, 2))
	can = load("res://scenes/interactables/products/can.tscn").instantiate()
	mart.add_child(can)
	await place(can, Vector3(0, 0.2, 2))
	var can_start := can.global_position
	mop.apply_central_impulse(Vector3(8, 0, 0))
	await frames(45)
	check(can.global_position.distance_to(can_start) > 0.1, "mop head physically pushes product")
	mop.lock_rotation = false
	player.global_position = Vector3(0, 0.01, 3)
	interaction.camera.rotation = Vector3.ZERO
	await place(mop, Vector3(0, 1.6, 1.5))
	await press("grab")
	await press("throw")
	check(mop.holder == null and mop.linear_velocity.length() > 2, "mop uses ordinary charge throw")
	print("Prompt 7 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
