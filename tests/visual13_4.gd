extends SceneTree
## One final rendered smoke; no keyboard, OS mouse or focus assertions.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	var mart: Node3D=main.get_node("MartGraybox")
	var day: DayManager=mart.get_node("DayManager")
	while day.state!=DayManager.State.ACTIVE: await process_frame
	day.timeline_enabled=false
	mart.get_node("Customers").spawning_enabled=false
	var player: CharacterBody3D=mart.get_node("Player")
	player.set_physics_process(false)
	var interaction: Node=player.get_node("Interaction")
	interaction.set_process(false)
	interaction.set_physics_process(false)
	var food: GrabbableBody=load(ProductCatalog.find(&"bread").scene_path).instantiate()
	mart.add_child(food)
	food.position=player.position+Vector3.UP
	food.begin_carry(interaction,player)
	interaction.held_object=food
	interaction.context_prompt.text=InteractionContext.prompt(InteractionContext.resolve(interaction))
	interaction.context_prompt.show()
	mart.get_node("Drunks").spawn_drunk()
	day.event_banner.set_process(false)
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/p134_visual_%d.png" % size.x)
		print("VISUAL134 ",size," ",day.event_banner.description.text," / ",interaction.context_prompt.text)
	for tick in range(600):
		await physics_frame
		await process_frame
	print("Visual smoke completed")
	quit(0)
