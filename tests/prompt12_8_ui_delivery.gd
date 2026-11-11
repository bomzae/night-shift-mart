extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	root.size = Vector2i(1280,720)
	await stock("can")
	var customer := manager.spawn_customer([&"can"])
	await wait_checkout(customer)
	check(customer.progress_watchdog.recovery_count == 0,"normal customer reaches checkout without recovery")
	await frames(3)
	var stats: Array[Control] = [manager._spawn_label,station._money]
	for path in ["Fires","Drunks","LostFamilies","Thieves","TouristBus","Accidents"]:
		var node = mart.get_node_or_null(path)
		if node != null: stats.append(node._label)
	check(stats.size() == 8,"all event and business statistics retained")
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		await frames(3)
		check(station._panel.visible and station._title.text.contains("SCAN"),"checkout job visible at "+str(size))
		for i in stats.size():
			var rect := stats[i].get_global_rect()
			check(stats[i].visible and not rect.intersects(station._panel.get_global_rect()),"event stats separated from checkout "+str(i))
			check(not rect.intersects(mart.get_node("TeamLife").label.get_global_rect()) and not rect.intersects(interaction.weapon_info.get_global_rect()),"stats preserve HP and weapon HUD space")
			check(Rect2(Vector2.ZERO,Vector2(root.get_visible_rect().size)).encloses(rect),"event stat remains inside viewport "+str(i))
			for j in range(i): check(not rect.intersects(stats[j].get_global_rect()),"stat rows do not overlap")
	root.size = Vector2i(1280,720)
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p128_checkout.png")
	check(not customer._pickup_marks.is_empty() and customer._pickup_marks[0].visible,"world purchase indicators preserved")
	check(station._icons.visible and interaction.weapon_info != null,"purchase and held weapon UI retained")
	check(mart.get_node("TeamLife").label.visible and mart.get_node("TeamLife").label.text.contains("HP"),"player HP HUD retained")
	var delivery: DeliveryManager = mart.get_node("Delivery")
	delivery.delivery_interval = 17
	delivery.truck_wait_time = 5
	delivery.arrive()
	await frames(90)
	var count := delivery.delivered
	check(count > 1,"real shipment for departure feedback")
	delivery.shipment[0].global_position = delivery.global_position+Vector3(4,1,0)
	delivery.depart()
	check(delivery.last_result.Unloaded == 1 and delivery.last_result["Left Behind"] == count-1,"summary counts real unloaded and returned bodies")
	check(delivery._hud.visible and delivery._hud.text.contains("RETURNED: %d" % (count-1)),"departure summary visible immediately")
	await frames(2)
	check(not delivery._hud.get_global_rect().intersects(station._panel.get_global_rect()),"departure summary does not overlap checkout job")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p128_delivery_left.png")
	delivery._physics_process(3.1)
	check(delivery.summary_left == 0 and delivery._hud.text == "NEXT DELIVERY 00:09","summary timeout reveals actual manager countdown")
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p128_delivery_next.png")
	delivery._physics_process(2)
	check(delivery._hud.text == "NEXT DELIVERY 00:07","countdown decreases")
	await frames(2)
	delivery._physics_process(7)
	check(delivery.truck_present and delivery.delivery_number == 2 and not delivery._hud.text.contains("NEXT"),"second arrival swaps back to active delivery")
	delivery.depart()
	check(delivery.last_result.Delivered == delivery.last_result.Unloaded+delivery.last_result["Left Behind"],"second departure accounting preserved")
	print("P128 UI DELIVERY complete failures=",failures)
	quit(1 if failures else 0)
