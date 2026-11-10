extends "res://tests/prompt12_smoke.gd"

func snapshot() -> Dictionary:
	return {"state":KingRat.State.keys()[rat.state], "instance":rat.attack_instance_id,
		"target":rat.aggro_target.get_instance_id() if is_instance_valid(rat.aggro_target) else 0,
		"velocity":rat.velocity,"ai":rat.last_ai_velocity,"recoil":rat.recoil_velocity,
		"recoil_left":rat._recoil_left,"committed":rat.attack_committed,"remaining":rat.telegraph_remaining}

func trial(mode: String, data: WeaponDefinition = null) -> void:
	if data == null: data = WEAPONS[1]
	await weapon_setup(data)
	rat.rotation.y = PI
	rat.current_health = 10000
	rat.provoke(player)
	rat.update_awareness(0)
	rat._charge_wait = 0
	if mode == "approach":
		rat.position.z = 17.5
		rat.charge_range = 0.1
		rat.desired_attack_distance = 0.1
		rat.pursuit_speed = 1.5 # Hit while approaching, before reaching body-contact hold.
	else:
		if mode == "charge": rat.position.z = 16.5
		rat.begin_telegraph()
	rat.set_physics_process(true)
	await frames(2)
	if mode == "charge":
		for tick in range(60):
			await frames(1)
			if rat.charge_start_count > 0: break
	var before := snapshot()
	await press("grab")
	for tick in range(35):
		if rat.hit_count > 0: break
		await frames(1)
	print("PHASE127 ",mode," weapon=",data.weapon_id," before=",before," hit=",snapshot())
	check(rat.hit_count == 1 and rat._recoil_left > 0 and rat._flash > 0, "real weapon hit in " + mode + " " + data.weapon_id)
	check(rat.is_aggro and rat.aggro_target == player, "same combat target survives " + mode)
	if mode == "charge":
		check(not rat.attack_committed and rat.ended_attack_instance_id == before.instance and rat.charge_interrupt_count == 1, "charge hit ends old attack instance immediately")
		check(Vector2(rat.velocity.x,rat.velocity.z).length() < 0.01 and rat.last_ai_velocity == Vector3.ZERO, "charge motor velocity removed on damage before recoil tick")
		check(rat._charge_wait > 0, "interrupted charge retains cadence cooldown")
	var saved := rat.telegraph_remaining
	var first_recovered := -1
	var resumed_old_charge := false
	for tick in range(90):
		await frames(1)
		if first_recovered < 0 and not rat.damage_reaction_active(): first_recovered = rat.state
		if mode == "telegraph" and rat.damage_reaction_active():
			check(is_equal_approx(saved,rat.telegraph_remaining), "telegraph pause preserves remaining")
		if not rat.damage_reaction_active() and rat.state == KingRat.State.CHARGE and rat.attack_instance_id == before.instance: resumed_old_charge = true
	print("PHASE127 AFTER ",mode," first_recovered=",KingRat.State.keys()[first_recovered] if first_recovered >= 0 else "none"," final=",snapshot()," same_charge=",resumed_old_charge)
	if mode == "approach":
		check(first_recovered == KingRat.State.PURSUIT and rat.is_aggro and rat.aggro_target == player, "approach reaction resumes pursuit of same player")
		check(rat.charge_start_count == 0 and rat.telegraph_start_count == 0, "approach cannot skip warning")
	elif mode == "telegraph":
		check(rat.attack_instance_id == before.instance and rat.telegraph_start_count == 1 and rat.telegraph_resume_count == 1 and rat.charge_start_count == 1, "same telegraph resumes and charges once")
	else:
		check(not resumed_old_charge and not rat.attack_committed and rat.charge_start_count == 1, "damaged charge ends without same-instance resume")
		# Keep target in open attack range while the original cooldown expires.
		player.position = rat.position + Vector3(0,0,4)
		var next_warning := false
		for tick in range(360):
			await frames(1)
			if rat.telegraph_active:
				next_warning = true
				check(rat.attack_instance_id != before.instance and rat.telegraph_remaining > 0.6, "next attack begins a new full telegraph")
				break
		check(next_warning, "interrupted charge returns to active combat decision")
		for tick in range(60):
			await frames(1)
			if rat.charge_start_count == 2: break
		check(rat.charge_start_count == 2 and rat.attack_instance_id != before.instance, "next charge uses a new attack instance")

func run_checks() -> void:
	for mode in ["approach","telegraph"]: await trial(mode)
	for data in WEAPONS: await trial("charge",data)
	print("P127 phase complete failures=",failures)
	quit(1 if failures else 0)
