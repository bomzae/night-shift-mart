extends "res://tests/prompt12_smoke.gd"

func pressure(data: WeaponDefinition) -> void:
	await weapon_setup(data)
	rat.current_health = 10000
	player.health.max_health = 10000
	player.health.current_health = 10000
	rat._charge_wait = 0
	await press("grab")
	await frames(35)
	check(rat.hit_count == 1, "actual first swing " + data.weapon_id)
	rat.set_physics_process(true)
	var hold_ticks := 0
	var translated := false
	var telegraph_tick := -1
	for tick in range(90):
		await frames(1)
		if rat.state == KingRat.State.HOLD and rat._spacing_grace > 0:
			hold_ticks += 1
			translated = translated or rat.last_ai_velocity.length() > 0.01
		if rat.state == KingRat.State.TELEGRAPH:
			telegraph_tick = tick
			break
	check(hold_ticks >= 8 and hold_ticks <= 25 and not translated, "brief stationary hold " + data.weapon_id)
	check(telegraph_tick >= 0 and telegraph_tick < 75, "post-hit telegraph within 1.25 seconds " + data.weapon_id)
	player.set_physics_process(true)
	var first_hits := rat.hit_count
	var attacks := 1
	var previous := rat.state
	var retreat := 0.0
	var repositions := 0
	for tick in range(480):
		var toward := rat.position-player.position
		toward.y = 0
		if toward.length() > 0.1: player.look_at(player.position+toward)
		Input.action_press("move_forward")
		if is_instance_valid(weapon_body) and weapon_body.cooldown_left <= 0 and toward.length() < data.range:
			await press("grab")
		await frames(1)
		if rat.state == KingRat.State.REPOSITION: repositions += 1
		if rat.state not in [KingRat.State.CHARGE, KingRat.State.TELEGRAPH]: retreat += maxf(0, rat.last_ai_velocity.dot(toward.normalized())) / 60
		if rat.state == KingRat.State.TELEGRAPH and previous != rat.state: attacks += 1
		previous = rat.state
	Input.action_release("move_forward")
	print("PRESSURE124 ", data.weapon_id, " hits=", rat.hit_count-first_hits, " attacks=", attacks, " reposition_ticks=", repositions, " ai_retreat=", retreat)
	check(rat.hit_count > first_hits, "moving repeated swings " + data.weapon_id)
	check(retreat < 0.5 and repositions < 30, "open pressure does not retreat " + data.weapon_id)
	check(attacks >= 2 and rat.is_aggro, "pressure connects to counterattack " + data.weapon_id)
	player.set_physics_process(false)

func run_checks() -> void:
	for data in WEAPONS: await pressure(data)
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,15.5)
	rat.provoke(player)
	rat._charge_wait = 3
	var start := rat.position
	await frames(60)
	check(rat.state == KingRat.State.HOLD and rat.position.distance_to(start) < 0.05, "1.5m cooldown holds ground")
	rat._charge_wait = 0
	await frames(3)
	check(rat.state == KingRat.State.TELEGRAPH, "close ready charge telegraphs")
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = rat.position
	player.set_physics_process(true)
	rat.provoke(player)
	rat._charge_wait = 3
	start = rat.position
	await frames(45)
	print("OVERLAP124 gap=", player.position.distance_to(rat.position), " rat=", rat.position.distance_to(start))
	check(player.position.distance_to(rat.position) >= 1.15 and rat.position.distance_to(start) < 0.05, "exact overlap separates without boss retreat")
	player.set_physics_process(false)
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,18)
	Graybox.box(mart, "BlockedLane", Vector3(1.6,0.9,0.3), Vector3(0,0.45,16), Color.GRAY)
	Graybox.box(mart, "CornerRear", Vector3(3,2,0.2), Vector3(0,1,13.1), Color.GRAY)
	Graybox.box(mart, "CornerSide", Vector3(0.2,2,2), Vector3(-0.9,1,14), Color.GRAY)
	rat.provoke(player)
	rat._charge_wait = 0
	var adjusted := false
	var attacked := false
	for tick in range(240):
		await frames(1)
		adjusted = adjusted or rat.state in [KingRat.State.REPOSITION, KingRat.State.PURSUIT]
		attacked = attacked or rat.state == KingRat.State.TELEGRAPH
	check(adjusted and attacked and rat.position.is_finite(), "corner with blocked physical lane escapes then attacks")
	await weapon_setup(WEAPONS[1])
	await press("grab")
	await frames(35)
	check(rat.get_collision_exceptions().has(weapon_body) and weapon_body.get_collision_exceptions().has(rat), "successful held melee cannot block its own recoil")
	rat.set_physics_process(true)
	await frames(20)
	check(not rat.get_collision_exceptions().has(weapon_body) and not weapon_body.get_collision_exceptions().has(rat), "recoil expiry restores both weapon collision directions")
	await weapon_setup(WEAPONS[0])
	await press("grab")
	await frames(35)
	await press("drop_item")
	check(rat._recoil_weapon == null and not weapon_body.get_collision_exceptions().has(rat), "drop restores collision immediately even if target motor is paused")
	await weapon_setup(WEAPONS[1])
	await press("grab")
	await frames(35)
	weapon_body.queue_free()
	rat.set_physics_process(true)
	await frames(2)
	check(rat._recoil_weapon == null, "removed weapon leaves no stale recoil pair")
	quit(1 if failures else 0)
