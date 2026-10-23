class_name DrunkCustomer
extends CarryableCharacter

signal product_broken(value: float)
@export var wander_speed: float = 1.8
@export var wander_acceleration: float = 14.0
@export var direction_interval: float = 2.0
@export var product_push_impulse: float = 2.5
@export var contact_cooldown: float = 1.0
@export var break_min_speed: float = 2.7
@export var wet_wobble_multiplier: float = 1.8
var wander_direction := Vector3.FORWARD
var direction_changes: int = 0
var _direction_wait: float = 0
var _contact_wait: float = 0
var _phase: float = 0
var _incoming_speed: float = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	knockdown.minimum_fall_speed = 1.2
	can_sleep = false
	_rng.randomize()
	body_entered.connect(_contact)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockdown.active() or fire_reaction.active(): return
	_contact_wait = maxf(0, _contact_wait - delta)
	if is_instance_valid(holder) or supported_by_cart:
		$Mood.text = "@_@"
		return
	_phase += delta
	$Mesh.rotation.z = sin(_phase * 3.5) * 0.12
	$Mood.text = "~_~"
	_direction_wait -= delta
	if _direction_wait <= 0:
		_direction_wait = maxf(0.2, direction_interval)
		var destination := Vector3(_rng.randf_range(-7, 7), global_position.y, _rng.randf_range(2, 10))
		wander_direction = (destination - global_position).normalized()
		direction_changes += 1
	_incoming_speed = Vector2(linear_velocity.x, linear_velocity.z).length()

func _free_motion(state: PhysicsDirectBodyState3D) -> void:
	# No seat or velocity attachment: a cart-supported character is passive cargo.
	if not grounded or supported_by_cart:
		return
	var wobble := 0.45 * (wet_wobble_multiplier if SlipState.wet(self) else 1.0)
	var desired := wander_direction.rotated(Vector3.UP, sin(_phase * 2.1) * wobble) * wander_speed
	desired += human_separation.correction(self, desired, separation_multiplier)
	desired = cart_recovery.steer(desired, state.step, 0.6)
	desired = product_recovery.steer(desired, state.step, 0.6)
	var horizontal := Vector3(state.linear_velocity.x, 0, state.linear_velocity.z)
	horizontal = horizontal.move_toward(desired, wander_acceleration * SlipState.control(self) * state.step)
	state.linear_velocity.x = horizontal.x
	state.linear_velocity.z = horizontal.z

func _contact(body: Node) -> void:
	if knockdown.active() or is_instance_valid(holder) or supported_by_cart or _contact_wait > 0:
		return
	if body is GrabbableBody:
		_contact_wait = contact_cooldown
		_disturb_product(body)
	elif body.get_parent() is StockShelf:
		_contact_wait = contact_cooldown
		# Jolt only nearby real goods; Shelf remains the sole stock authority.
		for product in body.get_parent().zone.get_overlapping_bodies():
			if product is GrabbableBody and product.global_position.distance_to(global_position) < 2.0:
				_disturb_product(product)

func _disturb_product(product: GrabbableBody) -> void:
	if is_instance_valid(product.holder) or product.is_queued_for_deletion() or product.get_meta("broken", false) or product.get_meta("sold", false):
		return
	var direction := product.global_position - global_position
	direction.y = 0.15
	product.apply_central_impulse(direction.normalized() * product_push_impulse)
	if _incoming_speed >= break_min_speed:
		product.set_meta("broken", true)
		product_broken.emit(product.price)
		product.queue_free()
