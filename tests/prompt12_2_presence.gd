extends "res://tests/prompt12_smoke.gd"

func body_trial(speed: float, side: bool, active: bool = false) -> Dictionary:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 15)
	rat.clear_aggro()
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	rat.close_threat_time = 100 # Isolate contact from intentional AI retreat.
	rat.external_velocity = Vector3.ZERO
	player.position = rat.position + (Vector3.RIGHT if side else Vector3.BACK) * 1.3
	player.rotation.y = PI / 2 if side else 0
	player.velocity = Vector3.ZERO
	player.external_velocity = Vector3.ZERO
	player.move_speed = speed # No sprint input exists; stress at 2x walk speed.
	player.set_physics_process(true)
	if active: rat.provoke(player)
	await frames(2)
	var start := rat.position
	var minimum := INF
	var lateral := 0.0
	Input.action_press("move_forward")
	for tick in range(180):
		await frames(1)
		minimum = minf(minimum, Vector2(player.position.x-rat.position.x, player.position.z-rat.position.z).length())
		lateral = maxf(lateral, absf(rat.position.x-start.x))
	Input.action_release("move_forward")
	player.set_physics_process(false)
	var result := {"rat_distance": Vector2(rat.position.x-start.x, rat.position.z-start.z).length(), "along_push": start.z-rat.position.z, "lateral": lateral, "minimum_gap": minimum, "hp": player.health.current_health, "external": rat.external_velocity.length()}
	print("BODY speed=", speed, " side=", side, " active=", active, " ", result)
	return result

func force_trial(label: String, damage: float, impulse: float) -> float:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 15)
	player.position = Vector3(8, 0.01, 20)
	rat.clear_aggro()
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	rat.external_velocity = Vector3.ZERO
	rat.velocity = Vector3.ZERO
	var start := rat.position
	rat.receive_impact(damage, Vector3.FORWARD * impulse)
	await frames(15)
	var distance := Vector2(rat.position.x-start.x, rat.position.z-start.z).length()
	print("FORCE ", label, " damage=", damage, " impulse=", impulse, " distance_025=", distance)
	check(distance > 0.2, "combat force remains far above zero body displacement " + label)
	return distance

func run_checks() -> void:
	for speed in [5.0, 10.0]:
		for side in [false, true]:
			var result := await body_trial(speed, side)
			check(result.rat_distance < 0.08 and result.minimum_gap >= 1.05, "body cannot carry or pass through rat")
			check(result.hp >= 70 and result.hp <= 90 and not player.knockdown.active() and rat._flash == 0, "normal contact bounded damage without knockdown or rat flash")
	var active := await body_trial(5, false, true)
	check(active.external == 0 and active.minimum_gap >= 1.05, "active AI motion remains independent of body impulses")
	check(not rat._retreating and active.hp < 100, "normal contact damages player instead of triggering retreat")
	var bat := await force_trial("Bat", 22, 18)
	var broom := await force_trial("Broom", 12, 150)
	var hammer := await force_trial("Hammer", 48, 40)
	await force_trial("TV", 51, 18)
	await force_trial("Loaded Cart", 48, 32)
	check(broom > hammer and hammer > bat, "physical control differences retained")
	# Rear contact and tangential escape use the live player motor.
	await body_trial(5, false)
	player.position = rat.position + Vector3.FORWARD * 1.3
	player.rotation.y = PI
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(180)
	Input.action_release("move_forward")
	check(player.position.distance_to(rat.position) >= 1.15 and rat.external_velocity == Vector3.ZERO, "rear pushing stays separated without steering boss")
	var escape_start := player.position
	Input.action_press("move_right")
	await frames(45)
	Input.action_release("move_right")
	check(player.position.distance_to(escape_start) > 2, "sideways escape remains available without hard deadlock")
	player.set_physics_process(false)
	player.position = rat.position + Vector3.BACK * 0.1
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(45)
	check(player.position.distance_to(rat.position) >= 1.15, "existing deep overlap resolves through player motor")
	player.set_physics_process(false)
	player.position = rat.position + Vector3.BACK * 0.8
	player.health.current_health = 100 # Isolate charge from the preceding ordinary-contact trials.
	rat.state = KingRat.State.CHARGE
	rat._left = 0.5
	rat.charge_direction = Vector3.BACK
	await frames(4)
	check(player.health.current_health == 70 and player.knockdown.active(), "charge still deals thirty damage and knockdown")
	quit(1 if failures else 0)
