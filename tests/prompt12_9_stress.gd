extends "res://tests/prompt12_8_stress.gd"

func run_checks() -> void:
	await setup_thief()
	mart.get_node("AutoStock").top_up()
	manager._rng.seed = 115
	manager.patience_time = 90
	player.position = Vector3(0, 0.01, 20)
	# Keep the no-input player alive, but tick real knockback/knockdown recovery.
	player.health.max_health = 10000
	player.health.current_health = 10000
	player.set_physics_process(true)
	var bus: TouristBus = mart.get_node("TouristBus")
	bus.tourist_count = 12
	rat = mart.get_node("Bosses").spawn_boss()
	rat.set_physics_process(false) # Assemble events before measuring the full approach/combat path.
	rat.receive_damage(1, null, player) # Business-under-combat fixture.
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
	var fell_outside := false
	var local_origin := rat.position
	var local_distance := rat.combat_distance()
	var local_still := 0.0
	var max_local_still := 0.0
	rat.set_physics_process(true)
	for tick in range(6301):
		await frames(1)
		movement += rat.position.distance_to(previous)
		previous = rat.position
		var required := rat.state in [KingRat.State.PURSUIT,KingRat.State.REPOSITION] and not rat.damage_reaction_active()
		var displacement := Vector2(rat.position.x-local_origin.x,rat.position.z-local_origin.z).length()
		if not required or displacement >= 0.3 or local_distance-rat.combat_distance() >= 0.3:
			local_origin = rat.position
			local_distance = rat.combat_distance()
			local_still = 0
		else:
			local_still += 1.0/60
		max_local_still = maxf(max_local_still,local_still)
		if not fell_outside and (rat.position.y < -2 or player.position.y < -2):
			fell_outside = true
			print("STRESS128 BOUNDS tick=",tick," rat=",rat.position," player=",player.position," state=",rat.state," velocity=",rat.velocity)
		if rat.state == KingRat.State.PURSUIT: pursuit_ticks += 1
		for person in bus.passengers:
			if is_instance_valid(person):
				recovered[person.get_instance_id()] = person.progress_watchdog.recovery_count
				if not person.visited_types.is_empty(): shoppers[person.get_instance_id()] = true
		peak_queue = maxi(peak_queue, manager.queue.size())
		if tick % 1800 == 0 or tick == 6300:
			print("CHAOS PROGRESS tick=", tick, " shoppers=", shoppers.size(), " queue=", peak_queue)
			for person in bus.passengers:
				if is_instance_valid(person): trace_person(person, tick)
			var stuck := 0
			var recoveries := 0
			for id in recovered: recoveries += recovered[id]
			for id in observations:
				var rows: Array = observations[id]
				if rows.size() >= 3 and rows[-1].moving and rows[-2].moving and rows[-3].moving and rows[-1].goal == rows[-2].goal and rows[-2].goal == rows[-3].goal and rows[-1].pos.distance_to(rows[-2].pos) < 0.4 and rows[-2].pos.distance_to(rows[-3].pos) < 0.4: stuck += 1
			print("STRESS128 seconds=",tick/60," active=",manager.customers.size()," stuck=",stuck," recoveries=",recoveries," queue=",manager.queue.size()," checkout=",manager.current_customer()!=null," exited=",manager.exited_count)
			print("STRESS128 POS rat=",rat.position," player=",player.position," cart=",cart.position)
			if tick == 5400: check(stuck == 0,"no same moving target remains stationary at 30 60 90 seconds")
			print("STRESS129 seconds=",tick/60," state=",KingRat.State.keys()[rat.state]," distance=",rat.combat_distance()," local_still=",local_still," max_local_still=",max_local_still," recoveries=",rat.combat_recovery_count," telegraph=",rat.telegraph_start_count," charge=",rat.charge_count," unpaid=",manager.unpaid_loss," path_abort=",manager.npc_recovery_abort_count," path_loss=",manager.npc_recovery_unpaid_loss)
			for person in bus.passengers:
				if is_instance_valid(person) and not person.recovery_abort_reason.is_empty(): print("ABORT129 id=",person.get_instance_id()," reason=",person.recovery_abort_reason," state=",person.state," basket=",person.picked_items)

	print("FULL CHAOS shoppers=", shoppers.size(), " queue=", peak_queue, " pursuit_ticks=", pursuit_ticks, " boss_path=", movement, " player_hp=", player.health.current_health)
	check(bus.spawned_count == 12 and shoppers.size() >= 6 and peak_queue >= 2, "twelve tourists keep shopping and queueing during pursuit fire scatter and special events")
	check(pursuit_ticks > 60 and movement > 20 and player.health.current_health < 10000, "boss pursuit charge damage continue during full business chaos")
	check(rat.position.is_finite() and cart.position.is_finite() and not mart.get_tree().paused, "combined systems remain finite and do not lock world")
	interaction.camera.global_position = Vector3(2, 5, 26)
	interaction.camera.look_at(rat.global_position + Vector3.UP)
	await frames(2)
	root.get_texture().get_image().save_png("res://.godot/p115_chaos.png")
	check(max_local_still < 12.1,"independent local movement monitor rejects prolonged pursuit freeze")
	check(manager.npc_recovery_unpaid_loss == 0,"AI path aborts never directly add unpaid loss in stress")
	quit(1 if failures else 0)

