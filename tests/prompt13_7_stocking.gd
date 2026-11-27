extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	await starter_main()
	player.set_physics_process(false)
	var jobs:=[]
	for rack in ["ZoneSection0_3_cereal","InstantNoodlesShelf","CanShelf","ChipsShelf"]:
		var shelf: StockShelf=mart.get_node("Shelves/"+rack)
		var index:=0
		for product in shelf.stocked_objects.duplicate():
			if index>=3: break
			jobs.append({"shelf":shelf,"product":product,"index":index})
			product.apply_central_impulse((shelf.global_basis.z*4.5+Vector3.UP*1.5)*product.mass)
			index+=1
	await frames(240)
	var success:=0
	var fronts:=0
	var backs:=0
	var maximum_error:=0.0
	var wrong_tier:=0
	for job in jobs:
		var product: GrabbableBody=job.product
		var shelf: StockShelf=job.shelf
		check(product.global_position.y<0.6,"starter goods physically fell before manual recovery")
		interaction.drop_held()
		for side in [Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD]:
			player.position=product.global_position+shelf.global_basis*side*1.2
			player.position.y=0.01
			player._set_stance(true)
			await frames(1)
			interaction.camera.look_at(product.global_position)
			if interaction.find_candidate()==product:
				await press("grab")
				break
		check(interaction.held_object==product,"actual ray/LMB grabs fallen starter product")
		if interaction.held_object!=product: continue
		interaction.camera.look_at(player.global_position+shelf.global_basis.z*4+Vector3.UP*1.5)
		await frames(90)
		var x: float=[-0.8,0.0,0.8][job.index]
		var rear: bool=job.index!=1
		var operator_position:=shelf.to_global(Vector3(x,0.01,1.65))
		# Move the operator continuously; teleporting across the aisle breaks the real carry tether.
		while player.position.distance_to(operator_position)>0.02:
			player.position=player.position.move_toward(operator_position,0.04)
			await frames(1)
		player._set_stance(shelf.tier_height==0)
		await frames(1)
		var center:=0.65+shelf.tier_height+product.definition.size.y/2+0.025
		var depth: float=-0.4 if rear else (0.2 if shelf.tier_height>0 else 0.7)-product.definition.size.z/2-0.04
		interaction.camera.look_at(shelf.to_global(Vector3(x,center,depth)))
		var preview:=Vector3.ZERO
		for tick in range(240):
			await frames(1)
			if is_instance_valid(interaction.placement_shelf):
				if interaction.placement_shelf!=shelf: wrong_tier+=1
				preview=interaction.desired_hold_position
				if product.global_position.distance_to(preview)<0.06: break
		print("STOCK137 ready=",interaction.placement_shelf," intended=",shelf.name," reason=",shelf.placement_reason," local=",shelf.to_local(product.position)," depth=",depth)
		check(interaction.placement_shelf==shelf,"intended tier and valid PLACE after physical approach")
		await press("grab")
		await frames(180)
		if shelf.has_stock(product): success+=1
		var actual:=shelf.to_local(product.global_position)
		print("AFTER137 local=",actual," stock=",shelf.has_stock(product)," holder=",product.holder," velocity=",product.linear_velocity)
		if rear and actual.z< -0.22: backs+=1
		if not rear and actual.z> -0.1: fronts+=1
		if preview!=Vector3.ZERO: maximum_error=maxf(maximum_error,product.global_position.distance_to(preview))
		check(shelf.has_stock(product) and absf(actual.z-depth)<0.16,"same physical product rests at aimed depth")
	check(success>=10 and fronts>=3 and backs>=6 and wrong_tier==0,"bulk ten-plus manual returns use both depths without wrong tier")
	check(maximum_error<0.15,"PLACE indication agrees with final physical position")
	print("BULK137 total=",jobs.size()," success=",success," front=",fronts," rear=",backs," wrong_tier=",wrong_tier," preview_error=",maximum_error)
	quit(1 if failures else 0)
