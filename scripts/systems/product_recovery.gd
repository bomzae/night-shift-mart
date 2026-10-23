class_name ProductRecovery
extends Node
## Human-only, floor-level recovery. Keep free/held/projectile objects physical.
@export var probe_distance: float = 1.25
@export var stuck_threshold: float = 1.1
@export var sidestep_delay: float = 0.2
@export var side_speed: float = 0.9
@export var clear_distance: float = 1.8
@export_range(0.0, 1.0) var minimum_progress_ratio: float = 0.3
@export var push_force: float = 12.0
var body: PhysicsBody3D
var obstacle: GrabbableBody
var previous: Vector3
var side: Vector3
var stuck: float = 0
var recoveries: int = 0
var pairs: Dictionary = {}
var encounters: Dictionary = {}
var encounter_clock: float = 0

func setup(target: PhysicsBody3D) -> void:
	body = target
	name = "ProductRecovery"
	target.add_child(self)
	previous = body.global_position

func eligible(product: GrabbableBody) -> bool:
	return is_instance_valid(product) and not product.is_queued_for_deletion() and not is_instance_valid(product.holder) and product.linear_velocity.length() < 2.5

func feet() -> Vector3:
	var height := 0.0
	if body is CarryableCharacter:
		height = body.get_node("CollisionShape3D").shape.height / 2
	return body.global_position - Vector3.UP * height

func on_floor_level(product: GrabbableBody) -> bool:
	if product.definition == null: return product.global_position.y <= feet().y + 1.05
	var size := product.definition.size
	var basis := product.global_basis
	var half_height := (absf(basis.x.y) * size.x + absf(basis.y.y) * size.y + absf(basis.z.y) * size.z) / 2
	return product.global_position.y - half_height <= feet().y + 0.18

func _physics_process(_delta: float) -> void:
	for id in pairs.keys():
		var product = pairs[id].get_ref()
		if not is_instance_valid(product):
			pairs.erase(id)
		elif not eligible(product) or body.global_position.distance_to(product.global_position) > clear_distance:
			restore(product)

func restore(product: GrabbableBody) -> void:
	pairs.erase(product.get_instance_id())
	encounters.erase(product.get_instance_id())
	body.remove_collision_exception_with(product)
	product.remove_collision_exception_with(body)
	var callback := restore.bind(product)
	if product.tree_exiting.is_connected(callback): product.tree_exiting.disconnect(callback)

func clear() -> void:
	for ref: WeakRef in pairs.values():
		var product = ref.get_ref()
		if is_instance_valid(product): restore(product)
	pairs.clear()
	encounters.clear()
	obstacle = null
	stuck = 0

func steer(desired: Vector3, delta: float, strength: float = 1.0) -> Vector3:
	encounter_clock += delta
	for id in encounters.keys():
		if not is_instance_valid(encounters[id].ref.get_ref()) or encounter_clock - encounters[id].seen > 1.5: encounters.erase(id)
	var progress := body.global_position - previous
	previous = body.global_position
	if desired.length() < 0.15:
		stuck = 0
		return desired
	var direction := desired.normalized()
	var excluded: Array[RID] = [body.get_rid()]
	for ref: WeakRef in pairs.values():
		var product = ref.get_ref()
		if is_instance_valid(product): excluded.append(product.get_rid())
	var found: GrabbableBody
	for height in [0.15, 0.45, 0.8]:
		for lateral in [-0.25, 0.0, 0.25]:
			var origin: Vector3 = feet() + Vector3.UP * height + direction.cross(Vector3.UP) * lateral
			var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * probe_distance, 1, excluded)
			var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider is GrabbableBody and eligible(hit.collider):
				if on_floor_level(hit.collider):
					found = hit.collider
					break
		if found != null: break
	# A capsule can rest on the edge of a flat fallen object below all forward
	# probes. Preserve that real contact as the recovery candidate.
	if found == null:
		var contacts: Array = []
		if body is RigidBody3D:
			contacts = body.get_colliding_bodies()
		elif body is CharacterBody3D:
			for i in range(body.get_slide_collision_count()): contacts.append(body.get_slide_collision(i).get_collider())
		for contact in contacts:
			if contact is GrabbableBody and eligible(contact) and on_floor_level(contact) and not pairs.has(contact.get_instance_id()):
				found = contact
				break
	if found == null:
		stuck = 0
		obstacle = null
		return desired
	var id := found.get_instance_id()
	if not encounters.has(id):
		var chosen_side := direction.cross(Vector3.UP)
		var origin: Vector3 = feet() + Vector3.UP * 0.5
		if clearance(origin, -chosen_side) > clearance(origin, chosen_side): chosen_side = -chosen_side
		encounters[id] = {"ref": weakref(found), "time": 0.0, "seen": encounter_clock, "side": chosen_side}
	obstacle = found
	side = encounters[id].side
	# Keep progress per object across wobbling probes and adjacent pile contacts.
	found.apply_central_impulse(direction * push_force * delta)
	stuck = float(encounters[id].time)
	stuck = stuck + delta if progress.dot(direction) < maxf(0.15, desired.length() * minimum_progress_ratio) * delta else maxf(0, stuck - delta * 2)
	encounters[id].time = stuck
	encounters[id].seen = encounter_clock
	if stuck >= stuck_threshold:
		body.add_collision_exception_with(found)
		found.add_collision_exception_with(body)
		pairs[found.get_instance_id()] = weakref(found)
		found.tree_exiting.connect(restore.bind(found), CONNECT_ONE_SHOT)
		recoveries += 1
		stuck = 0
		return desired
	if stuck < sidestep_delay: return desired
	return desired + side * minf(side_speed * strength, desired.length() * 0.5)

func clearance(origin: Vector3, direction: Vector3) -> float:
	var hit := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction, 1, [body.get_rid()]))
	return 1.0 if hit.is_empty() else origin.distance_to(hit.position)

func _exit_tree() -> void:
	clear()
