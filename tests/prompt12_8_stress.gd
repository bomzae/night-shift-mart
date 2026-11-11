extends "res://tests/prompt11_5_smoke.gd"
var observations := {}
var recovered := {}
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
	rat.set_physics_process(true)
	for tick in range(5401):
		await frames(1)
		movement += rat.position.distance_to(previous)
		previous = rat.position
		if not fell_outside and (rat.position.y < -2 or player.position.y < -2):
			fell_outside = true
			print("STRESS128 BOUNDS tick=",tick," rat=",rat.position," player=",player.position," state=",rat.state," velocity=",rat.velocity)
		if rat.state == KingRat.State.PURSUIT: pursuit_ticks += 1
		for person in bus.passengers:
			if is_instance_valid(person):
				recovered[person.get_instance_id()] = person.progress_watchdog.recovery_count
				if not person.visited_types.is_empty(): shoppers[person.get_instance_id()] = true
		peak_queue = maxi(peak_queue, manager.queue.size())
		if tick % 1800 == 0:
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

	# A new obstruction near the end of the observation must also resolve;
	# passing the three snapshots must not hide a pending recovery at 90s.
	var late_stalls := []
	for person in bus.passengers:
		if is_instance_valid(person) and person.state == BasicCustomer.State.STORE and person.progress_watchdog.recovery_attempts >= 4 and person.velocity.length() < 0.1:
			late_stalls.append({"person":person,"position":person.position,"visits":person.visited_types.size()})
	await frames(900)
	for entry in late_stalls:
		var person = entry.person
		check(not is_instance_valid(person) or person.resolved or person.state != BasicCustomer.State.STORE or person.visited_types.size() > entry.visits or person.position.distance_to(entry.position) > 0.4,"late 90-second obstruction progresses or reaches finite fallback by 105 seconds")
	print("LATE128 observed=",late_stalls.size())
	print("FULL CHAOS shoppers=", shoppers.size(), " queue=", peak_queue, " pursuit_ticks=", pursuit_ticks, " boss_path=", movement, " player_hp=", player.health.current_health)
	check(bus.spawned_count == 12 and shoppers.size() >= 6 and peak_queue >= 2, "twelve tourists keep shopping and queueing during pursuit fire scatter and special events")
	check(pursuit_ticks > 60 and movement > 20 and player.health.current_health < 10000, "boss pursuit charge damage continue during full business chaos")
	check(rat.position.is_finite() and cart.position.is_finite() and not mart.get_tree().paused, "combined systems remain finite and do not lock world")
	interaction.camera.global_position = Vector3(2, 5, 26)
	interaction.camera.look_at(rat.global_position + Vector3.UP)
	await frames(2)
	root.get_texture().get_image().save_png("res://.godot/p115_chaos.png")
	quit(1 if failures else 0)

func trace_person(person: BasicCustomer, tick: int) -> void:
	var id := person.get_instance_id()
	var goal: Vector3 = person.waypoints.back() if not person.waypoints.is_empty() else person.recovery_target
	var moving := (person.state == BasicCustomer.State.STORE and not person.waypoints.is_empty()) or (person.state == BasicCustomer.State.SHOP and person.position.distance_to(person.recovery_target) > 0.35)
	if tick > 0:
		if not observations.has(id): observations[id] = []
		observations[id].append({"pos":person.position,"goal":goal,"moving":moving and not person.knockdown.active() and not person.fire_reaction.active()})
	recovered[id] = person.progress_watchdog.recovery_count
	var near := []
	var nearby_cart: ShoppingCart = mart.get_node("Cart")
	if nearby_cart.global_position.distance_to(person.global_position) < 3:
		near.append("Cart@"+str(nearby_cart.global_position))
	for group in ["basic_customers","monsters","grabbable"]:
		for body in get_nodes_in_group(group):
			if body != person and body is Node3D and body.global_position.distance_to(person.global_position) < 2:
				near.append(str(body.get_class())+":"+str(body.name)+"@"+str(body.global_position))
	var claims := []
	for claim_id in manager._claims:
		if manager._claims[claim_id] == person: claims.append(claim_id)
	var slides := []
	for i in person.get_slide_collision_count():
		var hit := person.get_slide_collision(i)
		slides.append(str(hit.get_collider())+" normal="+str(hit.get_normal()))
	var occupancy := {}
	if is_instance_valid(person.shopping_shelf):
		var shelf := person.shopping_shelf.point_owner if is_instance_valid(person.shopping_shelf.point_owner) else person.shopping_shelf
		for point in shelf._shopping_users:
			var owner = shelf._shopping_users[point]
			occupancy[point] = owner.get_instance_id() if is_instance_valid(owner) else 0
	print("NPC128 WATCH id=",id," distance=",person.position.distance_to(person.recovery_target)," window_progress=",person.progress_watchdog.last_progress," attempts=",person.progress_watchdog.recovery_attempts," action=",person.recovery_last_action," occupancy=",occupancy)
	print("NPC128 tick=",tick," id=",person.get_instance_id()," state=",BasicCustomer.State.keys()[person.state]," pos=",person.position," route=",person.waypoints," vel=",person.velocity," purchased=",person.visited_types," shelf=",person.shopping_shelf," point=",person.shopping_point_index," goods=",person.goods," claims=",claims," near=",near," slides=",slides," exceptions=",person.get_collision_exceptions())
