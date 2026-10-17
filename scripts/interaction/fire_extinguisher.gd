class_name FireExtinguisher
extends GrabbableBody

@export var capacity: float = 100.0
@export var capacity_drain: float = 8.0
@export var spray_range: float = 4.0
@export var spray_half_angle: float = 12.0
@export var extinguish_rate: float = 0.3
@export var spray_force: float = 90.0
@export var push_weight_penalty: float = 0.1
@export var recoil_acceleration: float = 1.5
var spraying: bool = false
var _spray: MeshInstance3D

func _ready() -> void:
	super._ready()
	flammable = false
	_spray = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.bottom_radius = 0.035
	cone.top_radius = tan(deg_to_rad(spray_half_angle)) * spray_range
	cone.height = 1
	_spray.mesh = cone
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.96, 1, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spray.material_override = material
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)
	_spray.visible = false
	_update_label()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	spraying = is_instance_valid(holder) and capacity > 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("use_tool")
	if spraying:
		spraying = not KnockdownState.blocked(holder.player) and not holder.is_charging
	_spray.visible = spraying
	if not spraying: return
	var duration := minf(delta, capacity / maxf(0.01, capacity_drain))
	capacity = maxf(0, capacity - capacity_drain * duration)
	var camera: Camera3D = holder.camera
	var direction := -camera.global_basis.z
	var origin := global_position + Vector3.UP * 0.22 + direction * 0.25
	var exclusions: Array[RID] = [get_rid(), holder.player.get_rid()]
	# A blocked carried nozzle cannot project spray from the far side of a wall.
	if not clear_path(camera.global_position, origin, exclusions):
		_spray.visible = false
		_update_label()
		return
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * spray_range, 1 | HumanSeparation.HUMAN_LAYER, exclusions)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var visible_length := spray_range if hit.is_empty() else origin.distance_to(hit.position)
	_spray.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, direction)).scaled(Vector3(1, maxf(0.02, visible_length), 1)), origin + direction * visible_length * 0.5)
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire.is_queued_for_deletion(): continue
		var target: Vector3 = fire.global_position + Vector3.UP * 0.4
		if in_spray(origin, direction, target) and clear_path(origin, target, exclusions): fire.suppress(extinguish_rate * duration)
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = spray_range
	query.shape = sphere
	query.transform.origin = origin
	query.exclude = exclusions
	var seen := {}
	for contact in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var body: Node3D = contact.collider
		if seen.has(body) or not body is PhysicsBody3D: continue
		seen[body] = true
		var ignored := exclusions.duplicate()
		ignored.append(body.get_rid())
		# Compound bodies may have their origin at the floor, outside the visible
		# spray. Sample actual collider centres without a special cart boost.
		var targets: Array[Vector3] = [body.global_position]
		for child in body.get_children():
			if child is CollisionShape3D and not child.disabled: targets.append(child.global_position)
		var reached := false
		for target in targets:
			if in_spray(origin, direction, target) and clear_path(origin, target, ignored):
				reached = true
				break
		if not reached: continue
		var target_mass: float = body.mass if body is RigidBody3D else 8.0
		var force := spray_force / (1 + push_weight_penalty * maxf(0, target_mass - 1))
		PhysicsPush.apply(body, direction * force * duration)
	var recoil := -direction * recoil_acceleration * duration
	recoil.y = 0
	holder.player.velocity += recoil
	_update_label()

func in_spray(origin: Vector3, direction: Vector3, target: Vector3) -> bool:
	var offset := target - origin
	var forward := offset.dot(direction)
	return forward >= 0 and forward <= spray_range and (offset - direction * forward).length() <= 0.15 + forward * tan(deg_to_rad(spray_half_angle))

func clear_path(from: Vector3, to: Vector3, excluded: Array[RID]) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1 | HumanSeparation.HUMAN_LAYER, excluded)).is_empty()

func _update_label() -> void:
	$Label.text = "[F]  %.0f%%" % capacity
	$Label.modulate = Color.WHITE if capacity > 0 else Color.GRAY

func end_carry() -> void:
	super.end_carry()
	spraying = false
	if is_instance_valid(_spray): _spray.visible = false

func _on_body_entered(_body: Node) -> void:
	pass # Physical contact/impulse only; no scripted tool combat damage.
