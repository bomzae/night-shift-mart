class_name DeliveryManager
extends Node3D
## The pallet is a dispatch area, never an inventory. Unloaded bodies survive departure.
@export var first_delivery_delay: float = 5.0
@export var delivery_interval: float = 120.0
@export var truck_wait_time: float = 60.0
@export var max_active_products: int = 36
@export var product_scenes: Array[PackedScene] = [preload("res://scenes/interactables/products/can.tscn"), preload("res://scenes/interactables/products/watermelon.tscn"), preload("res://scenes/interactables/products/appliance.tscn")]
var truck_present: bool = false
var delivered: int = 0
var unloaded: int = 0
var left_behind: int = 0
var delivery_number: int = 0
var shipment: Array[GrabbableBody] = []
var last_result: Dictionary = {}
var _timer: float
var _truck: Node3D
var _status: Label3D
var _hud: Label
var products: Node3D

func _ready() -> void:
	products = get_parent().get_node("Products")
	_timer = first_delivery_delay
	Graybox.box(self, "Pallet", Vector3(3.4, 0.3, 2.4), Vector3.ZERO + Vector3(0, 0.15, 0), Color(0.48, 0.38, 0.26))
	_truck = Node3D.new()
	_truck.name = "Truck"
	add_child(_truck)
	Graybox.box(_truck, "Cargo", Vector3(2, 2.2, 4), Vector3(-3.1, 1.5, 0), Color.SLATE_GRAY)
	Graybox.box(_truck, "Cab", Vector3(2, 1.7, 1.5), Vector3(-3.1, 1.15, 2.6), Color.STEEL_BLUE)
	for x in [-4.05, -2.15]:
		for z in [-1.4, 2.5]:
			Graybox.box(_truck, "Wheel", Vector3(0.25, 0.6, 0.65), Vector3(x, 0.3, z), Color(0.08, 0.08, 0.1))
	_status = Graybox.sign(self, "", Vector3(0, 2.4, 0))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_hud = Label.new()
	_hud.position = Vector2(24, 24)
	_hud.add_theme_font_size_override("font_size", 22)
	canvas.add_child(_hud)
	_set_truck(false)

func _set_truck(present: bool) -> void:
	truck_present = present
	_truck.visible = present
	for child in _truck.get_children():
		for component in child.get_children():
			if component is CollisionShape3D:
				component.set_deferred("disabled", not present)
	_hud.visible = present

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		if truck_present:
			depart()
		else:
			arrive()
	if truck_present:
		unloaded = 0
		for body in shipment:
			if is_instance_valid(body) and not _on_pallet(body):
				unloaded += 1
		_status.modulate = Color.LIME_GREEN
		_status.text = "DELIVERY  %ds\n%d / %d" % [ceili(maxf(0, _timer)), unloaded, delivered]
		_hud.text = "↓ DELIVERY  %ds" % ceili(maxf(0, _timer))
	else:
		_status.modulate = Color.GRAY
		_status.text = "DELIVERY  --"

func _on_pallet(body: GrabbableBody) -> bool:
	if is_instance_valid(body.holder):
		return false # Never despawn something from a player's hands.
	var point := to_local(body.global_position)
	return absf(point.x) < 1.7 and absf(point.z) < 1.2 and point.y < 2.5

func arrive() -> void:
	if truck_present:
		return
	if products.get_child_count() >= max_active_products:
		_timer = delivery_interval
		print("DELIVERY deferred: active product limit")
		return
	shipment.clear()
	delivered = 0
	unloaded = 0
	left_behind = 0
	delivery_number += 1
	_set_truck(true)
	_timer = maxf(0.1, truck_wait_time)
	for row in range(2):
		for column in range(product_scenes.size()):
			if products.get_child_count() >= max_active_products:
				continue
			var point := to_global(Vector3((column - 1) * 1.05, 0.8, (row - 0.5) * 1.05))
			# Old physical goods may obstruct the pallet: skip instead of overlapping.
			var query := PhysicsShapeQueryParameters3D.new()
			var bounds := BoxShape3D.new()
			bounds.size = Vector3(0.75, 0.65, 0.75)
			query.shape = bounds
			query.transform.origin = point
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			var body := product_scenes[column].instantiate() as GrabbableBody
			products.add_child(body)
			body.global_position = point
			shipment.append(body)
			delivered += 1
	print("DELIVERY arrived #", delivery_number, " Delivered=", delivered)

func depart() -> void:
	if not truck_present:
		return
	unloaded = 0
	left_behind = 0
	for body in shipment:
		if is_instance_valid(body) and _on_pallet(body):
			left_behind += 1
			body.queue_free()
		else:
			unloaded += 1
	last_result = {"Delivered": delivered, "Unloaded": unloaded, "Left Behind": left_behind}
	print("DELIVERY departed ", last_result)
	shipment.clear()
	_set_truck(false)
	# Interval is arrival-to-arrival; never spawn a second truck over the first.
	_timer = maxf(0.1, delivery_interval - truck_wait_time)
