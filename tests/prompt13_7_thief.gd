extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	await starter_main()
	var thieves: ThiefManager=mart.get_node("Thieves")
	var day: DayManager=mart.get_node("DayManager")
	var events:=[]
	day.event_started.connect(func(kind):
		if kind==&"thief": events.append(day.shift_elapsed_seconds))
	await press("debug_spawn_thief")
	var thief: ThiefCustomer=thieves.get_children().filter(func(n):return n is ThiefCustomer)[0]
	var lease_hour: float=day._event_slots[thief.get_instance_id()].hour
	check(thief.theft_state==ThiefCustomer.TheftState.ENTRY and events.is_empty(),"debug spawn uses anonymous entry with no thief notification")
	check(thief._mesh.material_override.albedo_color==Color(0.65,0.75,0.85) and thief._mood.text==":)","entry appearance matches ordinary customer")
	var browsing:=false
	var pre_theft_loss:=false
	for tick in range(6000):
		await frames(1)
		if not is_instance_valid(thief): break
		if thief.theft_state==ThiefCustomer.TheftState.BROWSING:
			browsing=true
			pre_theft_loss=pre_theft_loss or not events.is_empty() or thieves.stolen_goods_value>0
		if thief.capturable(): break
	check(browsing and not pre_theft_loss,"real internal browsing is silent with no early loss")
	check(is_instance_valid(thief) and thief.capturable() and thief.browsing_visits==1 and events.size()==1,"actual pickup alone announces theft and begins escape")
	if is_instance_valid(thief):
		check(day._event_slots[thief.get_instance_id()].hour==lease_hour,"theft never renews entry scheduling lease")
		var price: float=thief.stolen_item.price
		var outside:=thieves.escape_position()
		thief.position=outside
		thieves.finish_escape(thief)
		thieves.finish_escape(thief)
		check(thieves.stolen_goods_value==price,"actual outside escape records loss once")
	await starter_main()
	thieves=mart.get_node("Thieves")
	day=mart.get_node("DayManager")
	for product in mart.get_node("Products").get_children(): product.queue_free()
	await frames(3)
	var empty:=thieves.spawn_thief()
	await frames(240)
	check(not is_instance_valid(empty) and thieves.stolen_goods_value==0 and not day.event_banner.seen.has(&"thief"),"empty store fallback has no theft banner or loss")
	quit(1 if failures else 0)
