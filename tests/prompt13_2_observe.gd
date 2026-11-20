extends "res://tests/prompt4_smoke.gd"

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
	drunk._rng.seed = 132
	var products := {}
	for product in mart.get_node("Products").get_children(): products[product] = product.position
	var contacts := {}
	var shelf_contacts := {"count":0}
	drunk.body_entered.connect(func(body):
		if body is GrabbableBody: contacts[body.get_instance_id()] = true
		elif body.get_parent() is StockShelf: shelf_contacts.count += 1)
	var zones := {}
	var store_zones := {}
	var passes := {}
	var travel := 0.0
	var previous := drunk.position
	var still := 0.0
	var maximum_still := 0.0
	var window_origin := previous
	for tick in range(1800):
		await frames(1)
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
	var moved := 0
	var fallen := 0
	for product in products:
		if not is_instance_valid(product): continue
		if product.position.distance_to(products[product])>0.3: moved += 1
		if product.position.y < 0.5: fallen += 1
	print("OBSERVE132 zones=",zones.keys()," store_zones=",store_zones.keys()," travel=",travel," shelf_passes=",passes.size()," shelf_contacts=",shelf_contacts.count," contacts=",contacts.size()," moved=",moved," fallen=",fallen," broken_value=",mart.get_node("Drunks").broken_product_value," max_still=",maximum_still," end=",drunk.position)
	if not OS.get_cmdline_user_args().has("--baseline"):
		check(zones.size()>=3 and passes.size()>=2, "drunk crosses several stocked aisle regions")
		check(maximum_still<10, "drunk does not remain locally stuck")
		check(absf(drunk.position.x)>10,"drunk leaves the old central wander rectangle")
	print("Prompt 13.2 observation completed; failures: ",failures)
	quit(1 if failures else 0)
