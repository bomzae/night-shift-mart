extends Node3D

@export var start_in_prototype: bool = false

func _ready() -> void:
	var prototype := start_in_prototype or OS.get_cmdline_user_args().has("--prototype")
	var scene: PackedScene = load("res://scenes/test/prototype_test_room.tscn" if prototype else "res://scenes/mart/mart_graybox.tscn")
	add_child(scene.instantiate())
