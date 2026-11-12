extends "res://tests/prompt11_8_smoke.gd"

func run_checks() -> void:
	await combat_at(15,1000)
	rat.set_physics_process(false)
	var before := rat.combat_recovery_count
	for excluded in [KingRat.State.TELEGRAPH,KingRat.State.HOLD,KingRat.State.STAGGER,KingRat.State.RECOIL,KingRat.State.CHARGE_RECOVERY]:
		rat.state = excluded
		for i in range(180): rat.observe_combat_progress(1.0/60)
		check(rat.combat_recovery_count == before and rat.local_no_progress_time == 0,"intentional/reaction state excluded "+str(excluded))
	rat.state = KingRat.State.PURSUIT
	for i in range(125): rat.observe_combat_progress(1.0/60)
	check(rat.combat_recovery_count == before+1 and rat.combat_recovery_stage == 1,"two-second local no-progress triggers decision reevaluation")
	for i in range(125): rat.observe_combat_progress(1.0/60)
	check(rat.combat_recovery_stage == 2 and not rat.pursuit_route.is_empty(),"blocked approach recomputes actual aisle route")
	for i in range(125): rat.observe_combat_progress(1.0/60)
	check(rat.combat_recovery_stage == 3 and rat._escape_left > 0,"obstruction schedules bounded lateral bypass")
	var offset := rat._escape_goal-rat.position
	check(offset.length() <= 1.01 and absf(offset.normalized().dot((player.position-rat.position).normalized())) < 0.1,"escape is lateral rather than large retreat")
	for i in range(250): rat.observe_combat_progress(1.0/60)
	check(rat.combat_recovery_stage == 5 and rat.state == KingRat.State.HOLD and rat.aggro_target == player and rat.is_aggro,"exhausted approach resets to brief decision hold with target preserved")
	rat.state = KingRat.State.PURSUIT
	before = rat.combat_recovery_count
	for i in range(180):
		rat.position.x += 0.01
		rat.observe_combat_progress(1.0/60)
	check(rat.combat_recovery_count == before,"real horizontal progress prevents false stuck")
	await boss_setup()
	rat.set_physics_process(false)
	rat.position = Vector3(0,0.01,20)
	player.position = Vector3(0,0.01,26)
	for wall_offset in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]:
		Graybox.box(mart,"LowCombatBlock",Vector3(0.3,0.95,2.3) if wall_offset.x != 0 else Vector3(2.3,0.95,0.3),rat.position+wall_offset+Vector3.UP*0.475,Color.GRAY)
	await frames(3)
	rat.provoke(player)
	rat._charge_wait = 0
	rat.state = KingRat.State.PURSUIT
	rat.set_physics_process(true)
	await frames(900)
	check(rat.combat_recovery_count >= 3 and rat.is_aggro and rat.aggro_target == player,"actual solid low-wall obstruction invokes recovery while retaining visible target")
	check(absf(rat.position.x) < 0.5 and absf(rat.position.z-20) < 0.5,"recovery cannot teleport through sealed world geometry")
	await combat_at(5)
	var instance := rat.attack_instance_id
	rat.receive_impact(48,Vector3.FORWARD*48,player,6,true)
	await frames(90)
	check(rat.attack_instance_id == instance and rat.telegraph_start_count == 1 and rat.charge_start_count == 1,"watchdog does not restart committed telegraph through hammer reaction")
	print("RAT WATCH129 failures=",failures)
	quit(1 if failures else 0)
