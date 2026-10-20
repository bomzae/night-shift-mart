extends "res://tests/prompt10_2_smoke.gd"

func held_food(type: StringName) -> GrabbableBody:
	var food := load(ProductCatalog.find(type).scene_path).instantiate() as GrabbableBody
	mart.add_child(food)
	food.global_position = player.global_position + Vector3.UP
	food.begin_carry(interaction, player)
	interaction.held_object = food
	return food

func dummy_at(at: Vector3) -> CharacterBody3D:
	var dummy := CharacterBody3D.new()
	dummy.set_script(preload("res://tests/revive_dummy.gd"))
	dummy.position = at
	mart.add_child(dummy)
	mart.get_node("TeamLife").register_player(dummy.health)
	return dummy

func cart_crossing(steering: bool, narrow: bool) -> Dictionary:
	await setup_thief()
	player.position = Vector3(5, 0.01, 11)
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 1.8))
	cart.freeze = true
	var npc := walker(Vector3(0, 0.01, -0.2))
	if narrow:
		for x in [-1.15, 1.15]: Graybox.box(mart, "Corridor", Vector3(0.2, 2, 7), Vector3(x, 1, 1.8), Color.GRAY)
	var maximum_side := 0.0
	var saw_exception := false
	for tick in range(600):
		var desired := Vector3(0, 0, 2.2)
		if steering: desired = npc.cart_recovery.steer(desired, 1.0 / 60)
		npc.velocity = desired + Vector3.DOWN * 0.2
		npc.move_and_slide()
		maximum_side = maxf(maximum_side, absf(npc.position.x))
		saw_exception = saw_exception or npc.cart_recovery.passing
		await frames(1)
		if npc.position.z > 4.5: break
	print("CART RECOVERY steering=", steering, " narrow=", narrow, " position=", npc.position, " passing=", saw_exception)
	return {"z": npc.position.z, "side": maximum_side, "passed": saw_exception, "restored": not npc.get_collision_exceptions().has(cart) and not cart.get_collision_exceptions().has(npc), "mask": npc.collision_mask}

func run_checks() -> void:
	var baseline := await cart_crossing(false, true)
	check(baseline.z < 2.5, "baseline reproduces cart obstruction with original direct motor")
	var open := await cart_crossing(true, false)
	check(open.z > 4.5 and open.side > 0.4, "open aisle side-step progresses around real cart")
	var narrow := await cart_crossing(true, true)
	check(narrow.z > 4.5 and narrow.passed, "narrow cart blockage recovers with pair exception")
	check(narrow.restored and narrow.mask == 129, "pair collision restored and world player monster masks unchanged")
	await setup_thief()
	var cart_pair: Array[ShoppingCart] = [mart.get_node("Cart"), preload("res://scenes/interactables/shopping_cart.tscn").instantiate()]
	mart.add_child(cart_pair[1])
	for i in range(2):
		await place(cart_pair[i], Vector3(10.5, 0.05, 2.2 + i * 1.3))
		cart_pair[i].freeze = true
	for x in [9.35, 11.65]: Graybox.box(mart, "DoubleCorridor", Vector3(0.2, 2, 8), Vector3(x, 1, 4), Color.GRAY)
	var crossing := walker(Vector3(10.5, 0.01, 0.2))
	for tick in range(1000):
		crossing.velocity = crossing.cart_recovery.steer(Vector3.BACK * 2.2, 1.0 / 60) + Vector3.DOWN * 0.2
		crossing.move_and_slide()
		await frames(1)
		if crossing.position.z > 6.5: break
	check(crossing.position.z > 6.5 and crossing.cart_recovery.recoveries >= 2, "two adjacent carts cannot trap recovering human")
	check(crossing.get_collision_exceptions().is_empty() and not crossing.cart_recovery.passing, "every temporary cart pair restores independently")
	await setup_thief()
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.05, 1.8))
	cart.freeze = true
	var walking_customer := walker(Vector3(0, 0.01, -0.2))
	walking_customer.state = BasicCustomer.State.EXIT
	walking_customer.waypoints = [Vector3(0, 0, 4.7)]
	walking_customer.set_physics_process(true)
	var motor_progress := false
	for tick in range(600):
		await frames(1)
		if not is_instance_valid(walking_customer) or walking_customer.position.z > 4.4:
			motor_progress = true
			break
	check(motor_progress, "actual customer state motor progresses around cart")
	await setup_thief()
	var health: PlayerHealth = player.health
	var team: TeamLifeManager = mart.get_node("TeamLife")
	check(health.max_health == 100 and health.current_health == 100 and team.players.has(health), "full HP and team registration")
	health.receive_damage(30)
	check(health.current_health == 70, "damage 30 leaves 70")
	health.heal(200)
	check(health.current_health == 100, "heal clamps max")
	var food := held_food(&"bread")
	check(not health.use_food(food) and not food.is_queued_for_deletion(), "full HP prevents food waste")
	interaction.drop_held()
	food.queue_free()
	for type in [&"bread", &"milk", &"watermelon"]:
		health.current_health = 10
		food = held_food(type)
		var before := team.consumed_product_value
		var value := food.price
		check(health.use_food(food), "consume real food: " + String(type))
		check(health.current_health == 10 + ProductCatalog.find(type).heal_value and food.is_queued_for_deletion(), "catalog heal and actual deletion: " + String(type))
		check(team.consumed_product_value == before + value and not health.use_food(food), "consumed cost exactly once: " + String(type))
		await frames(2)
	for type in [&"tv", &"microwave", &"detergent"]:
		food = held_food(type)
		check(not health.use_food(food) and not food.is_queued_for_deletion(), "nonfood rejected: " + String(type))
		interaction.drop_held()
		food.queue_free()
	food = held_food(&"bread")
	health.current_health = 50
	await press("consume_item")
	check(health.current_health == 65 and interaction.held_object == null, "G consumes held food for self heal")
	# Checkout counter is a real LOS blocker. Use the unobstructed rear aisle.
	player.global_position = Vector3(0, 0.01, 3)
	var dummy := dummy_at(player.global_position + Vector3(0, 0, -1.5))
	dummy.health.enter_downed()
	food = held_food(&"tv")
	check(not health.use_food(food, dummy.health) and dummy.health.is_downed, "nonfood cannot revive teammate")
	interaction.drop_held()
	food.queue_free()
	food = held_food(&"bread")
	dummy.position.z -= 5
	check(not health.use_food(food, dummy.health), "distant teammate cannot be fed")
	dummy.position.z += 5
	var barrier := Graybox.box(mart, "FeedBarrier", Vector3(2, 2, 0.15), Vector3(0, 1, 2.25), Color.GRAY)
	await frames(2)
	check(not health.use_food(food, dummy.health), "wall blocks feed API")
	barrier.queue_free()
	interaction.drop_held()
	food.queue_free()
	await frames(2)
	for type in [&"bread", &"milk", &"watermelon"]:
		dummy.health.enter_downed()
		await frames(90)
		check(dummy.health.is_downed and dummy.knockdown.phase == KnockdownState.Phase.DOWN and not team.day_failed_active, "downed persists while teammate alive")
		food = held_food(type)
		interaction.camera.look_at(dummy.global_position + Vector3.UP * 0.7)
		await press("consume_item")
		check(not dummy.health.is_downed, "G ray-target teammate feed succeeds: " + String(type))
		check(dummy.health.current_health == ProductCatalog.find(type).heal_value * 2 and not dummy.health.is_downed, "revive multiplier: " + String(type))
		await frames(35)
		check(not dummy.knockdown.active(), "revive stands up")
	# Player downed keeps view low, releases goods, and cannot self feed.
	food = held_food(&"watermelon")
	interaction.is_charging = true
	player.set_physics_process(true)
	health.receive_damage(200)
	await frames(110)
	check(health.is_downed and health.current_health == 0 and not team.day_failed_active, "one living teammate prevents day failure")
	check(interaction.held_object == null and not interaction.is_charging and not is_instance_valid(food.holder), "downed drops held product and cancels charge")
	check(player.knockdown.phase == KnockdownState.Phase.DOWN and player.head.position.y < 1, "downed camera stays low without auto stand")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p111_downed.png")
	check(not health.use_food(food) and not health.heal(30), "downed cannot self heal or self revive")
	var position_before := player.position
	Input.action_press("move_forward")
	Input.action_press("jump")
	await frames(30)
	Input.action_release("move_forward")
	Input.action_release("jump")
	check(player.position.distance_to(position_before) < 0.1, "downed movement jump blocked")
	var failures_seen := [0]
	team.day_failed.connect(func(): failures_seen[0] += 1)
	dummy.health.receive_damage(200)
	check(team.day_failed_active and team.all_players_downed(), "last teammate down ends day immediately")
	check(not health.revive(60), "revive window closes on all downed")
	team.check_failure()
	check(failures_seen[0] == 1, "day failed signal exactly once")
	await frames(150)
	check(team.current_day == 2 and health.current_health == 100 and dummy.health.current_health == 100, "next day restores all registered players")
	check(not health.is_downed and not player.knockdown.active() and player.head.position.y > 1.5, "next day restores pose controls")
	check(player.position.distance_to(health.spawn_transform.origin) < 0.2, "next day returns player to spawn")
	# HP-zero releases both carry kinds through the same started callback.
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	child.begin_carry(interaction, player)
	interaction.held_object = child
	health.enter_downed()
	check(interaction.held_object == null and child.holder == null, "HP zero drops carried character")
	health.revive(30)
	await frames(35)
	cart = mart.get_node("Cart")
	player.global_position = Vector3(0, 0.01, 3)
	await place(cart, Vector3(0, 0.05, 1))
	check(cart.begin_carry(interaction, player), "prepare actual cart hold")
	interaction.held_object = cart
	health.enter_downed()
	check(interaction.held_object == null and cart.holder == null, "HP zero releases cart")
	await setup_thief()
	health = player.health
	team = mart.get_node("TeamLife")
	var boss: KingRat = mart.get_node("Bosses").spawn_boss()
	boss._charge_hit(player)
	check(health.current_health == 70 and player.knockdown.active(), "King Rat charge damages and knocks down")
	boss._charge_hit(player)
	check(health.current_health == 70, "same charge cannot damage twice")
	health.receive_damage(200)
	check(team.day_failed_active, "single player down ends day")
	await frames(150)
	check(not is_instance_valid(boss) and health.current_health == 100 and team.current_day == 2, "prototype reset clears boss and restores solo player")
	print("Prompt 11.1 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
