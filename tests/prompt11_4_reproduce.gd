extends "res://tests/prompt11_1_smoke.gd"
func run_checks() -> void:
	await setup_thief()
	player.position = Vector3(8, 0.01, -3)
	var box := load(ProductCatalog.find(&"tv").scene_path).instantiate() as GrabbableBody
	mart.add_child(box)
	box.position = Vector3(0, 0.39, 2)
	box.freeze = true
	for x in [-0.72, 0.72]: Graybox.box(mart, "Corridor", Vector3(0.2, 2, 7), Vector3(x, 1, 2), Color.GRAY)
	var npc := walker(Vector3(0, 0.01, 0.2))
	npc.state = BasicCustomer.State.EXIT
	npc.waypoints = [Vector3(0, 0.01, 5)]
	npc.set_physics_process(true)
	for tick in range(480):
		await frames(1)
		if not is_instance_valid(npc) or npc.position.z > 4: break
	print("PRODUCT RECOVERY z=", npc.position.z if is_instance_valid(npc) else "completed")
	check(not is_instance_valid(npc) or npc.position.z > 4, "actual human motor must pass pinned floor TV")
	quit(1 if failures else 0)
