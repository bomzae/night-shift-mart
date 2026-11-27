extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	for run_seed in [137,237,337]:
		await starter_main()
		seed(run_seed)
		var day: DayManager=mart.get_node("DayManager")
		var announced:=[]
		day.event_started.connect(func(kind):
			if kind==&"thief": announced.append(day.shift_elapsed_seconds))
		var thief: ThiefCustomer=mart.get_node("Thieves").spawn_thief()
		var start:=day.shift_elapsed_seconds
		var before:=thief.position
		var travel:=0.0
		var theft_at:=-1.0
		var theft_distance:=0.0
		var theft_pos:=Vector3.ZERO
		var zones:={}
		for tick in range(9000):
			await frames(1)
			if not is_instance_valid(thief): break
			travel+=thief.position.distance_to(before)
			before=thief.position
			zones[DrunkCustomer.store_zone(before)]=true
			if theft_at<0 and thief.theft_state==ThiefCustomer.TheftState.ESCAPING:
				theft_at=day.shift_elapsed_seconds-start
				theft_pos=thief.position
				theft_distance=travel
		print("THIEF137 ",JSON.stringify({"seed":run_seed,"theft_seconds":theft_at,"theft_pos":theft_pos,"pre_distance":theft_distance,"escape_distance":travel-theft_distance,"escape_seconds":day.shift_elapsed_seconds-start-theft_at,"zones":zones.keys(),"notifications":announced,"entry":start,"alive":is_instance_valid(thief)}))
		check(not announced.is_empty() and announced[0]>start+3,"notification follows actual shopping route, not spawn")
	quit(1 if failures else 0)
