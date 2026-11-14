extends "res://tests/prompt12_10_gap.gd"

func run_checks() -> void:
	for count in range(3):
		await close_setup(1.24347496,1000)
		var cart: ShoppingCart = mart.get_node("Cart")
		await place(cart,Vector3(2,0.01,21.25) if count else Vector3(30,0.01,30))
		if count == 2:
			var extra: ShoppingCart = load("res://scenes/interactables/shopping_cart.tscn").instantiate()
			mart.add_child(extra)
			extra.position = Vector3(-2,0.01,21.25)
		await frames(10)
		rat._charge_wait = 0
		await frames(600)
		print("CART1210 count=",count," telegraph=",rat.telegraph_start_count," charge=",rat.charge_start_count," distance=",rat.combat_distance()," recovery=",rat.combat_recovery_count," inactivity=",rat.combat_inactivity_recovery_count)
		check(rat.telegraph_start_count > 0 and rat.charge_start_count > 0,"close attack with nearby carts "+str(count))
		check(not rat.get_collision_exceptions().has(cart),"cart remains solid "+str(count))
		check(rat.aggro_target == player,"cart comparison retains target "+str(count))
	quit(1 if failures else 0)
