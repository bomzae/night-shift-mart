extends "res://tests/prompt11_smoke.gd"

func run_checks() -> void:
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	rat._charge_wait = 0
	Graybox.box(mart, "CombatShelf", Vector3(4, 2, 1.2), Vector3(0, 1, 15), Color.GRAY)
	rat.provoke(player)
	var detour := false
	var attacked := false
	var reacquire_delay := 0.0
	var max_delay := 0.0
	for tick in range(600):
		await frames(1)
		detour = detour or absf(rat.position.x) > 2.8
		if rat._sees_player and rat._clear_attack_lane and rat.combat_distance() < 7 and rat._charge_wait <= 0:
			reacquire_delay += 1.0 / 60
			max_delay = maxf(max_delay, reacquire_delay)
		else: reacquire_delay = 0
		if rat.state == KingRat.State.TELEGRAPH:
			attacked = true
			break
	print("SHELF_COMBAT position=", rat.position, " range=", rat.combat_distance(), " reacquire_delay=", max_delay)
	check(detour and attacked, "blocked LOS uses aisle then attacks")
	check(max_delay < 0.25, "clear lane reacquire has no discovery wait")
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.02, 14))
	cart.freeze = true
	rat.provoke(player)
	rat._charge_wait = 0
	await frames(3)
	check(rat.state == KingRat.State.PURSUIT and not rat._clear_attack_lane, "visible player behind solid cart requires combat route")
	var moved_side := false
	attacked = false
	for tick in range(600):
		await frames(1)
		moved_side = moved_side or absf(rat.position.x) > 1.5
		if rat.state == KingRat.State.TELEGRAPH:
			attacked = true
			break
	check(moved_side and attacked, "cart obstruction routes to next attack")
	check(not rat.get_collision_exceptions().has(cart), "cart remains solid")
	await setup_thief()
	rat = mart.get_node("Bosses").spawn_boss()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 15)
	rat.receive_damage(1, null, player)
	await frames(2)
	check(rat.state == KingRat.State.TELEGRAPH, "fresh damage aggro starts decision without initial four-second wait")
	player.position = Vector3(35, 0.01, 35)
	await frames(800)
	check(not rat.is_aggro and rat.state in [KingRat.State.TRAVEL_ZONE, KingRat.State.MOVE_TO_FOOD, KingRat.State.SEEK_FOOD, KingRat.State.EAT], "active combat still expires into world behavior")
	quit(0 if failures == 0 else 1)
