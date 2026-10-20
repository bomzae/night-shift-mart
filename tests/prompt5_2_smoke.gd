extends "res://tests/prompt4_smoke.gd"

func stage_pickup(buyer: BasicCustomer, type: StringName) -> StockShelf:
	# Focused transaction fixture: route integration is tested separately below.
	buyer.set_physics_process(false)
	var shelf: StockShelf = mart.get_node("Shelves/" + {&"can": "CanShelf", &"watermelon": "WatermelonShelf", &"appliance": "ApplianceShelf"}[type])
	buyer.state = BasicCustomer.State.SHOP
	buyer.shopping_shelf = shelf
	return shelf

func run_checks() -> void:
	for path in ["AGENTS.md", ".agents/skills/godot-testing/SKILL.md"]:
		var text := FileAccess.get_file_as_string("res://" + path)
		check(text.contains("Godot Test Authorization") and text.contains("pre-authorized") and text.contains("execution environment"), "automatic testing authorization with environment boundary " + path)
	await setup_mart()
	var a := await stock("can", Vector3(-0.7, 0, 0))
	var b := await stock("can", Vector3(0.7, 0, 0))
	var melon := await stock("watermelon")
	var shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	var buyer := manager.spawn_customer([&"can", &"can", &"watermelon"])
	check(shelf.stock_count == 2 and is_instance_valid(a) and is_instance_valid(b) and buyer.picked_items.is_empty(), "physical goods remain before SHOP")
	for tick in range(1400):
		await frames(1)
		if buyer.visited_types.has(&"can"):
			break
	check(buyer.visited_types == [&"can"] and buyer.picked_items.size() == 2, "one shelf visit picks quantity two")
	check(not is_instance_valid(a) and not is_instance_valid(b) and is_instance_valid(melon), "only reserved visited type disappears")
	check(shelf.stock_count == 0 and mart.get_node("Shelves/WatermelonShelf").stock_count == 1, "shelf count follows physical removal immediately")
	check(buyer._pickup_marks[0].visible and buyer._pickup_marks[1].visible and not buyer._pickup_marks[2].visible, "bubble marks only completed pickup type")
	check(manager.basket_total(buyer) == 10 and manager.sales == 0 and manager.unpaid_loss == 0, "pickup snapshots prices without a sale or loss")
	check(manager.valid_goods(buyer), "mixed basket and remaining reservation stays valid")
	player.global_position = Vector3(-5, 0.01, 1.4)
	interaction.camera.look_at(buyer.global_position + Vector3(0, 1.8, 0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p52_pickup.png")
	await wait_checkout(buyer)
	check(buyer.picked_items.size() == 3 and buyer.goods.is_empty() and not is_instance_valid(melon), "all types transfer to basket before checkout")
	check(manager._claims.is_empty() and manager.basket_total(buyer) == 60, "physical claims released and basket keeps full price")
	# Fresh stock must survive payment for already collected goods.
	var replacement := await stock("can")
	player.global_position = station.global_position + Vector3(0, 0.01, 1.25)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await aim_action("pay")
	check(manager.sales == 0, "basket cannot pay before all scans")
	for i in range(3):
		await aim_action("scan")
		await frames(32)
	await aim_action("pay")
	check(manager.sales == 60 and buyer.picked_items.is_empty(), "payment consumes basket and records exact sales")
	check(is_instance_valid(replacement) and shelf.has_stock(replacement) and shelf.stock_count == 1, "payment never removes replacement shelf product")
	check(not manager.finish(buyer, true) and manager.sales == 60, "repeat payment is rejected")

	await setup_mart()
	var units: Array[GrabbableBody] = []
	for x in [-0.9, -0.3, 0.3, 0.9]:
		units.append(await stock("can", Vector3(x, 0, 0)))
	buyer = manager.spawn_customer([&"can", &"can", &"can"])
	var spare: GrabbableBody
	for unit in units:
		if not buyer.goods.has(unit):
			spare = unit
	buyer.goods[0].price = 7 # Price must come from reserved physical unit, not a catalog.
	shelf = stage_pickup(buyer, &"can")
	check(manager.pickup_from_shelf(buyer, shelf, &"can") and buyer.picked_items.size() == 3, "quantity three commits in one shelf visit")
	check(shelf.stock_count == 1 and shelf.has_stock(spare), "exact reserved quantity leaves unrelated stock untouched")
	check(manager.basket_total(buyer) == 17 and buyer.purchase_total == 17, "basket and quote preserve actual pickup price snapshots")
	check(buyer.goods.is_empty() and manager._claims.is_empty(), "basket holds no live physical product references")
	check(not manager.pickup_from_shelf(buyer, shelf, &"can") and buyer.picked_items.size() == 3, "duplicate commit is inert")

	await setup_mart()
	var escaping_unit := await stock("can")
	buyer = manager.spawn_customer([&"can"])
	await wait_checkout(buyer)
	check(not is_instance_valid(escaping_unit), "escape basket already absent from shelf")
	buyer.patience_left = 0.01
	await frames(3)
	check(buyer.unpaid and buyer.picked_items.is_empty() and manager.unpaid_loss == 5 and manager.sales == 0, "patience settles only picked price as loss")
	check(mart.get_node("Shelves/CanShelf").stock_count == 0 and not manager.finish(buyer, false) and manager.unpaid_loss == 5, "escape neither restocks nor double charges")

	await setup_mart()
	var held := await stock("can")
	buyer = manager.spawn_customer([&"can"])
	held.begin_carry(interaction, player)
	await frames(2)
	check(buyer.state == BasicCustomer.State.DISAPPOINTED and buyer.picked_items.is_empty() and manager.unpaid_loss == 0, "player can take reservation before approach without phantom pickup or loss")
	held.end_carry()

	await setup_mart()
	a = await stock("can", Vector3(-0.7, 0, 0))
	b = await stock("can", Vector3(0.7, 0, 0))
	buyer = manager.spawn_customer([&"can", &"can"])
	shelf = stage_pickup(buyer, &"can")
	b.begin_carry(interaction, player)
	check(not manager.pickup_from_shelf(buyer, shelf, &"can"), "SHOP commit rejects same-frame removal")
	check(is_instance_valid(a) and not a.is_queued_for_deletion() and buyer.picked_items.is_empty() and manager.unpaid_loss == 0, "multi-unit pickup is atomic when one unit is missing")
	b.end_carry()

	await setup_mart()
	a = await stock("can")
	melon = await stock("watermelon")
	buyer = manager.spawn_customer([&"can", &"watermelon"])
	shelf = stage_pickup(buyer, &"can")
	check(manager.pickup_from_shelf(buyer, shelf, &"can") and shelf.stock_count == 0, "transaction refreshes stock synchronously")
	check(not manager.pickup_from_shelf(buyer, shelf, &"can") and buyer.picked_items.size() == 1 and manager.unpaid_loss == 0, "repeated pickup cannot duplicate units or settle basket")
	melon.begin_carry(interaction, player)
	shelf = stage_pickup(buyer, &"watermelon")
	check(not manager.pickup_from_shelf(buyer, shelf, &"watermelon") and manager.unpaid_loss == 5 and buyer.picked_items.is_empty(), "later shortage charges only already-picked basket")
	check(is_instance_valid(melon) and not melon.is_queued_for_deletion(), "unpicked future stock survives aborted shopping")
	manager.out_of_stock(buyer)
	check(manager.unpaid_loss == 5, "partial out-of-stock loss is recorded once")
	melon.end_carry()

	await setup_mart()
	a = await stock("can", Vector3(0, 0, 0.5))
	buyer = manager.spawn_customer([&"can"])
	shelf = stage_pickup(buyer, &"can")
	# Existing drunk physics pushes a reserved product out; no special stock exception.
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	await place(drunk, shelf.global_position + Vector3(0, 0.76, -2.1))
	drunk.wander_direction = Vector3.BACK
	drunk._direction_wait = 20
	for tick in range(150):
		await frames(1)
		if not shelf.has_stock(a):
			break
	check(is_instance_valid(a) and not shelf.has_stock(a), "actual drunk contact invalidates reserved stock")
	check(not manager.pickup_from_shelf(buyer, shelf, &"can") and buyer.state == BasicCustomer.State.DISAPPOINTED, "displaced stock uses common live out-of-stock check")
	check(buyer.picked_items.is_empty() and manager.unpaid_loss == 0 and is_instance_valid(a), "displaced physical product is not deleted or billed")
	check(drunk is CarryableCharacter and manager.queue.is_empty() and manager.customers.size() == 1, "drunk remains separate from purchase flow")
	print("Prompt 5.2 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
