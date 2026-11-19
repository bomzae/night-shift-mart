extends Node3D

@export var start_in_prototype: bool = false
@export var starter_stock_enabled: bool = true

func _ready() -> void:
	var prototype := start_in_prototype or OS.get_cmdline_user_args().has("--prototype")
	var scene: PackedScene = load("res://scenes/test/prototype_test_room.tscn" if prototype else "res://scenes/mart/mart_graybox.tscn")
	var room := scene.instantiate()
	if not prototype: room.starter_stock_enabled = starter_stock_enabled
	add_child(room)
