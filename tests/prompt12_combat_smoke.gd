extends "res://tests/prompt12_smoke.gd"

func run_checks() -> void:
	await weapon_setup(WEAPONS[0])
	var input := InputEventAction.new()
	input.action = "throw"
	input.pressed = true
	Input.parse_input_event(input)
	await frames(3)
	await press("grab")
	check(interaction.is_charging and not weapon_body.swinging(), "throw charge blocks melee")
	interaction.cancel_charge()
	input.pressed = false
	Input.parse_input_event(input)
	await frames(2)
	await press("grab")
	await frames(20)
	await press("grab")
	check(rat.hit_count == 1, "repeated LMB respects cooldown")
	check(not weapon_body.start_swing(), "cooldown belongs to physical weapon")
	rat.set_physics_process(true)
	await frames(90)
	check(rat.is_aggro and rat.state in [KingRat.State.PURSUIT, KingRat.State.REPOSITION, KingRat.State.TELEGRAPH, KingRat.State.CHARGE], "melee recoil resumes active combat")
	# Re-enter melee while an actual attack overlaps: no invulnerability.
	rat.position = player.position + Vector3(0, 0, -0.8)
	rat.state = KingRat.State.CHARGE
	rat.charge_direction = Vector3.BACK
	rat._hit_targets.clear()
	rat._left = 0.5
	await press("grab")
	await frames(4)
	check(player.health.current_health == 70 and player.knockdown.active(), "swing can take real charge damage and knockdown")
	check(interaction.held_object == null and not weapon_body.swinging(), "knockdown releases weapon and cancels swing")
	await weapon_setup(WEAPONS[2])
	rat.position.z = 17.1
	await press("grab")
	await frames(25)
	check(rat.hit_count == 1, "broom reaches target beyond bat reach")
	await weapon_setup(WEAPONS[0])
	rat.position.z = 17.1
	await press("grab")
	await frames(25)
	check(rat.hit_count == 0, "bat cannot hit beyond its shorter range")
	# Actual weapon stays loose cargo and becomes a projectile on cart launch.
	await boss_setup()
	rat.set_physics_process(false)
	rat.position = Vector3(0, 0.01, 15)
	rat.current_health = 2000
	player.position = Vector3(8, 0.01, 10)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 10))
	var cargo: Array[WeaponBody] = []
	for i in range(2):
		var body := WeaponBody.new()
		body.weapon = WEAPONS[i]
		mart.add_child(body)
		body.position = cart.to_global(Vector3((i - 0.5) * 0.35, 0.8 + i * 0.2, 0))
		cargo.append(body)
	await frames(180)
	cart.refresh_load()
	check(cart.cargo.has(cargo[0]) and cart.cargo.has(cargo[1]), "bat and hammer remain physical cart cargo")
	check(not cargo[0].freeze and cargo[0].get_parent() == mart, "cargo is not parented or frozen inventory")
	check(cargo[0].linear_velocity.length() < 1 and cargo[1].linear_velocity.length() < 1, "normal weapon load settles")
	cart.launch_cart(Vector3.BACK, interaction.throw_multiplier(1), 1, interaction)
	check(cargo[0]._armed_seconds > 0 and cargo[1]._armed_seconds > 0, "cart bomb arms weapons through shared impact path")
	var max_separation := 0.0
	var unassisted := false
	for tick in range(120):
		await frames(1)
		for body in cargo:
			max_separation = maxf(max_separation, body.position.distance_to(cart.position))
			unassisted = unassisted or not body.cargo_assisted
	print("WEAPON CART max_separation=", max_separation, " unassisted=", unassisted)
	print("WEAPON CART hits=", rat.hit_count, " damage=", 2000-rat.current_health, " separation=", cargo[0].position.distance_to(cart.position), ",", cargo[1].position.distance_to(cart.position))
	check(rat.hit_count > 0, "loaded weapon cart damages real combat target")
	check(max_separation > 1 and unassisted, "weapon cargo freely scatters on impact")
	await cart_trial(true)
	check(rat.hit_count >= 2, "existing product cart bomb remains useful")
	# One continuous target: melee, real product throw, then loaded cart.
	await weapon_setup(WEAPONS[0])
	await press("grab")
	await frames(35)
	var melee_hp := rat.current_health
	await press("drop_item")
	weapon_body.position.x = 8
	rat.position = Vector3(0, 0.01, 15)
	var fruit: GrabbableBody = load(ProductCatalog.find(&"watermelon").scene_path).instantiate()
	mart.add_child(fruit)
	await place(fruit, interaction.camera.global_position + Vector3(0, 0, -1.5))
	await press("grab")
	check(interaction.held_object == fruit, "mixed fight switches from bat to real product")
	await frames(30)
	await press("throw")
	await frames(70)
	var fruit_hp := rat.current_health
	check(fruit_hp < melee_hp and rat.aggro_target == player, "same rat takes product damage after melee")
	cart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 10))
	var mixed_cargo: Array[GrabbableBody] = []
	for x in [-0.3, 0.3]:
		var can: GrabbableBody = load(ProductCatalog.find(&"can").scene_path).instantiate()
		mart.add_child(can)
		can.position = cart.to_global(Vector3(x, 0.8, 0))
		mixed_cargo.append(can)
	await frames(90)
	cart.launch_cart(Vector3.BACK, interaction.throw_multiplier(1), 1, interaction)
	await frames(100)
	var cargo_hits := mixed_cargo[0].impact_count + mixed_cargo[1].impact_count
	check(rat.current_health < fruit_hp and (cart.impact_count > 0 or cargo_hits > 0), "same fight continues with actual cart or armed cargo damage")
	print("MIXED HP melee=", melee_hp, " product=", fruit_hp, " cart=", rat.current_health, " body_hits=", cart.impact_count, " cargo_hits=", cargo_hits)
	# World-only misses and customers never acquire combat health/damage.
	await weapon_setup(WEAPONS[0])
	rat.position.x = 8
	var npc := manager.spawn_customer()
	npc.set_physics_process(false)
	npc.position = Vector3(0, 0.01, 18)
	await press("grab")
	await frames(30)
	check(weapon_body.durability == 14 and npc.get_node_or_null("PlayerHealth") == null, "human customer is not melee damage target")
	root.get_texture().get_image().save_png("res://.godot/p12_held.png")
	quit(1 if failures else 0)
