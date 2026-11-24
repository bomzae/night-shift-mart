extends "res://tests/prompt4_smoke.gd"
func run_checks() -> void:
	await setup_mart()
	var shelf: StockShelf = mart.get_node("Shelves/InstantNoodlesShelf")
	var data := ProductCatalog.find(&"instant_noodles")
	var product: GrabbableBody = load(data.scene_path).instantiate()
	mart.get_node("Products").add_child(product)
	product.global_position = shelf.to_global(shelf.slot_position(data.stock_slots()[0]))
	await frames(90)
	check(shelf.has_stock(product),"real recessed tier initially stocked")
	player.position = shelf.to_global(Vector3(-0.9375,0.01,1.6))
	player.look_at(Vector3(shelf.global_position.x,player.position.y,shelf.global_position.z))
	interaction.camera.look_at(product.global_position)
	check(interaction.find_candidate() == product,"standing player can aim at recessed product")
	interaction.toggle_grab()
	interaction.camera.look_at(shelf.to_global(Vector3(-0.9375,1.5,4)))
	await frames(60)
	check(shelf.to_local(product.global_position).z > 0.7,"product actually extracted before same-tier return")
	interaction.camera.look_at(shelf.to_global(Vector3(-0.9375,1.30,0.2)))
	await frames(120)
	print("SHELF135 tier=",shelf.tier_height," clearance=",shelf.tier_clearance," camera=",shelf.to_local(interaction.camera.global_position)," product=",shelf.to_local(product.global_position)," desired=",shelf.to_local(interaction.desired_hold_position)," safe=",shelf.to_local(interaction.safe_hold_position)," blocked=",interaction.hold_obstructed)
	interaction.drop_held(true)
	await frames(120)
	check(shelf.has_stock(product),"product returned physically to same recessed tier")
	var probe: GrabbableBody = load(data.scene_path).instantiate()
	mart.get_node("Products").add_child(probe)
	probe.position = Vector3(0,2,24)
	probe.freeze = true
	var origin := shelf.to_global(Vector3(-0.9375,1.61,1.6))
	var direction := (shelf.to_global(Vector3(-0.9375,1.3,0.2))-origin).normalized()
	check(shelf.placement_point(origin,direction,probe,2.8).is_empty(),"occupied opening rejects overlap placement")
	product.queue_free()
	await frames(3)
	var point := shelf.placement_point(origin,direction,probe,2.8)
	check(not point.is_empty(),"front opening resolves empty recessed middle tier")
	if not point.is_empty():
		var local := shelf.to_local(point.position)
		check(local.z < 0.2 and local.z > -0.7 and local.y > 1.2,"placement stays inside actual tier bounds")
	var large: GrabbableBody = load(ProductCatalog.find(&"appliance").scene_path).instantiate()
	mart.get_node("Products").add_child(large)
	large.position = Vector3(3,2,24)
	large.freeze = true
	check(shelf.placement_point(origin,direction,large,2.8).is_empty(),"oversized appliance cannot fit recessed noodles tier")
	var saved := shelf.stock_count
	shelf.stock_count = shelf.max_stock
	check(shelf.placement_point(origin,direction,probe,2.8).is_empty(),"capacity still prevents additional placement")
	shelf.stock_count = saved
	for height in [0.0,0.55,1.0]:
		var tier: StockShelf
		for candidate in mart.get_node("Shelves").get_children():
			if candidate is StockShelf and is_equal_approx(candidate.tier_height,height):
				tier = candidate
				break
		check(tier != null,"actual shelf tier exists at height "+str(height))
		if tier == null: continue
		var front := 0.2 if height > 0 else 0.7
		var start := tier.to_global(Vector3(0,0.8+height,1.8))
		var aim := (tier.to_global(Vector3(0,0.8+height,front))-start).normalized()
		var placement := tier.placement_point(start,aim,probe,2.8)
		check(not placement.is_empty(),"normal/lower/upper shelf opening remains accessible "+str(height))
		if not placement.is_empty():
			await place(probe,placement.position)
			await frames(100)
			check(tier.has_stock(probe) == (tier.accepted_type == probe.product_type),"wrong-stock is physical but not accepted inventory "+str(height))
	quit(1 if failures else 0)
