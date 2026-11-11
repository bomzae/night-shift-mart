extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	var watchdog := NPCProgressWatchdog.new()
	for i in range(30): watchdog.observe(Vector3.ZERO,Vector3.RIGHT*4,"goal",true,0.1)
	check(watchdog.recovery_attempts == 1,"moving stagnation detected within three seconds")
	for i in range(100): watchdog.observe(Vector3.ZERO,Vector3.RIGHT*4,"goal",false,0.1)
	check(watchdog.recovery_attempts == 1,"intentional waiting does not accumulate recovery")
	for i in range(30): watchdog.observe(Vector3.RIGHT*i*0.05,Vector3.RIGHT*4,"goal",true,0.1)
	check(watchdog.recovery_attempts == 1,"normal movement preserves route and target")
	for i in range(300): watchdog.observe(Vector3.ZERO,Vector3.RIGHT*4,"goal",true,0.1)
	check(watchdog.recovery_attempts == 6 and watchdog.recovery_count == 6,"same target recovery ladder has finite attempts")
	await setup_mart()
	var product := await stock("can")
	var shopper := manager.spawn_customer([&"can"])
	shopper.set_physics_process(false)
	var shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	shopper.waypoints.clear()
	shopper.continue_shopping()
	var point := shopper.shopping_point_index
	check(shelf._shopping_users.get(point) == shopper,"customer reserves a real shopping point")
	manager.repair_reservations(shopper)
	check(manager._claims.get(product.get_instance_id()) == shopper and shelf._shopping_users.get(point) == shopper,"healthy goods and point reservations survive repair")
	manager._claims.erase(product.get_instance_id())
	manager.repair_reservations(shopper)
	check(manager._claims.get(product.get_instance_id()) == shopper,"missing unowned valid goods claim repaired")
	shopper.shopping_shelf = null
	await frames(190) # A just-created API reservation has a three-second ownership grace.
	shelf.prune_shopping_points()
	check(not shelf._shopping_users.values().has(shopper),"stale point owner no longer targeting shelf is released")
	shopper.continue_shopping()
	shopper.global_position = shelf.shopping_point(shopper.shopping_point_index)
	shopper.state = BasicCustomer.State.SHOP
	shopper.shopping_time = 30
	shopper._shopping_left = 30
	shopper.set_physics_process(true)
	await frames(240)
	check(shopper.progress_watchdog.recovery_count == 0 and shopper.state == BasicCustomer.State.SHOP,"intentional shopping hold excluded")
	manager.queue.append(shopper)
	shopper.state = BasicCustomer.State.QUEUE
	shopper.global_position = manager.queue_position(shopper)
	await frames(240)
	check(shopper.progress_watchdog.recovery_count == 0 and shopper.state == BasicCustomer.State.CHECKOUT,"intentional checkout queue wait excluded")
	product.queue_free()
	await frames(2)
	check(shopper.resolved and shopper.state == BasicCustomer.State.DISAPPOINTED,"removed shopping product safely abandons invalid target")
	await setup_mart()
	await stock("can")
	shopper = manager.spawn_customer([&"can"])
	shopper.position = Vector3(0,0.01,20)
	shopper.waypoints = [Vector3(0,0.01,10)]
	shopper.move_speed = 0 # Persistent obstruction fixture; stress test uses real shelf collision.
	for tick in range(2100):
		await frames(1)
		if shopper.resolved: break
	check(shopper.resolved and shopper.progress_watchdog.recovery_count == 6,"six failed recovery levels abort impossible shopping instead of looping")
	check(not manager._claims.values().has(shopper) and shopper.state in [BasicCustomer.State.DISAPPOINTED,BasicCustomer.State.EXIT],"final fallback releases claims and advances state")
	await setup_mart()
	await stock("can")
	shelf = mart.get_node("Shelves/CanShelf")
	for i in range(shelf.shopping_point_count):
		var occupant := Node3D.new()
		mart.add_child(occupant)
		shelf._shopping_users[i] = occupant
	shopper = manager.spawn_customer([&"can"])
	shopper.position = Vector3(0,0.01,4.35)
	shopper.waypoints.clear()
	shopper.continue_shopping()
	await frames(120)
	check(shopper._occupancy_wait == 0 and not shopper.resolved,"travel to occupied shelf does not consume intentional waiting budget")
	var waiting_point: Vector3 = shopper.waypoints.back()
	shopper.position = waiting_point
	shopper.waypoints = [waiting_point]
	for tick in range(1600):
		await frames(1)
		if shopper.resolved: break
	check(shopper.resolved,"permanently occupied shopping points have bounded wait")
	check(shelf._shopping_users.size() == shelf.shopping_point_count,"occupied point fallback never evicts legitimate other owners")
	print("P128 RECOVERY complete failures=",failures)
	quit(1 if failures else 0)
