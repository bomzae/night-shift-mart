extends "res://tests/prompt4_smoke.gd"

func run_checks() -> void:
	await setup_mart()
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	await place(drunk,Vector3(0,0.8,18))
	await frames(20)
	drunk.bump_remaining=0.6
	drunk.shelf_contact_time=0.3
	check(drunk.begin_carry(interaction,player),"carry accepts drunk during bump")
	check(drunk.bump_remaining==0 and drunk.shelf_contact_time==0,"carry immediately cancels collision steering")
	drunk.end_carry()
	drunk.bump_remaining=0.6
	drunk.supported_by_cart=true
	drunk._physics_process(0.01)
	check(drunk.bump_remaining==0 and drunk.wander_route.is_empty(),"cart cargo cancels steering and route")
	drunk.supported_by_cart=false
	drunk.bump_remaining=0.6
	drunk.knockdown.try_start(Vector3.RIGHT)
	drunk._physics_process(0.01)
	check(drunk.knockdown.active() and drunk.bump_remaining==0,"knockdown takes priority over shelf reaction")
	drunk.knockdown.finish_recovery()
	drunk.avoided_shelves[&"CanShelf"]=5.0
	drunk._physics_process(0.1)
	check(drunk.avoided_shelves.has(&"CanShelf"),"collided shelf remains temporarily excluded")
	drunk._physics_process(5.1)
	check(not drunk.avoided_shelves.has(&"CanShelf"),"shelf exclusion expires")
	drunk._bump_origin=drunk.global_position
	drunk.bump_remaining=0.1
	drunk.knockdown.phase=KnockdownState.Phase.UPRIGHT
	drunk._physics_process(0.11)
	check(drunk.bump_cooldown>drunk.progress_watchdog.check_window,"failed short escape yields to long progress watchdog instead of repeated bumps")
	print("Prompt 13.3 priority completed; failures: ",failures)
	quit(1 if failures else 0)
