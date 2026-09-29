extends "res://tests/prompt1_smoke.gd"
## Reuse room/physics fixtures, but exercise press, hold, release and cancellation.

var charge_frames: int = 0
var last_launch_speed: float = 0.0


func send_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func press(action: String) -> void:
	var body: GrabbableBody = interaction.held_object
	send_action(action, true)
	if action == "throw":
		await frames(charge_frames)
	else:
		await frames(2)
	send_action(action, false)
	await frames(2)
	if action == "throw" and is_instance_valid(body):
		last_launch_speed = body.linear_velocity.length()


func prepare() -> GrabbableBody:
	await fresh_room()
	var body: GrabbableBody = fixtures.get_node("ObjectA")
	await place(body, Vector3(0, 1.6, -2))
	await press("grab")
	await frames(30)
	return body


func run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Charge input tests require a window; omit --headless.")
		quit(1)
		return
	var body := await prepare()
	check(not interaction.charge_bar.visible, "charge bar hidden at rest")
	send_action("throw", true)
	await frames(1) # Input.parse_input_event dispatches on the next main-loop turn.
	check(interaction.is_charging and interaction.held_object == body, "press starts charging without launching")
	await frames(18)
	var partial: float = interaction.charge_ratio
	check(partial > 0.1 and partial < 0.5, "hold time increases normalized charge")
	check(interaction.charge_bar.visible and absf(interaction.charge_bar.value - partial) < 0.01, "bar follows partial charge")
	send_action("throw", true)
	await frames(1)
	check(interaction.charge_ratio >= partial and interaction.charge_ratio < partial + 0.05, "duplicate press does not reset charge")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/charge_partial.png")
	await frames(100)
	check(interaction.charge_ratio == 1.0 and interaction.held_object == body, "charge clamps at one without auto throw")
	check(interaction.charge_bar.value == 1.0, "bar fills at maximum")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/charge_full.png")
	send_action("throw", false)
	await frames(2)
	check(interaction.held_object == null and body.linear_velocity.z < -20.0, "release launches full charge forward")
	check(not interaction.is_charging and interaction.charge_ratio == 0.0 and not interaction.charge_bar.visible, "throw resets charge and hides UI")
	send_action("throw", true)
	await frames(5)
	check(not interaction.is_charging, "empty hand cannot charge")
	send_action("throw", false)

	body = await prepare()
	send_action("throw", true)
	await frames(15)
	await press("grab")
	send_action("throw", false)
	await frames(2)
	check(interaction.held_object == null and interaction.charge_ratio == 0.0 and body.throw_damage == 0.0, "drop cancels charge and late release cannot throw")

	body = await prepare()
	send_action("throw", true)
	await frames(15)
	body.end_carry()
	send_action("throw", false)
	await frames(2)
	check(interaction.held_object == null and not interaction.is_charging and body.throw_damage == 0.0, "lost carry ownership cancels before release")

	body = await prepare()
	send_action("throw", true)
	await frames(15)
	player.global_position = Vector3(6, 0, 0)
	# Prompt 6.2: preserve the unrecoverable-separation/queued-throw contract,
	# now allowing the safety grace instead of requiring an immediate drop.
	body.freeze = true
	send_action("throw", false)
	await frames(ceili(interaction.break_grace_time * Engine.physics_ticks_per_second) + 3)
	check(interaction.held_object == null and interaction.charge_ratio == 0.0 and body.throw_damage == 0.0, "break distance overrides pending charged release")

	body = await prepare()
	send_action("throw", true)
	await frames(15)
	body.queue_free()
	await frames(2)
	send_action("throw", false)
	await frames(2)
	check(not interaction.is_charging and interaction.charge_ratio == 0.0, "deleted object cancels safely")

	body = await prepare()
	send_action("throw", true)
	await frames(15)
	await press("toggle_mouse_capture")
	send_action("throw", false)
	await frames(2)
	check(not interaction.is_charging and interaction.charge_ratio == 0.0 and interaction.held_object == body, "Esc cancels charge but preserves carry")
	await press("toggle_mouse_capture")
	send_action("throw", false)
	await frames(2)
	check(body.throw_damage == 0.0, "recapture does not launch stale release")
	send_action("throw", true)
	await frames(15)
	interaction._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	send_action("throw", false)
	await frames(2)
	check(not interaction.is_charging and body.throw_damage == 0.0, "focus loss cancels charge")

	body = await prepare()
	charge_frames = 0
	await press("throw")
	check(interaction.held_object == null and body.linear_velocity.z < -4.0, "same-frame tap press/release still tosses")

	# Same height and horizontal direction, first-floor-contact distances.
	var distances: Array[float] = []
	var speeds: Array[float] = []
	for ticks in [0, 36, 90]:
		charge_frames = ticks
		distances.append(await flight_distance("ObjectA"))
		speeds.append(last_launch_speed)
	check(distances[0] < distances[1] and distances[1] < distances[2], "1kg tap < half < full flight distance")
	check(speeds[0] < speeds[1] and speeds[1] < speeds[2], "1kg tap < half < full actual launch speed")
	charge_frames = 0
	var heavy_tap := await flight_distance("ObjectB")
	charge_frames = 90
	var heavy_full := await flight_distance("ObjectB")
	check(heavy_full > heavy_tap + 1.0, "8kg full charge travels farther than tap")
	check(distances[0] > heavy_tap and distances[2] > heavy_full, "weight penalty preserved at tap and full charge")
	var pricey_full := await flight_distance("ObjectD")
	check(absf(pricey_full - distances[2]) < 0.25, "same weight and charge: price does not change flight")
	print("CHARGE FLIGHT 1kg tap=%.2f half=%.2f full=%.2f; 8kg tap=%.2f full=%.2f; expensive 1kg full=%.2f" % [distances[0], distances[1], distances[2], heavy_tap, heavy_full, pricey_full])
	print("CHARGE SPEED 1kg tap=%.2f half=%.2f full=%.2f" % [speeds[0], speeds[1], speeds[2]])

	charge_frames = 0
	var tap := await actual_hit("ObjectA", "KnockbackTarget")
	charge_frames = 90
	var full := await actual_hit("ObjectA", "KnockbackTarget")
	var expensive := await actual_hit("ObjectD", "TestDamageTarget")
	check(full.damage > tap.damage, "actual full charge damage exceeds tap")
	check(full.impulse > tap.impulse and full.travel > tap.travel, "actual full charge knockback exceeds tap")
	check(expensive.damage > full.damage, "full charge preserves price damage advantage")
	check(full.impulse <= interaction.max_knockback_impulse, "normal full charge respects impulse cap")
	print("CHARGE IMPACT tap damage=%.2f impulse=%.2f; full damage=%.2f impulse=%.2f; expensive full damage=%.2f" % [tap.damage, tap.impulse, full.damage, full.impulse, expensive.damage])
	# Deliberately lower the cap to verify clamping on a real high-momentum hit.
	body = await prepare()
	interaction.drop_held()
	var target: Node3D = fixtures.get_node("KnockbackTarget")
	player.global_position = Vector3(3, 0, -0.5)
	await place(body, Vector3(3, 1.6, -2))
	interaction.max_knockback_impulse = 0.4
	await press("grab")
	await frames(30)
	await press("throw")
	await frames(65)
	check(target.hit_count == 1 and target.last_impulse <= 0.401 and target.last_impulse > 0.0, "configured impulse cap clamps an actual hit")
	print("Prompt 1.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
