extends "res://tests/prompt11_smoke.gd"

func cargo_trial(types: Array, assist: bool = true) -> Dictionary:
	await setup_thief()
	player.position = Vector3(10, 0.01, -3)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.02, 10))
	if "cargo_assist_enabled" in cart: cart.set("cargo_assist_enabled", assist)
	var items: Array[GrabbableBody] = []
	for i in range(types.size()):
		var d := ProductCatalog.find(types[i])
		var item := load(d.scene_path).instantiate() as GrabbableBody
		mart.add_child(item)
		# Compact layers; the mixed stack deliberately exercises overload too.
		var point := Vector3((i % 3 - 1) * 0.43, 0.45 + d.size.y / 2 + (i / 9) * 0.8, (i / 3 % 3 - 1) * 0.5)
		if types.size() <= 2: point = Vector3(0, 0.46 + d.size.y / 2 + i * 0.85, 0)
		item.position = cart.to_global(point)
		items.append(item)
	await frames(180)
	var sum_y := 0.0
	var peak_y := 0.0
	var count := 0
	for tick in range(180):
		await frames(1)
		for item in items:
			sum_y += absf(item.linear_velocity.y)
			peak_y = maxf(peak_y, absf(item.linear_velocity.y))
			count += 1
	cart.refresh_load()
	var result := {"mean_y": sum_y / max(1, count), "peak_y": peak_y, "resting": cart.cargo.size(), "count": items.size()}
	cart.holder = interaction
	cart.drive_velocity = Vector3(0, 0, 3)
	cart._control_forward = Vector3.BACK
	var drive_peak := 0.0
	for tick in range(180):
		cart._control_target = cart.position
		await frames(1)
		for item in items: drive_peak = maxf(drive_peak, absf(item.linear_velocity.y))
	result["drive_peak"] = drive_peak
	result["drive_cargo"] = cart.cargo.size()
	cart.drive_velocity = Vector3.RIGHT * 3
	cart._control_forward = Vector3.RIGHT
	for tick in range(90):
		cart._control_target = cart.position
		await frames(1)
	cart.drive_velocity = Vector3.ZERO
	for tick in range(90):
		cart._control_target = cart.position
		await frames(1)
	result["turn_brake_cargo"] = cart.cargo.size()
	print("CARGO PROBE assist=", assist, " types=", types, " result=", result)
	return result

func run_checks() -> void:
	for types in [[], [&"can", &"can", &"can", &"can", &"can", &"can", &"can", &"can", &"can"], [&"watermelon"], [&"microwave"], [&"tv"], [&"can", &"bread", &"chips", &"milk", &"instant_noodles", &"can", &"chips", &"bread", &"shampoo", &"microwave", &"tv"]]:
		await cargo_trial(types)
	await boss_setup()
	rat.position = Vector3(0, 0.01, 10)
	player.position = Vector3(0, 0.01, 20)
	rat._charge_wait = 1000
	var before := rat.position.distance_to(player.position)
	await frames(180)
	print("PURSUIT BASELINE distance_before=", before, " after=", rat.position.distance_to(player.position), " state=", rat.state)
	quit(0)
