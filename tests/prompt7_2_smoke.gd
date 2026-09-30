extends "res://tests/prompt7_1_smoke.gd"

func run_checks() -> void:
	var zone := await ready_player()
	var kd: KnockdownState = player.knockdown
	var head: Node3D = player.get_node("Head")
	var camera: Camera3D = interaction.camera
	var rest_head := head.position
	var rest_camera := camera.transform
	var collider: Transform3D = player.get_node("CollisionShape3D").transform
	player.velocity = Vector3(2, 0, 0)
	await frames(2)
	check(kd.phase == KnockdownState.Phase.FALLING, "actual spill starts visual fall")
	check(head.position.y > rest_head.y - kd.fall_camera_drop, "fall is interpolated rather than one-frame snap")
	var previous_y := head.position.y
	var previous_pitch := camera.rotation.x
	var bounded_steps := true
	for step in range(18):
		await frames(1)
		bounded_steps = bounded_steps and absf(head.position.y - previous_y) < 0.25 and absf(camera.rotation.x - previous_pitch) < 0.3
		previous_y = head.position.y
		previous_pitch = camera.rotation.x
	check(bounded_steps, "fall height and pitch transition have bounded per-tick steps")
	check(kd.phase == KnockdownState.Phase.DOWN, "fall reaches down phase")
	check(rest_head.y - head.position.y >= 0.9, "down view lowers by at least 0.9 metres")
	check(absf(rad_to_deg(camera.rotation.x)) >= 65, "down pitch clearly lies backward")
	check(is_zero_approx(camera.rotation.z), "rightward slip does not select side roll")
	check(camera.global_position.y > 0.17 and camera.global_position.y < 0.65, "down eye stays close to floor without entering it")
	var down_y := head.position.y
	var down_pitch := camera.rotation.x
	await frames(8)
	check(is_equal_approx(head.position.y, down_y) and is_equal_approx(camera.rotation.x, down_pitch), "down pose remains held")
	var old_pitch := head.rotation.x
	var old_yaw := player.rotation.y
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(40, 100)
	Input.parse_input_event(mouse)
	await frames(2)
	check(head.rotation.x != old_pitch and player.rotation.y != old_yaw, "down mouse input controls both pitch and yaw")
	check(is_equal_approx(camera.rotation.x, down_pitch) and is_zero_approx(head.rotation.z), "look cannot overwrite independent fall pitch")
	check(is_equal_approx(head.position.y, down_y), "mouse pitch does not orbit eye into floor")
	check(player.get_node("CollisionShape3D").transform == collider and player.global_basis.y.dot(Vector3.UP) > 0.999, "player collider and body stay upright")
	await process_frame
	root.get_texture().get_image().save_png("res://.godot/p73_presentation_regression.png")
	var saved_pitch := head.rotation.x
	var saved_yaw := player.rotation.y
	while kd.phase != KnockdownState.Phase.STANDING_UP:
		await frames(1)
	await frames(10)
	check(head.position.y > down_y and head.position.y < rest_head.y, "standing gradually raises eye")
	check(absf(camera.rotation.x) < absf(down_pitch) and absf(camera.rotation.x) > 0.01, "standing gradually removes pitch")
	await frames(22)
	check(kd.phase == KnockdownState.Phase.IMMUNE, "recovery preserves normal immunity state")
	check(head.position.is_equal_approx(rest_head) and camera.transform.is_equal_approx(rest_camera), "complete rest position and camera visual transform restore")
	check(is_equal_approx(head.rotation.x, saved_pitch) and is_equal_approx(player.rotation.y, saved_yaw), "recovery preserves live look angles")
	zone.clean(1)
	await frames(85)
	check(kd.try_start(-player.global_basis.x * 2), "second fall starts after immunity")
	await frames(20)
	check(camera.rotation.x > 1 and is_equal_approx(head.position.y, down_y), "opposite lateral fall keeps backward pose without accumulated offset")
	await frames(80)
	check(head.position.is_equal_approx(rest_head) and camera.transform.is_equal_approx(rest_camera), "second recovery leaves no residual offset")

	# Test extreme tuning at a real floor and close to a wall. Geometry and
	# collider remain unchanged; camera only moves on the capsule centre line.
	await ready_player()
	kd = player.knockdown
	head = player.get_node("Head")
	camera = interaction.camera
	Graybox.box(mart, "CameraFallWall", Vector3(0.2, 3, 4), Vector3(0.46, 1.5, 2), Color.GRAY)
	await frames(2)
	kd.fall_camera_drop = 10
	player.velocity = Vector3(0, 0, -2)
	await frames(20)
	check(kd.phase == KnockdownState.Phase.DOWN, "wall-adjacent core fall reaches down")
	check(camera.global_position.y >= kd.fall_camera_floor_margin - 0.01, "oversized drop is clamped above floor margin")
	check(camera.global_position.is_finite() and camera.global_basis.is_finite(), "wall-adjacent camera stays finite")
	check(absf(camera.global_position.x - player.global_position.x) < 0.001 and camera.global_position.x < 0.15, "pitch has no lateral eye offset through wall")
	await frames(85)
	check(is_equal_approx(head.position.y, 1.6) and camera.rotation.is_zero_approx(), "wall-adjacent fall fully recovers")
	print("Prompt 7.2 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
