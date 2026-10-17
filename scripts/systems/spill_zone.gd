class_name SpillZone
extends Area3D

signal cleaned
@export var radius: float = 1.5
@export_range(0.1, 1.0) var core_ratio: float = 0.7
@export var activation_delay: float = 0.3
var age: float = 0.0
@export_range(0.1, 1.0) var control_multiplier: float = 0.3
@export_range(0.0, 1.0) var wet_friction: float = 0.04
@export_range(0.0, 1.0) var damping_multiplier: float = 0.2
var clean_progress: float = 0.0
var visual: MeshInstance3D
var _shape: CylinderShape3D
var _bodies: Dictionary = {}

func _physics_process(delta: float) -> void:
	age += delta

func contains_core(point: Vector3) -> bool:
	if is_queued_for_deletion() or age < activation_delay: return false
	var offset := point - global_position
	return Vector2(offset.x, offset.z).length() <= _shape.radius * core_ratio

func _ready() -> void:
	collision_layer = 16 # Mop head sensing only; no solid liquid collider.
	collision_mask = 1 | HumanSeparation.HUMAN_LAYER
	_shape = CylinderShape3D.new()
	_shape.radius = radius
	_shape.height = 0.2
	var collision := CollisionShape3D.new()
	collision.shape = _shape
	collision.position.y = 0.09
	add_child(collision)
	visual = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	mesh.radial_segments = 48
	visual.mesh = mesh
	visual.position.y = 0.015
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.1, 0.65, 1.0, 0.65)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	body_entered.connect(_entered)
	body_exited.connect(_exited)

func _entered(body: Node3D) -> void:
	if not (body is RigidBody3D or body is CharacterBody3D):
		return
	_bodies[body.get_instance_id()] = weakref(body)
	SlipState.enter(body, self)

func _exited(body: Node3D) -> void:
	_bodies.erase(body.get_instance_id())
	SlipState.leave(body, self)

func clean(amount: float) -> void:
	if is_queued_for_deletion() or amount <= 0:
		return
	clean_progress = minf(1.0, clean_progress + amount)
	var size := maxf(0.2, sqrt(1.0 - clean_progress))
	visual.scale = Vector3(size, 1, size)
	_shape.radius = radius * size
	if clean_progress >= 1.0:
		cleaned.emit()
		queue_free()

func _exit_tree() -> void:
	for entry in _bodies.values():
		var body = entry.get_ref()
		if is_instance_valid(body):
			SlipState.leave(body, self)
