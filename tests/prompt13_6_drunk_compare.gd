extends "res://tests/prompt4_smoke.gd"

func trial(rack: String, goods: StringName, seed_value: int, angle: float) -> Dictionary:
	await setup_mart()
	player.position=Vector3(0,0,34)
	var shelf: StockShelf=mart.get_node("Shelves/"+rack)
	var data:=ProductCatalog.find(goods)
	var products: Array[GrabbableBody]=[]
	var origins: Array[Vector3]=[]
	for x in [-0.8,0.0,0.8]:
		var body: GrabbableBody=load(data.scene_path).instantiate()
		mart.get_node("Products").add_child(body)
		body.global_position=shelf.to_global(Vector3(x,0.65+shelf.tier_height+data.size.y/2+0.015,0))
		products.append(body)
	await frames(100)
	for body in products: origins.append(body.global_position)
	var drunk: DrunkCustomer=mart.get_node("Drunks").spawn_drunk()
	drunk._rng.seed=seed_value
	await place(drunk,shelf.to_global(Vector3(-0.25,0.76,-1.8 if seed_value>=300 else 2.0)))
	drunk.wander_direction=shelf.global_basis*Vector3.FORWARD.rotated(Vector3.UP,angle+(PI if seed_value>=300 else 0))
	drunk.reset_wander_route()
	drunk._direction_wait=100
	var contact_times: Array[float]=[]
	var duration:=0.0
	var peak:=0.0
	var last_speed:=0.0
	var contacts:=0
	var direct_products: Dictionary={}
	drunk.body_entered.connect(func(body):
		if body is GrabbableBody: direct_products[body.get_instance_id()]=true)
	for tick in range(360):
		await frames(1)
		var state:=PhysicsServer3D.body_get_direct_state(drunk.get_rid())
		var touching:=false
		for index in range(state.get_contact_count()):
			var collider=state.get_contact_collider_object(index)
			var normal:=state.get_contact_local_normal(index)
			if collider is StaticBody3D and collider.get_parent() is StockShelf and absf(normal.y)<0.4:
				touching=true
				if duration==0: print("IMPACT136 rack=",rack," goods=",goods," before_speed=",last_speed," normal=",normal," point=",state.get_contact_local_position(index)," body=",collider.name)
		if touching:
			if duration==0: contacts+=1
			duration+=1.0/60
		elif duration>0:
			contact_times.append(duration)
			duration=0
		last_speed=Vector2(drunk.linear_velocity.x,drunk.linear_velocity.z).length()
		for body in products:
			if is_instance_valid(body): peak=maxf(peak,body.linear_velocity.length())
	if duration>0: contact_times.append(duration)
	var moved:=0
	var fallen:=0
	for i in range(products.size()):
		if not is_instance_valid(products[i]): continue
		if products[i].global_position.distance_to(origins[i])>0.15: moved+=1
		if products[i].global_position.y<0.5: fallen+=1
	print("COMPARE136 ",JSON.stringify({"rack":rack,"goods":goods,"mass":data.weight,"seed":seed_value,"angle":angle,"contacts":contacts,"mean":contact_times.reduce(func(a,b):return a+b,0.0)/maxi(1,contact_times.size()),"max":contact_times.max() if not contact_times.is_empty() else 0,"moved":moved,"fallen":fallen,"peak":peak,"direct":direct_products.size(),"bump":drunk.bump_count}))
	check(mart.get_node("Drunks").broken_product_value==0,"ordinary shelf bump never scripts product destruction")
	check(contact_times.is_empty() or contact_times.max()<1.2,"short shelf escape preserved "+rack)
	if rack == "ZoneSection1_0":
		check(drunk.low_shelf_impacts>0 and float(drunk.last_shelf_impact.get("impulse",0))<=3.125,"real low shelf contact uses bounded local impulse")
		print("LOCAL136 ",drunk.last_shelf_impact)
	return {"peak":peak,"moved":moved,"fallen":fallen}

func run_checks() -> void:
	var light_peak:=0.0
	for rack in ["CanShelf","InstantNoodlesShelf","ZoneSection1_0"]:
		for seed_value in [136,236,336]:
			var result:=await trial(rack,&"can",seed_value,0.2 if seed_value==136 else -0.2)
			if rack=="ZoneSection1_0" and seed_value==136: light_peak=result.peak
	var heavy:=await trial("ZoneSection1_0",&"tv",136,0.2)
	check(light_peak>heavy.peak*3 and heavy.moved==0,"physical mass preserves strong light/heavy response difference")
	quit(1 if failures else 0)
