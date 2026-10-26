class_name ShoppingCart
extends RigidBody3D
## Loose physical cargo, force-limited handle control, no inventory or riding mode.

@export var cart_base_mass: float = 12.0
@export var load_mass_multiplier: float = 1.0
@export var push_strength: float = 576.0
@export var follow_strength: float = 18.0
@export var stopped_follow_strength: float = 6.0
@export var steering_strength: float = 432.0
@export var steering_gain: float = 10.0
@export var max_steering_speed: float = 5.0
@export var max_follow_correction: float = 6.0
@export var load_control_penalty: float = 0.35
@export var braking_strength: float = 360.0
@export var load_braking_penalty: float = 0.7
@export var handle_distance: float = 2.1
@export var emergency_break_distance: float = 6.0
@export var max_push_speed: float = 6.0
@export var rolling_resistance: float = 0.6
@export var launch_force: float = 12.0
@export var launch_load_penalty: float = 0.45
@export var impact_min_speed: float = 2.0
@export var impact_damage_multiplier: float = 0.12
@export var impact_knockback_multiplier: float = 0.08
@export var max_impact_damage: float = 60.0
@export var max_knockback_impulse: float = 18.0
@export var impact_cooldown: float = 0.8
@export var righting_torque: float = 120.0
@export var spill_min_speed: float = 5.0
@export var spill_lift_multiplier: float = 0.75
@export var spill_forward_multiplier: float = 0.35
@export var max_spill_lift: float = 6.0
@export var crash_flip_speed: float = 12.0
@export var crash_torque_multiplier: float = 2.0
@export var max_crash_torque_impulse: float = 120.0
@export var max_spin_speed: float = 6.0
@export var wet_drive_multiplier: float = 0.85
@export var wet_steering_multiplier: float = 0.6

@export var cargo_assist_enabled: bool = true
@export var cargo_relative_speed: float = 1.6
@export var cargo_linear_damping: float = 4.0
@export var cargo_angular_damping: float = 5.0
@export var cargo_assist_acceleration: float = 3.0
var cargo_release_time: float = 0.0
var _cargo_previous_velocity := Vector3.ZERO

var holder: Node
var loaded_weight: float = 0.0
var effective_mass: float = 12.0
var cargo: Array[GrabbableBody] = []
var last_impact_speed: float = 0.0
var last_impact_mass: float = 0.0
var last_impact_damage: float = 0.0
var impact_count: int = 0
var _control_target: Vector3
var _control_forward: Vector3 = Vector3.FORWARD
var _impact_wait: float = 0.0
var _recent_velocities: Array[Vector3] = []
var _launch_remaining: float = 0.0
var _launch_hits: Array[int] = []
var _crash_available: bool = true
var drive_velocity: Vector3 = Vector3.ZERO
var _grabbing_player: PhysicsBody3D


func _ready() -> void:
	collision_mask |= HumanSeparation.HUMAN_LAYER | HumanSeparation.MONSTER_LAYER
	mass = maxf(0.1, cart_base_mass)
	effective_mass = mass
	contact_monitor = true
	max_contacts_reported = 16
	continuous_cd = true
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0)
	body_entered.connect(_on_body_entered)


func begin_carry(controller: Node, player: PhysicsBody3D) -> bool:
	if is_instance_valid(holder):
		return false
	var local_player := to_local(player.global_position)
	if absf(local_player.x) < 0.95 and absf(local_player.z) < 1.0 and local_player.y > 0.25:
		return false # A rider cannot pull their own floor from inside the basket.
	holder = controller
	_grabbing_player = player
	add_collision_exception_with(player)
	player.add_collision_exception_with(self)
	drive_velocity = Vector3.ZERO
	_crash_available = true
	sleeping = false
	_control_target = global_position
	return true


func end_carry() -> void:
	if is_instance_valid(_grabbing_player):
		remove_collision_exception_with(_grabbing_player)
		_grabbing_player.remove_collision_exception_with(self)
	_grabbing_player = null
	drive_velocity = Vector3.ZERO
	holder = null


func update_control(player: CharacterBody3D, camera: Camera3D) -> void:
	_control_forward = -camera.global_basis.z
	_control_forward.y = 0.0
	_control_forward = _control_forward.normalized()
	_control_target = player.global_position + _control_forward * handle_distance
	_control_target.y = global_position.y
	if not player.is_physics_processing():
		drive_velocity = Vector3.ZERO


func constrain_player_velocity(player: CharacterBody3D, desired: Vector3, delta: float) -> Vector3:
	# A virtual handle limits walking through / away from a blocked chassis.
	# Only velocity is constrained; neither body's transform is assigned.
	drive_velocity = Vector3(desired.x, 0, desired.z)
	sleeping = false
	var offset := player.global_position - global_position
	offset.y = 0
	var distance := offset.length()
	if distance < 0.01:
		return desired
	var radial := offset / distance
	# Use the current physical position, not the commanded chassis velocity:
	# a solver-blocked cart can still report a nonzero drive velocity this tick.
	var radial_speed := desired.dot(radial)
	var minimum := -maxf(0, distance - 1.75) / delta
	var maximum := maxf(0, 2.65 - distance) / delta
	return desired + radial * (clampf(radial_speed, minimum, maximum) - radial_speed)


func refresh_load() -> void:
	var previous := cargo.duplicate()
	cargo.clear()
	loaded_weight = 0.0
	for body in $LoadVolume.get_overlapping_bodies():
		if body is GrabbableBody and not is_instance_valid(body.holder):
			var local_point: Vector3 = to_local(body.global_position)
			if absf(local_point.x) < 0.83 and absf(local_point.z) < 0.96 and local_point.y > 0.38 and local_point.y < 1.6:
				cargo.append(body)
				body.cargo_cart = weakref(self)
				loaded_weight += body.weight
	# The cargo keeps its own mass. Do not add it again to the chassis RigidBody.
	effective_mass = maxf(0.1, cart_base_mass + loaded_weight * load_mass_multiplier)
	for body in previous:
		if is_instance_valid(body) and not cargo.has(body):
			body.get_node("Label").visible = body.show_debug_label or body.product_type == &""
	for body in cargo:
		body.get_node("Label").hide()


func push_acceleration() -> float:
	return push_strength / (maxf(0.1, cart_base_mass) * control_penalty(load_control_penalty)) * (wet_drive_multiplier if SlipState.wet(self) else 1.0)


func control_penalty(amount: float) -> float:
	# Saturating assistance applies only while driving, never to impact/launch mass.
	var ratio := maxf(0, effective_mass / maxf(0.1, cart_base_mass) - 1.0)
	return 1.0 + maxf(0, amount) * ratio / (1.0 + ratio)


func braking_acceleration() -> float:
	return braking_strength / (maxf(0.1, cart_base_mass) * control_penalty(load_braking_penalty)) * SlipState.control(self)


func steering_acceleration() -> float:
	return steering_strength / (maxf(0.1, cart_base_mass) * control_penalty(load_control_penalty)) * (wet_steering_multiplier if SlipState.wet(self) else 1.0)


func launch_speed(multiplier: float) -> float:
	return launch_force * multiplier / (1.0 + launch_load_penalty * loaded_weight / maxf(0.1, cart_base_mass))


func damage_at_speed(speed: float) -> float:
	return minf(max_impact_damage, speed * effective_mass * impact_damage_multiplier)


func launch_cart(direction: Vector3, multiplier: float, charge: float, interaction: Node) -> void:
	refresh_load()
	end_carry()
	_launch_remaining = 4.0
	cargo_release_time = 4.0
	_launch_hits.clear()
	_crash_available = true
	var forward := Vector3(direction.x, 0, direction.z).normalized()
	if forward.is_zero_approx():
		forward = -global_basis.z
	var desired := forward * launch_speed(multiplier)
	var change := desired - Vector3(linear_velocity.x, 0, linear_velocity.z)
	apply_central_impulse(change * mass)
	# A launch impulse accelerates the current loose load too. No attachment,
	# frozen bodies or continued velocity matching after this single impulse.
	for body in cargo:
		body.apply_central_impulse(change * body.mass)
		body.impact_min_speed = interaction.impact_min_speed
		body.knockback_multiplier = interaction.knockback_multiplier * multiplier
		body.max_knockback_impulse = interaction.max_knockback_impulse
		body.arm_cart_impact(interaction.damage_for(body.price, charge), self)
	_recent_velocities = [desired]
	sleeping = false


func _physics_process(delta: float) -> void:
	refresh_load()
	var acceleration := (linear_velocity - _cargo_previous_velocity).length() / maxf(delta, 0.001)
	if acceleration > 24 or angular_velocity.length() > 2.5 or global_basis.y.dot(Vector3.UP) < 0.94:
		cargo_release_time = maxf(cargo_release_time, 0.45)
	_cargo_previous_velocity = linear_velocity
	cargo_release_time = maxf(0, cargo_release_time - delta)
	# Sleeping cargo must wake when its supporting chassis moves, not hang in space.
	if linear_velocity.length() > 0.15 or angular_velocity.length() > 0.15:
		for body in cargo:
			if body.sleeping: body.sleeping = false
	_impact_wait = maxf(0.0, _impact_wait - delta)
	_launch_remaining = maxf(0.0, _launch_remaining - delta)
	$Label.text = "CART | load %.1f kg" % loaded_weight


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.angular_velocity = state.angular_velocity.limit_length(max_spin_speed)
	var horizontal := Vector3(state.linear_velocity.x, 0, state.linear_velocity.z)
	var grounded := false
	for index in range(state.get_contact_count()):
		if (state.transform.basis * state.get_contact_local_normal(index)).dot(Vector3.UP) > 0.5:
			grounded = true
	if is_instance_valid(holder):
		var correction := _control_target - state.transform.origin
		correction.y = 0
		var slowing := drive_velocity.length_squared() < 0.01
		var correction_gain := stopped_follow_strength if slowing else follow_strength
		var desired := (drive_velocity + (correction * correction_gain).limit_length(max_follow_correction)).limit_length(max_push_speed)
		desired.y = 0
		var acceleration := braking_acceleration() if slowing else push_acceleration()
		if SlipState.wet(self):
			var change := desired - horizontal
			var along := _control_forward * change.dot(_control_forward)
			horizontal += along.limit_length(acceleration * state.step) + (change - along).limit_length(acceleration * SlipState.control(self) * state.step)
		else:
			horizontal = horizontal.move_toward(desired, acceleration * state.step)
		var facing := -state.transform.basis.z
		facing.y = 0
		var turn_error := facing.normalized().signed_angle_to(_control_forward, Vector3.UP)
		state.angular_velocity.y = move_toward(state.angular_velocity.y, clampf(turn_error * steering_gain, -max_steering_speed, max_steering_speed), steering_acceleration() * state.step)
		# Pulling the handle can physically right an overturned cart; no reset.
		var up := state.transform.basis.y
		if up.dot(Vector3.UP) < 0.85:
			var axis := up.cross(Vector3.UP)
			if axis.length_squared() < 0.01:
				axis = state.transform.basis.z
			state.apply_torque(axis.normalized() * righting_torque)
	elif grounded:
		horizontal = horizontal.move_toward(Vector3.ZERO, rolling_resistance * SlipState.control(self) * cart_base_mass / effective_mass * state.step)
	state.linear_velocity.x = horizontal.x
	state.linear_velocity.z = horizontal.z
	_recent_velocities.append(state.linear_velocity)
	if _recent_velocities.size() > 3:
		_recent_velocities.pop_front()


func _on_body_entered(body: Node) -> void:
	if _impact_wait > 0.0 or body is GrabbableBody:
		return
	if _launch_remaining > 0.0 and _launch_hits.has(body.get_instance_id()):
		return
	var incoming := linear_velocity
	for sample in _recent_velocities:
		if sample.length_squared() > incoming.length_squared():
			incoming = sample
	var speed := Vector2(incoming.x, incoming.z).length()
	if speed < impact_min_speed:
		return
	if _crash_available and speed >= crash_flip_speed and (body is StaticBody3D or body.has_method("receive_impact")):
		# A severe collision transfers a capped pitch impulse above the low COM.
		# Ordinary pushing cannot trigger this; orientation is never assigned.
		_impact_wait = impact_cooldown
		_crash_available = false
		var axis := Vector3.UP.cross(Vector3(incoming.x, 0, incoming.z).normalized())
		apply_torque_impulse(axis * minf(max_crash_torque_impulse, (speed - crash_flip_speed) * cart_base_mass * crash_torque_multiplier))
	if body.has_method("receive_impact"):
		if _launch_remaining > 0.0:
			_launch_hits.append(body.get_instance_id())
		_impact_wait = impact_cooldown
		last_impact_speed = speed
		last_impact_mass = effective_mass
		last_impact_damage = damage_at_speed(speed)
		impact_count += 1
		var impulse := (incoming * effective_mass * impact_knockback_multiplier).limit_length(max_knockback_impulse)
		body.call_deferred("receive_impact", last_impact_damage, impulse)
		print("CART impact speed=%.2f mass=%.2f damage=%.2f impulse=%.2f" % [speed, effective_mass, last_impact_damage, impulse.length()])
		if speed >= spill_min_speed:
			call_deferred("_spill_on_impact", incoming, cargo.duplicate())


func _spill_on_impact(incoming: Vector3, impacted_cargo: Array) -> void:
	cargo_release_time = maxf(cargo_release_time, 1.0)
	# Stylized collision shock, applied as a bounded physical impulse. Cargo is
	# never repositioned or detached: it must clear the basket's real colliders.
	var horizontal := Vector3(incoming.x, 0, incoming.z)
	var change := horizontal * spill_forward_multiplier
	change.y = minf(max_spill_lift, horizontal.length() * spill_lift_multiplier)
	for body in impacted_cargo:
		if is_instance_valid(body) and not is_instance_valid(body.holder):
			body.apply_central_impulse(change * body.mass)


func _exit_tree() -> void:
	end_carry()
	for body in cargo:
		if is_instance_valid(body):
			body.get_node("Label").visible = body.show_debug_label or body.product_type == &""

func assist_cargo(body: GrabbableBody, physics: PhysicsDirectBodyState3D) -> bool:
	if not cargo_assist_enabled or cargo_release_time > 0 or _launch_remaining > 0: return false
	if is_instance_valid(body.holder) or body._armed_seconds > 0 or not cargo.has(body): return false
	if linear_velocity.length() > 6.5 or angular_velocity.length() > 2.5 or global_basis.y.dot(Vector3.UP) < 0.94: return false
	var local_point := to_local(physics.transform.origin)
	# Upper overload and objects riding the rim receive no glue/centering.
	if absf(local_point.x) > 0.72 or absf(local_point.z) > 0.82 or local_point.y > 1.12: return false
	var support_velocity := linear_velocity + angular_velocity.cross(physics.transform.origin - global_position)
	var relative := physics.linear_velocity - support_velocity
	if relative.length() > cargo_relative_speed or physics.angular_velocity.length() > 5: return false
	var damping := Vector3(relative.x, relative.y * 0.5, relative.z) * (1.0 - exp(-cargo_linear_damping * physics.step))
	physics.linear_velocity -= damping.limit_length(cargo_assist_acceleration * physics.step)
	physics.angular_velocity *= exp(-cargo_angular_damping * physics.step)
	# Thin footprints need persistent support, not just presence in LoadVolume.
	# Keep rim/vertical/overloaded objects free to tip and fall.
	if body.definition != null:
		var size := body.definition.size
		var axes := [size.x, size.y, size.z]
		axes.sort()
		var flat: bool = axes[0] <= axes[1] * 0.3
		var relative_basis := global_basis.inverse() * physics.transform.basis
		var extent := relative_basis.x.abs() * size.x + relative_basis.y.abs() * size.y + relative_basis.z.abs() * size.z
		var supported := false
		for i in range(physics.get_contact_count()):
			# Direct-body contact normals are already expressed in world axes in
			# this physics backend (including bodies resting on a rotated axis).
			var normal := physics.get_contact_local_normal(i)
			var collider := physics.get_contact_collider_object(i)
			if normal.dot(Vector3.UP) > 0.8 and (collider == self or cargo.has(collider)):
				supported = true
		var footprint_fits := absf(local_point.x) + extent.x / 2 < 0.76 and absf(local_point.z) + extent.z / 2 < 0.86
		var quiet := relative.length() < 0.25 and physics.angular_velocity.length() < 0.35
		var lying_flat: bool = extent.y < axes[0] + axes[1] * 0.12
		if flat and supported and quiet and footprint_fits and lying_flat:
			body.cargo_support_time += physics.step
		else:
			body.cargo_support_time = 0
		if body.cargo_support_time >= 0.35:
			var strength := clampf(1.0 - linear_velocity.length() / 3.0 - angular_velocity.length(), 0, 1)
			physics.angular_velocity *= exp(-18.0 * strength * physics.step)
			if absf(relative.y) < 0.08:
				physics.linear_velocity.y -= relative.y * (1.0 - exp(-12.0 * strength * physics.step))
	return true
