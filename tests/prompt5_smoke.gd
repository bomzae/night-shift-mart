extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var drunks := mart.get_node("Drunks")
	await press("debug_spawn_drunk")
	var drunk: DrunkCustomer
	for child in drunks.get_children():
		if child is DrunkCustomer:
			drunk = child
	check(drunk != null, "debug action spawns drunk at entrance")
	if drunk == null:
		quit(1)
		return
	var start := drunk.global_position
	await frames(180)
	print("WANDER displacement=", drunk.global_position.distance_to(start), " grounded=", drunk.grounded)
	check(drunk.global_position.distance_to(start) > 0.5, "drunk wanders physically")
	check(drunk.direction_changes >= 2, "wander direction changes")
	check(manager.queue.is_empty() and manager.customers.is_empty(), "drunk never joins checkout")
	player.global_position = Vector3(-3, 0.01, 4)
	await place(drunk, Vector3(-3, 0.8, 2.3))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interaction.camera.look_at(drunk.global_position)
	await frames(3)
	await press("grab")
	check(interaction.held_object == drunk, "ray-selected left click carries character")
	check(drunk.get_collision_exceptions().has(player), "carrier collision exception")
	var changes := drunk.direction_changes
	await press("throw")
	check(interaction.held_object == drunk and not interaction.is_charging, "right click cannot charge or throw character")
	await frames(130)
	check(drunk.direction_changes == changes and drunk.gravity_scale == 0, "AI pauses during carry")
	player.set_physics_process(true)
	player.rotation = Vector3.ZERO
	interaction.camera.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	var player_start := player.global_position
	Input.action_press("move_forward")
	await frames(40)
	Input.action_release("move_forward")
	check(player.global_position.distance_to(player_start) > 1, "player walks while carrying")
	check(player.velocity.length() <= 4.4, "character carry applies 85 percent speed")
	check(interaction.held_object == drunk, "carry follows player without breaking")
	player.set_physics_process(false)
	# A carried capsule must still be blocked by real geometry.
	Graybox.box(mart, "CarryTestWall", Vector3(3, 3, 0.2), Vector3(-3, 1.5, -1.2), Color.GRAY)
	await frames(3)
	player.global_position = Vector3(-3, 0.01, -0.1)
	interaction.camera.rotation = Vector3.ZERO
	await frames(75)
	check(drunk.global_position.z > -1.2 and drunk.linear_velocity.length() < 8, "held character stays on near side of wall with bounded speed")
	mart.get_node("CarryTestWall").queue_free()
	await press("grab")
	check(drunk.holder == null and drunk.gravity_scale == 1, "left click drops and restores gravity")
	player.global_position.x += 2
	await frames(150)
	check(drunk.direction_changes > changes, "drunk behavior resumes after drop")
	check(not drunk.get_collision_exceptions().has(player), "drop restores collision after separation")

	# Real shelf collision: low speed shakes goods, never instant-breaks them.
	# Keep the already-tested wandering actor clear while this fixture settles;
	# the intentional shelf collision begins at the explicit placement below.
	await place(drunk, Vector3(7, 0.8, 2))
	var can := await stock("can", Vector3(0, 0, 0.5))
	var shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	var can_start := can.global_position
	await place(drunk, shelf.global_position + Vector3(0, 0.76, -2.1))
	drunk.wander_direction = Vector3.BACK
	drunk._direction_wait = 20
	await frames(90)
	check(is_instance_valid(can), "gentle shelf contact does not destroy product")
	print("SHELF displacement=", can.global_position.distance_to(can_start), " drunk=", drunk.global_position)
	check(can.global_position.distance_to(can_start) > 0.05 or not shelf.has_stock(can), "shelf contact disturbs real stock")
	# High-speed body collision is one break/value event, not resting damage.
	var product: GrabbableBody = load("res://scenes/interactables/products/appliance.tscn").instantiate()
	mart.add_child(product)
	await place(product, Vector3(2, 0.5, 3))
	await place(drunk, Vector3(2, 0.8, 1))
	drunk._contact_wait = 0
	drunk.wander_acceleration = 0
	drunk.linear_velocity = Vector3(0, 0, 7)
	await frames(45)
	check(not is_instance_valid(product) and drunks.broken_product_value == 500, "strong physical impact breaks once at product price")
	await frames(60)
	check(drunks.broken_product_value == 500, "no repeated breakage from resting contacts")

	# Carry through real entrance; removal also releases interaction safely.
	await place(drunk, Vector3(-3, 0.8, 34.5))
	player.global_position = Vector3(-3, 0.01, 32.8)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	interaction.camera.look_at(drunk.global_position)
	await frames(3)
	print("REGRAB candidate=", interaction.find_candidate(), " drunk=", drunk.global_position, " camera=", interaction.camera.global_position)
	await press("grab")
	check(interaction.held_object == drunk, "character can be picked up again")
	player.rotation.y = PI
	player.get_node("Head").rotation = Vector3.ZERO
	interaction.camera.rotation = Vector3.ZERO
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(85)
	Input.action_release("move_forward")
	player.set_physics_process(false)
	check(not is_instance_valid(drunk) and drunks.drunks_removed == 1, "carry through actual doorway removes drunk once")
	check(not is_instance_valid(interaction.held_object), "removal safely clears held reference")
	player.global_position = Vector3(0, 0.01, 2)
	await frames(5)
	drunk = drunks.spawn_drunk()
	check(drunk != null, "spawn again after removal")
	if drunk == null:
		quit(1)
		return
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(-3, 0.1, 33.5))
	await place(drunk, Vector3(-3, 2.2, 33.5))
	# Begin/end carry uses the same physical drop path without a seat.
	drunk.begin_carry(interaction, player)
	drunk.end_carry()
	await frames(100)
	check(drunk.supported_by_cart, "dropped character physically rests on cart")
	check(drunk.global_position.distance_to(cart.global_position) < 1.8, "rider remains inside without attachment")
	var rider_start := drunk.global_position
	cart.apply_central_impulse(Vector3(0, 0, 30))
	await frames(60)
	print("RIDER displacement=", drunk.global_position - rider_start)
	check(drunk.global_position.z > rider_start.z + 0.15, "cart transports physical rider")
	cart.launch_cart(Vector3.BACK, 1.5, 1, interaction)
	await frames(120)
	check(not is_instance_valid(drunk) and drunks.drunks_removed == 2, "cart launch delivery reaches removal zone")
	# Business continues in presence of a separate drunk.
	player.global_position = station.global_position + Vector3(0, 0.01, 1.25)
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	interaction.camera.rotation = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	drunk = drunks.spawn_drunk()
	if drunk != null:
		await place(drunk, Vector3(7, 0.8, 2))
		# This fixture tests checkout coexistence, not random stock interference.
		# Walking/contact are checked above; Prompt 5.2 tests contact-driven OOS.
		drunk.wander_speed = 0
		drunk.linear_velocity = Vector3.ZERO
	if is_instance_valid(can):
		can.queue_free()
	await frames(2)
	var sale_can := await stock("can", Vector3(-0.8, 0, 0))
	var customer := manager.spawn_customer([&"can"])
	await wait_checkout(customer)
	await aim_action("scan")
	await frames(32)
	await aim_action("pay")
	check(manager.sales == 5 and not is_instance_valid(sale_can) and is_instance_valid(drunk), "normal checkout continues alongside drunk")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p5_checkout.png")
	print("Prompt 5 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
