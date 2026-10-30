extends "res://tests/prompt12_smoke.gd"
func run_checks() -> void:
	var distances: Array[float] = []
	for original in WEAPONS:
		var data: WeaponDefinition = original.duplicate()
		data.durability_max = 1000 # Isolate successful-hit DPS from the finite stock of one weapon.
		await weapon_setup(data)
		rat.current_health = 10000
		for tick in range(600):
			if weapon_body.cooldown_left <= 0: weapon_body.start_swing()
			await frames(1)
		print("DPS ", data.weapon_id, " hits=", rat.hit_count, " damage=", 10000-rat.current_health, " dps=", (10000-rat.current_health)/10)
		check(rat.hit_count > 5, "ten second successful-hit sequence " + String(data.weapon_id))
		interaction.drop_held()
		weapon_body.position = Vector3(8, 1, 15)
		player.position = Vector3(8, 0.01, 20)
		rat.position = Vector3(0, 0.01, 15)
		rat.clear_aggro()
		rat.external_velocity = Vector3.ZERO
		rat.velocity = Vector3.ZERO
		rat.recoil_velocity = Vector3.ZERO
		rat._recoil_left = 0
		rat._stagger_wait = 0
		rat._recoil_wait = 0
		rat.state = KingRat.State.SPAWN
		rat._left = 10
		rat.set_physics_process(true)
		var start := rat.position
		rat.receive_impact(data.damage, Vector3.FORWARD * data.knockback)
		var stagger := rat.state == KingRat.State.STAGGER
		await frames(15)
		distances.append(Vector2(rat.position.x-start.x,rat.position.z-start.z).length())
		print("CONTROL ", data.weapon_id, " distance_025=", Vector2(rat.position.x-start.x,rat.position.z-start.z).length(), " stagger=", stagger)
	check(distances[2] > distances[1] * 1.1 and distances[1] > distances[0] * 1.5, "measured control broom above hammer above bat")
	quit(1 if failures else 0)
