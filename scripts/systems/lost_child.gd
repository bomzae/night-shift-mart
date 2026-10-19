class_name LostChild
extends CarryableCharacter

var family_id: int
var family_manager: Node
var parent_npc: BasicCustomer
var reunited: bool = false
var family_symbol: Label3D
@export var walk_speed: float = 2.3
@export var follow_distance: float = 0.9
@export var lateral_offset: float = 0.35
@export var recovery_start_distance: float = 2.0
@export var recovery_speed: float = 4.5
@export var follow_acceleration: float = 16.0
@export var follow_correction: float = 3.0

func follow_position() -> Vector3:
	var direction: Vector3 = parent_npc.exit_direction
	return parent_npc.global_position - direction * follow_distance + direction.cross(Vector3.UP) * lateral_offset

func begin_carry(controller: Node, player: PhysicsBody3D) -> bool:
	return false if reunited else super.begin_carry(controller, player)

func on_player_drop() -> void:
	if is_instance_valid(family_manager):
		family_manager.try_reunion(self)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockdown.active() or fire_reaction.active(): return
	$Mood.text = "♥" if reunited else ":'( ?"
	$Mood.modulate = Color.PINK if reunited else Color.WHITE
	$Mesh.rotation.z = 0 if is_instance_valid(holder) else sin(Time.get_ticks_msec() * 0.002) * 0.035

func _free_motion(state: PhysicsDirectBodyState3D) -> void:
	if not grounded or supported_by_cart:
		return
	if not reunited or not is_instance_valid(parent_npc):
		var spacing := human_separation.correction(self, Vector3.ZERO, 0.25)
		var idle := Vector3(state.linear_velocity.x, 0, state.linear_velocity.z).move_toward(spacing, follow_acceleration * state.step)
		state.linear_velocity.x = idle.x
		state.linear_velocity.z = idle.z
		return
	var offset := follow_position() - state.transform.origin
	offset.y = 0
	var speed_limit := lerpf(walk_speed, recovery_speed, clampf((offset.length() - recovery_start_distance) / maxf(0.1, recovery_start_distance), 0, 1))
	var desired := offset.normalized() * minf(speed_limit, offset.length() * follow_correction)
	desired += human_separation.correction(self, desired, 0.25 * minf(1, offset.length()))
	desired = cart_recovery.steer(desired, state.step)
	var horizontal := Vector3(state.linear_velocity.x, 0, state.linear_velocity.z).move_toward(desired, follow_acceleration * SlipState.control(self) * state.step)
	state.linear_velocity.x = horizontal.x
	state.linear_velocity.z = horizontal.z
