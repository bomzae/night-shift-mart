extends "res://tests/prompt11_5_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	await stock("can")
	await stock("watermelon")
	var shopper := manager.spawn_customer([&"can",&"watermelon"])
	shopper.set_physics_process(false)
	shopper.waypoints.clear()
	shopper.continue_shopping()
	shopper.state = BasicCustomer.State.SHOP
	check(manager.pickup_from_shelf(shopper,shopper.shopping_shelf,&"can"),"real first product picked before recovery")
	shopper.visited_types.append(&"can")
	var value := manager.basket_total(shopper)
	shopper.state = BasicCustomer.State.STORE
	shopper.recover_progress(6)
	print("ECON129 basket_value=",value," loss=",manager.unpaid_loss," state=",shopper.state," basket=",shopper.picked_items)
	check(manager.unpaid_loss == 0 and not shopper.picked_items.is_empty(),"path failure preserves basket without economic penalty")
	for cart_count in range(3):
		await boss_setup()
		rat.position = Vector3(-0.060,0.001,20.664)
		player.position = Vector3(0.740,0.01,22.874)
		player.health.max_health = 10000
		player.health.current_health = 10000
		var cart: ShoppingCart = mart.get_node("Cart")
		await place(cart,Vector3(2,0.01,22) if cart_count > 0 else Vector3(30,0.01,30))
		if cart_count == 2:
			var extra: ShoppingCart = load("res://scenes/interactables/shopping_cart.tscn").instantiate()
			mart.add_child(extra)
			extra.position = Vector3(-2,0.01,22)
		rat.provoke(player)
		rat._charge_wait = 0
		rat.state = KingRat.State.PURSUIT
		await frames(600)
		var slides := []
		for i in rat.get_slide_collision_count(): slides.append(str(rat.get_slide_collision(i).get_collider()))
		print("RAT129 carts=",cart_count," pos=",rat.position," distance=",rat.combat_distance()," state=",rat.state," lane=",rat._clear_attack_lane," sees=",rat._sees_player," route=",rat.pursuit_route," detour=",rat._pursuit_detour_left," blocked=",rat._pursuit_blocked," slides=",slides," telegraph=",rat.telegraph_start_count)
		for at in [rat.position,player.position]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = rat.pursuit_planner.shape
			query.transform.origin = Vector3(at.x,0.65,at.z)
			query.exclude = rat.pursuit_planner.exclusions
			print("LANE129 at=",at," overlaps=",rat.get_world_3d().direct_space_state.intersect_shape(query))
		check(rat.telegraph_start_count > 0,"near pursuit reaches a real attack decision carts="+str(cart_count))
		check(not rat.get_collision_exceptions().has(cart),"cart remains a solid movement obstacle")
	print("REPRO129 failures=",failures)
	quit(1 if failures else 0)
