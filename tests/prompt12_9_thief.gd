extends "res://tests/prompt9_smoke.gd"

func run_checks() -> void:
	var thief := await contact_fixture()
	thief.position = Vector3(0,0.01,20)
	thief.start_exit()
	for offset in [Vector3(0.65,0,0),Vector3(-0.65,0,0),Vector3(0,0,0.65),Vector3(0,0,-0.65)]:
		Graybox.box(mart,"EscapeBlock",Vector3(0.25,2,2) if offset.x != 0 else Vector3(2,2,0.25),thief.position+offset+Vector3.UP,Color.GRAY)
	await frames(2100)
	if is_instance_valid(thief): print("THIEF129 state=",thief.theft_state," attempts=",thief.progress_watchdog.recovery_attempts," pos=",thief.position," exit_distance=",thief.position.distance_to(thieves.escape_position())," resolved=",thief.resolved)
	check(not is_instance_valid(thief) or thief.resolved,"blocked escape final fallback cannot remain permanently unresolved")
	check(thieves.recovery_abort_count == 1 and thieves.stolen_goods_value == 0 and thieves.thieves_caught == 0,"navigation abort is neither remote escape loss nor player capture")
	check(is_instance_valid(thieves.last_recovered) and thieves.recovery_returned_value > 0,"blocked thief returns real loot to a checked free location")
	quit(1 if failures else 0)
