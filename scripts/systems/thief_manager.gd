class_name ThiefManager
extends Node3D

@export var enable_thief_test_spawn: bool = true
@export var max_active_thieves: int = 2
@export var high_value_bias: float = 0.25
var thieves_caught: int = 0
var stolen_goods_value: float = 0
var last_recovered: GrabbableBody
var _label: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	canvas.add_child(_label)
	_label.position = Vector2(24, 172)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if enable_thief_test_spawn and event.is_action_pressed("debug_spawn_thief") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_thief()
		get_viewport().set_input_as_handled()

func stock_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shelf: StockShelf in get_parent().get_node("Shelves").get_children():
		for product in shelf.stocked_objects:
			if shelf.has_stock(product) and not product.get_meta("broken", false) and not product.scene_file_path.is_empty():
				result.append({"shelf": shelf, "product": product})
	return result

func spawn_thief() -> ThiefCustomer:
	var count := get_children().filter(func(n): return n is ThiefCustomer and not n.is_queued_for_deletion()).size()
	if count >= max_active_thieves: return null
	var customers: CustomerManager = get_parent().get_node("Customers")
	var at := customers.exit_position()
	var query := PhysicsShapeQueryParameters3D.new()
	var bounds := SphereShape3D.new()
	bounds.radius = 0.4
	query.shape = bounds
	query.transform.origin = at + Vector3.UP * 0.85
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return null
	var thief: ThiefCustomer = preload("res://scenes/interactables/thief_customer.tscn").instantiate()
	thief.manager = customers
	thief.theft_manager = self
	thief.position = at
	var candidates := stock_candidates()
	if not candidates.is_empty():
		var total := 0.0
		for entry in candidates: total += 1 + high_value_bias * log(1 + maxf(0, entry.product.price))
		var draw := randf() * total
		var chosen: Dictionary = candidates.back()
		for entry in candidates:
			draw -= 1 + high_value_bias * log(1 + maxf(0, entry.product.price))
			if draw <= 0:
				chosen = entry
				break
		thief.target_product = chosen.product
		thief.target_shelf = chosen.shelf
		var point: int = chosen.shelf.reserve_shopping_point(thief, chosen.product.global_position)
		if point >= 0:
			var destination: Vector3 = chosen.shelf.shopping_point(point)
			thief.waypoints = [Vector3(-7.65, 0, 9), Vector3(-7.65, 0, 3.1), Vector3(destination.x, 0, 3.1), destination]
	add_child(thief)
	if thief.waypoints.is_empty(): thief.leave_empty()
	return thief

func snapshot(product: GrabbableBody) -> Dictionary:
	if product.scene_file_path.is_empty(): return {}
	var settings := {}
	for property in product.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			settings[property.name] = product.get(property.name)
	for key in ["gravity_scale", "linear_damp", "angular_damp", "collision_layer", "collision_mask", "physics_material_override", "scale"]:
		settings[key] = product.get(key)
	return {"product_type": product.product_type, "price": product.price, "weight": product.weight, "source_id": product.get_instance_id(), "scene": product.scene_file_path, "settings": settings}

func recover(thief: ThiefCustomer, _player: PhysicsBody3D) -> bool:
	if not thief.capturable(): return false
	var loot := thief.stolen_item
	var product: GrabbableBody = load(loot.scene).instantiate()
	if loot.settings.has("definition"): product.definition = loot.settings.definition
	for key in loot.settings:
		if key != "definition": product.set(key, loot.settings[key])
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = product.carry_radius
	query.shape = shape
	query.exclude = [thief.get_rid()]
	var found := false
	var location := Vector3.ZERO
	for offset in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.ZERO]:
		location = thief.global_position + offset * (product.carry_radius + 0.6) + Vector3.UP * (product.carry_radius + 0.15)
		query.transform.origin = location
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			found = true
			break
	if not found:
		product.free()
		return false # Do not resolve an event without returning the real goods.
	get_parent().get_node("Products").add_child(product)
	product.global_position = location
	last_recovered = product
	thief.stolen_item.clear()
	thieves_caught += 1
	_update_label()
	return true

func finish_escape(thief: ThiefCustomer) -> void:
	if thief.resolved: return
	if thief.global_position.distance_to(escape_position()) > 0.5: return
	thief.resolved = true
	if not thief.stolen_item.is_empty():
		stolen_goods_value += thief.stolen_item.price
		thief.stolen_item.clear()
	_update_label()
	thief.queue_free()

func escape_position() -> Vector3:
	var entrance: Vector3 = get_parent().get_node("Entrance").global_position
	return Vector3(entrance.x, 0.01, entrance.z + 1.75)

func _update_label() -> void:
	_label.text = "[T] CAUGHT %d / STOLEN $%.0f" % [thieves_caught, stolen_goods_value]
