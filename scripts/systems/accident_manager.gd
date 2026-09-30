class_name AccidentManager
extends Node3D
## Debug events only. Normal reservations, purchases and exits stay in Customers.
@export var enable_accident_test_spawn: bool = true
@export_range(1, 2) var max_accident_customers: int = 2
@export var spill_radius: float = 1.5
var spills_created: int = 0
var spills_cleaned: int = 0
var _label: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	canvas.add_child(_label)
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -380
	_label.offset_right = -24
	_label.offset_top = 24
	_label.offset_bottom = 48
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if enable_accident_test_spawn and event.is_action_pressed("debug_spawn_accident") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_accident()
		get_viewport().set_input_as_handled()

func spawn_accident(requested: Array[StringName] = []) -> AccidentCustomer:
	var customers: CustomerManager = get_parent().get_node("Customers")
	var count := 0
	for customer in customers.customers:
		if customer is AccidentCustomer:
			count += 1
	if count >= max_accident_customers:
		return null
	var customer := customers.spawn_customer(requested, preload("res://scenes/interactables/accident_customer.tscn")) as AccidentCustomer
	if customer != null:
		customer.accident_manager = self
	return customer

func create_spill(at: Vector3, excluded: Array[RID] = []) -> SpillZone:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at - Vector3.UP * 1.5, 1, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.dot(Vector3.UP) < 0.9:
		return null
	var spill: SpillZone = preload("res://scenes/interactables/spill_zone.tscn").instantiate()
	spill.radius = spill_radius
	add_child(spill)
	spill.global_position = hit.position
	spill.cleaned.connect(_on_cleaned)
	spills_created += 1
	_update_label()
	return spill

func _on_cleaned() -> void:
	spills_cleaned += 1
	_update_label()

func _update_label() -> void:
	_label.text = "[O] :O  | SPILLS %d / CLEANED %d" % [spills_created, spills_cleaned]
