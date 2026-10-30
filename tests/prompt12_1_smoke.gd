extends "res://tests/prompt12_smoke.gd"
func run_checks() -> void:
	for data in WEAPONS:
		await weapon_setup(data)
		await press("grab")
		if data.windup_time > 0.1:
			await frames(3)
			check(rat.hit_count == 0 and weapon_body.sweep_phase() < 0, "heavy windup has no early hit")
		var hit := false
		for i in range(90):
			await frames(1)
			if weapon_body.hit_stop_left > 0:
				hit = true
				break
		root.get_texture().get_image().save_png("res://.godot/p121_hit_" + String(data.weapon_id) + ".png")
		check(hit and rat.last_damage == data.damage and rat.hit_count == 1, "exact hit and local hit-stop " + String(data.weapon_id))
		var left := weapon_body.swing_left
		var frame := Engine.get_physics_frames()
		await frames(1)
		check(is_equal_approx(left, weapon_body.swing_left) and Engine.get_physics_frames() > frame and not paused and Engine.time_scale == 1, "only weapon motion pauses")
		check(interaction.camera_impact > 0 and interaction.camera_impact <= 0.025, "bounded impact camera kick")
		await frames(90)
		check(not weapon_body.swinging() and weapon_body.cooldown_left == 0 and interaction.camera_impact == 0, "swing recovery and camera restore")
		check(weapon_body.motion_pose().basis.is_equal_approx(Basis.IDENTITY), "idle pose restored")
		rat.position.x = 8
		await press("grab")
		await frames(8)
		check(weapon_body.hit_stop_left == 0 and interaction.camera_impact == 0, "miss has no hit feedback")
		await frames(90)
		weapon_body.durability = 1
		await frames(2)
		check(interaction.weapon_info.modulate == Color.SALMON, "low durability subtle warning")
		# Physical full-charge flight with existing weight/price calculation.
		rat.position = Vector3(0, 0.01, 15)
		rat.current_health = 300
		rat.hit_count = 0
		interaction.drop_held()
		await place(weapon_body, Vector3(0, 0.85, 18))
		weapon_body.gravity_scale = 0
		var expected: float = interaction.damage_for(weapon_body.price, 1) * data.throw_damage_multiplier
		var speed: float = interaction.throw_speed(weapon_body.weight, 1)
		weapon_body.launch(Vector3.FORWARD, speed, interaction.damage_for(weapon_body.price, 1))
		await frames(50)
		check(not is_instance_valid(weapon_body) and rat.hit_count == 1 and is_equal_approx(rat.last_damage, expected), "throw final durability breaks AFTER damage " + String(data.weapon_id))
		print("THROW ", data.weapon_id, " damage=", rat.last_damage, " launch_speed=", speed)
		await weapon_setup(data)
		interaction.drop_held()
		await place(weapon_body, Vector3(0, 1, 21))
		weapon_body.launch(Vector3.DOWN, 5, 10)
		await frames(40)
		check(weapon_body.durability == data.durability_max and weapon_body._armed_seconds == 0, "floor throw impact preserves durability")
		await weapon_setup(data)
		rat.position.x = 8
		player.set_physics_process(true)
		var start := player.position
		Input.action_press("move_forward")
		weapon_body.start_swing()
		var clearance := INF
		for i in range(30):
			await frames(1)
			clearance = minf(clearance, interaction.camera.global_position.distance_to(weapon_body.global_position) - weapon_body.carry_radius)
		Input.action_release("move_forward")
		check(start.distance_to(player.position) > 1.5 and Vector2(player.velocity.x, player.velocity.z).length() > 4.5, "swing preserves player movement " + String(data.weapon_id))
		check(clearance > 0.1, "physical swing remains outside camera")
		player.set_physics_process(false)
	# Alternating high damage sources must not keep restarting incapacitation.
	await boss_setup()
	rat.position = Vector3(0, 0.01, 14)
	player.position = Vector3(0, 0.01, 19)
	rat.current_health = 10000
	rat._charge_wait = 0
	var active_ticks := 0
	var charge_ticks := 0
	for tick in range(240):
		if tick % 6 == 0: rat.receive_impact(48, Vector3.FORWARD * 40 * (1 if tick % 12 == 0 else -1), player)
		await frames(1)
		if rat.state not in [KingRat.State.STAGGER, KingRat.State.RECOIL]: active_ticks += 1
		if rat.state in [KingRat.State.TELEGRAPH, KingRat.State.CHARGE]: charge_ticks += 1
	print("REACTION REARM active=", active_ticks, " attacks=", charge_ticks, " hp=", rat.current_health)
	check(active_ticks > 100 and charge_ticks > 0 and rat.current_health == 8080, "rapid strong hits keep damage but allow combat actions")
	await setup_thief()
	player.position = Vector3(8, 0.01, 10)
	await press("debug_order_weapon")
	var delivery = mart.get_node("Delivery/WeaponDelivery")
	check(delivery.order_info.visible and delivery.order_info.text.contains("BASEBALL BAT"), "order selection visible briefly on HUD")
	await frames(130)
	check(not delivery.order_info.visible, "order HUD expires")
	quit(1 if failures else 0)
