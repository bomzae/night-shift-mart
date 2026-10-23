class_name GrabbableBody
extends RigidBody3D
## Shared physical object; data lives on each instance, never in an inventory.

@export var show_debug_label: bool = false
@export var display_name: String = "Object"
@export var product_type: StringName = &""
@export var flammable: bool = true
@export_range(0.0, 100000.0) var price: float = 5.0
@export_range(0.1, 100.0) var weight: float = 1.0
@export var tint: Color = Color.CORAL
@export_range(0.1, 3.0) var carry_radius: float = 0.49
@export var definition: ProductDefinition:
	set(value):
		definition = value
		if value != null:
			display_name = value.display_name
			product_type = value.id
			price = value.price
			weight = value.weight
			flammable = value.flammable
			tint = value.tint
			carry_radius = value.carry_radius

var holder: Node = null
var hold_target: Vector3
var follow_strength: float = 12.0
var max_carry_speed: float = 8.0
var max_carry_acceleration: float = 45.0
var throw_damage: float = 0.0
var impact_min_speed: float = 2.0
var knockback_multiplier: float = 0.15
var max_knockback_impulse: float = 18.0
var _armed_seconds: float = 0.0
var _incoming_velocity: Vector3
var _recent_velocities: Array[Vector3] = []
var _ignored_player: PhysicsBody3D
var _saved_gravity: float
var _saved_angular_damp: float
var _cart_source: PhysicsBody3D
var impact_count: int = 0


func _ready() -> void:
	collision_mask |= HumanSeparation.HUMAN_LAYER | HumanSeparation.MONSTER_LAYER
	if definition != null:
		$Mesh.mesh = definition.mesh()
		$CollisionShape3D.shape = definition.collision_shape()
	mass = weight
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	body_entered.connect(_on_body_entered)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	$Mesh.material_override = material
	$Label.visible = show_debug_label or product_type == &""
	$Label.text = "%s  $%.0f\n%.1f kg" % [display_name, price, weight]


func begin_carry(controller: Node, player: PhysicsBody3D) -> bool:
	if is_instance_valid(holder):
		return false
	holder = controller
	_cart_source = null
	_armed_seconds = 0.0
	_saved_gravity = gravity_scale
	_saved_angular_damp = angular_damp
	gravity_scale = 0.0
	angular_damp = 8.0
	if is_instance_valid(_ignored_player):
		remove_collision_exception_with(_ignored_player)
	_ignored_player = player
	add_collision_exception_with(player)
	sleeping = false
	hold_target = global_position
	return true


func end_carry() -> void:
	if not is_instance_valid(holder):
		return
	holder = null
	gravity_scale = _saved_gravity
	angular_damp = _saved_angular_damp
	sleeping = false
	# The player's collision exception is removed only after separation.


func launch(direction: Vector3, speed: float, damage: float) -> void:
	end_carry()
	_cart_source = null
	throw_damage = damage
	_armed_seconds = 4.0
	linear_velocity = Vector3.ZERO
	apply_central_impulse(direction.normalized() * mass * speed)
	_incoming_velocity = direction.normalized() * speed
	_recent_velocities = [_incoming_velocity]


func arm_cart_impact(damage: float, cart: PhysicsBody3D) -> void:
	# Use the same one-hit damage path for loose cargo; internal basket contacts
	# remain physical but do not consume its first external impact.
	_cart_source = cart
	throw_damage = damage
	_armed_seconds = 4.0
	_incoming_velocity = linear_velocity
	_recent_velocities = [_incoming_velocity]


func _physics_process(delta: float) -> void:
	_armed_seconds = maxf(0.0, _armed_seconds - delta)
	if not is_instance_valid(holder) and is_instance_valid(_ignored_player):
		var offset := global_position - (_ignored_player.global_position + Vector3.UP * 0.9)
		if Vector2(offset.x, offset.z).length() > carry_radius + 0.4 or absf(offset.y) > carry_radius + 0.9:
			remove_collision_exception_with(_ignored_player)
			_ignored_player = null


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_instance_valid(holder):
		var desired := ((hold_target - state.transform.origin) * follow_strength).limit_length(max_carry_speed)
		state.linear_velocity = state.linear_velocity.move_toward(desired, max_carry_acceleration * state.step)
	# Keep pre-impact velocity: the solver may stop a body before body_entered.
	# Cart cargo remains in contact with its basket while travelling. Those
	# ignored internal contacts must not leave a pre-launch zero-speed sample.
	var external_contact := false
	for index in range(state.get_contact_count()):
		var other := state.get_contact_collider_object(index)
		if not is_instance_valid(_cart_source) or (other != _cart_source and not other is GrabbableBody):
			external_contact = true
			break
	if not external_contact:
		_incoming_velocity = state.linear_velocity
		if _armed_seconds > 0.0:
			_recent_velocities.append(_incoming_velocity)
			if _recent_velocities.size() > 3:
				_recent_velocities.pop_front()


func _on_body_entered(body: Node) -> void:
	if is_instance_valid(holder) or _armed_seconds <= 0.0:
		return
	if is_instance_valid(_cart_source) and (body == _cart_source or body is GrabbableBody):
		return
	_armed_seconds = 0.0 # One first collision per throw; resting/rolling cannot farm damage.
	# CCD may clip velocity before reporting contact. Retain the incoming motion
	# from the last three physics ticks, not the lifetime maximum/launch speed.
	for sample in _recent_velocities:
		if sample.length_squared() > _incoming_velocity.length_squared():
			_incoming_velocity = sample
	_recent_velocities.clear()
	if _incoming_velocity.length() < impact_min_speed or not body.has_method("receive_impact"):
		return
	var impulse := (_incoming_velocity * weight * knockback_multiplier).limit_length(max_knockback_impulse)
	impact_count += 1
	body.call_deferred("receive_impact", throw_damage, impulse)
