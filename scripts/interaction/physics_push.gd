class_name PhysicsPush
extends RefCounted
## Bounded impulse shared by spray and environmental panic, never damage.
static func apply(body: Node, impulse: Vector3) -> void:
	if body.has_method("apply_external_impulse"):
		body.apply_external_impulse(impulse)
	elif body is RigidBody3D:
		if body.get("holder") != null: return
		body.sleeping = false
		body.apply_central_impulse(impulse)
