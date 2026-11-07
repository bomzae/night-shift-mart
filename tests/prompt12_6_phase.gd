extends "res://tests/prompt12_smoke.gd"

func telegraph_hit(data: WeaponDefinition) -> void:
	await weapon_setup(data)
	rat.rotation.y = PI
	rat.provoke(player)
	rat.update_awareness(0)
	rat.begin_telegraph()
	var instance := rat.attack_instance_id
	rat.set_physics_process(true)
	await frames(maxi(1, int((0.30-data.windup_time)*60)))
	await press("grab")
	for tick in range(40):
		if rat.hit_count > 0: break
		await frames(1)
	var saved := rat.telegraph_remaining
	var origin := rat.position
	print("PHASE126 HIT ",data.weapon_id," state=",KingRat.State.keys()[rat.state]," committed=",rat.attack_committed," remaining=",saved," cue=",rat.mood.text)
	check(rat.hit_count == 1 and rat._recoil_left > 0, "real telegraph swing retains recoil " + data.weapon_id)
	check(rat.state == KingRat.State.TELEGRAPH and rat.mood.text.begins_with("!") and rat.material.albedo_color == Color.ORANGE_RED, "telegraph state and warning survive damage overlay " + data.weapon_id)
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/p126_telegraph_"+data.weapon_id+".png")
	await frames(5)
	check(is_equal_approx(saved, rat.telegraph_remaining), "hit overlay pauses remaining warning " + data.weapon_id)
	var previous := rat.state
	var reentries := 0
	var continuous := true
	for tick in range(90):
		await frames(1)
		if rat.damage_reaction_active(): continuous = continuous and rat.telegraph_active and rat.state == KingRat.State.TELEGRAPH and rat.mood.text.begins_with("!")
		if rat.state == KingRat.State.TELEGRAPH and previous != rat.state: reentries += 1
		previous = rat.state
		if rat.charge_count > 0: break
	check(rat.charge_count == 1 and rat.attack_commit_count == 1 and reentries == 0, "same telegraph reaches one charge without enter again " + data.weapon_id)
	check(continuous and rat.attack_instance_id == instance and rat.telegraph_start_count == 1 and rat.telegraph_resume_count == 1, "entire damage overlay keeps one warning instance " + data.weapon_id)
	check(rat.position.distance_to(origin) > 0.15, "continued telegraph accepts displaced origin " + data.weapon_id)
	print("PHASE126 END ",data.weapon_id," commits=",rat.attack_commit_count," resumes=",rat.attack_resume_count," charge=",rat.charge_count," reentries=",reentries)

func run_checks() -> void:
	for data in WEAPONS: await telegraph_hit(data)
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,19)
	rat.provoke(player)
	rat.update_awareness(0)
	rat.begin_telegraph()
	for tick in range(60):
		await frames(1)
		if rat.charge_count > 0: break
	rat.receive_impact(48, Vector3.FORWARD*40, player, 0, true)
	var rewarned := false
	for tick in range(100):
		await frames(1)
		rewarned = rewarned or rat.state == KingRat.State.TELEGRAPH
	check(not rewarned and rat.charge_count == 1, "charge hit never creates another telegraph or launch")
	print("P126 phase complete failures=",failures)
	quit(1 if failures else 0)
