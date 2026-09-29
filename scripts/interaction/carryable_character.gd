class_name CarryableCharacter
extends RigidBody3D
## Upright physical character, reusable carry/drop without item damage or throw.

@export var carry_radius: float = 0.82
@export var carry_follow_strength: float = 10.0
@export var carry_speed: float = 7.0
@export var carry_acceleration: float = 35.0
@export_range(0.5, 1.0) var carrier_speed_multiplier: float = 0.85
var holder: Node
var hold_target: Vector3
var _carrier: PhysicsBody3D
var _saved_gravity: float
var supported_by_cart: bool = false
var grounded: bool = false

func _ready() -> void:
	lock_rotation = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 16

func begin_carry(controller: Node, player: PhysicsBody3D) -> bool:
	if is_instance_valid(holder):
		return false
	_restore_collision()
	holder = controller
	_carrier = player
	_saved_gravity = gravity_scale
	gravity_scale = 0
	add_collision_exception_with(player)
	player.add_collision_exception_with(self)
	hold_target = global_position
	sleeping = false
	return true

func end_carry() -> void:
	if not is_instance_valid(holder):
		return
	holder = null
	gravity_scale = _saved_gravity
	linear_velocity = linear_velocity.limit_length(2.0)
	sleeping = false
	# Restore after separation, avoiding an overlapping capsule explosion.

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(holder) and is_instance_valid(_carrier):
		var offset := global_position - (_carrier.global_position + Vector3.UP * 0.9)
		if Vector2(offset.x, offset.z).length() > 0.8 or absf(offset.y) > 1.8:
			_restore_collision()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	grounded = false
	supported_by_cart = false
	for i in range(state.get_contact_count()):
		if state.get_contact_local_normal(i).y > 0.45:
			grounded = true
			if state.get_contact_collider_object(i) is ShoppingCart:
				supported_by_cart = true
	if is_instance_valid(holder):
		var target_velocity := ((hold_target - state.transform.origin) * carry_follow_strength).limit_length(carry_speed)
		state.linear_velocity = state.linear_velocity.move_toward(target_velocity, carry_acceleration * state.step)
	else:
		_free_motion(state)

func _free_motion(_state: PhysicsDirectBodyState3D) -> void:
	pass

func on_player_drop() -> void:
	pass

func _restore_collision() -> void:
	if is_instance_valid(_carrier):
		remove_collision_exception_with(_carrier)
		_carrier.remove_collision_exception_with(self)
	_carrier = null

func _exit_tree() -> void:
	_restore_collision()
