extends "res://tests/prompt11_smoke.gd"
var weapon_body: WeaponBody
const WEAPONS = [preload("res://data/weapons/bat.tres"), preload("res://data/weapons/sledgehammer.tres"), preload("res://data/weapons/broom.tres")]

func equip(data: WeaponDefinition) -> void:
	weapon_body = WeaponBody.new()
	weapon_body.weapon = data
	mart.add_child(weapon_body)
	await place(weapon_body, interaction.camera.global_position + Vector3(0, 0, -1.5))
	await press("grab")
	check(interaction.held_object == weapon_body, "actual LMB grabs " + data.display_name)
	await frames(30)

func weapon_setup(data: WeaponDefinition) -> void:
	await boss_setup()
	rat.set_physics_process(false)
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	player.rotation = Vector3.ZERO
	interaction.camera.rotation = Vector3.ZERO
	await equip(data)
	rat.position = Vector3(0, 0.01, 18)
	await frames(2)

func run_checks() -> void:
	var recoil: Array[float] = []
	for data in WEAPONS:
		check(data.damage > 0 and data.range > 0 and data.durability_max > 0 and data.weight > 0, "definition " + data.display_name)
		await weapon_setup(data)
		await press("grab")
		check(weapon_body.swinging() and interaction.held_object == weapon_body, "held LMB swings instead of dropping")
		await press("throw")
		check(not interaction.is_charging and interaction.held_object == weapon_body, "swing blocks throw charge")
		await frames(40)
		check(rat.current_health == 300 - data.damage and rat.hit_count == 1, "exact once-per-swing damage " + data.display_name)
		check(weapon_body.durability == data.durability_max - 1, "successful hit durability")
		check(rat.is_aggro and rat.aggro_target == player and rat.last_recoil_speed > 0, "melee attribution and existing recoil")
		recoil.append(rat.last_recoil_speed)
		check(interaction.weapon_info.visible and interaction.weapon_info.text.contains(data.display_name), "held weapon UI")
		if data.damage >= rat.stagger_threshold: check(rat.state == KingRat.State.STAGGER, "hammer uses existing stagger")
		await frames(90)
		rat.position.x = 8
		await press("grab")
		await frames(40)
		check(weapon_body.durability == data.durability_max - 1, "miss preserves durability")
		await press("drop_item")
		check(interaction.held_object == null and weapon_body.holder == null and not weapon_body.freeze, "Q drops real body")
		check(not interaction.weapon_info.visible, "drop hides held UI")
	check(recoil[1] > recoil[0] and recoil[2] > recoil[0], "hammer and broom recoil exceed bat")
	await weapon_setup(WEAPONS[0])
	Graybox.box(mart, "MeleeWall", Vector3(3, 3, 0.2), Vector3(0, 1.5, 18.8), Color.GRAY)
	await frames(2)
	await press("grab")
	await frames(35)
	check(rat.current_health == 300 and weapon_body.durability == 14, "wall occludes swing without durability cost")
	await weapon_setup(WEAPONS[0])
	weapon_body.durability = 1
	await press("grab")
	await frames(35)
	check(not is_instance_valid(weapon_body) and interaction.held_object == null, "last hit breaks and releases weapon")
	check(rat.current_health == 278, "break still deals exactly one final hit")
	check(interaction.weapon_info.visible and interaction.weapon_info.text.contains("BROKEN"), "break displays short held-item feedback")
	await weapon_setup(WEAPONS[0])
	rat.position = Vector3(0, 0.01, 15)
	await press("throw")
	check(weapon_body.holder == null and weapon_body.linear_velocity.length() > 2, "weapon charged throw remains physical")
	await frames(70)
	check(rat.hit_count == 1 and rat.is_aggro, "thrown weapon damage and attribution")
	check(weapon_body.durability == 14, "prototype throw does not spend melee durability")
	await setup_thief()
	player.position = Vector3(8, 0.01, 10)
	var delivery = mart.get_node("Delivery/WeaponDelivery")
	mart.get_node("Cart").position = Vector3(-5, 0.1, 8)
	for data in WEAPONS:
		await press("debug_order_weapon")
		var crate: WeaponCrate
		for child in delivery.get_children():
			if child is WeaponCrate and not child.is_queued_for_deletion(): crate = child
		check(crate != null and crate.weapon == data, "N delivers cyclic weapon crate")
		if crate == null: continue
		player.global_position = crate.global_position + Vector3(0, -0.29, 2)
		interaction.camera.look_at(crate.global_position)
		await press("interact")
		await frames(10)
		check(not is_instance_valid(crate), "E opens physical crate once")
		var found := false
		for child in delivery.get_children():
			if child is WeaponBody and child.weapon == data:
				found = true
				child.position = Vector3(8, 1, 10)
		check(found, "crate creates actual weapon")
	quit(1 if failures else 0)
