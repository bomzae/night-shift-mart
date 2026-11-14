extends "res://tests/prompt12_10_gap.gd"

func run_checks() -> void:
	# Real contact path without motor separation changing the measured boundary.
	await close_setup(1.229)
	rat.set_physics_process(false)
	rat._resolve_body_contact(weakref(player))
	check(player.health.current_health == 9990 and rat.contact_damage_count == 1,"body contact stays ten HP at the existing shell edge")
	check(not KnockdownState.blocked(player),"normal contact does not knock down")
	for i in range(60): rat._resolve_body_contact(weakref(player))
	check(rat.contact_damage_count == 1,"contact per-player cooldown prevents spam")
	player.position = rat.position+Vector3(0,0,1.231)
	rat._contact_waits.clear()
	rat._resolve_body_contact(weakref(player))
	check(rat.contact_damage_count == 1,"no invisible contact beyond 1.23m front shell")
	for distance in [1.25,1.3,1.35]:
		player.position = rat.position+Vector3(0,0,distance)
		rat._resolve_body_contact(weakref(player))
	check(rat.contact_damage_count == 1,"gap fix does not enlarge contact damage range")

	await close_setup(1.3,1.0)
	var origin := rat.position
	await frames(45)
	check(rat.state == KingRat.State.HOLD and rat.telegraph_start_count == 0,"cooldown still prevents premature close attack")
	check(rat._hold_decision_left <= rat.hold_decision_interval and rat.position.distance_to(origin) < 0.05,"cooldown uses bounded hold beats without backward retreat")
	await frames(20)
	check(rat.telegraph_active and rat.telegraph_remaining > 0.5,"cooldown expiry promptly starts a full readable telegraph")
	check(rat.combat_inactivity_recovery_count == 0,"legitimate cooldown is not diagnosed as inactive")

	await close_setup(1.3)
	rat.set_physics_process(false)
	rat.update_awareness(0)
	# Inject the old stuck HOLD independently of the corrected normal decision.
	for i in range(91): rat.observe_combat_inactivity(1.0/60)
	check(rat.combat_inactivity_recovery_count == 1 and rat.telegraph_active,"independent inactivity watchdog exits stale ready HOLD")
	check(rat.aggro_target == player and rat.telegraph_start_count == 1,"watchdog preserves target and commits only once")
	rat._charge_wait = 0 # Isolate phase exclusion from the separate cooldown guard.
	for i in range(180): rat.observe_combat_inactivity(1.0/60)
	check(rat.combat_inactivity_recovery_count == 1,"telegraph excluded from inactivity")
	rat.cancel_attack("test")
	for excluded in [KingRat.State.RECOIL,KingRat.State.STAGGER,KingRat.State.CHARGE_RECOVERY,KingRat.State.CHARGE]:
		rat.state = excluded
		for i in range(120): rat.observe_combat_inactivity(1.0/60)
		check(rat.combat_inactivity_recovery_count == 1,"active phase/reaction excluded "+str(excluded))
	rat.state = KingRat.State.HOLD
	rat._spacing_grace = 0.2
	for i in range(120): rat.observe_combat_inactivity(1.0/60)
	check(rat.combat_inactive_time == 0,"brief hit hold excluded")
	rat._spacing_grace = 0
	rat._charge_wait = 0
	rat.combat_inactive_time = 1.4
	rat.contact_damage_count += 1
	rat.observe_combat_inactivity(1.0/60)
	check(rat.combat_inactive_time == 0,"actual contact event resets inactivity")
	rat.clear_aggro()
	for i in range(120): rat.observe_combat_inactivity(1.0/60)
	check(rat.combat_inactivity_recovery_count == 1,"neutral behavior excluded")

	await close_setup(5)
	await frames(1)
	check(rat.telegraph_active,"five metres remains inside existing seven metre attack range")
	await close_setup(9)
	await frames(15)
	check(rat.state == KingRat.State.PURSUIT,"outside attack range still approaches")
	quit(1 if failures else 0)
