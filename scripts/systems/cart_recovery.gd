class_name CartRecovery
extends Node
## Human-only steering. Exceptions belong to this one human/cart encounter.
@export var probe_distance: float = 2.2
@export var side_speed: float = 1.5
@export var stuck_threshold: float = 2.0
@export var clear_distance: float = 2.5
var body: PhysicsBody3D
var obstacle: ShoppingCart
var passing: bool = false
var _exceptions: Array[ShoppingCart] = []
var stuck: float = 0
var side: Vector3
var previous: Vector3
var recoveries: int = 0

func setup(target: PhysicsBody3D) -> void:
	body = target
	name = "CartRecovery"
	target.add_child(self)
	previous = body.global_position

func _physics_process(_delta: float) -> void:
	for cart in _exceptions.duplicate():
		if not is_instance_valid(cart):
			_exceptions.erase(cart)
		elif body.global_position.distance_to(cart.global_position) > clear_distance:
			body.remove_collision_exception_with(cart)
			cart.remove_collision_exception_with(body)
			_exceptions.erase(cart)
	passing = not _exceptions.is_empty()
	if is_instance_valid(obstacle) and body.global_position.distance_to(obstacle.global_position) > clear_distance:
		obstacle = null
		stuck = 0

func clear() -> void:
	for cart in _exceptions:
		if is_instance_valid(cart):
			body.remove_collision_exception_with(cart)
			cart.remove_collision_exception_with(body)
	_exceptions.clear()
	obstacle = null
	passing = false
	stuck = 0

func steer(desired: Vector3, delta: float, strength: float = 1.0) -> Vector3:
	var progress := body.global_position - previous
	previous = body.global_position
	if desired.length() < 0.15:
		stuck = 0
		return desired
	var direction := desired.normalized()
	var found: ShoppingCart
	var excluded: Array[RID] = [body.get_rid()]
	for cart in _exceptions:
		if is_instance_valid(cart): excluded.append(cart.get_rid())
	# Three short probes cover the capsule width, but do not see through walls.
	for lateral in [-0.25, 0.0, 0.25]:
		var origin: Vector3 = body.global_position + Vector3.UP * (0.6 if body is CharacterBody3D else 0.0) + direction.cross(Vector3.UP) * lateral
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * probe_distance, 1, excluded)
		var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider is ShoppingCart:
			found = hit.collider
			break
	if found == null:
		stuck = maxf(0, stuck - delta)
		return desired
	if obstacle != found:
		obstacle = found
		stuck = 0
		side = direction.cross(Vector3.UP)
		var origin: Vector3 = body.global_position + Vector3.UP * (0.6 if body is CharacterBody3D else 0.0)
		var right := _clearance(origin, side)
		var left := _clearance(origin, -side)
		if left > right: side = -side
	# Forward progress, not sideways wobble, determines whether recovery is needed.
	stuck = stuck + delta if progress.dot(direction) < 0.15 * delta else maxf(0, stuck - delta * 2)
	if stuck >= stuck_threshold and body.global_position.distance_to(obstacle.global_position) < probe_distance + 0.5:
		body.add_collision_exception_with(obstacle)
		obstacle.add_collision_exception_with(body)
		_exceptions.append(obstacle)
		passing = true
		recoveries += 1
		return desired
	return desired + side * minf(side_speed * strength, desired.length() * 0.8)

func _clearance(origin: Vector3, direction: Vector3) -> float:
	var hit := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.5, 1, [body.get_rid()]))
	return 1.5 if hit.is_empty() else origin.distance_to(hit.position)

func _exit_tree() -> void:
	clear()

