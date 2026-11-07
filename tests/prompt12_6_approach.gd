extends "res://tests/prompt12_smoke.gd"

func approach_hit(data: WeaponDefinition) -> void:
	await weapon_setup(data)
	rat.rotation.y = PI
	rat.position.z = 17.5
	rat.provoke(player)
	rat.update_awareness(0)
	# A controlled approach inside melee reach; normal decision/velocity remain active.
	rat.charge_range = 0.1
	rat.desired_attack_distance = 0.1
	rat._charge_wait = 0
	rat.set_physics_process(true)
	await frames(2)
	check(rat.attack_phase == KingRat.AttackPhase.COMBAT_APPROACH and rat.last_ai_velocity.z > 1 and not rat.attack_committed, "moving approach is uncommitted " + data.weapon_id)
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/p126_approach_"+data.weapon_id+".png")
	await press("grab")
	for tick in range(40):
		await frames(1)
		if rat.hit_count > 0: break
	check(rat.hit_count == 1 and rat._recoil_left > 0 and rat.approach_interrupt_count == 1, "actual approach hit interrupts once " + data.weapon_id)
	check(not rat.attack_committed and not rat.telegraph_active and rat.attack_instance_id == 0 and not rat.mood.text.begins_with("!"), "approach hit has no saved warning or intent " + data.weapon_id)
	var at_hit := rat.position
	var held := 0
	var charged_early := false
	var moved_in_hold := false
	var reached_decision := false
	# Restore ordinary attack range for the post-reaction decision.
	rat.charge_range = 7
	rat.desired_attack_distance = 3.2
	for tick in range(150):
		await frames(1)
		charged_early = charged_early or rat.charge_count > 0
		if rat.state == KingRat.State.HOLD and rat._spacing_grace > 0:
			held += 1
			moved_in_hold = moved_in_hold or rat.last_ai_velocity.length() > 0.01
		if rat.attack_committed:
			reached_decision = true
			break
	print("APPROACH126 ",data.weapon_id," interrupted=",rat.approach_interrupt_count," hold_ticks=",held," recoil_z=",at_hit.z-rat.position.z," commit=",rat.new_attack_commit_count," warning=",rat.telegraph_remaining)
	check(at_hit.z-rat.position.z > 0.15, "approach hit creates recoil space " + data.weapon_id)
	check(held >= 8 and held <= 25 and not moved_in_hold and not charged_early, "approach reaction has stationary brief hold and no sudden charge " + data.weapon_id)
	check(reached_decision and rat.telegraph_start_count == 1 and rat.telegraph_resume_count == 0 and rat.telegraph_remaining > 0.6, "fresh decision starts a full new warning " + data.weapon_id)

func approach_product() -> void:
	await boss_setup()
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.01,23)
	rat.provoke(player)
	rat._charge_wait = 0
	await frames(2)
	check(rat.attack_phase == KingRat.AttackPhase.COMBAT_APPROACH and not rat.attack_committed, "product target is naturally outside attack range")
	var product: GrabbableBody = load(ProductCatalog.find(&"frying_pan").scene_path).instantiate()
	mart.add_child(product)
	await place(product, rat.position+Vector3(0,0.85,1.4))
	product.gravity_scale = 0
	product.attack_attribution.remember(player)
	product.launch(Vector3.FORWARD,12,interaction.damage_for(product.price,1))
	for tick in range(30):
		await frames(1)
		if rat.hit_count > 0: break
	check(rat.hit_count == 1 and rat.approach_interrupt_count == 1 and not rat.attack_committed and rat._recoil_left > 0, "actual thrown product interrupts uncommitted approach")
	await frames(10)
	check(rat.charge_count == 0 and rat.telegraph_start_count == 0, "approach product reaction cannot skip to charge")

func run_checks() -> void:
	for data in WEAPONS: await approach_hit(data)
	await approach_product()
	print("P126 approach complete failures=",failures)
	quit(1 if failures else 0)
