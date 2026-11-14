extends "res://tests/prompt11_8_smoke.gd"

func close_setup(distance: float, cooldown: float = 0) -> void:
	await boss_setup()
	rat.set_physics_process(false)
	rat.position = Vector3(0,0.01,20)
	player.position = rat.position + Vector3(0,0,distance)
	player.health.max_health = 10000
	player.health.current_health = 10000
	rat.look_at(player.position)
	rat.provoke(player)
	rat._charge_wait = cooldown
	rat.state = KingRat.State.HOLD
	rat.set_physics_process(true)

func sample(distance: float, seconds: int = 10) -> Dictionary:
	await close_setup(distance)
	var result := {"distance":distance,"contact":0,"hold":0.0,"telegraph":0,"charge":0,"approach":0.0,"max_idle":0.0}
	var idle := 0.0
	var contacts := rat.contact_damage_count
	print("GAP INITIAL distance=",rat.combat_distance()," shell_gap=",rat.body_contact_sample(player.position).w," cooldown=",rat._charge_wait," lane=",rat.clear_combat_lane(player.position))
	for tick in range(seconds*60):
		await frames(1)
		if rat.state == KingRat.State.HOLD: result.hold += 1.0/60
		if rat.state in [KingRat.State.PURSUIT,KingRat.State.REPOSITION]: result.approach += 1.0/60
		if rat.state == KingRat.State.HOLD and rat._charge_wait <= 0 and rat._spacing_grace <= 0 and contacts == rat.contact_damage_count:
			idle += 1.0/60
		else: idle = 0
		contacts = rat.contact_damage_count
		result.max_idle = maxf(result.max_idle,idle)
	result.contact = rat.contact_damage_count
	result.telegraph = rat.telegraph_start_count
	result.charge = rat.charge_start_count
	print("SWEEP1210 ",JSON.stringify(result))
	check(result.contact > 0 or result.charge > 0,"close distance produces real combat event "+str(distance))
	check(result.max_idle < 2.1,"no cooldown-ready inactive HOLD "+str(distance))
	return result

func run_checks() -> void:
	for distance in [0.8,1.0,1.2,1.23,1.24,1.25,1.28,1.30,1.32,1.35,1.5,2.0,2.5,3.0]:
		await sample(distance)
	var exact := await sample(1.24347496,30)
	check(exact.telegraph >= 3 and exact.charge >= 3,"exact QA distance sustains attacks over thirty seconds")
	quit(1 if failures else 0)
