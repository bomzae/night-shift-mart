extends Node3D
## Opt-in debug spawn, separate from regular customers and any future director.
@export var enable_drunk_test_spawn: bool = true
@export var max_test_drunks: int = 2
var drunks_removed: int = 0
var broken_product_value: float = 0
var _label: Label

func _ready() -> void:
	var zone := Area3D.new()
	zone.name = "ExitRemovalZone"
	zone.position = get_parent().get_node("Entrance").position + Vector3(0, 0.25, 2.15)
	zone.collision_layer = 0
	zone.collision_mask = 1 | HumanSeparation.HUMAN_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 2)
	shape.shape = box
	zone.add_child(shape)
	add_child(zone)
	zone.body_entered.connect(_remove_drunk)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(24, 86)
	canvas.add_child(_label)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if enable_drunk_test_spawn and event.is_action_pressed("debug_spawn_drunk") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_drunk()
		get_viewport().set_input_as_handled()

func spawn_drunk() -> DrunkCustomer:
	var count := 0
	for child in get_children():
		if child is DrunkCustomer:
			count += 1
	if count >= max_test_drunks:
		return null
	var at := Vector3(-3, 0.8, get_parent().get_node("Entrance").position.z - 0.85)
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	query.shape = sphere
	query.transform.origin = at
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return null
	var drunk: DrunkCustomer = preload("res://scenes/interactables/drunk_customer.tscn").instantiate()
	add_child(drunk)
	drunk.global_position = at
	drunk.product_broken.connect(_record_breakage)
	return drunk

func _record_breakage(value: float) -> void:
	broken_product_value += value
	print("BROKEN PRODUCTS +$", value)
	_update_label()

func _remove_drunk(body: Node3D) -> void:
	if not body is DrunkCustomer or body.get_meta("removed", false):
		return
	body.set_meta("removed", true)
	if is_instance_valid(body.holder):
		body.holder.drop_held()
	drunks_removed += 1
	body.queue_free()
	print("DRUNKS REMOVED ", drunks_removed)
	_update_label()

func _update_label() -> void:
	_label.text = "[K] ~_~  | REMOVED %d | BROKEN $%.0f" % [drunks_removed, broken_product_value]
