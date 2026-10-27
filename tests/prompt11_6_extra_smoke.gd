extends "res://tests/prompt11_6_probe.gd"

func run_checks() -> void:
	await pan_trial("flat")
	var cart: ShoppingCart = mart.get_node("Cart")
	var pan: GrabbableBody = cart.cargo[0]
	check(pan.cargo_support_time >= 0.35, "flat support contact timer actually activates")
	await place(pan, cart.to_global(Vector3(1.02, 0.94, 0)))
	pan.rotation.z = 0.5
	await frames(180)
	check(pan.cargo_support_time == 0 and not pan.freeze and not cart.cargo.has(pan), "unstable edge cargo falls freely")
	var tray: GrabbableBody = load(ProductCatalog.find(&"can").scene_path).instantiate()
	tray.definition = tray.definition.duplicate()
	tray.definition.id = &"test_flat_shape"
	tray.definition.shape_kind = 0
	tray.definition.size = Vector3(0.45, 0.35, 0.06)
	mart.add_child(tray)
	tray.position = cart.to_global(Vector3(0, 0.48, 0))
	tray.rotation.x = PI / 2
	await frames(180)
	var direct := PhysicsServer3D.body_get_direct_state(tray.get_rid())
	var normals: Array = []
	for i in range(direct.get_contact_count()): normals.append(direct.get_contact_local_normal(i))
	print("ROTATED FLAT support=", tray.cargo_support_time, " local=", cart.to_local(tray.position), " rotation=", tray.rotation, " velocities=", tray.linear_velocity, "/", tray.angular_velocity, " contacts=", normals, " assisted=", tray.cargo_assisted)
	check(tray.cargo_support_time >= 0.35 and not tray.freeze, "geometry-based support handles another thin axis and product")
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 11)
	rat.provoke(player) # Explicit combat fixture; neutral LOS no longer provokes.
	rat.update_awareness(0)
	rat.state = KingRat.State.PURSUIT
	rat.receive_impact(2, Vector3.FORWARD)
	check(rat.state == KingRat.State.RECOIL, "light hit has explicit movement interruption")
	rat._charge_wait = 0
	await frames(10)
	check(rat.state == KingRat.State.RECOIL, "charge cannot start during light recoil")
	await frames(20)
	check(rat.state == KingRat.State.REPOSITION, "light recoil near player repositions")
	for i in range(4):
		rat.receive_impact(60, Vector3.FORWARD * 10)
		await frames(20)
	await frames(150)
	check(rat.state not in [KingRat.State.STAGGER, KingRat.State.RECOIL], "repeated hits recover instead of locking state")
	check(rat.position.is_finite() and rat.target_memory > 0, "repeated impacts preserve finite aggressive AI")
	# A rear wall forces the spacing motor to use its stable lateral escape.
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 11)
	Graybox.box(mart, "SpacingWall", Vector3(3, 2, 0.3), Vector3(0, 1, 9), Color.GRAY)
	rat.provoke(player) # Explicit combat fixture; neutral LOS no longer provokes.
	rat.update_awareness(0)
	rat.resume_combat()
	await frames(180)
	check(rat.combat_distance() > 2.8 and rat.position.is_finite(), "reposition uses lateral space at rear wall")
	quit(0 if failures == 0 else 1)
