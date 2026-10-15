class_name StockShelf
extends Node3D

@export var accepted_type: StringName = &"can"
@export var max_stock: int = 8
@export var shelf_color: Color = Color.CORNFLOWER_BLUE
@export var settle_time: float = 0.4
@export var max_stock_speed: float = 0.35
@export var max_stock_spin: float = 1.0
var stock_count: int = 0
var stocked_objects: Array[GrabbableBody] = []
var _settled: Dictionary = {}
var zone: Area3D
var _label: Label3D
@export_range(2, 4) var shopping_point_count: int = 3
@export var shopping_front_distance: float = 1.35
@export var shopping_point_span: float = 0.95
var _shopping_users: Dictionary = {}

func shopping_point(index: int) -> Vector3:
	return to_global(Vector3(lerpf(-shopping_point_span, shopping_point_span, float(index) / (shopping_point_count - 1)), 0.01, shopping_front_distance))

func reserve_shopping_point(customer: Node3D, product_position: Vector3) -> int:
	var selected := -1
	var nearest := INF
	for i in range(shopping_point_count):
		if _shopping_users.has(i) and is_instance_valid(_shopping_users[i]):
			continue
		var distance := shopping_point(i).distance_squared_to(product_position)
		if distance < nearest:
			nearest = distance
			selected = i
	if selected >= 0:
		_shopping_users[selected] = customer
	return selected

func release_shopping_point(customer: Node) -> void:
	for i in _shopping_users.keys():
		if not is_instance_valid(_shopping_users[i]) or _shopping_users[i] == customer:
			_shopping_users.erase(i)

func _ready() -> void:
	Graybox.box(self, "Deck", Vector3(2.8, 0.14, 1.4), Vector3(0, 0.58, 0), shelf_color)
	Graybox.box(self, "Back", Vector3(2.8, 1.2, 0.12), Vector3(0, 0.65, -0.7), Color.DIM_GRAY)
	for x in [-1.25, 1.25]:
		Graybox.box(self, "Leg", Vector3(0.12, 0.55, 1.2), Vector3(x, 0.275, 0), Color.DIM_GRAY)
	zone = Area3D.new()
	zone.name = "StockZone"
	zone.position.y = 1.25
	zone.collision_layer = 0
	zone.collision_mask = 1
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.8, 1.2, 1.4)
	collision.shape = bounds
	zone.add_child(collision)
	add_child(zone)
	_label = Graybox.sign(self, "", Vector3(0, 2.1, 0), shelf_color)

func _physics_process(delta: float) -> void:
	refresh_stock(delta)

func refresh_stock(delta: float) -> void:
	var present: Dictionary = {}
	stocked_objects.clear()
	for candidate in zone.get_overlapping_bodies():
		if not candidate is GrabbableBody:
			continue
		var body := candidate as GrabbableBody
		if not stock_eligible(body):
			continue
		var id := body.get_instance_id()
		present[id] = float(_settled.get(id, 0.0)) + delta
		if present[id] >= settle_time and stocked_objects.size() < max_stock:
			stocked_objects.append(body)
	_settled = present
	stock_count = stocked_objects.size()
	_label.text = "%s\n%d / %d" % [String(accepted_type).to_upper(), stock_count, max_stock]

func stock_eligible(body: GrabbableBody) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_meta("sold", false):
		return false
	var local := to_local(body.global_position)
	return body.product_type == accepted_type and not is_instance_valid(body.holder) and absf(local.x) <= 1.4 and absf(local.z) <= 0.7 and local.y >= 0.65 and local.y <= 1.85 and body.linear_velocity.length() <= max_stock_speed and body.angular_velocity.length() <= max_stock_spin

func has_stock(body: GrabbableBody) -> bool:
	# Recheck live physics/ownership at pickup, not just last tick's cached count.
	return stock_eligible(body) and stocked_objects.has(body)
