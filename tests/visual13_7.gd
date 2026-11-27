extends "res://tests/fixture13_7.gd"

func pose(depth: float, product: GrabbableBody, shelf: StockShelf) -> void:
	interaction.camera.look_at(shelf.to_global(Vector3(-0.9375,1.425,depth)))
	for tick in range(240):
		interaction._update_hold_target()
		await frames(1)
	interaction.context_prompt.text=InteractionContext.prompt(InteractionContext.resolve(interaction))
	interaction.context_prompt.show()
	print("VISUAL137 depth=",depth," body=",shelf.to_local(product.global_position)," prompt=",interaction.context_prompt.text)

func run_checks() -> void:
	await starter_main()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE # Rendering only: OS focus is not a test condition.
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	interaction.set_physics_process(false)
	interaction.set_process_unhandled_input(false)
	var shelf: StockShelf=mart.get_node("Shelves/ZoneSection0_3_cereal")
	var product: GrabbableBody=shelf.stocked_objects[0]
	player.position=shelf.to_global(Vector3(-0.9375,0.01,1.7))
	product.begin_carry(interaction,player)
	interaction.held_object=product
	interaction.camera.look_at(shelf.to_global(Vector3(-0.9375,1.65,4)))
	for tick in range(100):
		interaction._update_hold_target()
		await frames(1)
	await pose(-0.4,product,shelf)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p137_visual_rear.png")
	await pose(0.06,product,shelf)
	var thief: ThiefCustomer=mart.get_node("Thieves").spawn_thief()
	thief.approach_target() # Render notification from a real successful pickup.
	thief.position=thief.waypoints.back()
	thief.waypoints.clear()
	await frames(45)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p137_visual_theft.png")
	var banner: EventBanner=mart.get_node("DayManager").event_banner
	check(banner.current==&"thief" and not banner.panel.get_global_rect().intersects(interaction.context_prompt.get_global_rect()),"rendered theft banner and stocking prompt have separate rectangles")
	interaction.drop_held()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	quit(1 if failures else 0)
