extends "res://tests/prompt2_smoke.gd"

func handling_trial(heavy: bool) -> void:
	await setup_cart()
	if heavy:
		await load_items(["ObjectB", "ObjectE"])
	await aim_handle()
	await press("grab")
	await frames(30)
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(2)
	var initial_speed := Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length()
	check(initial_speed > 0.1, "immediate empty/loaded movement")
	await frames(16)
	var speed := Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length()
	check(speed > 4.5, "empty/loaded reaches walking speed within 0.3s")
	print("HANDLING heavy=", heavy, " first_speed=", initial_speed, " speed_0.3s=", speed, " acceleration=", cart.push_acceleration())
	for degrees in [30, -45, 90]:
		player.rotate_y(deg_to_rad(degrees))
		await frames(30)
		var facing := -cart.global_basis.z
		facing.y = 0
		var forward := -player.global_basis.z
		var error := rad_to_deg(absf(facing.normalized().signed_angle_to(forward, Vector3.UP)))
		print("TURN heavy=", heavy, " degrees=", degrees, " error_after_0.5s=", error)
		check(error < 15, "moving 30/45/90 degree turn aligns within 0.5s")
		check(interaction.held_object == cart, "fast turns keep grab")
	Input.action_release("move_forward")
	await frames(60)
	print("STOP heavy=", heavy, " speed_after_1s=", Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length())
	check(Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length() < 0.5, "release input settles held cart within 1s after rapid turns")
	check(cart.global_basis.y.dot(Vector3.UP) > 0.8, "rapid normal turns do not overturn cart")
	check(cart.launch_speed(1.5) > cart.max_push_speed * 1.5, "full launch remains distinct from normal drive")

func run_checks() -> void:
	await handling_trial(false)
	await handling_trial(true)
	var loaded_accel := cart.push_acceleration()
	check(loaded_accel > 576.0 / 12.0 * 0.75, "16kg load retains over 75 percent acceleration")
	check(cart.steering_acceleration() > 96.0 / 28.0 * 5, "loaded steering acceleration exceeds old baseline")
	check(cart.damage_at_speed(8) > 8 * 12 * cart.impact_damage_multiplier, "loaded impact mass advantage unchanged")
	check(cart.braking_acceleration() < cart.braking_strength / cart.cart_base_mass, "load reduces braking acceleration")
	interaction.drop_held()
	main.free()
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(30)
	var mart: Node3D = main.get_node("MartGraybox")
	var mart_cart: ShoppingCart = mart.get_node("Cart")
	check(mart.has_node("Backroom") and mart.has_node("LoadingArea"), "Main opens connected delivery/backroom")
	check(absf(mart_cart.position.x) < 0.1 and absf(mart_cart.position.z) < 4, "loading cart aligned with main aisle less than 4m from door")
	# Sweep the whole chassis envelope down the straight work route at floor height.
	var query := PhysicsShapeQueryParameters3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.0, 1.5, 2.2)
	query.shape = bounds
	query.transform.origin = Vector3(0, 0.9, -3)
	query.motion = Vector3(0, 0, 6)
	query.exclude = [mart_cart.get_rid(), mart.get_node("Player").get_rid()]
	var result := mart.get_world_3d().direct_space_state.cast_motion(query)
	check(result[0] > 0.99, "cart-sized straight route has no wall/corner obstruction")
	print("Prompt 3.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
