extends "res://tests/prompt12_smoke.gd"

func run_checks() -> void:
	await weapon_setup(WEAPONS[1])
	rat._charge_wait = 4
	await press("grab")
	await frames(35)
	check(rat.hit_count == 1, "real hammer hit precedes pressure measurement")
	rat.set_physics_process(true)
	await frames(35)
	var backward := 0.0
	var ai_backward := 0.0
	var reposition_ticks := 0
	for tick in range(90):
		player.position = rat.position + Vector3.BACK * 1.5
		var previous := rat.position
		await frames(1)
		backward += maxf(0, previous.z - rat.position.z)
		ai_backward += maxf(0, -rat.last_ai_velocity.z) / 60
		if rat.state == KingRat.State.REPOSITION: reposition_ticks += 1
	print("PRESSURE backward=", backward, " ai_backward=", ai_backward, " reposition_ticks=", reposition_ticks)
	check(ai_backward < 0.1 and backward < 0.3 and reposition_ticks < 10, "post-hit close pressure holds recoil position")
	player.position = Vector3(0, 0.01, 24)
	player.velocity = Vector3.RIGHT * 5
	player.receive_body_bump(Vector3.BACK * 2.4)
	player.set_physics_process(true)
	Input.action_press("move_right")
	await frames(4)
	print("BUMP velocity=", player.velocity, " camera=", interaction.camera_impact)
	check(player.velocity.x < 3, "contact briefly damps tangent movement")
	Input.action_release("move_right")
	quit(1 if failures else 0)
