extends "res://tests/prompt12_smoke.gd"

func snapshot() -> Dictionary:
	return {"state": KingRat.State.keys()[rat.state], "committed": rat.get("attack_committed"),
		"remaining": rat.get("telegraph_remaining"), "legacy_left": rat._left,
		"cooldown": rat._charge_wait, "recoil": rat._recoil_left,
		"stagger": rat.state == KingRat.State.STAGGER or rat._attack_stagger_left > 0}

func during_telegraph(data: WeaponDefinition) -> void:
	await weapon_setup(data)
	rat.rotation.y = PI
	rat.current_health = 10000
	rat.provoke(player)
	rat._charge_wait = 0
	rat.update_awareness(0)
	rat.begin_telegraph()
	rat.set_physics_process(true)
	# Start swing so its active arc lands around the middle of the warning.
	await frames(maxi(1, int((0.32-data.windup_time)*60)))
	var before := snapshot()
	await press("grab")
	for tick in range(40):
		if rat.hit_count > 0: break
		await frames(1)
	print("INTENT_HIT ", data.weapon_id, " before=", before, " hit=", snapshot())
	check(rat.hit_count == 1 and rat._recoil_left > 0 and rat._flash > 0, "real telegraph hit reacts " + data.weapon_id)
	check(rat.get("attack_committed") == true, "telegraph intent survives " + data.weapon_id)
	var saved := rat.telegraph_remaining
	var origin := rat.position
	await frames(3)
	check(is_equal_approx(rat.telegraph_remaining, saved), "damage reaction pauses saved telegraph " + data.weapon_id)
	var charge_tick := -1
	var reaction_end := -1
	var resumed := false
	for tick in range(180):
		await frames(1)
		if rat.state == KingRat.State.TELEGRAPH and not rat.damage_reaction_active() and not resumed:
			resumed = true
			reaction_end = tick
			print("INTENT_RESUME ", data.weapon_id, " ", snapshot())
			check(is_equal_approx(rat.telegraph_remaining, saved) and saved < 0.5, "resume preserves progress instead of restarting " + data.weapon_id)
			check(rat.position.distance_to(origin) > 0.15, "attack resumes from displaced origin " + data.weapon_id)
		if rat.state == KingRat.State.CHARGE:
			charge_tick = tick
			break
	print("INTENT_RESULT ", data.weapon_id, " charge_after=", charge_tick/60.0, " reaction_end=", reaction_end/60.0, " final=", snapshot())
	check(resumed and charge_tick >= 0 and charge_tick < 110, "committed attack resumes promptly " + data.weapon_id)
	check(charge_tick-reaction_end >= 14, "resumed warning remains readable " + data.weapon_id)

func run_checks() -> void:
	for data in WEAPONS: await during_telegraph(data)
	await product_warning()
	await boundary_checks()
	await execution_boundary()
	print("P125 intent complete failures=", failures)
	quit(1 if failures else 0)

func boundary_checks() -> void:
	await weapon_setup(WEAPONS[0])
	rat.rotation.y = PI
	rat.provoke(player)
	rat.update_awareness(0)
	rat._charge_wait = 0
	rat.begin_telegraph()
	rat.set_physics_process(true)
	while rat.telegraph_remaining > 0.04: await frames(1)
	weapon_body.start_swing()
	weapon_body._sample_arc(0.5)
	check(rat.hit_count == 1 and rat.attack_committed and rat.telegraph_remaining < 0.05 and rat.mood.text.begins_with("!"), "late real sweep preserves almost-complete visible warning")
	while rat.damage_reaction_active(): await frames(1)
	var resumed_frame := Engine.get_physics_frames()
	var saved_progress := rat.telegraph_remaining
	check(rat.state == KingRat.State.TELEGRAPH and rat.mood.text == "!" and saved_progress > 0, "late hit keeps its warning throughout reaction instead of hiding it")
	while rat.state != KingRat.State.CHARGE: await frames(1)
	var elapsed := (Engine.get_physics_frames()-resumed_frame)/60.0
	check(elapsed >= saved_progress-0.02 and elapsed <= saved_progress+0.04, "continuous visible warning resumes exact remainder without added quarter-second")
	# Aim can change while warning; after execution it cannot home.
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,19)
	rat.provoke(player)
	rat.update_awareness(0)
	rat._charge_wait = 0
	rat.begin_telegraph()
	await frames(20)
	player.position.x = 2
	while rat.state != KingRat.State.CHARGE: await frames(1)
	await frames(1) # First charge motor tick locks the launch direction.
	var locked := rat.charge_direction
	var aimed := (player.position-rat.position).normalized()
	check(locked.dot(aimed) > 0.99 and locked.x > 0.2, "charge locks current player direction only at execution")
	player.position.x = -4
	await frames(12)
	check(rat.charge_direction.is_equal_approx(locked) and not player.knockdown.active(), "post-launch dodge works without homing")

func product_warning() -> void:
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,18)
	rat.provoke(player)
	rat.update_awareness(0)
	rat._charge_wait = 0
	rat.begin_telegraph()
	await frames(20)
	var product: GrabbableBody = load(ProductCatalog.find(&"frying_pan").scene_path).instantiate()
	mart.add_child(product)
	await place(product, Vector3(0,0.85,15.4))
	product.gravity_scale = 0
	product.attack_attribution.remember(player)
	product.launch(Vector3.FORWARD, 12, interaction.damage_for(product.price, 1))
	for tick in range(20):
		await frames(1)
		if rat.hit_count > 0: break
	print("PRODUCT_INTENT hit=", snapshot())
	check(rat.hit_count == 1 and rat._recoil_left > 0 and rat.get("attack_committed") == true, "real thrown product preserves committed intent")
	var charged := false
	for tick in range(120):
		await frames(1)
		if rat.state == KingRat.State.CHARGE:
			charged = true
			break
	check(charged, "product reaction resumes charge")

func execution_boundary() -> void:
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,19)
	rat.provoke(player)
	rat.update_awareness(0)
	rat._charge_wait = 0
	rat.begin_telegraph()
	for tick in range(60):
		await frames(1)
		if rat.charge_count > 0: break
	check(rat.charge_count == 1 and rat.attack_committed, "first motor tick does not discard unfinished attack intent")
	var target_id := player.get_instance_id()
	rat._charge_hit(player) # Existing shared charge damage/knockdown path.
	check(player.health.current_health == 70 and player.knockdown.fall_count == 1, "charge contact remains thirty HP and knockdown")
	rat.receive_impact(12, Vector3.FORWARD*150, player, 0, true)
	check(rat.attack_committed and rat._recoil_left > 0, "execution-boundary hit still displaces and delays boss")
	for tick in range(90):
		await frames(1)
		if not rat.attack_committed: break
	check(rat.charge_count == 1 and rat.attack_commit_count == 1 and rat.attack_cancel_count == 0 and rat.telegraph_resume_count == 0, "execution reaction never creates another telegraph or charge start")
	rat._charge_hit(player)
	check(rat._hit_targets.has(target_id) and player.health.current_health == 70, "resuming same attack cannot reset per-target charge damage guard")
