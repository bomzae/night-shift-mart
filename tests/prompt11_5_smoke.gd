extends "res://tests/prompt11_5_cargo_probe.gd"

func run_checks() -> void:
	var cans := [&"can", &"can", &"can", &"can", &"can", &"can", &"can", &"can", &"can"]
	var before := await cargo_trial(cans, false)
	var after := await cargo_trial(cans, true)
	check(after.mean_y < before.mean_y * 0.85, "resting can cargo vertical jitter reduced versus identical unassisted load")
	check(after.resting == 9 and after.drive_cargo == 9, "nine real cargo remain during rest and straight drive")
	check(after.drive_peak < 2 and after.turn_brake_cargo >= 7, "turn and brake retain physical load without explosion")
	var cart: ShoppingCart = mart.get_node("Cart")
	check(not cart.cargo[0].freeze and cart.cargo[0].get_parent() != cart, "cargo remains independent RigidBody")
	var item: GrabbableBody = cart.cargo[0]
	cart.end_carry()
	await frames(60)
	item.begin_carry(interaction, player)
	await frames(2)
	check(not item.cargo_assisted, "grab immediately disables cargo assist")
	item.end_carry()
	cart.launch_cart(Vector3.FORWARD, interaction.throw_multiplier(1), 1, interaction)
	await frames(2)
	check(cart.cargo_release_time > 0 and not item.cargo_assisted, "launch releases stabilization")
	var mixed := await cargo_trial([&"can", &"bread", &"chips", &"milk", &"instant_noodles", &"can", &"chips", &"bread", &"shampoo", &"microwave", &"tv"])
	check(mixed.resting >= 8 and mixed.drive_peak < 3, "mixed eleven-product resting load and drive bounded")
	for type in [&"watermelon", &"microwave", &"tv"]:
		var single := await cargo_trial([type])
		check(single.resting == 1 and single.drive_cargo == 1, "large physical cargo " + String(type))
	await cart_trial(true)

	await boss_setup()
	rat.player_awareness_radius = 22
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 25) # Keep the speed probe outside the new attack band.
	rat.aggro_memory_time = 6.0 # Preserve this legacy memory-duration fixture.
	rat.provoke(player) # Combat regression now explicitly starts a fight.
	rat.state = KingRat.State.SEEK_FOOD
	await frames(3)
	check(rat.state == KingRat.State.PURSUIT and rat.target_memory > 5.8, "provoked visible player takes combat priority")
	var start := rat.position
	await frames(60)
	check(rat.position.z > start.z + 4, "pursuit actual progress toward player")
	var remembered := rat.last_known_position
	player.position = Vector3(34, 0.01, 33)
	await frames(2)
	check(rat.target_memory > 5 and rat.last_known_position.is_equal_approx(remembered), "out-of-sight memory retains last seen position")
	await frames(380)
	check(rat.target_memory == 0 and rat.state != KingRat.State.PURSUIT, "memory expiry returns food or zone mode")

	await boss_setup()
	rat.player_awareness_radius = 22
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	rat.provoke(player)
	await frames(2)
	var barrier := Graybox.box(mart, "PursuitShelf", Vector3(4, 2, 1.2), Vector3(0, 1, 15), Color.GRAY)
	await frames(2)
	check(not rat._sees_player and rat.target_memory > 5, "solid shelf breaks sight without immediately dropping pursuit")
	var planned := rat.pursuit_planner.build(rat.position, rat.last_known_position)
	print("PURSUIT ROUTE ", planned)
	check(planned.size() >= 2, "blocked pursuit uses aisle waypoints")
	var detour := false
	for tick in range(340):
		await frames(1)
		if absf(rat.position.x) > 2.8: detour = true
	print("PURSUIT AROUND shelf position=", rat.position, " distance=", rat.position.distance_to(player.position))
	check(detour and rat.position.z > 15.8, "actual boss passes shelf via aisle instead of hard blocking")
	barrier.queue_free()

	await boss_setup()
	rat.player_awareness_radius = 100
	rat.position = Vector3(0, 0.01, 2)
	player.position = Vector3(0, 0.01, 34)
	rat.aggro_memory_time = 6.0 # Preserve this legacy memory-duration fixture.
	rat.provoke(player) # Combat regression now explicitly starts a fight.
	rat.state = KingRat.State.SEEK_FOOD
	start = rat.position
	await frames(300)
	var pursuit_distance := rat.position.distance_to(start)
	print("PURSUIT FIVE SECONDS ", pursuit_distance, " roam expected=18")
	check(pursuit_distance > 22 and pursuit_distance < 25, "actual pursuit five seconds exceeds roam eighteen meters")
	check(rat.pursuit_speed > rat.move_speed and rat.charge_speed > rat.pursuit_speed, "roam pursuit charge distinct speeds")

	var recoils: Array[float] = []
	for type in [&"bread", &"can", &"watermelon", &"frying_pan", &"microwave", &"tv"]:
		await projectile_trial(type, 1.0)
		recoils.append(rat.last_recoil_speed)
		check(rat.last_recoil_speed > 0 and rat.last_recoil_speed <= rat.max_recoil_speed, "real product impact bounded recoil " + String(type))
	print("RECOIL SPEEDS bread can watermelon pan microwave tv ", recoils)
	check(recoils[2] > recoils[1] and recoils[4] >= recoils[2], "stronger product damage increases recoil")
	await boss_setup()
	rat.player_awareness_radius = 0
	rat.position = Vector3(0, 0.01, 10)
	rat.state = KingRat.State.SPAWN
	rat._left = 10
	start = rat.position
	rat.receive_impact(80, Vector3.RIGHT * 18)
	await frames(12)
	check(rat.position.x > start.x + 0.3 and rat.state == KingRat.State.STAGGER, "strong impact physically recoils during stagger")
	var recoil_before := rat._recoil_left
	rat.apply_external_impulse(Vector3.RIGHT * 2)
	check(rat._recoil_left == recoil_before, "extinguisher force does not restart combat recoil")
	await frames(40)
	check(rat.state != KingRat.State.STAGGER and rat._recoil_left == 0, "AI resumes after short recoil and stagger")
	quit(1 if failures else 0)
