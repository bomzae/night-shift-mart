extends "res://tests/prompt7_1_smoke.gd"

func run_checks() -> void:
	await ready_player()
	var kd: KnockdownState = player.knockdown
	var head: Node3D = player.get_node("Head")
	var camera: Camera3D = interaction.camera
	var rest_camera := camera.transform
	var rest_height := head.position.y
	# Test-only ceiling with a beam: lets the render and a ray verify that the
	# chosen positive X pitch actually faces overhead, not the floor.
	Graybox.box(mart, "RenderCeiling", Vector3(12, 0.2, 12), Vector3(0, 3.5, 2), Color(0.7, 0.76, 0.8))
	Graybox.box(mart, "CeilingBeam", Vector3(0.2, 0.3, 12), Vector3(0.2, 3.25, 2), Color(0.3, 0.4, 0.5))
	await frames(2)
	var pose_before := head.rotation
	player.velocity = Vector3(0, 0, -2)
	await frames(2)
	check(kd.active() and player.velocity.z < -2, "spill keeps forward foot-slip impulse")
	await frames(18)
	check(kd.phase == KnockdownState.Phase.DOWN, "backward fall reaches down")
	check(camera.rotation.x > deg_to_rad(65) and absf(camera.rotation.z) < deg_to_rad(10), "large backward pitch replaces large side roll")
	check((-camera.global_basis.z).dot(Vector3.UP) > 0.9, "positive pitch points actual camera toward ceiling")
	check(head.position.y < rest_height - 0.9 and camera.global_position.y > 0.17, "backward pose is low and above floor")
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * 8)
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and hit.position.y > 3, "render direction hits overhead geometry instead of floor")
	check(head.rotation.is_equal_approx(pose_before), "fall leaves base look unchanged")
	await process_frame
	root.get_texture().get_image().save_png("res://.godot/p73_backward_down.png")
	var held_pose := camera.rotation
	await frames(8)
	check(camera.rotation.is_equal_approx(held_pose), "down holds backward visual offset")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(50, 60)
	var old_yaw := player.rotation.y
	Input.parse_input_event(mouse)
	await frames(2)
	check(head.rotation.x != pose_before.x and player.rotation.y != old_yaw, "down mouse input still changes base look")
	check(camera.rotation.is_equal_approx(held_pose) and (-camera.global_basis.z).y > 0.8, "small look input keeps supine pose")
	var saved_pitch := head.rotation.x
	var saved_yaw := player.rotation.y
	await frames(75)
	check(camera.transform.is_equal_approx(rest_camera) and is_equal_approx(head.position.y, rest_height), "stand removes pitch and roll offsets and restores height")
	check(is_equal_approx(head.rotation.x, saved_pitch) and is_equal_approx(player.rotation.y, saved_yaw), "stand preserves last base look")
	await frames(85)
	# Sideways entries are real spill-triggered falls too, never a side pose.
	for sign_value in [-1, 1]:
		player.global_position = Vector3(0, 0.01, 2)
		player.velocity = Vector3(sign_value * 2, 0, 0)
		await frames(20)
		check(kd.phase == KnockdownState.Phase.DOWN and camera.rotation.x > deg_to_rad(65) and is_zero_approx(camera.rotation.z), "lateral spill entry uses same backward fall " + str(sign_value))
		await frames(85)
		check(camera.transform.is_equal_approx(rest_camera) and is_equal_approx(head.position.y, rest_height), "repeated fall has no accumulated offset " + str(sign_value))
		await frames(85)
	print("Prompt 7.3 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
