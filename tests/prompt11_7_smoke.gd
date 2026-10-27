extends "res://tests/prompt11_smoke.gd"

func run_checks() -> void:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	check(not rat.is_aggro and rat.aggro_target == null, "spawn is neutral")
	var pursued := false
	var visible_ticks := 0
	for tick in range(600):
		await frames(1)
		# Keep the observer ten metres away from the real roaming motor.
		player.position = rat.position + Vector3.BACK * 10
		if rat.can_see(player): visible_ticks += 1
		pursued = pursued or rat.is_aggro or rat.state == KingRat.State.PURSUIT
	check(not pursued, "ten seconds visible observer does not provoke")
	check(visible_ticks > 60, "neutral observation includes sustained actual line of sight")
	check(rat.state in [KingRat.State.TRAVEL_ZONE, KingRat.State.SEEK_FOOD, KingRat.State.MOVE_TO_FOOD, KingRat.State.EAT], "neutral creature keeps world behavior")
	await boss_setup()
	rat.set_physics_process(false)
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	rat.receive_damage(3)
	check(not rat.is_aggro, "environment damage has no player attribution")
	rat.receive_damage(0, null, player)
	check(not rat.is_aggro, "zero damage cannot provoke")
	var item: GrabbableBody = load(ProductCatalog.find(&"frying_pan").scene_path).instantiate()
	mart.add_child(item)
	item.begin_carry(interaction, player)
	item.end_carry()
	item.position = Vector3(0, 0.85, 13)
	item.gravity_scale = 0
	item.launch(Vector3.FORWARD, 12, 60)
	await frames(40)
	check(rat.is_aggro and rat.aggro_target == player, "actual held then thrown product attributes attacker")
	check(rat.state == KingRat.State.STAGGER and rat.last_recoil_speed > 0, "first attributed hit preserves recoil and stagger")
	rat.set_physics_process(true)
	await frames(60)
	check(rat.is_aggro and rat.target_memory > 10, "combat resumes after first recoil")
	var last_seen := rat.last_known_position
	player.position = Vector3(35, 0.01, 35)
	await frames(120)
	check(rat.is_aggro and rat.last_known_position.is_equal_approx(last_seen), "lost sight keeps last known position")
	await frames(660)
	check(not rat.is_aggro and rat.aggro_target == null, "twelve second unseen memory expires")
	check(rat.state in [KingRat.State.TRAVEL_ZONE, KingRat.State.SEEK_FOOD, KingRat.State.MOVE_TO_FOOD, KingRat.State.EAT], "decay returns food zone behavior")
	rat.receive_damage(1, null, player)
	check(rat.is_aggro, "second fight starts after escape")
	player.health.is_downed = true
	rat.update_awareness(0)
	check(not rat.is_aggro, "downed target clears aggro")
	rat.receive_damage(1, null, player)
	check(not rat.is_aggro, "downed attacker cannot provoke")
	player.health.is_downed = false
	await boss_setup()
	rat.set_physics_process(false)
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 12)
	for i in range(45): rat.update_awareness(1.0 / 60)
	check(not rat.is_aggro, "brief pass within two metres remains neutral")
	player.position.z = 20
	rat.update_awareness(0.1)
	player.position.z = 12
	for i in range(60): rat.update_awareness(1.0 / 60)
	check(not rat.is_aggro, "separate passes do not accumulate harassment")
	for i in range(20): rat.update_awareness(1.0 / 60)
	check(rat.is_aggro and rat.aggro_target == player, "continuous close harassment provokes")
	var second := CharacterBody3D.new()
	mart.add_child(second)
	var health := PlayerHealth.new()
	health.name = "PlayerHealth"
	second.add_child(health)
	second.position = Vector3(4, 0, 12)
	rat.receive_damage(2, null, second)
	check(rat.aggro_target == second, "last meaningful attacker replaces target")
	rat.receive_damage(2)
	check(rat.aggro_target == second, "environment hit does not replace current attacker")
	second.queue_free()
	await frames(2)
	rat.update_awareness(0)
	check(not rat.is_aggro, "removed target clears safely")
	var attribution := AttackAttribution.new()
	attribution.remember(player)
	check(attribution.current() == player, "ownership weak reference valid")
	attribution.expires_frame = Engine.get_physics_frames()
	check(attribution.current() == null, "expired ownership is not attributed")
	await cart_trial(true)
	check(rat.is_aggro and rat.aggro_target == player, "real launched cart and cart bomb attribute launcher")
	quit(0 if failures == 0 else 1)
