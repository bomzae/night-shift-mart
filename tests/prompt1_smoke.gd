extends SceneTree
## Real window required for action dispatch and mouse capture. No gameplay test hooks.

var failures: int = 0
var main: Node
var player: CharacterBody3D
var interaction: Node
var fixtures: Node3D
var include_cart_fixtures: bool = false


func _initialize() -> void:
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


func fresh_room() -> void:
	if is_instance_valid(main):
		main.free()
	main = load("res://scenes/main/main.tscn").instantiate()
	main.start_in_prototype = true
	root.add_child(main)
	current_scene = main
	player = main.get_node("PrototypeTestRoom/PlayerStart/Player")
	interaction = player.get_node("Interaction")
	fixtures = main.get_node("PrototypeTestRoom/InteractionFixtures")
	if not include_cart_fixtures:
		main.get_node("PrototypeTestRoom/CartFixtures").free()
	await frames(30)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set_physics_process(false)
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO


func place(body: RigidBody3D, point: Vector3) -> void:
	body.freeze = true
	body.global_position = point
	body.rotation = Vector3.ZERO
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	await frames(2)
	body.freeze = false
	body.sleeping = false
	await frames(1)


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	# Preserve all Prompt 1 physical assertions using a normal (half-charge) throw.
	await frames(ceili(0.5 * interaction.max_charge_time * Engine.physics_ticks_per_second) if action == "throw" else 2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	# Release now queues the impulse; sample after the physics server integrates it.
	await frames(2)


func actual_hit(object_name: String, target_name: String) -> Dictionary:
	await fresh_room()
	var body: GrabbableBody = fixtures.get_node(object_name)
	var target: CharacterBody3D = fixtures.get_node(target_name)
	player.global_position = Vector3(target.global_position.x, 0, -0.5)
	await place(body, player.global_position + Vector3(0, 1.6, -1.5))
	await press("grab")
	check(interaction.held_object == body, "prepare impact: " + object_name + " -> " + target_name)
	await frames(30)
	var target_start: Vector3 = target.global_position
	await press("throw")
	var launch_speed := body.linear_velocity.length()
	await frames(65)
	check(target.hit_count == 1, "exactly one actual contact damage: " + object_name + " -> " + target_name)
	check(target.hp < target.max_hp, "HP reduced by collision")
	var result := {"damage": target.last_damage, "impulse": target.last_impulse, "travel": target.global_position.distance_to(target_start), "speed": launch_speed, "displacement": target.global_position - target_start}
	await frames(30)
	check(target.hit_count == 1, "no repeated resting damage")
	return result


func flight_distance(object_name: String) -> float:
	await fresh_room()
	player.global_position = Vector3(6, 0, 6)
	var body: GrabbableBody = fixtures.get_node(object_name)
	await place(body, player.global_position + Vector3(0, 1.6, -1.5))
	await press("grab")
	await frames(30)
	var start: Vector3 = body.global_position
	await press("throw")
	for index in range(120):
		await frames(1)
		if body.global_position.y < 0.4:
			return start.z - body.global_position.z
	check(false, "flight reached floor: " + object_name)
	return 0.0


func run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Prompt 1 input tests require a window; omit --headless.")
		quit(1)
		return
	await fresh_room()
	player.global_position = Vector3(0, 0, 5)
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/prompt1_test_room.png")
	check(get_nodes_in_group("grabbable").size() == 5, "five shared grabbable objects")
	var prices := [5.0, 5.0, 50.0, 500.0, 500.0]
	var weights := [1.0, 8.0, 4.0, 1.0, 8.0]
	for index in range(5):
		var body: GrabbableBody = fixtures.get_node("Object" + ["A", "B", "C", "D", "E"][index])
		check(body.price == prices[index] and body.weight == weights[index] and body.mass == body.weight, "price/weight/mass: " + body.name)
	player.global_position = Vector3.ZERO
	var object: GrabbableBody = fixtures.get_node("ObjectA")
	await place(object, Vector3(0, 1.6, -4))
	await press("grab")
	check(interaction.held_object == null, "reject out-of-range grab")
	await place(object, Vector3(0, 1.6, -2))
	await press("grab")
	check(interaction.held_object == object and object.holder == interaction, "grab via action")
	check(not object.freeze and object.gravity_scale == 0.0, "held body remains simulated")
	await frames(45)
	check(object.global_position.distance_to(object.hold_target) < 0.25, "carry converges with natural lag")
	player.set_physics_process(true)
	Input.action_press("move_right")
	await frames(25)
	Input.action_release("move_right")
	await frames(30)
	check(player.global_position.x > 1.0 and object.global_position.x > 1.0, "carry while moving")
	player.set_physics_process(false)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(180, 0)
	Input.parse_input_event(motion)
	await frames(40)
	check(object.global_position.distance_to(object.hold_target) < 0.35, "carry follows camera turn")
	await press("grab")
	check(interaction.held_object == null and object.holder == null and object.gravity_scale == 1.0, "second grab drops and restores gravity")
	await frames(75)
	check(object.global_position.y < 0.45 and object.global_position.y > 0.1, "drop lands on floor")
	check(not object.get_collision_exceptions().has(player), "player collision restored after separation")
	await press("throw")
	check(interaction.held_object == null, "empty throw is safe")
	await place(object, player.global_position - interaction.camera.global_basis.z * 1.7 + Vector3.UP * 1.6)
	await press("toggle_mouse_capture")
	await press("grab")
	check(interaction.held_object == null, "released mouse does not grab")
	await press("toggle_mouse_capture")

	await fresh_room()
	object = fixtures.get_node("ObjectA")
	await place(object, Vector3(0, 1.6, -2))
	await press("grab")
	await frames(20)
	await press("throw")
	check(interaction.held_object == null and object.linear_velocity.z < -10.0, "throw releases and launches forward")
	check(interaction.throw_speed(8.0) < interaction.throw_speed(1.0), "weight reduces throw speed")
	check(interaction.damage_for(500.0) > interaction.damage_for(5.0), "price increases bounded prototype damage")

	# Move toward the north wall with a held body and monitor the whole path.
	await fresh_room()
	object = fixtures.get_node("ObjectA")
	player.global_position = Vector3(0, 0, -6)
	await place(object, Vector3(0, 1.6, -7.5))
	await press("grab")
	player.set_physics_process(true)
	Input.action_press("move_forward")
	var bounded := true
	for index in range(120):
		await frames(1)
		bounded = bounded and object.global_position.z > -9.8 and object.linear_velocity.length() < 12.0
	Input.action_release("move_forward")
	check(bounded, "held wall approach: no tunneling or explosive speed")
	await frames(60)
	check(object.global_position.z > -9.8, "object remains inside wall after cramped release")
	# A wall blocks selection even when a body lies within the ray distance.
	player.set_physics_process(false)
	interaction.drop_held()
	player.global_position = Vector3(0, 0, -9)
	await place(object, Vector3(0, 1.6, -11))
	await press("grab")
	check(interaction.held_object == null, "cannot grab through wall")

	await fresh_room()
	object = fixtures.get_node("ObjectA")
	await place(object, Vector3(0, 1.6, -2))
	await press("grab")
	player.get_node("Head").rotation.x = deg_to_rad(-85.0)
	await frames(90)
	check(object.global_position.y > 0.25 and object.linear_velocity.length() < 2.0, "held downward aim respects floor without violent jitter")
	var other: GrabbableBody = fixtures.get_node("ObjectB")
	check(other.holder == null, "only one object carried")
	interaction.drop_held()

	var light_range := await flight_distance("ObjectA")
	var heavy_range := await flight_distance("ObjectB")
	print("Flight distances: light=%.2f heavy=%.2f" % [light_range, heavy_range])
	check(light_range > heavy_range + 1.0, "actual light flight travels farther")

	var cheap := await actual_hit("ObjectA", "TestDamageTarget")
	var expensive := await actual_hit("ObjectD", "TestDamageTarget")
	check(expensive.damage > cheap.damage and cheap.damage > 0.0, "actual high-price impact deals more damage")
	var light := await actual_hit("ObjectA", "KnockbackTarget")
	var heavy := await actual_hit("ObjectB", "KnockbackTarget")
	check(heavy.speed < light.speed, "actual heavy launch slower than light")
	check(light.travel > 0.02 and heavy.travel > light.travel, "larger momentum gives stronger actual knockback")
	check(heavy.impulse > light.impulse, "weight changes impact impulse independently of price")
	check(is_equal_approx(heavy.damage, light.damage), "same price keeps damage equal across weights")
	var target: Node = fixtures.get_node("KnockbackTarget")
	target.receive_impact(1000.0, Vector3.ZERO)
	check(target.hp == 0.0 and target.get_node("Mesh").material_override.albedo_color == Color.DIM_GRAY, "zero HP changes target color")
	print("Prompt 1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
