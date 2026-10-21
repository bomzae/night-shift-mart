extends "res://tests/prompt9_smoke.gd"
var bosses: KingRatManager
var rat: KingRat

func boss_setup() -> void:
	await setup_thief()
	bosses = mart.get_node("Bosses")
	await press("spawn_king_rat")
	rat = bosses.boss
	check(is_instance_valid(rat), "R spawns real King Rat")
	rat._charge_wait = 1000
	await frames(35)

func projectile_trial(type: StringName, charge: float) -> float:
	await boss_setup()
	rat.set_physics_process(false)
	rat.global_position = Vector3(0, 0.01, 2)
	rat.max_health = 2000
	rat.current_health = 2000
	var product: GrabbableBody = load(ProductCatalog.find(type).scene_path).instantiate()
	mart.get_node("Products").add_child(product)
	await place(product, Vector3(0, 0.85, 4))
	product.gravity_scale = 0
	product.launch(Vector3.FORWARD, interaction.throw_speed(product.weight, charge), interaction.damage_for(product.price, charge))
	await frames(50)
	check(rat.hit_count == 1, "actual product impact once: " + String(type))
	check(is_equal_approx(rat.last_damage, interaction.damage_for(product.price, charge)), "existing price/charge formula: " + String(type))
	return rat.last_damage

func cart_trial(loaded: bool) -> float:
	await boss_setup()
	rat.set_physics_process(false)
	rat.global_position = Vector3(0, 0.01, 4.3)
	rat.current_health = 2000
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 1))
	await frames(50)
	var cargo: Array[GrabbableBody] = []
	if loaded:
		for x in [-0.3, 0.3]:
			var product: GrabbableBody = load(ProductCatalog.find(&"can").scene_path).instantiate()
			mart.get_node("Products").add_child(product)
			await place(product, cart.to_global(Vector3(x, 0.9, 0)))
			cargo.append(product)
		await frames(90)
		cart.refresh_load()
		check(cart.cargo.size() == 2, "two real cart bomb products loaded")
	cart.launch_cart(Vector3.BACK, interaction.throw_multiplier(1), 1, interaction)
	print("CART START ", cart.global_position, " rat=", rat.global_position, " mask=", cart.collision_mask)
	if loaded: check(cargo[0]._armed_seconds > 0 and cargo[1]._armed_seconds > 0, "cart bomb arms existing individual damage path")
	await frames(90)
	print("CART END ", cart.global_position, " velocity=", cart.linear_velocity, " rat=", rat.global_position)
	check(cart.impact_count > 0 and rat.hit_count > 0, "real cart launch damages boss")
	check(is_equal_approx(cart.last_impact_damage, minf(cart.max_impact_damage, cart.last_impact_speed * cart.last_impact_mass * cart.impact_damage_multiplier)), "cart keeps existing impact formula at contact mass")
	if loaded:
		var scattered := false
		for body in cargo:
			if body.global_position.distance_to(cart.global_position) > 1: scattered = true
		check(scattered, "cart bomb physically scatters cargo")
		check(rat.hit_count >= 2 and 2000-rat.current_health > cart.last_impact_damage, "cart bomb adds individual product hits")
	print("BOSS CART loaded=", loaded, " mass=", cart.last_impact_mass, " hits=", rat.hit_count, " damage=", 2000-rat.current_health)
	return cart.last_impact_mass

func run_checks() -> void:
	await boss_setup()
	check(bosses.spawn_boss() == null, "one boss including defeat animation")
	check(bosses.health_bar.visible and rat.current_health == 300, "active boss health UI and default HP")
	interaction.camera.look_at(rat.global_position + Vector3.UP)
	await frames(3)
	root.get_texture().get_image().save_png("res://.godot/p11_boss.png")
	check(rat.collision_layer == 128 and rat.collision_mask == 129 and not rat.is_in_group("human_npcs"), "monster layer separate from human steering")
	check((player.collision_mask & 128) != 0 and (mart.get_node("Cart").collision_mask & 128) != 0, "player and cart detect monster")
	rat.receive_damage(10)
	check(rat.current_health == 290 and rat._flash > 0, "damage and visible feedback")
	rat.receive_impact(50, Vector3.RIGHT * 18)
	check(rat.state == KingRat.State.STAGGER and rat.external_velocity.x > 0, "strong impact staggers and pushes")
	await frames(35)
	check(rat.state != KingRat.State.STAGGER, "short stagger recovers")
	var previous_health := rat.current_health
	PhysicsPush.apply(rat, Vector3.LEFT * 5)
	check(rat.current_health == previous_health, "shared tool push does not deal damage")
	rat.receive_damage(1000)
	rat.receive_damage(1000)
	check(bosses.bosses_defeated == 1 and rat.state == KingRat.State.DEFEATED, "defeat statistic once")
	check(not bosses.health_bar.visible, "defeat hides health UI")
	check(is_instance_valid(rat), "defeat has visible delay")
	await frames(100)
	check(not is_instance_valid(rat) and bosses.spawn_boss() != null, "defeat despawns and permits new event")
	var cheap := await projectile_trial(&"can", 0)
	var full := await projectile_trial(&"can", 1)
	var expensive := await projectile_trial(&"tv", 1)
	check(full > cheap and expensive > full, "charge and price change real boss damage")
	var empty_mass := await cart_trial(false)
	var loaded_mass := await cart_trial(true)
	check(loaded_mass > empty_mass, "loaded cart uses greater effective mass")

	await boss_setup()
	rat.global_position = Vector3(0, 0.01, 8) # Return around the central shelf row after a charge.
	var product := await stock("can")
	var customer := manager.spawn_customer([&"can"])
	customer.set_physics_process(false)
	for tick in range(1200):
		await frames(1)
		if not is_instance_valid(product): break
	check(not is_instance_valid(product), "boss walks to shelf and eats actual reserved stock")
	check(bosses.boss_product_loss_value == 5 and mart.get_node("Shelves/CanShelf").stock_count == 0, "eat removes stock and records exact loss")
	check(not manager.valid_goods(customer), "eaten reservation triggers ordinary out of stock")
	check(not rat.finish_eating() and bosses.boss_product_loss_value == 5, "eaten product cannot count twice")
	check(manager.unpaid_loss == 0 and fire_manager.fire_damage_value == 0 and thieves.stolen_goods_value == 0, "boss loss is separate from other ledgers")
	var floor_at := rat.global_position + Vector3(0, 0.2, -0.6)
	product = await make_product(floor_at)
	for tick in range(240):
		await frames(1)
		if not is_instance_valid(product): break
	check(not is_instance_valid(product) and bosses.boss_product_loss_value == 10, "floor product is eaten through the same real loss path")
	product = await make_product(Vector3(0, 0.2, 2))
	rat.food = product
	product.begin_carry(interaction, player)
	check(not rat.valid_food(product), "player grab invalidates food")
	product.end_carry()
	check(rat.valid_food(product), "dropped floor food becomes eligible")
	product.queue_free()
	check(not rat.valid_food(product), "queued sale burn theft deletion invalidates food")

	await boss_setup()
	player.set_physics_process(true)
	player.global_position = Vector3(0, 0.01, 4.2)
	rat.global_position = Vector3(0, 0.01, 2)
	rat.begin_telegraph()
	var direction := rat.charge_direction
	await frames(20)
	check(rat.state == KingRat.State.TELEGRAPH, "charge has readable telegraph")
	await frames(55)
	check(player.knockdown.fall_count == 1, "actual charge collision triggers shared player knockdown")
	check(rat.charge_direction.is_equal_approx(direction), "charge does not home on player")
	await frames(100)
	check(not player.knockdown.active(), "player automatically recovers")

	await boss_setup()
	player.global_position = Vector3(0, 0.01, 4.2)
	rat.global_position = Vector3(0, 0.01, 2)
	rat.begin_telegraph()
	player.global_position.x = 3
	await frames(90)
	check(player.knockdown.fall_count == 0 and absf(rat.global_position.x) < 0.2, "side dodge avoids fixed charge")
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	check(child != null, "other family event remains available")
	if child != null:
		var parent: LostParent = child.parent_npc
		var old_state := parent.state
		parent.global_position = Vector3(0, 0.01, 4.2)
		rat.global_position = Vector3(0, 0.01, 2)
		player.global_position = parent.global_position
		rat.begin_telegraph()
		player.global_position.x = 5
		await frames(70)
		check(parent.knockdown.active() and parent.state == old_state, "human hit uses shared knockdown without resetting event")
		await frames(100)
		check(not parent.knockdown.active() and parent.state == old_state, "human event state survives recovery")
	mart.get_node("AutoStock").top_up()
	await frames(150)
	var bus: TouristBus = mart.get_node("TouristBus")
	check(bus.start_event(), "bus starts during boss")
	check(thieves.spawn_thief() != null, "thief can spawn during boss")
	await frames(300)
	check(bus.spawned_count > 0 and is_instance_valid(rat), "business and boss run concurrently")
	await boss_setup()
	player.global_position = Vector3(0, 0.01, 4.5)
	rat.global_position = Vector3(0, 0.01, 1.4)
	await grab_tool()
	interaction.camera.look_at(rat.global_position + Vector3.UP * 0.7)
	await frames(20)
	var before := rat.global_position
	var hp := rat.current_health
	Input.action_press("use_tool")
	await frames(60)
	Input.action_release("use_tool")
	check(rat.global_position.distance_to(before) > 0.03 and tool.capacity < 100, "actual extinguisher spray physically pushes monster")
	check(rat.current_health == hp, "spray is not a free damage weapon")
	print("Prompt 11 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
