extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	var hud := day.economy_hud
	manager.sales = 100
	manager.unpaid_loss = 10
	day.baseline = day._stats()
	await frames(2)
	check(hud.sales==0 and hud.losses==0,"economy uses daily baseline not lifetime totals")
	await stock("can")
	var customer := manager.spawn_customer([&"can"])
	await wait_checkout(customer)
	await aim_action("scan")
	await frames(35)
	await aim_action("pay")
	await frames(2)
	check(hud.sales==5 and hud.delta_label.text=="+$5 SALE" and hud.delta_label.visible,"real checkout sale updates summary and delta")
	manager.unpaid_loss += 3
	mart.get_node("Thieves").stolen_goods_value += 4
	mart.get_node("Fires").fire_damage_value += 5
	mart.get_node("Bosses").boss_product_loss_value += 6
	mart.get_node("Drunks").broken_product_value += 7
	mart.get_node("TeamLife").consumed_product_value += 8
	await frames(2)
	check(hud.losses==33 and hud.delta_label.text=="-$33 LOSSES","all six Result loss categories including food and breakage aggregate once")
	await frames(100)
	check(not hud.delta_label.visible,"money delta auto hides")
	mart.get_node("Thieves").stolen_goods_value += 45
	await frames(2)
	check(hud.delta_label.text=="-$45 STOLEN","single loss names its source")
	manager.sales += 25
	mart.get_node("Fires").fire_damage_value += 10
	await frames(2)
	check(hud.delta_label.text=="+$25 SALE  /  -$10 FIRE","simultaneous money batch replaces safely without queue spam")
	DayManager.notify_event(mart,&"drunk")
	mart.get_node("Delivery/WeaponDelivery").order()
	await frames(3)
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size
		await frames(3)
		check(hud.sales_label.get_global_rect().position.y>=day.clock_label.get_global_rect().end.y,"economy below clock "+str(size))
		var controls: Array[Control] = [day.clock_label,day.event_banner.panel,station._panel,interaction.weapon_info,interaction.context_prompt,mart.get_node("Delivery/WeaponDelivery").order_info,manager._spawn_label,mart.get_node("Fires")._label]
		for money in [hud.sales_label,hud.losses_label,hud.delta_label]:
			check(root.get_visible_rect().encloses(money.get_global_rect()),"money stays inside viewport")
			for control in controls: check(not money.get_global_rect().intersects(control.get_global_rect()),"economy separated from "+str(control.name))
	root.size=Vector2i(1280,720)
	await stock("can")
	customer=manager.spawn_customer([&"can"])
	await wait_checkout(customer)
	DayManager.notify_event(mart,&"family")
	mart.get_node("Delivery/WeaponDelivery").order()
	manager.sales+=25
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p132_hud.png")
	var displayed_sales:=hud.sales
	var displayed_losses:=hud.losses
	day.end_day()
	await frames(140)
	check(day.result.sales==displayed_sales and day.result.net==displayed_sales-displayed_losses,"Result net exactly matches summary sources")
	check(not hud.sales_label.visible and not hud.delta_label.visible,"Result hides gameplay economy")
	day.confirm_result()
	await frames(2)
	check(hud.sales==0 and hud.losses==0 and not hud.delta_label.visible,"next day baseline resets without a fake money delta")
	print("Prompt 13.2 HUD completed; failures: ",failures)
	quit(1 if failures else 0)
