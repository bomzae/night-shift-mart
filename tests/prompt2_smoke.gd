extends "res://tests/prompt1_smoke.gd"

var cart: ShoppingCart
var zone: Node3D


func setup_cart() -> void:
	include_cart_fixtures = true
	await fresh_room()
	zone = main.get_node("PrototypeTestRoom/CartFixtures")
	cart = zone.get_node("Cart")
	await frames(30)


func aim_handle() -> void:
	player.global_position = cart.global_position + Vector3(0, 0, 2.3)
	player.global_position.y = 0.01
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	interaction.camera.look_at(cart.get_node("HandleArea").global_position)
	await frames(2)


func load_items(names: Array) -> void:
	var points := [Vector3(-0.35, 0.9, -0.35), Vector3(0.35, 0.9, -0.35), Vector3(-0.35, 0.9, 0.35), Vector3(0.35, 0.9, 0.35), Vector3(0, 1.5, 0)]
	for index in range(names.size()):
		await place(fixtures.get_node(names[index]), cart.to_global(points[index]))
	await frames(90)
	cart.refresh_load()


func charge_launch(ticks: int) -> void:
	var event := InputEventAction.new()
	event.action = "throw"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(ticks)
	event = InputEventAction.new()
	event.action = "throw"
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)


func launch_trial(heavy: bool, ticks: int) -> Dictionary:
	await setup_cart()
	if heavy:
		await load_items(["ObjectB", "ObjectE"])
	await aim_handle()
	await press("grab")
	check(interaction.held_object == cart, "handle selected for launch")
	await frames(30)
	var weight := cart.loaded_weight
	await charge_launch(ticks)
	var speed := Vector2(cart.linear_velocity.x, cart.linear_velocity.z).length()
	check(interaction.held_object == null and not interaction.is_charging, "cart launch releases shared charge state")
	return {"speed": speed, "weight": weight}


func impact_trial(heavy: bool) -> Dictionary:
	await setup_cart()
	if heavy:
		await load_items(["ObjectB", "ObjectE"])
	var target: CharacterBody3D = zone.get_node("CartTarget")
	target.global_position = Vector3(7, 0, -1)
	await frames(2)
	cart.linear_velocity = Vector3(0, 0, -8)
	for body in cart.cargo:
		body.linear_velocity = cart.linear_velocity
	await frames(90)
	check(cart.impact_count > 0 and target.hp < target.max_hp, "actual chassis impact damages target")
	check(target.global_position.z < -1.05, "actual chassis impact knocks back target")
	return {"speed": cart.last_impact_speed, "mass": cart.last_impact_mass, "damage": cart.last_impact_damage}


func run_checks() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Cart input tests require a window.")
		quit(1)
		return
	await setup_cart()
	check(cart.mass == cart.cart_base_mass and cart.mass > 0, "cart scene has physical chassis mass")
	check(cart.global_basis.y.dot(Vector3.UP) > 0.95, "empty cart rests upright")
	await aim_handle()
	check(interaction.find_candidate() == cart, "handle ray selects cart")
	await press("grab")
	check(interaction.held_object == cart and cart.holder == interaction, "grab cart through common input")
	var start := cart.global_position
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(cart.global_position.z < start.z - 1.0, "W pushes cart using physics")
	await frames(20)
	var forward_position := cart.global_position
	Input.action_press("move_backward")
	await frames(60)
	Input.action_release("move_backward")
	check(cart.global_position.z > forward_position.z + 1.0, "S pulls cart using physics")
	await press("grab")
	check(interaction.held_object == null and cart.holder == null and not cart.freeze, "grab again releases simulated cart")
	player.set_physics_process(false)

	await setup_cart()
	var empty_accel := cart.push_acceleration()
	var empty_turn := cart.steering_acceleration()
	var empty_damage := cart.damage_at_speed(8)
	await load_items(["ObjectB", "ObjectE"])
	check(is_equal_approx(cart.loaded_weight, 16), "load volume sums two real weights")
	check(is_equal_approx(cart.effective_mass, 28) and cart.mass == 12, "effective load mass without duplicating physics mass")
	check(cart.push_acceleration() < empty_accel and cart.steering_acceleration() < empty_turn, "heavy cargo slows acceleration and steering")
	check(cart.damage_at_speed(8) > empty_damage, "heavy impact power exceeds empty at equal speed")
	await aim_handle()
	check(interaction.find_candidate() == cart, "loaded basket does not steal handle selection")
	var product: GrabbableBody = fixtures.get_node("ObjectB")
	# Aim over the side at a real loose product.
	player.global_position = cart.global_position + Vector3(-1.4, 0.7, 0)
	interaction.camera.look_at(product.global_position)
	await frames(2)
	check(interaction.find_candidate() == product, "product ray selects cargo independently")
	await press("grab")
	await frames(10)
	check(interaction.held_object == product and cart.loaded_weight < 16, "grabbed cargo leaves counted load")
	interaction.drop_held()

	var empty_tap := await launch_trial(false, 0)
	var empty_full := await launch_trial(false, 90)
	var heavy_tap := await launch_trial(true, 0)
	var heavy_full := await launch_trial(true, 90)
	check(empty_full.speed > empty_tap.speed * 2, "empty full launch clearly faster than tap")
	check(heavy_full.speed > heavy_tap.speed * 2, "heavy full launch clearly faster than tap")
	check(heavy_full.speed < empty_full.speed, "loaded launch slower than empty")
	print("CART SPEED empty tap=%.2f full=%.2f heavy tap=%.2f full=%.2f" % [empty_tap.speed, empty_full.speed, heavy_tap.speed, heavy_full.speed])
	var empty_hit := await impact_trial(false)
	var heavy_hit := await impact_trial(true)
	check(heavy_hit.damage > empty_hit.damage, "actual loaded impact stronger at comparable speed")
	print("CART IMPACT empty=", empty_hit, " heavy=", heavy_hit)

	await setup_cart()
	await load_items(["ObjectA", "ObjectB", "ObjectC", "ObjectD", "ObjectE"])
	check(cart.cargo.size() >= 3, "multiple loose objects physically stay in basket")
	var initial_cargo: Array[GrabbableBody] = cart.cargo.duplicate()
	var target: Node3D = zone.get_node("CartTarget")
	# Chassis knockback is tested above. Keep this damage receiver stationary:
	# a retreating dummy can outrun the loose cargo before its first contact.
	target.receive_knockback = false
	# Catch the physically scattered cargo across the basket width. This checks
	# damage delivery, not a frame-exact hit on the narrow gameplay dummy.
	var catch_shape: BoxShape3D = target.get_node("CollisionShape3D").shape.duplicate()
	catch_shape.size.x = 3.6
	target.get_node("CollisionShape3D").shape = catch_shape
	var catch_mesh: BoxMesh = target.get_node("Mesh").mesh.duplicate()
	catch_mesh.size.x = 3.6
	target.get_node("Mesh").mesh = catch_mesh
	target.global_position = Vector3(7, 0, -4)
	await aim_handle()
	await press("grab")
	await frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/cart_loaded.png")
	await charge_launch(90)
	await frames(150)
	var escaped := 0
	var product_hits := 0
	for body in initial_cargo:
		if not cart.cargo.has(body):
			escaped += 1
		product_hits += body.impact_count
	check(cart.impact_count > 0, "Cart Bomb chassis hits target")
	check(escaped > 0, "Cart Bomb physically ejects cargo")
	check(product_hits > 0, "Cart Bomb individual cargo also deals impact damage")
	print("CART BOMB loaded=", initial_cargo.size(), " escaped=", escaped, " product_hits=", product_hits, " chassis_hits=", cart.impact_count)

	await setup_cart()
	player.global_position = cart.global_position + Vector3(1.6, 0.01, 0)
	player.global_position.y = 0.01
	player.set_physics_process(true)
	await frames(10)
	Input.action_press("jump")
	Input.action_press("move_left")
	await frames(1)
	Input.action_release("jump")
	await frames(28)
	Input.action_release("move_left")
	await frames(60)
	var local_rider := cart.to_local(player.global_position)
	check(player.is_on_floor() and absf(local_rider.x) < 0.8 and local_rider.y > 0.3, "player jumps into basket with no riding mode")
	var rider_start := player.global_position
	cart.apply_central_impulse(Vector3(0, 0, -3) * cart.mass)
	await frames(60)
	check(player.global_position.z < rider_start.z - 0.4 and absf(cart.to_local(player.global_position).z) < 1, "physical cart floor carries rider when pushed")

	await setup_cart()
	await place(cart, Vector3(-7, 1.1, -5))
	await frames(30)
	var ramp_start := cart.global_position
	await frames(150)
	check(cart.global_position.z > ramp_start.z + 0.2, "cart rolls downhill under gravity")

	await setup_cart()
	await place(cart, Vector3(-7, 0.05, 3))
	await aim_handle()
	await press("grab")
	await frames(20)
	await charge_launch(90)
	var tipped := false
	for index in range(240):
		await frames(1)
		tipped = tipped or cart.global_basis.y.dot(Vector3.UP) < 0.0
	check(tipped, "full launch ramp accident can physically overturn cart")
	# A crash can land upright again. Independently verify recovery from a
	# settled inverted fixture, without any orientation reset in gameplay.
	await setup_cart()
	cart.freeze = true
	cart.rotation.z = PI
	cart.global_position = Vector3(7, 1.4, 4)
	await frames(2)
	cart.freeze = false
	cart.sleeping = false
	await frames(120)
	check(cart.global_basis.y.dot(Vector3.UP) < -0.5, "recovery fixture is genuinely inverted")
	var reached := false
	for index in range(12):
		var handle: Vector3 = cart.get_node("HandleArea").global_position
		var angle := index * TAU / 12
		player.global_position = handle + Vector3(cos(angle) * 1.6, 0, sin(angle) * 1.6)
		player.global_position.y = 0.01
		interaction.camera.look_at(handle)
		await frames(2)
		if interaction.find_candidate() == cart:
			await press("grab")
			reached = interaction.held_object == cart
			break
	check(reached, "accident handle can be selected with grab input")
	await frames(240)
	check(cart.global_basis.y.dot(Vector3.UP) > 0.7, "handle torque physically rights cart without reset")
	print("Prompt 2 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
