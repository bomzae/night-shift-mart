class_name BasicCustomer
extends CharacterBody3D

enum State { STORE, QUEUE, CHECKOUT, DISAPPOINTED, EXIT }
@export var move_speed: float = 2.2
@export var patience_time: float = 25.0
@export var disappointment_time: float = 2.0
@export var max_push_speed: float = 3.5
@export var push_decay: float = 6.0
var manager: Node
var state: State = State.STORE
var purchase_types: Array[StringName] = []
var goods: Array[GrabbableBody] = []
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

func _ready() -> void:
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
	_mood = Graybox.sign(self, ":)", Vector3(0, 2.15, 0))
	_mood.pixel_size = 0.005
	# Colored miniature product silhouettes: no inventory bodies or grabbed goods.
	for i in range(purchase_types.size()):
		var icon := MeshInstance3D.new()
		var type := purchase_types[i]
		if type == &"watermelon":
			var sphere := SphereMesh.new()
			sphere.radius = 0.1
			sphere.height = 0.2
			icon.mesh = sphere
		elif type == &"can":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.07
			cylinder.bottom_radius = 0.07
			cylinder.height = 0.2
			icon.mesh = cylinder
		else:
			var box := BoxMesh.new()
			box.size = Vector3(0.2, 0.16, 0.12)
			icon.mesh = box
		var color := StandardMaterial3D.new()
		color.albedo_color = manager.product_color(type)
		icon.material_override = color
		icon.position = Vector3((i - (purchase_types.size() - 1) * 0.5) * 0.25, 1.87, 0)
		add_child(icon)
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

func _physics_process(delta: float) -> void:
	scan_wait = maxf(0, scan_wait - delta)
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
	if state == State.STORE or state == State.EXIT:
		if not waypoints.is_empty():
			target = waypoints[0]
			if Vector2(target.x - global_position.x, target.z - global_position.z).length() < 0.23:
				waypoints.pop_front()
		elif state == State.STORE:
			manager.join_queue(self)
		else:
			manager.remove_customer(self)
			return
	elif state == State.QUEUE or state == State.CHECKOUT:
		target = manager.queue_position(self)
		if global_position.distance_to(target) < 0.35 and manager.queue.front() == self:
			state = State.CHECKOUT
	var direction := target - global_position
	direction.y = 0
	var walking := direction.normalized() * minf(move_speed, direction.length() * 5)
	for other in manager.customers:
		if other == self or not is_instance_valid(other):
			continue
		var separation: Vector3 = global_position - other.global_position
		separation.y = 0
		if separation.length() > 0.01 and separation.length() < 0.85:
			walking += separation.normalized() * (0.85 - separation.length()) * 4
	_push = _push.move_toward(Vector3.ZERO, push_decay * delta)
	for body in _contact_zone.get_overlapping_bodies():
		if body is ShoppingCart:
			var away := global_position - body.global_position
			away.y = 0
			away = away.normalized()
			var closing: float = body.linear_velocity.dot(away)
			if closing > 0.1:
				_push = away * minf(max_push_speed, closing * 0.8 + 0.2)
	velocity.x = walking.x + _push.x
	velocity.z = walking.z + _push.z
	velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_mesh.position.y = 0.825 + sin(Time.get_ticks_msec() * 0.012) * minf(0.035, walking.length() * 0.015)
	update_mood()

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

func disappoint() -> void:
	state = State.DISAPPOINTED
	_disappointment_left = disappointment_time
	update_mood()

func start_exit() -> void:
	var waiting_at_store := state == State.DISAPPOINTED and global_position.x < -6
	state = State.EXIT
	if waiting_at_store:
		waypoints = [Vector3(-6.9, 0, 10.8), manager.exit_position()]
	elif global_position.z < 7.5:
		waypoints = [Vector3(-7, 0, 8), Vector3(-7, 0, 10.8), manager.exit_position()]
	else:
		waypoints = [Vector3(global_position.x, 0, 7.7), Vector3(-3, 0, 7.7), manager.exit_position()]
	update_mood()
