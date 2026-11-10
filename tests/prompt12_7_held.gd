extends "res://tests/prompt12_smoke.gd"

func idle_trial(data: WeaponDefinition) -> void:
	await weapon_setup(data)
	rat.rotation.y = PI
	rat.position.z = 16
	rat.provoke(player)
	rat.charge_range = 0.1
	rat.desired_attack_distance = 0.1
	rat._charge_wait = 100
	rat.set_physics_process(true)
	var blocked_ticks := 0
	for tick in range(180):
		await frames(1)
		for i in range(rat.get_slide_collision_count()):
			if rat.get_slide_collision(i).get_collider() == weapon_body: blocked_ticks += 1
	var gap := player.position.distance_to(rat.position)
	print("HELD127 ",data.weapon_id," gap=",gap," blocked_ticks=",blocked_ticks," hits=",rat.hit_count," pairs=",rat.get_collision_exceptions().has(weapon_body))
	check(interaction.held_object == weapon_body and rat.hit_count == 0 and rat.current_health == 300, "idle held weapon never attacks " + data.weapon_id)
	check(gap < 1.5 and blocked_ticks == 0, "held weapon length cannot block approach " + data.weapon_id)
	check(rat.get_collision_exceptions().has(weapon_body) and weapon_body.get_collision_exceptions().has(rat), "held monster pair exception is symmetric " + data.weapon_id)

func run_checks() -> void:
	for data in WEAPONS: await idle_trial(data)
	print("P127 held complete failures=",failures)
	quit(1 if failures else 0)
