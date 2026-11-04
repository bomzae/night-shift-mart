extends "res://tests/prompt12_smoke.gd"

func fight(data: WeaponDefinition, ticks: int) -> void:
	await weapon_setup(data)
	weapon_body.durability = 10000 # Observe sustained pressure, not the existing break limit.
	rat.current_health = 10000
	player.health.max_health = 10000
	player.health.current_health = 10000
	rat.rotation.y = PI
	rat.provoke(player)
	rat.update_awareness(0)
	rat._charge_wait = 0
	rat.begin_telegraph()
	rat.set_physics_process(true)
	player.set_physics_process(true)
	var telegraphs := 1
	var charges := 0
	var moving_charge_ticks := 0
	var previous := rat.state
	var start := Engine.get_physics_frames()
	var last_attack := start
	var longest_gap := 0.0
	while Engine.get_physics_frames()-start < ticks:
		var toward := rat.position-player.position
		toward.y = 0
		if toward.length() > 0.1: player.look_at(player.position+toward)
		Input.action_press("move_forward")
		if is_instance_valid(weapon_body) and interaction.held_object != weapon_body and not player.knockdown.active():
			# Re-present a dropped weapon for real LMB pickup; preserve charge knockdown/recovery.
			await place(weapon_body, interaction.camera.global_position-interaction.camera.global_basis.z*1.5)
			await press("grab")
		elif is_instance_valid(weapon_body) and interaction.held_object == weapon_body and not player.knockdown.active() and weapon_body.cooldown_left <= 0 and toward.length() <= data.range:
			await press("grab")
		await frames(1)
		if rat.state == KingRat.State.TELEGRAPH and previous != rat.state: telegraphs += 1
		if rat.charge_count > charges:
			charges = rat.charge_count
			longest_gap = maxf(longest_gap, (Engine.get_physics_frames()-last_attack)/60.0)
			last_attack = Engine.get_physics_frames()
		if rat.state == KingRat.State.CHARGE and rat.last_ai_velocity.length() > 1: moving_charge_ticks += 1
		if OS.get_cmdline_user_args().has("--broom-only") and previous != rat.state:
			print("BROOM_STATE t=", (Engine.get_physics_frames()-start)/60.0, " state=", KingRat.State.keys()[rat.state], " remaining=", rat.telegraph_remaining, " warning=", rat.resume_warning_left, " blocked=", rat._attack_path_blocked, " recoil=", rat._recoil_left)
		previous = rat.state
	Input.action_release("move_forward")
	longest_gap = maxf(longest_gap, (Engine.get_physics_frames()-last_attack)/60.0)
	print("PRESSURE125 ", data.weapon_id, " seconds=", (Engine.get_physics_frames()-start)/60.0, " hits=", rat.hit_count, " telegraph_entries=", telegraphs, " charge_launches=", charges, " commits=", rat.attack_commit_count, " charge_motion_ticks=", moving_charge_ticks, " cancels=", rat.get("attack_cancel_count"), " max_gap=", longest_gap)
	check(rat.hit_count >= 4, "real sustained melee hits " + data.weapon_id)
	check(charges >= (3 if ticks > 1000 else 1) and longest_gap < 10, "sustained melee cannot erase all counterattacks " + data.weapon_id)
	check(moving_charge_ticks > 5, "counterattacks actually move instead of merely entering a state " + data.weapon_id)
	check(rat.get("attack_cancel_count") == 0, "ordinary melee never cancels intent " + data.weapon_id)
	player.set_physics_process(false)

func run_checks() -> void:
	if OS.get_cmdline_user_args().has("--broom-only"):
		await fight(WEAPONS[2], 360)
		quit(1 if failures else 0)
		return
	for data in WEAPONS: await fight(data, 480 if OS.get_cmdline_user_args().has("--baseline") else 1800)
	print("P125 pressure complete failures=", failures)
	quit(1 if failures else 0)
