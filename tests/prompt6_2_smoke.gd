extends "res://tests/prompt1_smoke.gd"

func prepare_body(kind: String) -> RigidBody3D:
	await fresh_room()
	var body: RigidBody3D
	if kind == "product":
		body = fixtures.get_node("ObjectA")
	elif kind == "appliance":
		body = load("res://scenes/interactables/products/appliance.tscn").instantiate()
		main.add_child(body)
	else:
		body = load("res://scenes/interactables/%s.tscn" % kind).instantiate()
		main.add_child(body)
	await place(body, Vector3(0, 1.6, -1.5))
	body.begin_carry(interaction, player)
	interaction.held_object = body
	await frames(30)
	return body

func run_checks() -> void:
	for kind in ["product", "appliance", "drunk_customer", "lost_child"]:
		var body := await prepare_body(kind)
		check(interaction.held_object == body, kind + " held before rapid turn")
		for yaw in [90, -90, 180, 0]:
			player.rotation.y = deg_to_rad(yaw)
			await frames(8)
		check(interaction.held_object == body, kind + " open-space rapid 90/180 turns retain hold")
		await frames(50)
		# Player capsule fits here; the old camera-centered bounding sphere does not.
		var wall := Graybox.box(main.get_node("PrototypeTestRoom"), "CarryWall", Vector3(0.1, 3, 8), Vector3(-0.5, 1.5, 0), Color.GRAY)
		for yaw in [90, -90, 180, 0]:
			player.rotation.y = deg_to_rad(yaw)
			await frames(6)
		check(interaction.held_object == body and body.holder == interaction, kind + " retains hold through rapid turns beside wall")
		check(body.global_position.x > -0.5, kind + " cannot tunnel through wall")
		print("TURN ", kind, " held=", interaction.held_object == body, " distance=", body.global_position.distance_to(interaction.camera.global_position))
		wall.queue_free()
		await frames(70)
		check(interaction.held_object == body and body.global_position.distance_to(interaction.camera.global_position - interaction.camera.global_basis.z * interaction.hold_distance) < 0.25, kind + " recovers normal hold position after obstruction clears")
		# Actual shelf geometry at eye level tests corner movement and camera overlap.
		var shelf: StockShelf = load("res://scenes/interactables/stock_shelf.tscn").instantiate()
		shelf.position = Vector3(0, 0.8, 1.3)
		main.get_node("PrototypeTestRoom").add_child(shelf)
		player.rotation.y = PI
		await frames(45)
		check(interaction.held_object == body and interaction.hold_obstructed, kind + " shelf shortens safe hold without dropping")
		check(body.global_position.z < 0.65, kind + " stays on near side of solid shelf back")
		check((body.collision_mask & 1) == 1 and body.get_collision_exceptions().has(player), kind + " keeps world mask and player exception")
		shelf.queue_free()
		player.rotation.y = 0
		player.set_physics_process(true)
		Input.action_press("move_right")
		for yaw in [90, 180, -90, 0]:
			player.rotation.y = deg_to_rad(yaw)
			await frames(8)
		Input.action_release("move_right")
		player.set_physics_process(false)
		check(interaction.held_object == body, kind + " moving rapid turns retain hold")
		if body is CarryableCharacter:
			interaction.throw_held(1.0)
			check(interaction.held_object == body and not interaction.is_charging, kind + " character throw remains blocked")
		interaction.drop_held()
		check(body.holder == null and body.gravity_scale == 1.0, kind + " deliberate drop remains immediate")

	var body := await prepare_body("product")
	await place(body, interaction.camera.global_position + Vector3(6.5, 0, 0))
	body.freeze = true
	await frames(6)
	check(interaction.held_object == body and interaction.break_timer > 0, "brief hard separation starts grace without dropping")
	await place(body, interaction.camera.global_position + Vector3(0, 0, -1.5))
	await frames(20)
	check(interaction.held_object == body and interaction.break_timer == 0.0, "recovered separation clears grace timer")
	await place(body, interaction.camera.global_position + Vector3(6.5, 0, 0))
	body.freeze = true
	await frames(ceili(interaction.break_grace_time * 60) + 5)
	check(interaction.held_object == null and body.holder == null and body.gravity_scale == 1.0, "sustained hard separation safely drops after grace")
	body = await prepare_body("product")
	await place(body, interaction.camera.global_position + Vector3(4.5, 0, 0))
	body.freeze = true
	await frames(6)
	check(interaction.held_object == body, "warning distance alone never drops immediately")
	await frames(ceili(interaction.stalled_release_time * 60) + 5)
	check(interaction.held_object == null and body.holder == null, "long unrecoverable stall retains safety release")
	body = await prepare_body("product")
	body.queue_free()
	await frames(4)
	check(interaction.held_object == null and not interaction.is_charging and interaction.break_timer == 0.0, "deleted held node clears ownership and charge safely")
	print("Prompt 6.2 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
