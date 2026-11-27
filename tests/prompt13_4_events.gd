extends "res://tests/prompt4_smoke.gd"

func observe_day(parked: bool) -> void:
	await setup_mart()
	var day: DayManager = mart.get_node("DayManager")
	day.shift_duration_seconds = 120
	day.timeline_enabled = true
	day.start_day()
	manager.spawning_enabled = false
	var stamps := {}
	var times: Array[float] = []
	var parked_once := false
	var supported := false
	var released_alive := false
	var drunk: DrunkCustomer
	# Scheduler tests count entry; the theft banner is checked separately in 13.7.
	day.event_started.connect(func(kind):
		if kind==&"thief": return
		stamps[kind] = day.clock_text()
		times.append(day.shift_elapsed_seconds)
		print("EVENT134 ",kind," clock=",day.clock_text()," elapsed=",day.shift_elapsed_seconds))
	mart.get_node("Thieves").thief_entered.connect(func(_actor):
		var kind:=&"thief"
		stamps[kind] = day.clock_text()
		times.append(day.shift_elapsed_seconds)
		print("EVENT134 ",kind," clock=",day.clock_text()," elapsed=",day.shift_elapsed_seconds))
	for tick in range(7350):
		await frames(1)
		for candidate in mart.get_node("Drunks").get_children():
			if candidate is DrunkCustomer: drunk = candidate
		if is_instance_valid(drunk):
			if parked and not parked_once:
				parked_once = true
				var cart: ShoppingCart = mart.get_node("Cart")
				await place(cart,Vector3(0,0.02,20))
				await place(drunk,Vector3(0,2.2,20))
				drunk.begin_carry(interaction,player)
				drunk.end_carry()
			supported = supported or drunk.supported_by_cart
			if day.drunk_slot_release_count > 0:
				released_alive = true
		# Only the drunk remains unresolved. Resolve each subsequent family normally.
		var families = mart.get_node("LostFamilies")
		for pair in families.pairs:
			if not pair.child.reunited:
				pair.child.position = pair.parent.position + Vector3(0,0.7,0.7)
				families.try_reunion(pair.child)
	print("DAY134 parked=",parked," supported=",supported," ",stamps," result=",day.state," removed=",mart.get_node("Drunks").drunks_removed)
	check(stamps.has(&"drunk") and stamps.has(&"family") and stamps.has(&"thief") and stamps.has(&"boss"),"unresolved drunk does not suppress day introductions")
	check(mart.get_node("Drunks").drunks_removed == 0,"slot expiry is not drunk completion")
	check(day.state == DayManager.State.RESULT,"unresolved drunk day reaches result")
	check(released_alive,"unresolved actor survives scheduler release")
	if parked: check(supported,"parked case actually rests on physical cart")
	for i in range(1,times.size()):
		check(times[i]-times[i-1] >= 12,"automatic introductions retain minimum real spacing")
	day.confirm_result()
	check(day.day_number == 2 and day._drunk_slots.is_empty() and day.drunk_slot_release_count == 0,"next day clears only runtime scheduling leases")

func run_checks() -> void:
	await observe_day(false)
	await observe_day(true)
	quit(1 if failures else 0)