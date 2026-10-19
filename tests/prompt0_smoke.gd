extends SceneTree
## Run with the documented Godot executable, --path . --script res://tests/prompt0_smoke.gd.
## Requires a window: the headless display does not support mouse capture.

var failures: int = 0


func _initialize() -> void:
	root.grab_focus() # Establish the real-window input precondition once.
	call_deferred("run_checks")


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1


func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This input test requires a window; omit --headless.")
		quit(1)
		return
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	main.start_in_prototype = true
	root.add_child(main)
	current_scene = main
	# Keep the original empty-room movement regression independent of new props.
	main.get_node("PrototypeTestRoom/InteractionFixtures").free()
	main.get_node("PrototypeTestRoom/CartFixtures").free()
	var player: CharacterBody3D = main.get_node("PrototypeTestRoom/PlayerStart/Player")
	for action in ["move_forward", "move_backward", "move_left", "move_right", "jump", "interact", "grab", "throw", "toggle_mouse_capture"]:
		check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Input Map: " + action)
	await frames(60)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/prompt0_test_room.png")
	check(player.is_on_floor() and absf(player.global_position.y) < 0.02, "gravity and floor collision")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await frames(30)
	Input.action_release("move_forward")
	check(player.global_position.z < start.z - 1.0, "forward movement")
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(10)
	check(player.global_position.y > 0.3, "jump rises")
	await frames(90)
	check(player.is_on_floor(), "jump lands")
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		player.global_position = Vector3(0, 0.1, 0)
		player.velocity = Vector3.ZERO
		await frames(30)
		Input.action_press(action)
		await frames(180)
		Input.action_release(action)
		var position: Vector3 = player.global_position
		check(player.is_on_wall() and absf(position.x) < 9.5 and absf(position.z) < 9.5, "wall collision: " + action)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, -10000)
	var yaw_before := player.rotation.y
	player._unhandled_input(motion)
	print("MOUSE YAW before=", yaw_before, " after=", player.rotation.y)
	check(is_equal_approx(angle_difference(yaw_before, player.rotation.y), -100 * player.mouse_sensitivity), "mouse yaw")
	var head: Node3D = player.get_node("Head")
	check(is_equal_approx(head.rotation.x, deg_to_rad(85.0)), "mouse pitch clamp")
	var toggle := InputEventAction.new()
	toggle.action = "toggle_mouse_capture"
	toggle.pressed = true
	player._unhandled_input(toggle)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "release mouse")
	player._unhandled_input(toggle)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "recapture mouse")
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "release mouse on focus loss")
	print("Prompt 0 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
