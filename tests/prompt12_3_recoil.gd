extends "res://tests/prompt12_smoke.gd"

var trace: Dictionary = {}
var prior_velocity := Vector3.ZERO

func record_hit(_damage: float) -> void:
	var away := rat.global_position - player.global_position
	away.y = 0
	trace = {"damage": rat.last_damage, "impulse": away.normalized() * weapon_body.weapon.knockback,
		"velocity_before": prior_velocity, "velocity_at_signal": rat.velocity, "recoil": rat.recoil_velocity,
		"recoil_left": rat._recoil_left, "recoil_wait": rat._recoil_wait, "stagger": rat.state == KingRat.State.STAGGER,
		"external": rat.external_velocity, "position": rat.position, "away": away.normalized(),
		"body_correction": player.velocity - rat.constrain_player_body(player, player.velocity, 1.0 / 60)}
	if "last_ai_velocity" in rat:
		trace["ai_velocity"] = rat.last_ai_velocity
		trace["applied_impulse"] = rat.last_impact_impulse

func trial(data: WeaponDefinition, speed: float, mode: String, gap: float, repeated: bool = false) -> float:
	await weapon_setup(data)
	rat.current_health = 10000
	rat.close_threat_time = 100
	rat.damaged.connect(record_hit)
	rat.set_physics_process(true)
	if repeated:
		# First real sweep arms the existing strong-hit rearm gate.
		rat.state = KingRat.State.SPAWN
		rat._left = 100
		await press("grab")
		while weapon_body.cooldown_left > 0: await frames(1)
	interaction.camera.rotation = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.position = Vector3(0, 0.01, 20)
	player.velocity = Vector3.ZERO
	player.external_velocity = Vector3.ZERO
	player.body_bump_left = 0 # Frozen preparation cannot tick a tail bump; start each trial at rest.
	player.body_bump_velocity = Vector3.ZERO
	player.move_speed = speed if speed > 0 else 5
	rat.position = Vector3(0, 0.01, 20-gap)
	rat.rotation.y = PI # Face the player; tail-side impacts have their own directional tests.
	rat.clear_aggro()
	rat.velocity = Vector3.ZERO
	rat.external_velocity = Vector3.ZERO
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	if mode != "static":
		rat.provoke(player)
		rat._charge_wait = 100
		if mode == "approach":
			rat.charge_range = 0.1 # Explicit approach fixture, outside the new hold/attack range.
			rat.too_close_distance = 0.1
			rat.desired_attack_distance = 0.1
			rat._clear_attack_lane = false # Approach the actor, not the ready attack position.
			rat._lane_wait = 100
			rat._route_wait = 0
		if mode == "recovery":
			rat.state = KingRat.State.CHARGE_RECOVERY
			rat._left = 1
	player.set_physics_process(true)
	trace = {}
	if speed > 0: Input.action_press("move_forward")
	await press("grab")
	for tick in range(60):
		prior_velocity = rat.velocity
		await frames(1)
		if not trace.is_empty(): break
	check(not trace.is_empty(), "real sweep hit " + mode + " speed=" + str(speed) + " repeat=" + str(repeated))
	if trace.is_empty():
		Input.action_release("move_forward")
		return 0
	await frames(2)
	trace["velocity_next_tick"] = rat.velocity
	for i in range(rat.get_slide_collision_count()):
		var collider := rat.get_slide_collision(i).get_collider()
		print("RECOIL_COLLIDER ", collider, " position=", collider.global_position if collider is Node3D else Vector3.ZERO)
	await frames(10)
	Input.action_release("move_forward")
	player.set_physics_process(false)
	var moved: Vector3 = rat.position - trace.position
	var projected := moved.dot(trace.away)
	print("RECOIL_TRACE weapon=", data.weapon_id, " mode=", mode, " speed=", speed, " gap=", gap, " repeated=", repeated, " projected_020=", projected, " data=", trace)
	check(trace.recoil_left > 0 and trace.recoil.dot(trace.away) > 0.5, "successful combat hit always starts directed recoil")
	check(projected > 0.15, "open-space hit displaces rat away")
	return projected

func run_checks() -> void:
	if OS.get_cmdline_user_args().has("--contact-diagnostic"):
		await trial(WEAPONS[1], 0, "static", 2.0, true)
		await trial(WEAPONS[1], 0, "reposition", 1.5, true)
		quit(1 if failures else 0)
		return
	if OS.get_cmdline_user_args().has("--approach-only"):
		for speed in [0.0, 5.0, 10.0]: await trial(WEAPONS[1], speed, "approach", 2.0, true)
		quit(1 if failures else 0)
		return
	for mode in ["static", "approach", "reposition", "recovery"]:
		for speed in [0.0, 5.0, 10.0]:
			await trial(WEAPONS[1], speed, mode, 1.5 if mode == "reposition" else 2.0, true)
	await trial(WEAPONS[1], 0, "static", 0.5)
	await trial(WEAPONS[1], 5, "static", 1.5)
	for data in WEAPONS: await trial(data, 0, "static", 2.0)
	await weapon_setup(WEAPONS[1])
	rat.set_physics_process(true)
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	Graybox.box(mart, "RecoilWall", Vector3(5, 3, 0.2), Vector3(0, 1.5, 17.2), Color.GRAY)
	await frames(2)
	await press("grab")
	for tick in range(60):
		await frames(1)
		if rat.hit_count > 0: break
	check(rat.hit_count == 1 and rat.current_health == 252 and rat._flash > 0 and rat.state == KingRat.State.STAGGER, "wall hit retains damage heavy feedback and stagger")
	await frames(15)
	check(rat.position.z > 17.8, "real wall limits recoil without tunneling")
	await weapon_setup(WEAPONS[1])
	rat.position = player.position
	await frames(2)
	weapon_body.start_swing()
	weapon_body._sample_arc(0.5)
	check(rat.hit_count == 1 and rat.last_impact_impulse.length() > 39 and rat.recoil_velocity.is_finite(), "coincident centers use valid swing direction fallback")
	await weapon_setup(WEAPONS[1])
	rat.receive_impact(2, Vector3.BACK * 90)
	weapon_body.start_swing()
	weapon_body._sample_arc(0.5)
	check(rat.current_health == 250 and rat._recoil_left > 0 and rat.recoil_velocity.z < -3, "fresh hammer overrides recent environmental recoil gate")
	check(rat.external_velocity.z < 0, "opposing old external force cannot cancel new combat recoil")
	quit(1 if failures else 0)
