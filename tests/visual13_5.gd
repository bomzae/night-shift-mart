extends SceneTree
## Render-only smoke; no OS mouse or focus success conditions.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var mart: Node3D = main.get_node("MartGraybox")
	var day: DayManager = mart.get_node("DayManager")
	while day.state != DayManager.State.ACTIVE: await process_frame
	day.timeline_enabled = false
	mart.get_node("Customers").spawning_enabled = false
	var player: CharacterBody3D = mart.get_node("Player")
	var interaction: Node = player.get_node("Interaction")
	player.set_physics_process(false)
	interaction.set_physics_process(false)
	interaction.set_process(false)
	var shelf: StockShelf = mart.get_node("Shelves/CanShelf")
	var body: GrabbableBody = load(ProductCatalog.find(&"instant_noodles").scene_path).instantiate()
	mart.get_node("Products").add_child(body)
	body.position = shelf.to_global(Vector3(0,0.11,-0.15))
	player.position = shelf.to_global(Vector3(0,0.01,1.45))
	player._set_stance(true)
	interaction.camera.look_at(body.global_position)
	interaction.context_prompt.text = "[LMB] GRAB"
	interaction.context_prompt.show()
	root.size = Vector2i(1280,720)
	for tick in range(30): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p135_crouch_visual.png")
	player._set_stance(false)
	shelf = mart.get_node("Shelves/InstantNoodlesShelf")
	player.position = shelf.to_global(Vector3(0,0.01,1.6))
	interaction.camera.look_at(shelf.to_global(Vector3(0,1.3,0.2)))
	interaction.context_prompt.text = "[LMB] PLACE"
	for tick in range(30): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/p135_shelf_visual.png")
	print("Visual 13.5 smoke completed: low view and shelf opening rendered")
	quit(0)
