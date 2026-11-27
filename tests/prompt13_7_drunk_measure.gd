extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	for rack in ["TVShelf","MicrowaveShelf","ZoneSection0_6","CanShelf"]:
		for rear in [false,true]:
			await starter_main()
			var shelf: StockShelf=mart.get_node("Shelves/"+rack)
			var products: Dictionary={}
			for p in shelf.stocked_objects: products[p]=p.global_position
			var drunk: DrunkCustomer=mart.get_node("Drunks").spawn_drunk()
			drunk._rng.seed=137
			await place(drunk,shelf.to_global(Vector3(0,0.76,-1.8 if rear else 2.0)))
			drunk.reset_wander_route()
			drunk._direction_wait=100
			drunk.wander_direction=shelf.global_basis*(Vector3.BACK if rear else Vector3.FORWARD)
			var peak:=0.0
			var contact:=0.0
			var maximum:=0.0
			var impact: Dictionary={}
			for tick in range(360):
				await frames(1)
				if impact.is_empty() and drunk.last_shelf_impact.get("shelf","")==shelf.name:
					impact=drunk.last_shelf_impact.duplicate(true)
				var state:=PhysicsServer3D.body_get_direct_state(drunk.get_rid())
				var touching:=false
				for i in range(state.get_contact_count()):
					var body=state.get_contact_collider_object(i)
					if body is StaticBody3D and body.get_parent()==shelf and absf(state.get_contact_local_normal(i).y)<0.4: touching=true
				contact=contact+1.0/60 if touching else 0
				maximum=maxf(maximum,contact)
				for p in products:
					if is_instance_valid(p): peak=maxf(peak,p.linear_velocity.length())
			var details:=[]
			var falls:=0
			var moved:=0
			for p in products:
				if not is_instance_valid(p): continue
				var distance: float=p.global_position.distance_to(products[p])
				if distance>0.15: moved+=1
				if p.position.y<0.5: falls+=1
				details.append({"mass":p.mass,"start":shelf.to_local(products[p]),"end":shelf.to_local(p.global_position),"distance":distance})
			print("LOW137 ",JSON.stringify({"rack":rack,"yaw":shelf.rotation.y,"rear":rear,"moved":moved,"falls":falls,"peak":peak,"max_contact":maximum,"impact":impact,"products":details}))
			if rear and DrunkCustomer.single_low_deck(shelf): check(falls>0,"starter heavy product can physically fall after real rear impact")
			check(maximum<1,"brief shelf collision "+rack)
	quit(1 if failures else 0)
