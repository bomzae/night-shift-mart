extends "res://tests/prompt12_smoke.gd"

func flash_visible() -> bool:
	return rat._flash > 0 and rat._flash_meshes.all(func(mesh): return mesh.material_overlay == rat._flash_material)

func restore_check() -> void:
	rat.clear_aggro()
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	rat.close_threat_time = 100
	rat.set_physics_process(true)
	await frames(35)
	check(rat._flash == 0 and rat._saved_overlays.is_empty(), "flash timer and saved state clear")
	check(rat._flash_meshes.all(func(mesh): return mesh.material_overlay == null), "every mesh restores original null overlay")
	check(is_zero_approx(rat.visual.rotation.x) and is_zero_approx(rat.visual.position.z), "local reaction pose restores")

func run_checks() -> void:
	for data in WEAPONS:
		await weapon_setup(data)
		await press("grab")
		for tick in range(60):
			await frames(1)
			if rat.hit_count > 0: break
		check(rat.last_damage == data.damage and flash_visible(), "actual melee damage flashes " + String(data.weapon_id))
		check(rat.visual.rotation.x < 0 and rat._reaction_left > 0 and rat.last_recoil_speed > 0, "immediate body pose reaction and recoil")
		check(rat._flash_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and rat._flash_meshes.size() == 7, "full silhouette flash independent of lighting")
		check(rat._flash >= 0.1 and rat._flash <= 0.15, "bounded flash duration")
		if data.damage >= 45:
			check(rat.state == KingRat.State.STAGGER and rat._reaction_tilt >= 0.24, "hammer strongest pose and original stagger")
		elif data.damage < 15:
			check(rat.last_recoil_speed > 2 and rat._reaction_tilt < 0.1, "broom light damage reaction but strong physical push")
		else:
			check(is_equal_approx(rat._reaction_duration, 0.16), "bat medium reaction")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/p122_hit_" + String(data.weapon_id) + ".png")
		interaction.drop_held()
		weapon_body.position = Vector3(8, 1, 20)
		await restore_check()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/p122_restored_" + String(data.weapon_id) + ".png")
		rat.set_physics_process(false)
		rat.position.x = 8
		await equip(data)
		await press("grab")
		await frames(50)
		check(rat._flash == 0 and rat._reaction_left == 0, "miss produces no target feedback")
	for type in [&"bread", &"can", &"watermelon", &"frying_pan", &"microwave", &"tv"]:
		await projectile_trial(type, 1)
		check(flash_visible() and rat._reaction_left > 0, "actual thrown product feedback " + String(type))
		var weight := ProductCatalog.find(type).weight
		var expected := 0.24 if weight >= 6 else (0.16 if weight >= 1 else 0.1)
		check(is_equal_approx(rat._reaction_duration, expected), "product mass selects light medium heavy feedback")
		await restore_check()
	for loaded in [false, true]:
		await cart_trial(loaded)
		check(flash_visible() and rat._reaction_left > 0, "actual cart and armed cargo feedback")
		mart.get_node("Cart").position.x = 10
		for item in mart.get_node("Products").get_children(): item.queue_free()
		await restore_check()
	await boss_setup()
	rat.position = Vector3(0, 0.01, 15)
	player.position = Vector3(0, 0.01, 20)
	rat.set_physics_process(false)
	var original := StandardMaterial3D.new()
	original.albedo_color = Color.BLUE
	rat._flash_meshes[0].material_overlay = original
	var base := rat.material
	for tick in range(8): rat.receive_damage(1)
	check(flash_visible(), "rapid damage refreshes single overlay snapshot")
	rat.set_physics_process(true)
	rat.state = KingRat.State.SPAWN
	rat._left = 100
	await frames(25)
	check(rat._flash_meshes[0].material_overlay == original and rat.material == base, "repeated hits restore exact prior material resource")
	rat.receive_impact(0, Vector3.RIGHT)
	PhysicsPush.apply(rat, Vector3.RIGHT * 0.1)
	check(rat._flash == 0 and rat._reaction_left == 0, "zero damage and extinguisher-style force never flash")
	rat._reaction_wait = 0
	rat._charge_wait = 0
	rat.receive_damage(22, null, player)
	await frames(5)
	check(rat._reaction_left > 0 and rat.velocity.length() < 0.1 and rat.state != KingRat.State.CHARGE, "local reaction suppresses approach even without directional recoil")
	await frames(20)
	check(rat._reaction_left == 0 and rat.state in [KingRat.State.REPOSITION, KingRat.State.TELEGRAPH], "reaction expiry immediately resumes combat decision")
	rat.current_health = 10000
	rat.provoke(player)
	rat._charge_wait = 0
	var active_ticks := 0
	for tick in range(240):
		if tick % 6 == 0: rat.receive_impact(48, Vector3.RIGHT * (1 if tick % 12 == 0 else -1), player)
		await frames(1)
		if rat.state in [KingRat.State.TELEGRAPH, KingRat.State.CHARGE, KingRat.State.REPOSITION, KingRat.State.PURSUIT] and rat._reaction_left == 0: active_ticks += 1
	check(active_ticks > 60, "repeated heavy hits do not lock active combat")
	check(rat._pose_left > 0 and rat.visual.rotation.x < 0, "rearm gate still allows every-hit visual reaction")
	check(not paused and Engine.time_scale == 1, "target feedback never freezes world")
	print("REACTION active_ticks=", active_ticks)
	quit(1 if failures else 0)
