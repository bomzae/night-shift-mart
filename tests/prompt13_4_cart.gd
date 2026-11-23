extends "res://tests/prompt11_smoke.gd"

func run_checks() -> void:
	await boss_setup()
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0,0.02,20))
	rat.position = Vector3(0,0.01,14)
	player.position = Vector3(0,0.5,20)
	player.health.max_health = 10000
	player.health.current_health = 10000
	player.set_physics_process(true)
	rat._charge_wait = 0
	rat.provoke(player)
	var origin := cart.position
	var gap := 0.0
	var longest := 0.0
	var last_count := 0
	var transitions := {}
	var previous := -1
	var prior_position := rat.position
	var largest_step := 0.0
	var damage_on_cart := false
	var last_hp: float = player.health.current_health
	for tick in range(5400):
		await frames(1)
		largest_step = maxf(largest_step,rat.position.distance_to(prior_position))
		prior_position = rat.position
		if player.health.current_health < last_hp:
			damage_on_cart = damage_on_cart or rat.cart_supports(cart,player)
		last_hp = player.health.current_health
		var count := rat.telegraph_start_count + rat.charge_count + rat.contact_damage_count
		gap = gap + 1.0/60 if count == last_count else 0
		longest = maxf(longest,gap)
		last_count = count
		if rat.state != previous:
			var key: String = KingRat.State.keys()[rat.state]
			transitions[key] = transitions.get(key,0)+1
		previous = rat.state
		if tick % 1800 == 1799:
			print("CART134 t=",(tick+1)/60," rat=",rat.position," player=",player.position," distance=",rat.combat_distance()," lane=",rat.clear_combat_lane(player.position)," telegraph=",rat.telegraph_start_count," charge=",rat.charge_count," damage=",10000-player.health.current_health," longest_no_threat=",longest," reeval=",rat.combat_inactivity_recovery_count," cart_move=",cart.position.distance_to(origin)," states=",transitions)
	check(rat.aggro_target == player,"cart player remains target")
	check(rat.telegraph_start_count > 0 and rat.charge_count > 0,"cart player receives attack attempts")
	check(player.health.current_health < 10000,"stationary cart player takes physical attack damage")
	check(longest < 15,"no long pursuit-only threat failure")
	check(largest_step < 0.3,"rat moves continuously without teleport")
	check(damage_on_cart,"damage occurs while physically supported by cart")
	check(cart.position.distance_to(origin) > 0.1,"existing charge impulses physically move cart")
	check(not rat.get_collision_exceptions().has(cart),"cart remains solid")
	quit(1 if failures else 0)