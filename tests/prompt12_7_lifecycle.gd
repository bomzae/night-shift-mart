extends "res://tests/prompt12_smoke.gd"

func pairs() -> bool:
	return rat.get_collision_exceptions().has(weapon_body) and weapon_body.get_collision_exceptions().has(rat)

func lifecycle(data: WeaponDefinition) -> void:
	await weapon_setup(data)
	var mask := weapon_body.collision_mask
	check(pairs() and mask & 1 != 0, "grab ignores monster while retaining world mask " + data.weapon_id)
	var extra := CombatTarget.new()
	mart.add_child(extra)
	check(extra.get_collision_exceptions().has(weapon_body), "new monster immediately ignores already held weapon")
	extra.queue_free()
	await frames(2)
	check(weapon_body._held_monsters.size() == 1, "removed monster clears weak pair reference")
	await press("drop_item")
	check(not pairs() and weapon_body._held_monsters.is_empty() and weapon_body.collision_mask == mask, "drop restores monster pair without changing masks " + data.weapon_id)
	check(weapon_body.begin_carry(interaction,player), "regrab starts held policy")
	check(pairs(), "regrab immediately restores symmetric exception")
	weapon_body.launch(Vector3.FORWARD,12,20)
	check(not pairs() and weapon_body._held_monsters.is_empty(), "throw immediately restores monster collision " + data.weapon_id)
	# Place the released physical body on an unobstructed inbound trajectory.
	rat.position = Vector3(0,0.01,14)
	await place(weapon_body,Vector3(0,0.85,15.5))
	weapon_body.gravity_scale = 0
	weapon_body.launch(Vector3.FORWARD,12,20)
	for tick in range(30):
		await frames(1)
		if rat.hit_count > 0: break
	check(rat.hit_count > 0 and rat.current_health < 300, "released weapon physically hits monster " + data.weapon_id)

func run_checks() -> void:
	for data in WEAPONS: await lifecycle(data)
	await weapon_setup(WEAPONS[2])
	weapon_body.durability = 1
	weapon_body.spend_durability()
	await frames(2)
	check(not is_instance_valid(weapon_body), "break releases held weapon and deletes body")
	for body in rat.get_collision_exceptions():
		check(not body is WeaponBody, "break leaves no weapon exception on monster")
	await weapon_setup(WEAPONS[0])
	weapon_body.queue_free()
	await frames(2)
	for body in rat.get_collision_exceptions():
		check(not body is WeaponBody, "direct deletion leaves no weapon exception")
	print("P127 lifecycle complete failures=",failures)
	quit(1 if failures else 0)
