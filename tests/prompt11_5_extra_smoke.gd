extends "res://tests/prompt11_5_smoke.gd"

func run_checks() -> void:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 25) # Stay outside attack range until the pinned-product detour.
	rat.aggro_memory_time = 6.0 # Preserve this legacy memory-duration fixture.
	rat.provoke(player) # Combat regression now explicitly starts a fight.
	rat.state = KingRat.State.SEEK_FOOD
	var tv := load(ProductCatalog.find(&"tv").scene_path).instantiate() as GrabbableBody
	mart.add_child(tv)
	tv.position = Vector3(0, 0.39, 14)
	tv.freeze = true
	var detoured := false
	for tick in range(600):
		await frames(1)
		if rat._pursuit_detour_left > 0: detoured = true
		if rat.position.z > 16: break
	print("PINNED TV pursuit pos=", rat.position, " detoured=", detoured)
	check(detoured and rat.position.z > 16, "stuck pursuit retains player and routes around pinned floor TV")
	check(rat.target_memory > 0, "product recovery does not discard pursuit target")

	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 15)
	rat.aggro_memory_time = 6.0 # Preserve this legacy memory-duration fixture.
	rat.provoke(player) # Combat regression now explicitly starts a fight.
	rat.state = KingRat.State.SEEK_FOOD
	rat._charge_wait = 0
	await frames(2)
	check(rat.state == KingRat.State.TELEGRAPH, "pursuit range triggers telegraphed attack")
	var direction := rat.charge_direction
	player.position.x = 4
	await frames(85)
	check(rat.charge_direction.is_equal_approx(direction) and player.health.current_health == 100, "charge direction locks and lateral dodge avoids damage")
	await frames(ceili(rat.charge_recovery_time * 60) + 5)
	check(rat.state in [KingRat.State.PURSUIT, KingRat.State.REPOSITION] and rat.target_memory > 0, "miss recovers briefly then resumes active combat")
	rat.current_health = 2000
	rat.receive_impact(1000, Vector3.RIGHT * 1000)
	check(rat.last_recoil_speed == rat.max_recoil_speed, "extreme combat recoil clamps")
	await frames(1)
	check(Vector2(rat.velocity.x, rat.velocity.z).length() <= rat.max_recoil_speed + 0.01, "combined external and recoil velocity also clamps")
	var last := rat.recoil_velocity
	rat.receive_impact(60, Vector3.LEFT * 18)
	check(rat.recoil_velocity == last, "repeated impact cooldown does not stack or redirect recoil")

	await setup_thief()
	player.position = Vector3(10, 0.01, -3)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.03, 10))
	var item := load(ProductCatalog.find(&"microwave").scene_path).instantiate() as GrabbableBody
	mart.add_child(item)
	item.position = cart.to_global(Vector3(0, 0.73, 0))
	await frames(240)
	check(cart.cargo.has(item) and item.cargo_assisted, "supported cargo receives resting assist")
	var damp := item.angular_damp
	print("CARGO SLEEP natural before drive=", item.sleeping)
	# Exercise the sleeping-body precondition explicitly; short settling need not sleep.
	item.sleeping = true
	var cargo_start := item.position
	cart.holder = interaction
	cart.drive_velocity = Vector3.BACK * 3
	cart._control_forward = Vector3.BACK
	for tick in range(60):
		cart._control_target = cart.position
		await frames(1)
	check(item.position.distance_to(cargo_start) > 1 and not item.sleeping, "resting cargo wakes and travels with moving support")
	cart.end_carry()
	var over := load(ProductCatalog.find(&"can").scene_path).instantiate() as GrabbableBody
	mart.add_child(over)
	over.position = cart.to_global(Vector3(0, 1.5, 0))
	await frames(2)
	check(not over.cargo_assisted and not over.freeze, "upper overload remains unassisted loose body")
	# A real tilted support/ramp fixture, not a change to cargo transforms.
	var ramp := Graybox.box(mart, "Ramp", Vector3(4, 0.25, 7), Vector3(0, 1.5, 15), Color.GRAY)
	ramp.rotation.x = deg_to_rad(25)
	cart.freeze = true
	cart.position = Vector3(0, 2.3, 15)
	cart.rotation.x = deg_to_rad(25)
	cart.freeze = false
	await frames(3)
	check(cart.cargo_release_time > 0 and not item.cargo_assisted, "steep ramp/tilt releases cargo assist")
	check(item.angular_damp == damp and not item.freeze, "assist never changes persistent damping or freezes cargo")
	await frames(120)
	check(cart.position.is_finite() and item.position.is_finite(), "ramp cargo simulation finite")
	await cart_trial(true)
	check(rat.last_recoil_speed > 0, "loaded cart and scatter deliver boss recoil")
	await boss_setup()
	rat.player_awareness_radius = 0
	rat.position = Vector3(0, 0.01, 8)
	rat.state = KingRat.State.SPAWN
	rat._left = 10
	rat.current_health = 2000
	cart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.03, 3))
	for x in [-0.3, 0.3]:
		var can := load(ProductCatalog.find(&"can").scene_path).instantiate() as GrabbableBody
		mart.add_child(can)
		can.position = cart.to_global(Vector3(x, 0.65, 0))
	await frames(90)
	var start := rat.position
	cart.launch_cart(Vector3.BACK, interaction.throw_multiplier(1), 1, interaction)
	await frames(90)
	print("LIVE CART RAT displacement=", rat.position.distance_to(start), " hp=", rat.current_health, " recoil=", rat.last_recoil_speed)
	check(rat.hit_count > 0 and rat.position.z > start.z + 0.3 and rat.last_recoil_speed > 0, "live boss physically recoils from actual loaded cart attack")
	quit(1 if failures else 0)
