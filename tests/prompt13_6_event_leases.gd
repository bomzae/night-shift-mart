extends "res://tests/prompt6_1_smoke.gd"

func run_flow(flow: String) -> void:
	await setup_mart()
	var day: DayManager=mart.get_node("DayManager")
	day.shift_duration_seconds=120
	day.timeline_enabled=true
	day.start_day()
	manager.spawning_enabled=false
	player.health.max_health=10000
	player.health.current_health=10000
	var events: Dictionary={}
	var times: Array[float]=[]
	day.event_started.connect(func(kind):
		events[kind]=int(events.get(kind,0))+1
		times.append(day.shift_elapsed_seconds)
		print("LEASE136 FLOW ",flow," ",kind," at=",day.clock_text()))
	var drunk: DrunkCustomer
	var child: LostChild
	var thief: ThiefCustomer
	var parked:=false
	var supported:=false
	var reunited:=false
	var late_done:=false
	var saw_pending:=false
	for tick in range(7380):
		await frames(1)
		if day.state==DayManager.State.RESULT: break
		for node in mart.get_node("Drunks").get_children():
			if node is DrunkCustomer: drunk=node
		for pair in mart.get_node("LostFamilies").pairs: child=pair.child
		if flow=="E" and is_instance_valid(drunk):
			if not parked:
				parked=true
				var cart: ShoppingCart=mart.get_node("Cart")
				await place(cart,Vector3(0,0.02,20))
				await place(drunk,Vector3(0,2.2,20))
				drunk.begin_carry(interaction,player)
				drunk.end_carry()
			supported=supported or drunk.supported_by_cart
		if flow=="F" and is_instance_valid(child) and not reunited:
			reunited=await reunite_at(child,Vector3(0,0.65,0.7))
			child.parent_npc.set_physics_process(false)
		if flow=="G":
			for node in mart.get_node("Thieves").get_children():
				if node is ThiefCustomer:
					thief=node
					thief.set_physics_process(false) # Controlled unresolved approach, no fake capture/escape.
		if events.has(&"boss") and not saw_pending:
			saw_pending=true
			check(is_instance_valid(child) and (child.reunited if flow=="F" else not child.reunited),flow+" family world state preserved through boss spawn")
			check(is_instance_valid(drunk) and mart.get_node("Drunks").drunks_removed==0,flow+" lease is not fake drunk completion")
			if flow=="G":
				check(is_instance_valid(thief) and thief.theft_state!=ThiefCustomer.TheftState.CAPTURED and int(day.event_slot_release_counts.get("thief",0))==1,"long unresolved thief releases lease without capture or loss mutation")
		if flow=="E" and events.has(&"boss") and not late_done:
			late_done=true
			drunk.begin_carry(interaction,player)
			interaction.held_object=drunk
			await place(drunk,mart.get_node("Drunks/ExitRemovalZone").global_position)
			interaction.drop_held(true)
			reunited=await reunite_at(child,Vector3(0,0.65,0.7))
			await frames(60)
			check(reunited and mart.get_node("LostFamilies").lost_children_found==1 and mart.get_node("Drunks").drunks_removed==1,"late genuine reunion and exit count once after lease release")
	check(events.get(&"drunk",0)==1 and events.get(&"family",0)==1 and events.get(&"thief",0)==1 and events.get(&"boss",0)==1,flow+" each automatic event occurs once")
	check(saw_pending and day.state==DayManager.State.RESULT,flow+" unresolved world reaches result")
	if flow=="E": check(supported and late_done,"parked cart cannot pause day; late resolution remains possible")
	for i in range(1,times.size()): check(times[i]-times[i-1]>=12,"minimum twelve-second spacing")
	day.confirm_result()
	check(day.day_number==2 and day._event_slots.is_empty() and day.event_slot_release_counts.is_empty(),flow+" Day 2 clears leases and actors")

func run_checks() -> void:
	await setup_mart()
	var day: DayManager=mart.get_node("DayManager")
	day.set_physics_process(false)
	var start:=day.shift_elapsed_seconds
	var child: LostChild=mart.get_node("LostFamilies").spawn_pair()
	day.shift_elapsed_seconds=start+150*(day.family_exclusive_hours-0.01)
	check(day.introduction_event_count()==1,"unresolved family owns full 75-minute resolution window")
	day.shift_elapsed_seconds+=3
	check(day.introduction_event_count()==0 and day.active_event_count()==1,"family lease releases without deleting world entity")
	day.introduction_event_count()
	check(not child.reunited and mart.get_node("LostFamilies").lost_children_found==0 and day.event_slot_release_counts.family==1,"family lease expiry is one-time and not success")
	for flow in ["E","F","G"]: await run_flow(flow)
	quit(1 if failures else 0)
