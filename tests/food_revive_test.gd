extends Node3D
## F6-only local teammate fixture. Never instantiated by Main.
func _ready() -> void:
	var main := preload("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	var mart := main.get_node("MartGraybox")
	mart.get_node("Customers").spawning_enabled = false
	mart.get_node("AutoStock").top_up()
	var dummy := CharacterBody3D.new()
	dummy.set_script(preload("res://tests/revive_dummy.gd"))
	dummy.position = Vector3(0, 0.01, 2)
	mart.add_child(dummy)
	mart.get_node("TeamLife").register_player(dummy.health)
	dummy.health.enter_downed()
	for i in range(3):
		var type: StringName = [&"bread", &"milk", &"watermelon"][i]
		var product := load(ProductCatalog.find(type).scene_path).instantiate() as GrabbableBody
		product.position = Vector3(-1.5 + i * 1.2, 0.5, 3.6)
		mart.add_child(product)
	Graybox.sign(mart, "TEST: GRAB FOOD → AIM TEAMMATE → G", Vector3(0, 2.6, 2), Color.PINK)
