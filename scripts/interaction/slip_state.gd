class_name SlipState
extends Node
## One non-stacking surface state per body. Owns only its temporary overrides.
var sources: Dictionary = {}
var control_multiplier: float = 1.0
var active: bool = false
var _original_material: PhysicsMaterial
var _original_damp: float
var _wet_material: PhysicsMaterial

static func enter(body: Node3D, source: Node) -> void:
	var state := body.get_node_or_null("SlipState") as SlipState
	if state == null:
		state = SlipState.new()
		state.name = "SlipState"
		body.add_child(state)
	state.sources[source.get_instance_id()] = weakref(source)
	state.refresh()

static func leave(body: Node3D, source: Node) -> void:
	var state := body.get_node_or_null("SlipState") as SlipState
	if state != null:
		state.sources.erase(source.get_instance_id())
		state.refresh()

static func control(body: Node) -> float:
	var state := body.get_node_or_null("SlipState") as SlipState
	return state.control_multiplier if state != null else 1.0

static func wet(body: Node) -> bool:
	return control(body) < 1.0

func _physics_process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var body := get_parent()
	var strength := 1.0
	var friction := 1.0
	var damping := 1.0
	for id in sources.keys():
		var source = sources[id].get_ref()
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			sources.erase(id)
			continue
		strength = minf(strength, source.control_multiplier)
		friction = minf(friction, source.wet_friction)
		damping = minf(damping, source.damping_multiplier)
	# A held product/character above or touching the floor must keep its carry feel.
	if (body is GrabbableBody or body is CarryableCharacter) and is_instance_valid(body.holder):
		strength = 1.0
	control_multiplier = strength
	var enabled := strength < 1.0
	if body is RigidBody3D:
		if enabled and not active:
			_original_material = body.physics_material_override
			_original_damp = body.linear_damp
			_wet_material = _original_material.duplicate() if _original_material != null else PhysicsMaterial.new()
			_wet_material.rough = false
			body.physics_material_override = _wet_material
		if enabled:
			_wet_material.friction = minf(_original_material.friction if _original_material != null else 1.0, friction)
			body.linear_damp = _original_damp * damping
		elif active:
			body.physics_material_override = _original_material
			body.linear_damp = _original_damp
	active = enabled

func _exit_tree() -> void:
	sources.clear()
	refresh()
