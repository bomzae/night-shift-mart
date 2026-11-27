extends "res://tests/prompt4_smoke.gd"

func seed_value() -> int:
	return 137

func run_checks() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	manager = mart.get_node("Customers")
	player = mart.get_node("Player")
	var day: DayManager = mart.get_node("DayManager")
	while day.state != DayManager.State.ACTIVE: await frames(1)
	day.timeline_enabled = false
	manager.spawning_enabled = false
	mart.get_node("Delivery").set_physics_process(false)
	player.set_physics_process(false)
	player.position = Vector3(0,0,34)
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	drunk._rng.seed = seed_value()
	var products := {}
	for product in mart.get_node("Products").get_children(): products[product] = product.position
	var contacts := {}
	var shelf_contacts := {"count":0}
	drunk.body_entered.connect(func(body):
		if body is GrabbableBody: contacts[body.get_instance_id()] = true
		elif body.get_parent() is StockShelf: shelf_contacts.count += 1)
	var target_changes := 0
	var last_target := drunk.wander_target
	var last_bumps := 0
	var durations: Array[float] = []
	var contact_time := 0.0
	var normal := Vector3.ZERO
	var zones := {}
	var store_zones := {}
	var passes := {}
	var travel := 0.0
	var previous := drunk.position
	var still := 0.0
	var maximum_still := 0.0
	var window_origin := previous
	var rear_products: Dictionary={}
	var previous_rear:=0
	for tick in range(18000):
		await frames(1)
		if drunk.rear_shelf_impacts>previous_rear:
			previous_rear=drunk.rear_shelf_impacts
			var impact:=drunk.last_shelf_impact
			var rack: StockShelf=mart.get_node("Shelves/"+String(impact.shelf))
			for item in impact.impulses:
				var product=instance_from_id(item.id)
				if is_instance_valid(product): rear_products[product]=rack
			print("NATURAL_REAR137 ",impact)
		var state := PhysicsServer3D.body_get_direct_state(drunk.get_rid())
		var touching := false
		for index in range(state.get_contact_count()):
			var body = state.get_contact_collider_object(index)
			var n := state.get_contact_local_normal(index)
			if body is StaticBody3D and absf(n.y)<0.4 and body.get_parent() is StockShelf:
				touching = true
				normal = n
		if touching:
			contact_time += 1.0/60
			if int(contact_time*60)%30==0: print("RUB137 time=",contact_time," target=",drunk.wander_target," direction=",drunk.wander_direction," normal=",normal," distance=",drunk.position.distance_to(drunk.wander_target)," wobble=",sin(drunk._phase*drunk._wobble_frequency)," route=",drunk.wander_route," recovery=",drunk.progress_watchdog.recovery_count)
		elif contact_time>0:
			durations.append(contact_time)
			contact_time=0
		if drunk.wander_target != last_target:
			target_changes += 1
			last_target = drunk.wander_target
		if drunk.bump_count > last_bumps:
			check(drunk.bump_direction.dot(drunk.bump_normal)>0.5,"bump moves outward from real collision normal")
			check(drunk.wander_route.is_empty() and (not is_instance_valid(drunk._contact_wall) or not drunk._contact_wall.get_parent() is StockShelf or drunk.avoided_shelves.size()>0),"sustained shelf contact abandons route and avoids collided shelf")
			check(drunk.bump_cooldown>drunk.bump_remaining,"cooldown outlasts committed escape direction")
			last_bumps = drunk.bump_count
		if drunk.position.distance_to(previous)>0.2: check(false,"no teleport during movement")
		travel += Vector2(drunk.position.x-previous.x,drunk.position.z-previous.z).length()
		previous = drunk.position
		zones[Vector2i(floori(drunk.position.x/8),floori(drunk.position.z/8))] = true
		store_zones[DrunkCustomer.store_zone(drunk.position)]=true
		for shelf in mart.get_node("Shelves").get_children():
			var local: Vector3 = shelf.to_local(drunk.global_position)
			if absf(local.x) < 2 and local.z > 0.7 and local.z < 1.8: passes[Vector2(shelf.position.x,shelf.position.z)] = true
		if tick % 60 == 59:
			still = still+1 if drunk.position.distance_to(window_origin)<0.2 else 0
			maximum_still = maxf(maximum_still,still)
			window_origin = drunk.position
	if contact_time>0: durations.append(contact_time)
	print("CONTACT137 durations=",durations," mean=",durations.reduce(func(a,b): return a+b,0.0)/maxi(1,durations.size())," max=",durations.max())
	print("BUMP137 count=",drunk.bump_count," targets=",target_changes," recovery=",drunk.progress_watchdog.recovery_count)
	print("REAR137 selected=",drunk.rear_routes_selected," impacts=",drunk.rear_shelf_impacts)
	var moved := 0
	var fallen := 0
	var forward_falls:=[]
	for product in rear_products:
		if is_instance_valid(product) and product.position.y<0.5 and rear_products[product].to_local(product.global_position).z>0.7:
			forward_falls.append({"type":product.product_type,"mass":product.mass,"shelf":rear_products[product].name})
	print("NATURAL_FORWARD_FALLS137 ",forward_falls)
	for product in products:
		if not is_instance_valid(product): continue
		if product.position.distance_to(products[product])>0.3: moved += 1
		if product.position.y < 0.5: fallen += 1
	print("OBSERVE137 zones=",zones.keys()," store_zones=",store_zones.keys()," travel=",travel," shelf_passes=",passes.size()," shelf_contacts=",shelf_contacts.count," contacts=",contacts.size()," moved=",moved," fallen=",fallen," broken_value=",mart.get_node("Drunks").broken_product_value," max_still=",maximum_still," end=",drunk.position)
	if not OS.get_cmdline_user_args().has("--baseline"):
		check(durations.size()>0 and durations.max()<1.0,"brief shelf contacts release within one second")
		check(drunk.bump_count>0 and target_changes>drunk.bump_count,"bump followed by new aisle objectives")
		check(zones.size()>=3 and passes.size()>=2, "drunk crosses several stocked aisle regions")
		check(maximum_still<10, "drunk does not remain locally stuck")
		check(drunk.rear_routes_selected>0 and drunk.rear_shelf_impacts>0,"natural wandering includes reachable rear approaches and real collisions")
		check(store_zones.keys().any(func(zone):return zone != "MAIN"),"drunk leaves the old central wander rectangle")
	print("Prompt 13.7 observation completed; failures: ",failures)
	quit(1 if failures else 0)
