extends "res://tests/prompt11_4_flow_smoke.gd"
func run_checks() -> void:
	await setup_thief()
	player.position = Vector3(8, 0.01, -3)
	var item := WeaponBody.new()
	item.weapon = preload("res://data/weapons/sledgehammer.tres")
	mart.add_child(item)
	item.position = Vector3(0, 0.15, 2)
	item.rotation.y = PI / 2
	item.freeze = true
	for x in [-0.72, 0.72]: Graybox.box(mart, "Corridor", Vector3(0.2, 2, 8), Vector3(x, 1, 2), Color.GRAY)
	var npc := walker(Vector3(0, 0.01, 0.2))
	npc.state = BasicCustomer.State.EXIT
	npc.waypoints = [Vector3(0, 0.01, 7)]
	npc.set_physics_process(true)
	await frames(600)
	check(not is_instance_valid(npc) or npc.position.z > 5, "human escapes pinned floor weapon")
	check(not is_instance_valid(npc) or npc.product_recovery.pairs.is_empty(), "weapon collision pair restored")
	await setup_thief()
	player.position = Vector3(8, 0.01, 10)
	mart.get_node("Cart").position = Vector3(-5, 0.1, 8)
	var delivery = mart.get_node("Delivery/WeaponDelivery")
	for i in range(3):
		await press("debug_order_weapon")
	var count := 0
	for child in delivery.get_children():
		if child is WeaponCrate: count += 1
	check(count == 3, "three safe nonoverlapping delivery slots")
	check(delivery.order() == null, "occupied crate slots defer additional order")
	quit(1 if failures else 0)
