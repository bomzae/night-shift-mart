class_name BasicCustomer
extends CharacterBody3D

enum State { STORE, QUEUE, CHECKOUT, DISAPPOINTED, EXIT, SHOP, EVENT_WAIT }
@export var move_speed: float = 2.2
@export var patience_time: float = 25.0
@export var disappointment_time: float = 2.0
@export var max_push_speed: float = 3.5
@export var push_decay: float = 6.0
@export_range(0.5, 1.5) var shopping_time: float = 0.8
var shopping_types: Array[StringName] = []
var visited_types: Array[StringName] = []
var shopping_shelf: StockShelf
var shopping_point_index: int = -1
var _leaving_shelf: StockShelf
var _shopping_left: float = 0
var _heading_queue: bool = false
var manager: Node
var state: State = State.STORE
var purchase_types: Array[StringName] = []
var goods: Array[GrabbableBody] = []
var picked_items: Array[Dictionary] = []
var _pickup_marks: Array[Label3D] = []
var scanned: int = 0
var scan_wait: float = 0.0
var patience_left: float
var purchase_total: float = 0.0
var resolved: bool = false
var unpaid: bool = false
var waypoints: Array[Vector3] = []
var _mood: Label3D
var _mesh: MeshInstance3D
var _contact_zone: Area3D
var _push: Vector3 = Vector3.ZERO
var _disappointment_left: float
var cart_recovery := CartRecovery.new()
var knockdown := KnockdownState.new()
var fire_reaction := FireReaction.new()
@export var human_separation := HumanSeparation.new()
@export var separation_multiplier: float = 1.0
@export var queue_separation_multiplier: float = 0.35

func _ready() -> void:
	human_separation.setup(self)
	cart_recovery.setup(self)
	add_to_group("basic_customers")
	patience_left = patience_time
	floor_snap_length = 0.2
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.65
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.825
	add_child(collision)
	_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.65
	_mesh.mesh = mesh
	_mesh.position.y = 0.825
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.75, 0.85)
	_mesh.material_override = material
	add_child(_mesh)
	var facing_mark := MeshInstance3D.new()
	var mark := BoxMesh.new()
	mark.size = Vector3(0.15, 0.1, 0.06)
	facing_mark.mesh = mark
	facing_mark.position = Vector3(0, 1.35, -0.32)
	add_child(facing_mark)
	_mood = Graybox.sign(self, ":)", Vector3(0, 2.4, 0))
	_mood.pixel_size = 0.005
	# Colored miniature product silhouettes: no inventory bodies or grabbed goods.
	for i in range(purchase_types.size()):
		var icon := MeshInstance3D.new()
		var type := purchase_types[i]
		var definition := ProductCatalog.find(type)
		if definition != null:
			icon.mesh = definition.mesh()
			icon.scale = Vector3.ONE * (0.2 / maxf(definition.size.x, maxf(definition.size.y, definition.size.z)))
		else:
			var box := BoxMesh.new()
			box.size = Vector3(0.2, 0.16, 0.12)
			icon.mesh = box
		var color := StandardMaterial3D.new()
		color.albedo_color = manager.product_color(type)
		icon.material_override = color
		icon.position = Vector3((i - (purchase_types.size() - 1) * 0.5) * 0.25, 1.87, 0)
		add_child(icon)
		var picked := Graybox.sign(self, "✓", icon.position + Vector3(0, 0.23, 0), Color.LIME_GREEN)
		picked.pixel_size = 0.005
		picked.visible = false
		_pickup_marks.append(picked)
	_contact_zone = Area3D.new()
	_contact_zone.collision_layer = 0
	_contact_zone.collision_mask = 1
	var near_shape := CollisionShape3D.new()
	var near_capsule := CapsuleShape3D.new()
	near_capsule.radius = 0.5
	near_capsule.height = 1.7
	near_shape.shape = near_capsule
	near_shape.position.y = 0.85
	_contact_zone.add_child(near_shape)
	add_child(_contact_zone)
	knockdown.setup(self, _mesh)
	fire_reaction.setup(self)

func _physics_process(delta: float) -> void:
	fire_reaction.tick(delta)
	if knockdown.tick(delta):
		velocity = knockdown.damp_motion(velocity, delta)
		velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
		move_and_slide()
		return # Keep timers, purchase state and path progress for recovery.
	if fire_reaction.active():
		velocity = fire_reaction.motion(velocity + _push * delta, delta)
		_push = _push.move_toward(Vector3.ZERO, push_decay * delta)
		velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
		move_and_slide()
		return
	scan_wait = maxf(0, scan_wait - delta)
	if (state == State.STORE or state == State.SHOP) and not manager.valid_goods(self):
		manager.out_of_stock(self)
	if state == State.QUEUE or state == State.CHECKOUT:
		patience_left = maxf(0, patience_left - delta)
		if not manager.valid_goods(self):
			manager.out_of_stock(self)
		elif patience_left <= 0:
			manager.finish(self, false)
	if state == State.DISAPPOINTED:
		_disappointment_left -= delta
		if _disappointment_left <= 0:
			start_exit()
	var target := global_position
	if state == State.SHOP:
		target = shopping_shelf.shopping_point(shopping_point_index)
		var facing := shopping_shelf.global_position
		facing.y = global_position.y
		look_at(facing, Vector3.UP)
		if global_position.distance_to(target) < 0.35:
			_shopping_left -= delta
		if _shopping_left <= 0:
			if not manager.pickup_from_shelf(self, shopping_shelf, shopping_types[visited_types.size()]):
				return
			visited_types.append(shopping_types[visited_types.size()])
			_leaving_shelf = shopping_shelf
			shopping_shelf = null
			# Keep the point occupied until physically clear of its approach.
			waypoints = [Vector3(0, 0, global_position.z)]
			state = State.STORE
	if state == State.STORE or state == State.EXIT:
		if not waypoints.is_empty():
			target = waypoints[0]
			if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.23:
				waypoints.pop_front()
		elif state == State.STORE:
			continue_shopping()
		else:
			finish_exit()
			return
	elif state == State.QUEUE or state == State.CHECKOUT:
		target = manager.queue_position(self)
		if global_position.distance_to(target) < 0.35 and manager.queue.front() == self:
			state = State.CHECKOUT
	var direction := target - global_position
	direction.y = 0
	var walking := direction.normalized() * minf(move_speed, direction.length() * 5)
	var spacing_weight := separation_multiplier * minf(1.0, direction.length() / 0.5)
	if state == State.QUEUE or state == State.CHECKOUT: spacing_weight *= queue_separation_multiplier
	if state == State.SHOP or state == State.EVENT_WAIT or not uses_customer_separation(): spacing_weight = 0
	walking += human_separation.correction(self, walking, spacing_weight)
	walking = cart_recovery.steer(walking, delta, 0.4 if state == State.QUEUE or state == State.CHECKOUT or state == State.SHOP else 1.0)
	_push = _push.move_toward(Vector3.ZERO, push_decay * delta)
	for body in _contact_zone.get_overlapping_bodies():
		if body is ShoppingCart:
			var away := global_position - body.global_position
			away.y = 0
			away = away.normalized()
			var closing: float = body.linear_velocity.dot(away)
			if closing > 0.1:
				_push = away * minf(max_push_speed, closing * 0.8 + 0.2)
	var motion := walking + _push
	if SlipState.wet(self) and is_on_floor():
		# Smooth the complete target velocity. Adding _push after smoothing would
		# repeatedly integrate last tick's push and accelerate without a bound.
		motion = Vector3(velocity.x, 0, velocity.z).move_toward(motion, 14.0 * SlipState.control(self) * delta)
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if state == State.STORE and walking.length() > 0.1:
		look_at(global_position + Vector3(walking.x, 0, walking.z), Vector3.UP)
	_mesh.rotation.x = -0.1 * sin(PI * (1 - _shopping_left / shopping_time)) if state == State.SHOP else 0.0
	_mesh.position.y = 0.825 + sin(Time.get_ticks_msec() * 0.012) * minf(0.035, walking.length() * 0.015)
	update_mood()

func uses_customer_separation() -> bool:
	return true

func apply_external_impulse(impulse: Vector3) -> void:
	impulse.y = 0
	_push = (_push + impulse * 0.4).limit_length(max_push_speed)

func update_mood() -> void:
	if state == State.DISAPPOINTED:
		_mood.text = "X  :("
		_mood.modulate = Color.SALMON
	elif state == State.EXIT:
		_mood.text = "[!]" if unpaid else ":)"
		_mood.modulate = Color.ORANGE_RED if unpaid else Color.LIME_GREEN
	else:
		var ratio := patience_left / maxf(0.1, patience_time)
		_mood.text = ":)" if ratio > 0.6 else (":|" if ratio > 0.3 else ":!")
		_mood.modulate = Color.WHITE if ratio > 0.6 else (Color.YELLOW if ratio > 0.3 else Color.ORANGE_RED)

func show_pickup(type: StringName) -> void:
	for i in range(purchase_types.size()):
		if purchase_types[i] == type:
			_pickup_marks[i].visible = true

func finish_exit() -> void:
	manager.remove_customer(self)

func disappoint() -> void:
	state = State.DISAPPOINTED
	_disappointment_left = disappointment_time
	update_mood()

func start_exit() -> void:
	release_shopping_points()
	state = State.EXIT
	waypoints = StoreRoutes.via_main(global_position, manager.exit_position())
	update_mood()

func continue_shopping() -> void:
	if is_instance_valid(_leaving_shelf):
		_leaving_shelf.release_shopping_point(self)
		_leaving_shelf = null
	if is_instance_valid(shopping_shelf):
		state = State.SHOP
		_shopping_left = shopping_time
		return
	if visited_types.size() == shopping_types.size():
		if not _heading_queue:
			_heading_queue = true
			waypoints = [Vector3(0, 0, 14.6), Vector3(1, 0, 14.6)]
		else:
			manager.join_queue(self)
		return
	var type := shopping_types[visited_types.size()]
	for shelf: StockShelf in manager.get_parent().get_node("Shelves").get_children():
		for product in goods:
			if not is_instance_valid(product) or product.product_type != type or not shelf.has_stock(product):
				continue
			var point := shelf.reserve_shopping_point(self, product.global_position)
			if point < 0:
				waypoints = [Vector3(-6.5 + manager.customers.find(self) * 0.85, 0, 2.0)]
				return
			shopping_shelf = shelf
			shopping_point_index = point
			var destination := shelf.shopping_point(point)
			waypoints = StoreRoutes.via_main(global_position, destination)
			return
	manager.out_of_stock(self)

func release_shopping_points() -> void:
	if is_instance_valid(shopping_shelf):
		shopping_shelf.release_shopping_point(self)
	if is_instance_valid(_leaving_shelf):
		_leaving_shelf.release_shopping_point(self)
	shopping_shelf = null
	_leaving_shelf = null

func _exit_tree() -> void:
	release_shopping_points()
