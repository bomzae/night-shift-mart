extends "res://tests/prompt11_6_probe.gd"

func run_checks() -> void:
	for kind in ["flat", "tilt", "can", "watermelon", "stack"]:
		var result := await pan_trial(kind)
		check(result.vertical < 0.01 and result.angular < 0.02 and result.displacement < 0.03, "supported flat cargo bounded: " + kind)
		var cart: ShoppingCart = mart.get_node("Cart")
		check(cart.cargo.size() > 0 and not cart.cargo[0].freeze, "real free cargo: " + kind)
	var motion := await cargo_trial([&"frying_pan"])
	check(motion.drive_cargo == 1 and motion.turn_brake_cargo == 1 and motion.drive_peak < 1, "flat cargo drive turn brake")
	var cart: ShoppingCart = mart.get_node("Cart")
	var pan: GrabbableBody = cart.cargo[0]
	cart.end_carry()
	cart.launch_cart(Vector3.FORWARD, interaction.throw_multiplier(1), 1, interaction)
	await frames(2)
	check(not pan.cargo_assisted and pan.cargo_support_time == 0, "launch releases flat support immediately")
	await cart_trial(true)
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 11)
	rat.provoke(player) # Explicit combat fixture; neutral LOS no longer provokes.
	rat.update_awareness(0)
	rat.receive_impact(60, Vector3.FORWARD * 18)
	var start := rat.position
	await frames(10)
	check(rat.position.z < start.z and rat.state == KingRat.State.STAGGER, "strong hit interrupts pursuit and opens space")
	check(rat.separation_push_count == 0, "no normal push during hit interruption")
	var saw_reposition := false
	for i in range(120):
		await frames(1)
		saw_reposition = saw_reposition or rat.state == KingRat.State.REPOSITION
	check(saw_reposition and rat.combat_distance() >= rat.desired_attack_distance - 0.2, "post-stagger reposition establishes attack spacing")
	check(rat.target_memory > 0 and rat.state == KingRat.State.PURSUIT, "target retained without contact pursuit")
	check(rat.separation_push_count <= 1, "cooldown does not generate push loop")
	rat._charge_wait = 0
	await frames(3)
	check(rat.state == KingRat.State.TELEGRAPH, "spacing permits telegraphed attack re-entry")
	await frames(45)
	check(rat.state == KingRat.State.CHARGE, "charge retains attack phase")
	await frames(75)
	check(rat.state != KingRat.State.CHARGE and rat.state != KingRat.State.STAGGER, "charge hit recovers AI")
	rat.state = KingRat.State.SPAWN
	rat._left = 10
	rat.player_awareness_radius = 0
	rat._recoil_left = 0
	rat.external_velocity = Vector3.ZERO
	rat.position = player.position + Vector3(0.1, 0, 0)
	await frames(3)
	rat._push_waits.clear()
	var pushes := rat.separation_push_count
	await frames(60)
	var push_count := rat.separation_push_count - pushes
	check(push_count >= 2 and push_count <= 3, "real one-second overlap limited to 2-3 pushes")
	rat.set_physics_process(false)
	var health: PlayerHealth = player.get_node("PlayerHealth")
	health.is_downed = true
	rat._push_waits.clear()
	pushes = rat.separation_push_count
	rat._character_contacts(1.0 / 60)
	check(rat.separation_push_count == pushes, "downed player never separation-pushed")
	health.is_downed = false
	quit(0 if failures == 0 else 1)
