extends Node3D
## Debug event pairs, independent of sales and any future round director.
@export var enable_lost_child_test_spawn: bool = true
@export_range(1, 2) var max_events: int = 2
@export var handoff_distance: float = 1.8
@export var reunion_time: float = 0.8
var lost_children_found: int = 0
var pairs: Array[Dictionary] = []
var _next_id: int = 1
var _label: Label
var _npc_exceptions: Array[Array] = []

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(24, 42)
	canvas.add_child(_label)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if enable_lost_child_test_spawn and event.is_action_pressed("debug_spawn_lost_child") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_pair()
		get_viewport().set_input_as_handled()

func spawn_pair() -> LostChild:
	if pairs.size() >= max_events:
		return null
	var slot := 0
	for pair in pairs:
		if pair.slot == 0:
			slot = 1
	var child_at := Vector3(-6 if slot == 0 else 4, 0.55, 2)
	var parent_at := Vector3(6 if slot == 0 else -6, 0.01, 8.0 if slot == 0 else 8.3)
	for at in [child_at, parent_at + Vector3.UP * 0.85]:
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.5
		query.shape = shape
		query.transform.origin = at
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return null
	var child: LostChild = preload("res://scenes/interactables/lost_child.tscn").instantiate()
	var parent: LostParent = preload("res://scenes/interactables/lost_parent.tscn").instantiate()
	child.family_id = _next_id
	parent.family_id = _next_id
	_next_id += 1
	child.family_manager = self
	child.parent_npc = parent
	parent.manager = get_parent().get_node("Customers")
	child.position = child_at
	parent.position = parent_at
	add_child(child)
	add_child(parent)
	var symbol := "●" if slot == 0 else "◆"
	var color := Color.GOLD if slot == 0 else Color.CYAN
	child.family_symbol = Graybox.sign(child, symbol, Vector3(0, 0.73, 0), color)
	parent.family_symbol = Graybox.sign(parent, symbol, Vector3(0, 1.98, 0), color)
	pairs.append({"slot": slot, "child": child, "parent": parent, "reunion_left": -1.0})
	return child

func can_reunite(child: LostChild, parent: LostParent) -> bool:
	if child.reunited or child.family_id != parent.family_id or child.parent_npc != parent:
		return false
	if child.global_position.distance_to(parent.global_position + Vector3.UP * 0.7) > handoff_distance:
		return false
	# No matching through shelves or walls.
	var ray := PhysicsRayQueryParameters3D.create(parent.global_position + Vector3.UP * 1.1, child.global_position)
	var excluded: Array[RID] = [parent.get_rid(), child.get_rid()]
	if is_instance_valid(child._carrier):
		excluded.append(child._carrier.get_rid())
	ray.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func try_reunion(child: LostChild) -> bool:
	if is_instance_valid(child.holder):
		return false
	for pair in pairs:
		if pair.child != child or not can_reunite(child, pair.parent):
			continue
		child.reunited = true
		child.can_sleep = false
		child.sleeping = false
		pair.parent.reunited = true
		_refresh_departing_exceptions()
		pair.reunion_left = reunion_time
		lost_children_found += 1
		print("LOST CHILDREN FOUND ", lost_children_found)
		_update_label()
		return true
	return false

func _physics_process(delta: float) -> void:
	for pair in pairs.duplicate():
		var child: LostChild = pair.child
		var parent: LostParent = pair.parent
		if not is_instance_valid(child) or not is_instance_valid(parent):
			_release_exceptions(child, parent)
			if is_instance_valid(child): child.queue_free()
			if is_instance_valid(parent): parent.queue_free()
			pairs.erase(pair)
			continue
		parent.handoff_ready = is_instance_valid(child.holder) and can_reunite(child, parent)
		if pair.reunion_left >= 0:
			pair.reunion_left -= delta
			if pair.reunion_left < 0:
				parent.start_exit()
		if parent.exit_arrived:
			_release_exceptions(child, parent)
			child.queue_free()
			parent.queue_free()
			pairs.erase(pair)

func _update_label() -> void:
	_label.text = "[L] ?  | FOUND %d" % lost_children_found

func _ignore_pair(a: PhysicsBody3D, b: PhysicsBody3D) -> void:
	if a == b or not is_instance_valid(a) or not is_instance_valid(b):
		return
	for direction in [[a, b], [b, a]]:
		if not direction[0].get_collision_exceptions().has(direction[1]):
			direction[0].add_collision_exception_with(direction[1])
			_npc_exceptions.append([weakref(direction[0]), weakref(direction[1])])

func _refresh_departing_exceptions() -> void:
	var departing: Array[PhysicsBody3D] = []
	for pair in pairs:
		if is_instance_valid(pair.child) and is_instance_valid(pair.parent) and pair.child.reunited:
			departing.append(pair.child)
			departing.append(pair.parent)
	for body in departing:
		for other in departing:
			_ignore_pair(body, other)
		for customer in get_tree().get_nodes_in_group("basic_customers"):
			# Unresolved parents stay physical; reunited families are handled above.
			if not customer is LostParent:
				_ignore_pair(body, customer)

func _on_node_added(node: Node) -> void:
	# Covers customers spawned after reunion, before their first movement tick.
	if node is BasicCustomer and not node is LostParent:
		for pair in pairs:
			if is_instance_valid(pair.child) and is_instance_valid(pair.parent) and pair.child.reunited:
				_ignore_pair(pair.child, node)
				_ignore_pair(pair.parent, node)

func _release_exceptions(child: LostChild, parent: LostParent, all_pairs: bool = false) -> void:
	for record in _npc_exceptions.duplicate():
		var a: PhysicsBody3D = record[0].get_ref()
		var b: PhysicsBody3D = record[1].get_ref()
		if all_pairs or not is_instance_valid(a) or not is_instance_valid(b) or a == child or b == child or a == parent or b == parent:
			if is_instance_valid(a) and is_instance_valid(b):
				a.remove_collision_exception_with(b)
			_npc_exceptions.erase(record)

func _exit_tree() -> void:
	_release_exceptions(null, null, true)
