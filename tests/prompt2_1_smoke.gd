extends "res://tests/prompt2_smoke.gd"


func drive_trial(heavy: bool) -> float:
	await setup_cart()
	zone.get_node("CartTarget").queue_free()
	if heavy:
		await load_items(["ObjectB", "ObjectE"])
	await aim_handle()
	await press("grab")
	await frames(30)
	check(cart.get_collision_exceptions().has(player) and player.get_collision_exceptions().has(cart), "held pair collision exception")
	check(cart.collision_mask == 1, "world collision mask preserved")
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(1)
	# Physics integration publishes the submitted velocity on the next tick.
	check(cart.drive_velocity.z < 0, "movement intent submitted in first input tick")
	await frames(1)
	var response := -cart.linear_velocity.z
	check(response > 0.01, "empty/heavy starts moving without a response timer")
	await frames(140)
	check(interaction.held_object == cart, "long straight push keeps grab")
	Input.action_release("move_forward")
	Input.action_press("move_backward")
	await frames(90)
	check(interaction.held_object == cart, "reverse keeps grab")
	Input.action_release("move_backward")
	Input.action_press("move_forward")
	for step in range(90):
		player.rotate_y(0.012)
		await frames(1)
	Input.action_release("move_forward")
	check(interaction.held_object == cart, "moving turn keeps grab")
	await frames(30)
	interaction.drop_held()
	check(not cart.get_collision_exceptions().has(player) and not player.get_collision_exceptions().has(cart), "drop restores pair collision")
	print("RESPONSE heavy=", heavy, " speed=", response)
	return response


func body_push_trial(name: String) -> float:
	await setup_cart()
	var body: RigidBody3D = cart if name == "Cart" else fixtures.get_node(name)
	if body != cart:
		await place(cart, Vector3(-7, 0.05, 5))
	await place(body, Vector3(7, 0.4 if name != "Cart" else 0.05, 3))
	await frames(30)
	player.global_position = Vector3(7, 0.01, 5.5)
	player.rotation = Vector3.ZERO
	player.set_physics_process(true)
	var start := body.global_position
	Input.action_press("move_forward")
	await frames(65)
	Input.action_release("move_forward")
	var distance := start.z - body.global_position.z
	check(distance > 0.02, "body walking pushes " + name)
	print("PUSH ", name, " distance=", distance)
	return distance


func run_checks() -> void:
	var empty := await drive_trial(false)
	var heavy := await drive_trial(true)
	check(empty > heavy, "loaded acceleration lower, both respond immediately")
	await setup_cart()
	await place(cart, Vector3(7, 0.05, -29))
	await aim_handle()
	await press("grab")
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(180)
	Input.action_release("move_forward")
	check(cart.global_position.z > -33.3, "held cart cannot drive through end wall")
	check(interaction.held_object == cart, "blocked cart does not break grab")
	check(player.global_position.distance_to(cart.global_position) > 1.65, "virtual handle prevents player entering blocked chassis")
	interaction.drop_held()
	check(not player.get_collision_exceptions().has(cart), "blocked release restores collision immediately")
	var light_push := await body_push_trial("ObjectA")
	var heavy_push := await body_push_trial("ObjectB")
	check(light_push > heavy_push, "1kg moves farther than 8kg")
	await body_push_trial("Cart")
	await setup_cart()
	await aim_handle()
	await press("grab")
	await charge_launch(80)
	check(not cart.get_collision_exceptions().has(player) and not player.get_collision_exceptions().has(cart), "launch restores collision")
	check(cart.linear_velocity.z < -10, "full charge launch still forward")
	# Existing held-product exception is also retained, with no push injection.
	await fresh_room()
	var product: GrabbableBody = fixtures.get_node("ObjectA")
	await place(product, Vector3(0, 1.6, -2))
	await press("grab")
	check(interaction.held_object == product and product.get_collision_exceptions().has(player), "held product keeps player collision exception")
	print("Prompt 2.1 failures: ", failures)
	quit(0 if failures == 0 else 1)
