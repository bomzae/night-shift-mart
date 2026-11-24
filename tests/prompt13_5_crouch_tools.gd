extends "res://tests/prompt4_smoke.gd"
func run_checks() -> void:
	await setup_mart()
	player.position = Vector3(0,0.01,3)
	Input.action_press("crouch")
	player.update_stance()
	var mop: Mop = mart.get_node("Mop")
	await place(mop,Vector3(0,0.9,1.7))
	interaction.camera.look_at(mop.global_position)
	interaction.toggle_grab()
	check(interaction.held_object == mop,"crouched ray grabs physical mop")
	var accidents: AccidentManager = mart.get_node("Accidents")
	var spill := accidents.create_spill(Vector3(0,0.01,2.4),[player.get_rid()])
	spill.activation_delay = 60
	interaction.camera.rotation.x = deg_to_rad(-25)
	await frames(80)
	var cleaned := false
	for tick in range(240):
		player.rotation.y = sin(tick / 60.0 * TAU * 1.5)*0.8
		await frames(1)
		if not is_instance_valid(spill):
			cleaned = true
			break
		cleaned = cleaned or spill.clean_progress > 0.05
	check(cleaned,"crouched physical mop strokes clean actual spill")
	interaction.drop_held(true)
	player.rotation = Vector3.ZERO
	player.position = Vector3(0,0.01,23)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart,Vector3(0,0.02,21))
	check(cart.begin_carry(interaction,player),"crouched player can acquire cart control")
	interaction.held_object = cart
	var start := cart.global_position
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(50)
	Input.action_release("move_forward")
	check(interaction.held_object == cart and cart.global_position.distance_to(start)>0.1,"crouched movement drives physical cart")
	interaction.drop_held(true)
	check(cart.holder == null,"crouched cart release restores free body")
	Input.action_release("crouch")
	quit(1 if failures else 0)
