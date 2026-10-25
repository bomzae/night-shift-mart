extends "res://tests/prompt11_5_smoke.gd"
func run_checks() -> void:
	await setup_thief()
	mart.get_node("AutoStock").top_up()
	manager._rng.seed = 115
	manager.patience_time = 90
	player.position = Vector3(0, 0.01, 20)
	# Keep the single stationary test player alive for a full business observation.
	player.health.max_health = 10000
	player.health.current_health = 10000
	var bus: TouristBus = mart.get_node("TouristBus")
	bus.tourist_count = 12
	rat = mart.get_node("Bosses").spawn_boss()
	check(mart.get_node("Thieves").spawn_thief() != null, "chaos thief active")
	# Respect the existing safe entrance spawn volume, as separate debug presses do.
	await frames(90)
	check(mart.get_node("Drunks").spawn_drunk() != null, "chaos drunk active")
	await frames(90)
	check(mart.get_node("LostFamilies").spawn_pair() != null, "chaos lost family active")
	bus.start_event()
	check(fire_manager.create_fire(Vector3(5, 0, 18)) != null, "chaos real fire active")
	check(mart.get_node("Accidents").create_spill(Vector3(-3, 0, 20)) != null, "chaos real spill active")
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(2, 0.02, 22))
	for i in range(8):
		var product := load(ProductCatalog.find([&"can", &"bread", &"tv"][i % 3]).scene_path).instantiate() as GrabbableBody
		mart.add_child(product)
		product.position = Vector3((i % 3 - 1) * 0.6, 0.7, 26 + i / 3.0)
	var shoppers := {}
	var peak_queue := 0
	var pursuit_ticks := 0
	var movement := 0.0
	var previous := rat.position
	for tick in range(7200):
		await frames(1)
		movement += rat.position.distance_to(previous)
		previous = rat.position
		if rat.state == KingRat.State.PURSUIT: pursuit_ticks += 1
		for person in bus.passengers:
			if is_instance_valid(person) and not person.visited_types.is_empty(): shoppers[person.get_instance_id()] = true
		peak_queue = maxi(peak_queue, manager.queue.size())
		if tick % 1800 == 0:
			print("CHAOS PROGRESS tick=", tick, " shoppers=", shoppers.size(), " queue=", peak_queue)
			for person in bus.passengers:
				if is_instance_valid(person): print(" CUSTOMER ", person.position, " state=", person.state, " purchased=", person.visited_types)

	print("FULL CHAOS shoppers=", shoppers.size(), " queue=", peak_queue, " pursuit_ticks=", pursuit_ticks, " boss_path=", movement, " player_hp=", player.health.current_health)
	check(bus.spawned_count == 12 and shoppers.size() >= 6 and peak_queue >= 2, "twelve tourists keep shopping and queueing during pursuit fire scatter and special events")
	check(pursuit_ticks > 60 and movement > 20 and player.health.current_health < 10000, "boss pursuit charge damage continue during full business chaos")
	check(rat.position.is_finite() and cart.position.is_finite() and not mart.get_tree().paused, "combined systems remain finite and do not lock world")
	interaction.camera.global_position = Vector3(2, 5, 26)
	interaction.camera.look_at(rat.global_position + Vector3.UP)
	await frames(2)
	root.get_texture().get_image().save_png("res://.godot/p115_chaos.png")
	quit(1 if failures else 0)
