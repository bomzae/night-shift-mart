extends "res://tests/prompt11_5_cargo_probe.gd"

func pan_trial(kind: String) -> Dictionary:
	await setup_thief()
	player.position = Vector3(10, 0.01, -3)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.02, 10))
	var pan: GrabbableBody = load(ProductCatalog.find(&"frying_pan").scene_path).instantiate()
	mart.add_child(pan)
	pan.position = cart.to_global(Vector3(0, 0.51, 0))
	if kind == "tilt": pan.rotation.z = 0.15
	if kind in ["can", "watermelon", "stack"]:
		var type: StringName = &"frying_pan" if kind == "stack" else StringName(kind)
		var other: GrabbableBody = load(ProductCatalog.find(type).scene_path).instantiate()
		mart.add_child(other)
		other.position = cart.to_global(Vector3(0, 0.62 + other.definition.size.y / 2, 0))
	await frames(120)
	var sums := Vector3.ZERO
	var contacts := 0.0
	var sleeps := 0
	var contact_points := 0.0
	var shape_ids := {}
	var support_frames := 0
	var max_displacement := 0.0
	var start := pan.position
	for i in range(300):
		await frames(1)
		sums += Vector3(pan.linear_velocity.length(), absf(pan.linear_velocity.y), pan.angular_velocity.length())
		contacts += pan.get_colliding_bodies().size()
		sleeps += int(pan.sleeping)
		if pan.cargo_support_time >= 0.35: support_frames += 1
		var direct := PhysicsServer3D.body_get_direct_state(pan.get_rid())
		if direct != null:
			contact_points += direct.get_contact_count()
			for c in range(direct.get_contact_count()):
				if direct.get_contact_collider_object(c) == cart: shape_ids[direct.get_contact_collider_shape(c)] = true
		max_displacement = maxf(max_displacement, pan.position.distance_to(start))
	var result := {"kind": kind, "linear": sums.x / 300, "vertical": sums.y / 300, "angular": sums.z / 300, "contacts": contacts / 300, "sleep_frames": sleeps, "displacement": max_displacement, "com": pan.center_of_mass, "rotation": pan.rotation}
	print("PAN_METRIC ", result)
	print("PAN_CONTACT kind=", kind, " mean_points=", contact_points / 300, " cart_shape_indices=", shape_ids.keys(), " support_frames=", support_frames)
	return result

func run_checks() -> void:
	for kind in ["flat", "tilt", "can", "watermelon", "stack"]: await pan_trial(kind)
	await cargo_trial([&"frying_pan"])
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 11)
	rat.receive_impact(60, Vector3.FORWARD * 18)
	await frames(180)
	print("POST_HIT distance=", rat.position.distance_to(player.position), " state=", rat.state, " cooldown=", rat._charge_wait)
	quit(0)
