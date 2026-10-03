extends "res://tests/prompt7_1_smoke.gd"
var fire_manager: FireManager
var tool: FireExtinguisher

func check(condition: bool, label: String) -> void:
	if not condition and is_instance_valid(player):
		print("DIAGNOSTIC ", label, " mouse=", Input.mouse_mode, " player=", player.global_position)
	super.check(condition, label)

func fire_setup() -> void:
	Input.action_release("use_tool")
	await setup_mart()
	fire_manager = mart.get_node("Fires")
	player.global_position = Vector3(0, 0.01, 3)
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	interaction.camera.rotation = Vector3.ZERO

func make_product(at: Vector3, heavy: float = 1) -> GrabbableBody:
	var body: GrabbableBody = load("res://scenes/interactables/products/can.tscn").instantiate()
	body.weight = heavy
	mart.add_child(body)
	await place(body, at)
	return body

func grab_tool() -> void:
	tool = load("res://scenes/interactables/fire_extinguisher.tscn").instantiate()
	mart.add_child(tool)
	await place(tool, player.global_position + Vector3(0, 1.45, -1.4))
	interaction.camera.look_at(tool.global_position)
	await press("grab")
	check(interaction.held_object == tool, "extinguisher uses ordinary ray grab")
	await frames(40)

func push_trial(weight: float) -> float:
	await fire_setup()
	await grab_tool()
	var body := await make_product(Vector3(0, 0.18, -0.8), weight)
	await frames(30)
	interaction.camera.look_at(body.global_position)
	await frames(35)
	var start := body.global_position
	Input.action_press("use_tool")
	await frames(40)
	Input.action_release("use_tool")
	var distance := body.global_position.distance_to(start)
	print("SPRAY weight=", weight, " displacement=", distance)
	return distance

func run_checks() -> void:
	await fire_setup()
	check(InputMap.has_action("use_tool") and InputMap.has_action("debug_spawn_dangerous"), "F and P actions exist")
	await stock("can")
	player.global_position = Vector3(5, 0.01, 11.25) # Keep the shopper's main aisle clear.
	var dangerous := fire_manager.spawn_dangerous([&"can"])
	check(dangerous is BasicCustomer, "dangerous reuses Basic Customer")
	for tick in range(1400):
		await frames(1)
		if dangerous.accident_triggered: break
	check(dangerous.accident_triggered and fire_manager.fires_created == 1, "first shopping pickup creates one fire")
	check(dangerous.panic_left > 0 and dangerous._mood.text == ":O !", "brief panic feedback")
	check(dangerous.picked_items.size() == 1, "dangerous retains purchase basket")
	await wait_checkout(dangerous)
	check(fire_manager.fires_created == 1 and dangerous.panic_left == 0, "dangerous resumes checkout without repeated accident")
	player.global_position = Vector3(5, 0.01, 11.25)
	await aim_action("scan")
	await frames(32)
	await aim_action("pay")
	check(manager.sales == 5, "dangerous customer pays normally during fire")

	await fire_setup()
	await press("debug_spawn_dangerous")
	check(manager.customers.size() == 1 and manager.customers[0] is DangerousCustomer, "P spawns debug dangerous customer")
	manager.customers[0].global_position = Vector3(-7, 0, 9)
	var second := fire_manager.spawn_dangerous()
	check(second != null, "second dangerous allowed")
	check(fire_manager.spawn_dangerous() == null, "dangerous count bounded")

	await fire_setup()
	var fire := fire_manager.create_fire(Vector3(0, 0.01, -1))
	check(fire != null and fire is Area3D and fire.get_child_count() >= 4, "physical fire area and flame visual exist")
	var initial := fire.intensity
	var radius := fire.radius
	var scale_before := fire._flame.scale
	await frames(65)
	check(fire.intensity > initial and fire.radius > radius and fire._flame.scale.x > scale_before.x, "fire intensity radius and visual grow")
	check(fire_manager.create_fire(fire.global_position) == null, "minimum fire spacing prevents duplicates")
	fire_manager.max_active_fires = 1
	check(fire_manager.create_fire(Vector3(3, 0.01, -1)) == null, "active fire cap enforced")
	fire_manager.max_active_fires = 10
	fire.intensity = 1
	fire_manager.burn_exposure = 100
	fire_manager.spread_exposure = 0.5
	fire_manager.spread_interval = 0.5
	var fuel := await make_product(Vector3(2, 0.3, -1))
	await frames(90)
	check(fire_manager.fires_created == 2, "exposed flammable product creates adjacent fire")
	check(is_instance_valid(fuel), "spread does not immediately destroy fuel")
	for existing in fire_manager.fires: existing.suppress(2)
	await frames(2)
	check(fire_manager.fires.is_empty() and fire_manager.fires_extinguished == 2, "extinction removes both areas and counts once")
	await frames(60)
	check(fire_manager.fires_created == 2, "extinguished fire cannot continue spreading")

	await fire_setup()
	fire_manager.burn_exposure = 0.6
	var product := await make_product(Vector3(0, 0.3, -1))
	fire = fire_manager.create_fire(Vector3(0, 0.01, -1), [product.get_rid()])
	fire.intensity = 1
	await frames(100)
	check(not is_instance_valid(product) and fire_manager.fire_damage_value == 5, "heat destroys physical product and records price once")
	await frames(100)
	check(fire_manager.fire_damage_value == 5, "no duplicate loss after product deletion")
	var safe := await make_product(Vector3(0, 0.3, -1))
	safe.flammable = false
	await frames(100)
	check(is_instance_valid(safe), "nonflammable flag prevents product burning")
	safe.flammable = true
	fire.suppress(2)
	await frames(100)
	check(is_instance_valid(safe) and fire_manager.fire_damage_value == 5, "extinction stops heat accumulation")

	await fire_setup()
	await grab_tool()
	check(tool.product_type == &"" and not tool.flammable, "tool cannot be stocked sold or burned")
	player.rotate_y(PI)
	await frames(20)
	check(interaction.held_object == tool, "extinguisher retains rapid-turn hold")
	player.rotation = Vector3.ZERO
	fire = fire_manager.create_fire(Vector3(0, 0.01, -1))
	interaction.camera.look_at(fire.global_position + Vector3.UP * 0.4)
	await frames(45)
	var fuel_before := tool.capacity
	Input.action_press("use_tool")
	await frames(10)
	check(tool.spraying and tool._spray.visible and tool.capacity < fuel_before, "F hold produces visible spray and consumes capacity")
	check(fire.intensity < 0.3, "spray reduces fire intensity")
	await process_frame
	root.get_texture().get_image().save_png("res://.godot/p8_spray.png")
	await frames(150)
	check(not is_instance_valid(fire) and fire_manager.fires_extinguished == 1, "focused spray extinguishes and counts")
	tool.capacity = 0.2
	await frames(10)
	check(tool.capacity == 0 and not tool.spraying, "empty capacity stops spraying")
	Input.action_release("use_tool")
	await press("grab")
	check(tool.holder == null and interaction.held_object == null, "empty tool still drops physically")
	await place(tool, player.global_position + Vector3(0, 1.4, -1.4))
	interaction.camera.look_at(tool.global_position)
	await press("grab")
	await press("throw")
	check(tool.holder == null and tool.linear_velocity.length() > 2, "empty extinguisher still charge throws")

	var light_distance := await push_trial(1)
	var heavy_distance := await push_trial(8)
	check(light_distance > 0.15 and light_distance > heavy_distance + 0.08, "spray moves light product farther than heavy one")
	await fire_setup()
	await grab_tool()
	var drunk: DrunkCustomer = mart.get_node("Drunks").spawn_drunk()
	await place(drunk, Vector3(0, 0.85, -0.8))
	drunk.wander_speed = 0
	drunk.wander_acceleration = 0
	interaction.camera.look_at(drunk.global_position)
	await frames(35)
	var start := drunk.global_position
	Input.action_press("use_tool")
	await frames(30)
	Input.action_release("use_tool")
	print("NPC SPRAY displacement=", drunk.global_position.distance_to(start), " impulse_grace=", drunk.external_push_time, " velocity=", drunk.linear_velocity)
	check(drunk.global_position.distance_to(start) > 0.05, "spray pushes physical NPC without damage")
	check(drunk.knockdown.fall_count == 0, "spray does not directly trigger knockdown")

	await fire_setup()
	await grab_tool()
	var cart: ShoppingCart = mart.get_node("Cart")
	await place(cart, Vector3(0, 0.2, -0.8))
	interaction.camera.look_at(cart.global_position + Vector3.UP * 0.25)
	await frames(40)
	start = cart.global_position
	Input.action_press("use_tool")
	await frames(50)
	Input.action_release("use_tool")
	check(cart.global_position.distance_to(start) > 0.03, "ordinary spray impulse pushes free cart")

	await fire_setup()
	await grab_tool()
	fire = fire_manager.create_fire(Vector3(0, 0.01, -1))
	Graybox.box(mart, "SprayWall", Vector3(5, 3, 0.2), Vector3(0, 1.5, 0), Color.GRAY)
	interaction.camera.look_at(fire.global_position + Vector3.UP * 0.4)
	await frames(30)
	initial = fire.intensity
	Input.action_press("use_tool")
	await frames(50)
	Input.action_release("use_tool")
	check(fire.intensity >= initial, "spray cannot extinguish through wall")

	await fire_setup()
	await grab_tool()
	fire = fire_manager.create_fire(Vector3(0, 0.01, -1))
	var accidents: AccidentManager = mart.get_node("Accidents")
	var zone: SpillZone = accidents.create_spill(player.global_position, [player.get_rid()])
	player.set_physics_process(true)
	await frames(25)
	Input.action_press("use_tool")
	player.velocity = Vector3(0, 0, -3)
	await frames(3)
	check(player.knockdown.active() and tool.holder == null and not tool.spraying, "spill fall drops extinguisher and stops spray")
	check(is_instance_valid(fire), "fire continues during player knockdown")
	Input.action_release("use_tool")
	zone.clean(1)

	await fire_setup()
	fire_manager.minimum_fire_spacing = 0.2
	fire_manager.burn_exposure = 1.8
	product = await make_product(Vector3(0.2, 0.3, -1))
	var left := fire_manager.create_fire(Vector3(0, 0.01, -1), [product.get_rid()])
	var right := fire_manager.create_fire(Vector3(0.4, 0.01, -1), [product.get_rid()])
	left.intensity = 1
	right.intensity = 1
	await frames(70)
	check(is_instance_valid(product), "overlapping flames do not double product heat")
	await frames(70)
	check(not is_instance_valid(product) and fire_manager.fire_damage_value == 5, "overlapping flames record one loss")

	await fire_setup()
	product = await stock("can")
	var reserved := manager.spawn_customer([&"can"])
	reserved.set_physics_process(false)
	fire_manager.burn_exposure = 0.3
	fire = fire_manager.create_fire(product.global_position, [product.get_rid()])
	fire.intensity = 1
	await frames(65)
	check(not is_instance_valid(product) and mart.get_node("Shelves/CanShelf").stock_count == 0, "fire loss removes physical shelf stock")
	check(not manager.valid_goods(reserved), "burned reserved product fails existing live reservation validation")
	reserved.set_physics_process(true)
	await frames(2)
	check(reserved.state == BasicCustomer.State.DISAPPOINTED and manager.sales == 0, "fire loss follows ordinary out of stock flow")

	await fire_setup()
	var customer := manager.spawn_customer()
	customer.state = BasicCustomer.State.EVENT_WAIT
	customer.global_position = Vector3(0, 0.01, -1)
	fire = fire_manager.create_fire(customer.global_position, [customer.get_rid()])
	await frames(40)
	check(fire_manager._panic.has(customer.get_instance_id()) and customer.global_position.x > 0.01, "basic customer panics and moves away without health damage")
	var child: LostChild = mart.get_node("LostFamilies").spawn_pair()
	var parent: LostParent = child.parent_npc
	parent.global_position = Vector3(0.5, 0.01, -1)
	await place(child, Vector3(-0.4, 0.6, -1))
	await frames(40)
	check(fire_manager._panic.has(parent.get_instance_id()) and fire_manager._panic.has(child.get_instance_id()), "lost parent and child share bounded fire reaction")
	check(not child.reunited and mart.get_node("LostFamilies").lost_children_found == 0, "fire does not fail or resolve lost child event")

	await fire_setup()
	await grab_tool()
	Input.action_press("use_tool")
	await frames(4)
	var charge := InputEventAction.new()
	charge.action = "throw"
	charge.pressed = true
	Input.parse_input_event(charge)
	await frames(3)
	fuel_before = tool.capacity
	await frames(10)
	check(interaction.is_charging and not tool.spraying and tool.capacity == fuel_before, "throw charge and tool use do not conflict")
	Input.action_release("use_tool")
	interaction.drop_held()
	charge.pressed = false
	Input.parse_input_event(charge)
	print("Prompt 8 smoke checks completed; failures: ", failures)
	quit(0 if failures == 0 else 1)
