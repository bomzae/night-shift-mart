extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	await starter_main()
	var thieves: ThiefManager=mart.get_node("Thieves")
	var candidates:=thieves.stock_candidates()
	candidates.sort_custom(func(a,b):return a.product.global_position.distance_to(thieves.escape_position())<b.product.global_position.distance_to(thieves.escape_position()))
	var retained: GrabbableBody=candidates[0].product
	for product in mart.get_node("Products").get_children():
		if product!=retained: product.queue_free()
	await frames(3)
	var thief:=thieves.spawn_thief()
	check(thief.target_product==retained and thief.theft_state==ThiefCustomer.TheftState.ENTRY,"sparse front stock still starts ordinary entry")
	var visited:=false
	for tick in range(6000):
		await frames(1)
		if not is_instance_valid(thief): break
		visited=visited or thief.browsing_visits>0
		if thief.capturable(): break
	check(visited and is_instance_valid(thief) and thief.capturable(),"sparse stock browses interior before returning to available goods")
	await starter_main()
	thieves=mart.get_node("Thieves")
	var day: DayManager=mart.get_node("DayManager")
	thief=thieves.spawn_thief()
	thief.recover_progress(6) # Isolated terminal obstruction outcome, not fake theft.
	check(thief.theft_state==ThiefCustomer.TheftState.LEAVING and thief.stolen_item.is_empty(),"failed browsing abandons objective without remote pickup")
	check(not day.event_banner.seen.has(&"thief") and thieves.stolen_goods_value==0,"failed browsing creates neither notification nor loss")
	quit(1 if failures else 0)
