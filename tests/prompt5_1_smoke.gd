extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	for path in ["AGENTS.md", ".agents/skills/gameplay-development/SKILL.md", ".agents/skills/godot-testing/SKILL.md", ".agents/skills/bug-fix/SKILL.md"]:
		check(FileAccess.file_exists("res://" + path), "agent instruction exists " + path)
	await setup_mart()
	var can_a := await stock("can", Vector3(-0.7, 0, 0))
	var can_b := await stock("can", Vector3(0.7, 0, 0))
	var melon := await stock("watermelon")
	var buyer := manager.spawn_customer([&"can", &"can", &"watermelon"])
	check(buyer.shopping_types.size() == 2 and buyer.goods.size() == 3, "distinct shelf itinerary preserves quantity and reservations")
	var seen: Array[StringName] = []
	var shop_frames := 0
	for tick in range(4200):
		await frames(1)
		if buyer.state == BasicCustomer.State.SHOP:
			shop_frames += 1
			var shelf := buyer.shopping_shelf
			if not seen.has(shelf.accepted_type):
				seen.append(shelf.accepted_type)
				var local := shelf.to_local(buyer.global_position)
				check(local.z > 1.0 and absf(local.x) < 1.3, "physically arrives in front of " + shelf.accepted_type)
				await frames(2)
				var toward := shelf.global_position - buyer.global_position
				toward.y = 0
				check((-buyer.global_basis.z).dot(toward.normalized()) > 0.98, "faces actual shelf during shopping")
		if buyer.state == BasicCustomer.State.CHECKOUT:
			break
	check(seen == [&"can", &"watermelon"], "visits both requested shelf types in order")
	check(buyer.visited_types == [&"can", &"watermelon"], "quantity two does not repeat same shelf")
	check(shop_frames >= 70, "shopping visibly pauses at both shelves")
	check(buyer.state == BasicCustomer.State.CHECKOUT, "shopping then reaches checkout")
	check(manager.valid_goods(buyer) and buyer.picked_items.size() == 3 and not is_instance_valid(can_a) and not is_instance_valid(melon), "shopping transfers reserved products into logical basket")
	for i in range(3):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await frames(3)
		await aim_action("scan")
		await frames(32)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(3)
	await aim_action("pay")
	check(manager.sales == 60 and not is_instance_valid(can_a) and not is_instance_valid(can_b) and not is_instance_valid(melon), "checkout sells all three actual reserved units once")

	await setup_mart()
	var shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	for x in [-0.8, 0.0, 0.8]:
		await stock("can", Vector3(x, 0, 0))
	var customers: Array[BasicCustomer] = []
	for i in range(3):
		var customer := manager.spawn_customer([&"can"])
		customer.shopping_time = 1.5
		customers.append(customer)
		await frames(45)
	var selected: Dictionary = {}
	var simultaneous := false
	var captured := false
	for tick in range(4200):
		await frames(1)
		if shelf._shopping_users.size() >= 2:
			simultaneous = true
		for customer in customers:
			if customer.state == BasicCustomer.State.SHOP:
				selected[customer.shopping_point_index] = true
		if selected.size() >= 2 and not captured:
			captured = true
			player.global_position = Vector3(-5, 0.01, 1.4)
			interaction.camera.look_at(Vector3(-5, 1, 4.6))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/p51_shopping.png")
		if manager.queue.size() == 3:
			break
	check(simultaneous and selected.size() >= 2, "concurrent shoppers use multiple exclusively owned points")
	check(manager.queue.size() == 3, "all spread shoppers eventually queue")
	check(customers[0].picked_items[0].source_id != customers[1].picked_items[0].source_id, "point reservations do not duplicate picked stock")
	check(shelf._shopping_users.is_empty(), "points released after leaving shelf")

	await setup_mart()
	var removable := await stock("can", Vector3(-0.8, 0, 0))
	buyer = manager.spawn_customer([&"can"])
	for tick in range(1000):
		await frames(1)
		if buyer.shopping_shelf != null:
			break
	check(buyer.shopping_point_index == 0, "prefers nearest point to actual left-side reserved product")
	removable.begin_carry(interaction, player)
	await frames(2)
	check(buyer.state == BasicCustomer.State.DISAPPOINTED, "taking product during shelf approach uses out of stock")
	check(manager.queue.is_empty() and manager.sales == 0 and manager.unpaid_loss == 0, "out of stock creates neither sale nor unpaid loss")
	check(mart.get_node("Shelves/CanShelf")._shopping_users.is_empty(), "out of stock releases shopping point")
	removable.end_carry()
	for tick in range(1000):
		await frames(1)
		if not is_instance_valid(buyer):
			break
	check(not is_instance_valid(buyer), "out of stock shopper exits around shelf instead of through it")
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	check(drunk != null and drunk is CarryableCharacter and manager.queue.is_empty(), "drunk remains separate and carryable")
	print("Prompt 5.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
