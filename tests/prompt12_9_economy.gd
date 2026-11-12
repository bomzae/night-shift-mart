extends "res://tests/prompt4_smoke.gd"

func basket_fixture() -> BasicCustomer:
	await setup_mart()
	mart.get_node("AutoStock").top_up()
	await frames(120)
	var customer := manager.spawn_customer([&"rice_bag",&"milk"])
	customer.set_physics_process(false)
	customer.waypoints.clear()
	customer.continue_shopping()
	customer.state = BasicCustomer.State.SHOP
	check(manager.pickup_from_shelf(customer,customer.shopping_shelf,&"rice_bag"),"physical rice bag pickup before route failure")
	customer.visited_types.append(&"rice_bag")
	customer.state = BasicCustomer.State.STORE
	await frames(2)
	return customer

func run_checks() -> void:
	var customer := await basket_fixture()
	var value := manager.basket_total(customer)
	var source_id: int = customer.picked_items[0].source_id
	var remaining: GrabbableBody = customer.goods[0]
	var physical_count := mart.get_node("Products").get_child_count()
	customer.recover_progress(6)
	check(value == 45 and manager.unpaid_loss == 0,"QA rice bag path abort never creates 45 dollar unpaid loss")
	check(customer.picked_items.size() == 1 and customer.purchase_types == [&"rice_bag"] and customer.purchase_total == value,"picked basket and payable price preserved")
	check(customer.goods.is_empty() and is_instance_valid(remaining) and not manager._claims.values().has(customer),"unpicked physical stock retained and reservation released")
	check(customer.shopping_shelf == null and customer._heading_queue and not customer.resolved,"path abort routes existing basket toward checkout")
	check(not is_instance_id_valid(source_id) and mart.get_node("Products").get_child_count() == physical_count,"picked physical product is not duplicated")
	customer.position = Vector3(0,0.01,24)
	customer.waypoints = StoreRoutes.via_main(customer.position,Vector3(1,0.01,32.6))
	customer.set_physics_process(true)
	await wait_checkout(customer)
	await aim_action("scan")
	await frames(45)
	await aim_action("pay")
	check(customer.resolved and manager.sales == value and manager.unpaid_loss == 0,"real checkout scan and payment work after recovery")
	check(customer.picked_items.is_empty() and manager.npc_recovery_abort_count == 1,"single recovery and single settlement")
	manager.abort_shopping_path(customer)
	check(manager.npc_recovery_abort_count == 1,"resolved recovery cannot repeat")

	customer = await basket_fixture()
	customer.recover_progress(6)
	customer.recover_progress(6) # Checkout route itself also proved impossible.
	check(customer.resolved and manager.unpaid_loss == 0 and manager.sales == 0,"impossible checkout uses neutral recovery not penalty or sale")
	check(manager.npc_recovery_returned_count == 1 and manager.npc_recovery_returned_value == 45 and customer.picked_items.is_empty(),"neutral recovery accounting consumes snapshot exactly once")
	manager.abort_shopping_path(customer)
	check(manager.npc_recovery_abort_count == 2 and manager.npc_recovery_returned_count == 1,"shopping and checkout fallback terminate without repeated accounting")

	customer = await basket_fixture()
	customer.recover_progress(6)
	manager.join_queue(customer)
	customer.patience_left = 0
	customer._physics_process(0.1)
	check(customer.resolved and manager.unpaid_loss == 45,"real patience escape still records unpaid basket")

	customer = await basket_fixture()
	customer.goods[0].queue_free()
	await frames(2)
	customer._physics_process(0.1)
	check(customer.resolved and manager.unpaid_loss == 45 and manager.npc_recovery_abort_count == 0,"actual unavailable stock keeps existing out-of-stock contract")

	await setup_mart()
	await stock("can")
	customer = manager.spawn_customer([&"can"])
	customer.recover_progress(6)
	check(customer.resolved and manager.unpaid_loss == 0 and customer.picked_items.is_empty(),"empty basket path abort exits without loss")
	print("ECONOMY129 failures=",failures)
	quit(1 if failures else 0)
