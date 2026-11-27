extends "res://tests/prompt4_smoke.gd"

func starter_main() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await frames(3)
	main=load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	mart=main.get_node("MartGraybox")
	player=mart.get_node("Player")
	interaction=player.get_node("Interaction")
	manager=mart.get_node("Customers")
	var day: DayManager=mart.get_node("DayManager")
	while day.state!=DayManager.State.ACTIVE: await frames(1)
	day.timeline_enabled=false
	manager.spawning_enabled=false
	mart.get_node("Delivery").set_physics_process(false)
	player.position=Vector3(0,0,34)
	player.health.max_health=10000
	player.health.current_health=10000
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
