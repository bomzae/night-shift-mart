extends "res://tests/prompt4_smoke.gd"

func return_item(shelf: StockShelf, item: GrabbableBody, label: String, repeats: int = 1) -> void:
	for attempt in range(repeats):
		var x := 0.3125 # Identical operator position and return ray for old/new goods.
		player.position = shelf.to_global(Vector3(x,0.01,1.7))
		interaction.camera.look_at(item.global_position)
		print("SOURCE136 ",label," shelf=",shelf.name," pos=",shelf.to_local(item.global_position)," rot=",item.rotation," scale=",item.scale," shape=",item.get_node("CollisionShape3D").shape," sleep=",item.sleeping," freeze=",item.freeze," meta=",item.get_meta_list()," exceptions=",item.get_collision_exceptions())
		check(interaction.find_candidate()==item,label+" actual stock ray Grab")
		interaction.toggle_grab()
		interaction.camera.look_at(shelf.to_global(Vector3(x,1.6,4)))
		await frames(90)
		check(shelf.to_local(item.global_position).z>0.7,label+" extracted")
		var aim := shelf.to_global(Vector3(x,0.85+shelf.tier_height,0.2))
		interaction.camera.look_at(aim)
		for candidate: StockShelf in mart.get_node("Shelves").get_children():
			if candidate.global_position.distance_to(shelf.global_position)>0.01: continue
			print("CANDIDATE136 ",label," ",candidate.name," height=",candidate.tier_height," clearance=",candidate.tier_clearance," result=",candidate.placement_point(interaction.camera.global_position,-interaction.camera.global_basis.z,item,interaction.grab_distance))
		await frames(120)
		print("SELECT136 ",label," selected=",interaction.placement_shelf," item=",shelf.to_local(item.global_position)," desired=",shelf.to_local(interaction.desired_hold_position))
		check(interaction.placement_shelf==shelf,label+" intended middle tier selected")
		interaction.drop_held(true)
		await frames(100)
		check(shelf.has_stock(item),label+" same physical product returned to intended tier")

func run_checks() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	mart = main.get_node("MartGraybox")
	manager = mart.get_node("Customers")
	player = mart.get_node("Player")
	interaction = player.get_node("Interaction")
	var day: DayManager = mart.get_node("DayManager")
	while day.state != DayManager.State.ACTIVE: await frames(1)
	day.timeline_enabled=false
	manager.spawning_enabled=false
	mart.get_node("Delivery").set_physics_process(false)
	player.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var cereal: StockShelf=mart.get_node("Shelves/ZoneSection0_3_cereal")
	var noodles: StockShelf=mart.get_node("Shelves/InstantNoodlesShelf")
	check(cereal.stock_count>0 and noodles.stock_count>0,"actual Day 1 starter stock exists before I")
	var old: GrabbableBody=cereal.stocked_objects[0]
	var starter_definition:=old.definition
	await return_item(cereal,old,"STARTER CEREAL")
	await return_item(noodles,noodles.stocked_objects[0],"STARTER NOODLES")
	old.queue_free()
	await frames(3)
	var ids: Array[int]=[]
	for body in mart.get_node("Products").get_children(): ids.append(body.get_instance_id())
	await press("debug_auto_stock")
	await frames(100)
	var fresh: GrabbableBody
	for body in cereal.stocked_objects:
		if not ids.has(body.get_instance_id()): fresh=body; break
	check(fresh!=null,"I produces fresh same-definition cereal through real input")
	if fresh!=null:
		check(fresh.definition==starter_definition and fresh.scale==Vector3.ONE and fresh.get_meta_list().is_empty(),"starter and I goods share data/scale with no tier metadata")
		await return_item(cereal,fresh,"I CEREAL",3)
		Input.action_press("crouch")
		player.update_stance()
		await return_item(cereal,fresh,"CROUCHED CEREAL")
		Input.action_release("crouch")
		player.update_stance()
		var at:=fresh.global_transform
		fresh.queue_free()
		await frames(3)
		var identical: GrabbableBody=load(starter_definition.scene_path).instantiate()
		mart.get_node("Products").add_child(identical)
		identical.global_transform=at
		await frames(100)
		await return_item(cereal,identical,"IDENTICAL NEW CEREAL")
		interaction.camera.look_at(identical.global_position)
		interaction.toggle_grab()
		interaction.camera.look_at(cereal.to_global(Vector3(0.3125,1.6,4)))
		await frames(90)
		var blocker:=Graybox.box(mart,"OccupiedMiddle",Vector3(2.6,0.43,0.88),cereal.to_global(Vector3(0,1.43,-0.25)),Color.GRAY)
		blocker.global_basis=cereal.global_basis
		interaction.camera.look_at(cereal.to_global(Vector3(0.3125,1.4,0.2)))
		await frames(60)
		check(interaction.placement_intent==cereal and interaction.placement_shelf==null,"occupied middle keeps intent and never falls back to lower tier")
		check(cereal.to_local(identical.global_position).y>1.2,"unavailable placement does not pull product to bottom shelf")
		interaction.drop_held(true)
		check(identical.holder==null,"free physical Drop remains allowed when placement invalid")
		blocker.queue_free()
	quit(1 if failures else 0)
