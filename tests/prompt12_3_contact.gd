extends "res://tests/prompt12_smoke.gd"

func contact_setup() -> void:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 15)
	rat.clear_aggro()
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	rat.close_threat_time = 100
	player.position = Vector3(0, 0.01, 16.2)
	player.velocity = Vector3.ZERO
	player.external_velocity = Vector3.ZERO
	player.health.current_health = 100
	await frames(3)

func run_checks() -> void:
	await contact_setup()
	check(player.health.current_health == 90 and rat.contact_damage_count == 1, "normal neutral contact deals exactly ten once")
	check(not player.knockdown.active() and not rat.is_aggro and rat._flash == 0, "body bump has no knockdown instant aggro or rat flash")
	check(player.body_bump_left > 0 and interaction.camera_impact > 0, "movement and existing camera feedback start")
	var start := player.position
	var rat_start := rat.position
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(10)
	Input.action_release("move_forward")
	check(player.position.z > start.z + 0.2, "contact pushes player away despite held forward input")
	check(rat.position.distance_to(rat_start) < 0.03, "body collision does not retreat or push rat")
	player.set_physics_process(false)
	await contact_setup()
	await frames(40)
	check(player.health.current_health == 90, "continuous overlap under one second cannot spam damage")
	await frames(24)
	check(player.health.current_health == 80 and rat.contact_damage_count == 2, "persistent contact can damage again after cooldown")
	var second: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	second.position = rat.position + Vector3.LEFT * 1.2
	mart.add_child(second)
	second.set_physics_process(false)
	await frames(3)
	check(second.health.current_health == 90 and player.health.current_health == 80, "each player owns independent contact cooldown")
	var second_id := second.get_instance_id()
	second.queue_free()
	await frames(2)
	check(not rat._contact_waits.has(second_id), "departing player clears cooldown and collision pair")
	await contact_setup()
	player.position.z += 0.12
	player.health.current_health = 100
	rat._contact_waits.clear()
	await frames(5)
	check(player.health.current_health == 100, "broad hit area alone is not actual body contact")
	for suppressed in [KingRat.State.RECOIL, KingRat.State.STAGGER, KingRat.State.DEFEATED]:
		await contact_setup()
		rat._contact_waits.clear()
		player.health.current_health = 100
		rat.state = suppressed
		rat._left = 100
		rat._recoil_left = 0.25 if suppressed == KingRat.State.RECOIL else 0
		rat.is_defeated = suppressed == KingRat.State.DEFEATED
		await frames(5)
		check(player.health.current_health == 100, "contact suppressed during " + KingRat.State.keys()[suppressed])
	await contact_setup()
	rat._contact_waits.clear()
	player.health.current_health = 100
	rat.state = KingRat.State.CHARGE
	rat._left = 0.1
	rat.charge_direction = Vector3.BACK
	await frames(5)
	check(player.health.current_health == 70 and player.knockdown.active(), "charge is thirty and knockdown without extra ten")
	await frames(20)
	check(player.health.current_health == 70, "charge recovery cannot immediately add body damage")
	for normal in [KingRat.State.SPAWN, KingRat.State.SEEK_FOOD, KingRat.State.PURSUIT, KingRat.State.REPOSITION, KingRat.State.CHARGE_RECOVERY]:
		await contact_setup()
		rat.set_physics_process(false)
		rat._contact_waits.clear()
		player.health.current_health = 100
		rat.state = normal
		rat._character_contacts(1.0 / 60)
		await frames(2)
		check(player.health.current_health == 90, "normal contact permitted in " + KingRat.State.keys()[normal])
	await contact_setup()
	rat.close_threat_time = 1.25
	await frames(85)
	check(rat.is_aggro and rat.aggro_target == player, "persistent nearby harassment still provokes")
	# Queue contact first, then land a real weapon sweep in the same physics batch.
	await weapon_setup(WEAPONS[1])
	rat.position = player.position + Vector3.FORWARD * 1.2
	await frames(3)
	player.health.current_health = 100
	weapon_body.start_swing()
	rat._character_contacts(1.0 / 60)
	# A dedicated active sample ensures ordering independent of windup timing.
	weapon_body._sample_arc(0.5)
	await frames(2)
	check(rat.hit_count == 1 and rat._recoil_left > 0, "real close melee enters recoil")
	check(player.health.current_health == 100, "successful hit cancels pending contact before damage resolution")
	await contact_setup()
	player.set_physics_process(true)
	Input.action_press("move_forward")
	start = rat.position
	await frames(180)
	Input.action_release("move_forward")
	check(rat.position.distance_to(start) < 0.05 and player.health.current_health >= 60 and player.health.current_health <= 80, "three second body pushing cannot herd rat or melt health")
	check(not player.knockdown.active(), "continuous ordinary bumps never knock down")
	print("CONTACT_3S hp=", player.health.current_health, " rat_displacement=", rat.position.distance_to(start), " contacts=", rat.contact_damage_count)
	quit(1 if failures else 0)
