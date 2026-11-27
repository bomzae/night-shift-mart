extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	drunk._rng.seed=132
	await frames(180)
	check(not drunk.wander_route.is_empty() and not drunk.visited_racks.is_empty(),"drunk selects physical shelf aisle without needing stocked products")
	check(drunk.progress_watchdog.check_window>3,"drunk progress threshold allows slower wobble")
	check(drunk.collision_mask & 1 and drunk.product_recovery!=null and drunk.cart_recovery!=null,"world product cart collision and recoveries retained")
	for name in drunk.visited_racks:
		var shelf: StockShelf=mart.get_node("Shelves").get_node(NodePath(name))
		var local:=shelf.to_local(drunk.wander_target)
		check((local.z>0.7 or (DrunkCustomer.single_low_deck(shelf) and local.z< -0.9)) and absf(local.x)>1.4,"wander destination is beside a valid front/rear aisle, not inside shelf")
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=drunk.get_node("CollisionShape3D").shape
		query.transform.origin=drunk.wander_target+Vector3.UP*0.75
		query.exclude=drunk._planner.exclusions
		query.collision_mask=1
		check(drunk.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"full drunk capsule fits destination outside shelf geometry")
	var lateral:=0.0
	var initial:=drunk.position
	drunk.reset_wander_route()
	drunk._direction_wait=10
	drunk.wander_direction=Vector3.FORWARD
	await place(drunk,Vector3(0,0.8,18))
	initial=drunk.position
	for tick in range(120):
		await frames(1)
		lateral=maxf(lateral,absf(drunk.position.x-initial.x))
	check(lateral>0.05,"physical wander includes lateral wobble")
	drunk.wander_acceleration=14
	drunk._direction_wait=100
	var changes:=drunk.direction_changes
	drunk.supported_by_cart=true
	drunk._physics_process(0.1)
	check(drunk.direction_changes==changes and drunk.wander_route.is_empty(),"cart cargo pauses autonomous route")
	# Existing collision callback, actual rigid bodies and weight response; no scheduled destruction.
	var velocities: Array[float]=[]
	for type in [&"can",&"tv"]:
		var product: GrabbableBody=load(ProductCatalog.find(type).scene_path).instantiate()
		mart.add_child(product)
		await place(drunk,Vector3(0,0.8,18))
		await place(product,Vector3(0,product.definition.size.y/2+0.02,16.9))
		drunk._contact_wait=0
		drunk._incoming_speed=1.8
		drunk.linear_velocity=Vector3(0,0,-1.8)
		var peak:=0.0
		for tick in range(60):
			await frames(1)
			peak=maxf(peak,Vector2(product.linear_velocity.x,product.linear_velocity.z).length())
		velocities.append(peak)
		check(not product.get_meta("broken",false),"gentle actual collision does not force destruction "+str(type))
		product.queue_free()
		await frames(2)
	print("DRUNK WEIGHT velocities=",velocities)
	check(velocities[0]>velocities[1],"light product responds more than heavy product to real collision")
	var watchdog:=drunk.progress_watchdog
	for i in range(3):
		check(watchdog.observe(Vector3.ZERO,Vector3.RIGHT*5,"fixed",true,5)==i+1,"five second no progress detects recovery level")
	watchdog.observe(Vector3.ZERO,Vector3.RIGHT*5,"fixed",false,10)
	check(watchdog.elapsed==0,"intentional carry or reaction pause not counted as stuck")
	drunk.queue_free()
	await frames(2)
	drunk=mart.get_node("Drunks").spawn_drunk()
	drunk._rng.seed=132
	await place(drunk,Vector3(0,0.8,18))
	drunk._planner=RatAisleRoute.new(drunk)
	drunk._planner.shape.radius=0.30
	drunk.wander_target=Vector3(0,0.01,14)
	drunk.wander_route=[drunk.wander_target]
	drunk._direction_wait=100
	Graybox.box(mart,"DrunkRouteBlock",Vector3(3,2.5,0.3),Vector3(0,1.25,16),Color.GRAY)
	var escaped_block:=false
	var traveled:=0.0
	var previous:=drunk.position
	for tick in range(900):
		await frames(1)
		traveled+=drunk.position.distance_to(previous)
		previous=drunk.position
		if drunk.bump_count>0 and (absf(drunk.position.x)>1.8 or drunk.position.z<15.5): escaped_block=true
		if tick%300==299: print("BLOCK132 time=",(tick+1)/60," pos=",drunk.position," grounded=",drunk.grounded," progress=",drunk.progress_watchdog.last_progress," elapsed=",drunk.progress_watchdog.elapsed," route=",drunk.wander_route," recoveries=",drunk.progress_watchdog.recovery_count)
	check(drunk.bump_count>0 or drunk.progress_watchdog.recovery_count>0,"real world obstruction triggers short contact recovery or progress watchdog")
	# A later valid aisle can return across x=0 after escaping. Observe the full path,
	# preserving the old escape boundary and also requiring sustained travel.
	check(escaped_block and traveled>5,"repath crosses the obstruction boundary and continues traveling")
	drunk.wander_speed=0
	var recoveries:=drunk.progress_watchdog.recovery_count
	await frames(330)
	check(drunk.progress_watchdog.recovery_count==recoveries and drunk.progress_watchdog.elapsed==0,"explicit stopped movement does not trigger progress recovery")
	print("Prompt 13.2 drunk completed; failures: ",failures)
	quit(1 if failures else 0)
