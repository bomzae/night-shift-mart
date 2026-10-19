class_name KnockdownState
extends Node
## Character-only interruption. Owners tick this before their normal movement/AI.
signal started
enum Phase { UPRIGHT, FALLING, DOWN, STANDING_UP, IMMUNE }
@export var minimum_fall_speed: float = 1.5
@export var fall_down_time: float = 0.2
@export var knockdown_duration: float = 0.8
@export var stand_up_time: float = 0.4
@export var slip_immunity_time: float = 1.3
@export var slip_speed_boost: float = 1.2
@export var max_slip_speed: float = 6.5
@export var down_braking: float = 5.0
@export var fall_camera_drop: float = 1.1
@export var fall_camera_pitch_degrees: float = 75.0
@export var fall_camera_roll_degrees: float = 0.0
@export var fall_camera_floor_margin: float = 0.18
@export var npc_tilt_degrees: float = 80.0
var persistent_down: bool = false
var phase: Phase = Phase.UPRIGHT
var elapsed: float = 0.0
var fall_count: int = 0
var visual: Node3D
var player_view: bool = false
var _rest_position: Vector3
var _rest_rotation: Vector3
var _camera: Camera3D
var _camera_rest_rotation: Vector3

static func blocked(body: Node) -> bool:
	var state := body.get_node_or_null("Knockdown") as KnockdownState
	return state != null and state.active()

func setup(body: Node3D, target: Node3D, is_player: bool = false) -> void:
	name = "Knockdown"
	body.add_child(self)
	visual = target
	player_view = is_player
	_rest_position = target.position
	_rest_rotation = target.rotation
	if player_view:
		_camera = target.get_node("Camera3D")
		_camera_rest_rotation = _camera.rotation

func active() -> bool:
	return phase == Phase.FALLING or phase == Phase.DOWN or phase == Phase.STANDING_UP

func tick(delta: float) -> bool:
	if phase != Phase.UPRIGHT:
		elapsed += delta
		var duration := slip_immunity_time
		if phase == Phase.FALLING: duration = fall_down_time
		elif phase == Phase.DOWN: duration = knockdown_duration
		elif phase == Phase.STANDING_UP: duration = stand_up_time
		if elapsed >= maxf(0.01, duration) and not (persistent_down and phase == Phase.DOWN):
			elapsed = 0
			if phase == Phase.STANDING_UP:
				finish_recovery()
			elif phase == Phase.IMMUNE: phase = Phase.UPRIGHT
			else: phase = (phase + 1) as Phase
	if phase == Phase.UPRIGHT:
		_check_spill()
	if active(): _pose()
	return active()

func _check_spill() -> void:
	var body := get_parent() as Node3D
	if body is CarryableCharacter:
		if is_instance_valid(body.holder) or not body.grounded or body.supported_by_cart: return
	elif body is CharacterBody3D:
		if not body.is_on_floor(): return
	else: return
	var motion: Vector3 = body.linear_velocity if body is RigidBody3D else body.velocity
	motion.y = 0
	if motion.length() < minimum_fall_speed: return
	var slip := body.get_node_or_null("SlipState") as SlipState
	if slip == null: return
	for entry in slip.sources.values():
		var zone = entry.get_ref()
		if is_instance_valid(zone) and zone.contains_core(body.global_position):
			try_start(motion)
			return

func try_start(direction: Vector3) -> bool:
	if phase != Phase.UPRIGHT: return false
	var body := get_parent()
	if body is CarryableCharacter and is_instance_valid(body.holder): return false
	phase = Phase.FALLING
	elapsed = 0
	fall_count += 1
	started.emit() # Drop ownership/charge before adding slip velocity.
	var motion: Vector3 = body.linear_velocity if body is RigidBody3D else body.velocity
	var horizontal := Vector3(motion.x, 0, motion.z)
	direction.y = 0
	horizontal = (horizontal + direction.normalized() * slip_speed_boost).limit_length(max_slip_speed)
	motion.x = horizontal.x
	motion.z = horizontal.z
	if body is RigidBody3D:
		body.linear_velocity = motion
		body.sleeping = false
	else: body.velocity = motion
	return true

func damp_motion(motion: Vector3, delta: float) -> Vector3:
	var horizontal := Vector3(motion.x, 0, motion.z).move_toward(Vector3.ZERO, down_braking * delta)
	return Vector3(horizontal.x, motion.y, horizontal.z)

func _pose() -> void:
	var amount := 1.0
	if phase == Phase.FALLING: amount = clampf(elapsed / maxf(0.01, fall_down_time), 0, 1)
	elif phase == Phase.STANDING_UP: amount = 1.0 - clampf(elapsed / maxf(0.01, stand_up_time), 0, 1)
	if player_view:
		_player_pose(smoothstep(0.0, 1.0, amount))
		return
	var lowering := 0.45 * amount
	if not player_view:
		lowering = 0.45 * amount
		if visual is MeshInstance3D and visual.mesh is CapsuleMesh:
			# Keep the tilted capsule's visual bottom above the floor throughout
			# the fall, not only at the final almost-horizontal pose.
			lowering = maxf(0, visual.mesh.height * 0.5 - visual.mesh.radius) * (1.0 - cos(deg_to_rad(npc_tilt_degrees) * amount))
	visual.position.y = _rest_position.y - lowering
	visual.rotation.z = _rest_rotation.z + deg_to_rad(npc_tilt_degrees) * amount
	# Do not overwrite the player's live mouse pitch/yaw.
	if not player_view: visual.rotation.x = _rest_rotation.x

func _player_pose(amount: float) -> void:
	# Translate Head vertically in the upright body's frame; mouse pitch stays
	# on Head, while Camera receives the backward visual pitch and small roll.
	var body := get_parent() as CharacterBody3D
	var rest_world := body.to_global(_rest_position)
	var margin := maxf(0.1, fall_camera_floor_margin)
	var lowering := minf(maxf(0, fall_camera_drop) * amount, maxf(0, _rest_position.y - margin))
	var query := PhysicsRayQueryParameters3D.create(rest_world, rest_world - Vector3.UP * (_rest_position.y + margin))
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		lowering = minf(lowering, maxf(0, rest_world.y - hit.position.y - margin))
	visual.position.y = _rest_position.y - lowering
	_camera.rotation = _camera_rest_rotation + Vector3(deg_to_rad(fall_camera_pitch_degrees), 0, deg_to_rad(fall_camera_roll_degrees)) * amount

func hold_downed() -> void:
	persistent_down = true
	if not active():
		phase = Phase.FALLING
		elapsed = 0
	elif phase == Phase.STANDING_UP:
		phase = Phase.DOWN
		elapsed = 0
	started.emit()

func release_downed() -> void:
	persistent_down = false
	phase = Phase.STANDING_UP
	elapsed = 0

func finish_recovery() -> void:
	phase = Phase.IMMUNE
	elapsed = 0
	visual.position.y = _rest_position.y
	visual.rotation.z = _rest_rotation.z
	if player_view: _camera.rotation = _camera_rest_rotation
	if not player_view: visual.rotation.x = _rest_rotation.x
