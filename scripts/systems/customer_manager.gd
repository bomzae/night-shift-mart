class_name CustomerManager
extends Node3D

@export var spawn_interval_min: float = 6.0
@export var spawn_interval_max: float = 10.0
@export var max_active_customers: int = 6
@export var patience_time: float = 25.0
@export var queue_spacing: float = 1.25
@export_range(1, 3) var max_purchase_units: int = 3
@export var spawning_enabled: bool = true:
	set(value):
		spawning_enabled = value
		if is_instance_valid(_spawn_label): _update_spawn_label()
var sales: float = 0.0
var unpaid_loss: float = 0.0
var customers: Array[BasicCustomer] = []
var queue: Array[BasicCustomer] = []
var _claims: Dictionary = {}
var _timer: float
var _rng := RandomNumberGenerator.new()
var checkout: Node3D
var exited_count: int = 0
var transaction_count: int = 0
var _spawn_label: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_spawn_label = Label.new()
	canvas.add_child(_spawn_label)
	_spawn_label.position = Vector2(24, 145)
	_update_spawn_label()
	_rng.randomize()
	_reset_timer()
	checkout = preload("res://scenes/interactables/checkout.tscn").instantiate()
	checkout.manager = self
	checkout.position = Vector3(5, 0, 10)
	add_child(checkout)

func _reset_timer() -> void:
	_timer = _rng.randf_range(maxf(0.1, spawn_interval_min), maxf(maxf(0.1, spawn_interval_min), spawn_interval_max))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_customer_spawn") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawning_enabled = not spawning_enabled
		_update_spawn_label()
		print(_spawn_label.text)
		get_viewport().set_input_as_handled()

func _update_spawn_label() -> void:
	_spawn_label.text = "[U] CUSTOMER SPAWN: " + ("ON" if spawning_enabled else "OFF")

func _physics_process(delta: float) -> void:
	if not spawning_enabled:
		return
	_timer -= delta
	if _timer <= 0:
		spawn_customer()
		_reset_timer()

func exit_position() -> Vector3:
	var entrance: Vector3 = get_parent().get_node("Entrance").global_position
	return Vector3(entrance.x, 0.01, entrance.z - 1.05)

func product_color(type: StringName) -> Color:
	return {&"can": Color(0.2, 0.55, 0.95), &"watermelon": Color(0.25, 0.8, 0.35), &"appliance": Color(0.95, 0.6, 0.2)}.get(type, Color.WHITE)

func available_goods() -> Array[GrabbableBody]:
	var available: Array[GrabbableBody] = []
	for shelf in get_parent().get_node("Shelves").get_children():
		for body in shelf.stocked_objects:
			if shelf.has_stock(body) and not _claims.has(body.get_instance_id()):
				available.append(body)
	return available

func spawn_customer(requested: Array[StringName] = [], customer_scene: PackedScene = null) -> BasicCustomer:
	requested = requested.duplicate()
	if customers.size() >= max_active_customers:
		return null
	for other in customers:
		if other.global_position.distance_to(exit_position()) < 0.85:
			return null # Do not stack new capsules at the door.
	var scene := customer_scene if customer_scene != null else preload("res://scenes/interactables/basic_customer.tscn")
	var customer: BasicCustomer = scene.instantiate()
	customer.manager = self
	customer.patience_time = patience_time
	var available := available_goods()
	if requested.is_empty():
		if available.is_empty():
			requested.append([&"can", &"watermelon", &"appliance"][_rng.randi_range(0, 2)])
		else:
			var count := _rng.randi_range(1, mini(max_purchase_units, available.size()))
			for i in range(count):
				var index := _rng.randi_range(0, available.size() - 1)
				requested.append(available[index].product_type)
				available.remove_at(index)
	available = available_goods()
	customer.purchase_types = requested.duplicate()
	for type in requested:
		for body in available:
			if body.product_type == type:
				customer.goods.append(body)
				customer.purchase_total += body.price
				_claims[body.get_instance_id()] = customer
				available.erase(body)
				break
	customer.position = exit_position()
	# Reach the front aisle before visiting the actual reserved stock.
	customer.waypoints = [Vector3(-7.65, 0, 9), Vector3(-7.65, 0, 3.1)]
	for type in requested:
		if not customer.shopping_types.has(type):
			customer.shopping_types.append(type)
	add_child(customer)
	customers.append(customer)
	return customer

func valid_goods(customer: BasicCustomer) -> bool:
	if customer.goods.size() + customer.picked_items.size() != customer.purchase_types.size() or customer.purchase_types.is_empty():
		return false
	var remaining := customer.purchase_types.duplicate()
	for item in customer.picked_items:
		if not remaining.has(item.product_type):
			return false
		remaining.erase(item.product_type)
	for body in customer.goods:
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			return false
		if not remaining.has(body.product_type):
			return false
		remaining.erase(body.product_type)
		var found := false
		for shelf in get_parent().get_node("Shelves").get_children():
			if shelf.has_stock(body):
				found = true
				break
		if not found or _claims.get(body.get_instance_id()) != customer:
			return false
	return true

func pickup_from_shelf(customer: BasicCustomer, shelf: StockShelf, type: StringName) -> bool:
	# Validate every reserved unit before committing this shelf's pickup. No awaits.
	if customer.resolved or customer.state != BasicCustomer.State.SHOP or customer.shopping_shelf != shelf or customer.visited_types.has(type):
		return false
	for item in customer.picked_items:
		if item.product_type == type:
			return false
	if not valid_goods(customer):
		out_of_stock(customer)
		return false
	var selected: Array[GrabbableBody] = []
	for body in customer.goods:
		if body.product_type == type:
			if not shelf.has_stock(body):
				out_of_stock(customer)
				return false
			selected.append(body)
	if selected.is_empty() or selected.size() != customer.purchase_types.count(type):
		out_of_stock(customer)
		return false
	for body in selected:
		customer.picked_items.append({"product_type": body.product_type, "price": body.price, "source_id": body.get_instance_id()})
		_claims.erase(body.get_instance_id())
		customer.goods.erase(body)
		body.set_meta("sold", true) # Reuse shelf exclusion; payment has not happened yet.
		body.hide()
		body.queue_free()
	shelf.refresh_stock(0.0)
	customer.purchase_total = basket_total(customer)
	for body in customer.goods:
		customer.purchase_total += body.price
	customer.show_pickup(type)
	return true

func basket_total(customer: BasicCustomer) -> float:
	var total := 0.0
	for item in customer.picked_items:
		total += float(item.price)
	return total

func record_unpaid_basket(customer: BasicCustomer) -> void:
	var total := basket_total(customer)
	if not customer.picked_items.is_empty():
		customer.unpaid = true
		unpaid_loss += total
		print("UNPAID LOSS -$%.2f" % total)
	customer.picked_items.clear()

func join_queue(customer: BasicCustomer) -> void:
	if not valid_goods(customer):
		out_of_stock(customer)
		return
	if not queue.has(customer):
		queue.append(customer)
	customer.state = BasicCustomer.State.QUEUE

func queue_position(customer: BasicCustomer) -> Vector3:
	return global_position + Vector3(5 - maxi(0, queue.find(customer)) * queue_spacing, 0.01, 8.6)

func current_customer() -> BasicCustomer:
	if queue.is_empty() or queue[0].state != BasicCustomer.State.CHECKOUT:
		return null
	return queue[0]

func release_claims(customer: BasicCustomer) -> void:
	customer.release_shopping_points()
	for id in _claims.keys():
		if _claims[id] == customer:
			_claims.erase(id)
	queue.erase(customer)

func out_of_stock(customer: BasicCustomer) -> void:
	if customer.resolved:
		return
	customer.resolved = true
	# If a later shelf runs out, only already-picked units leave unpaid.
	record_unpaid_basket(customer)
	release_claims(customer)
	customer.disappoint()

func finish(customer: BasicCustomer, paid: bool) -> bool:
	if customer.resolved:
		return false
	if paid and (current_customer() != customer or customer.scanned != customer.purchase_types.size() or customer.scan_wait > 0):
		return false
	if not valid_goods(customer) or not customer.goods.is_empty():
		out_of_stock(customer)
		return false
	# Physical stock was consumed at SHOP; settle the price snapshot exactly once.
	var total := basket_total(customer)
	customer.purchase_total = total
	customer.resolved = true
	customer.unpaid = not paid
	release_claims(customer)
	transaction_count += 1
	if paid:
		sales += total
		customer.picked_items.clear()
		print("SALES +$%.2f" % total)
	else:
		record_unpaid_basket(customer)
	customer.start_exit()
	return true

func remove_customer(customer: BasicCustomer) -> void:
	release_claims(customer)
	customers.erase(customer)
	exited_count += 1
	customer.queue_free()
