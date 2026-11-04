extends CharacterBody3D
## Local movement and bounded body pushing; selection/charge stay in Interaction.

@export var move_speed: float = 5.0
@export var acceleration: float = 24.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var player_push_strength: float = 36.0
@export var max_player_push_impulse: float = 3.0
@export var push_weight_penalty: float = 0.12
@export var minimum_push_speed: float = 0.2

@onready var head: Node3D = $Head
var external_velocity := Vector3.ZERO
var body_bump_velocity := Vector3.ZERO
var body_bump_left: float = 0
const BODY_BUMP_DURATION: float = 0.24
var health := PlayerHealth.new()
var knockdown := KnockdownState.new()
var fire_reaction := FireReaction.new()

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	collision_mask |= HumanSeparation.HUMAN_LAYER | HumanSeparation.MONSTER_LAYER
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	knockdown.setup(self, head, true)
	fire_reaction.setup(self, true)
	knockdown.started.connect(func(): $Interaction.drop_held())
	add_child(health)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_damage_player") and not event.is_echo():
		health.receive_damage(30)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	body_bump_left = maxf(0, body_bump_left - delta)
	external_velocity *= exp(-5.0 * delta)
	fire_reaction.tick(delta)
	if knockdown.tick(delta):
		velocity = knockdown.damp_motion(velocity, delta)
		velocity.y = 0 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		return
	var input_direction := Vector2.ZERO
	var controls_active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if controls_active:
		input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)
	var interaction := get_node_or_null("Interaction")
	var cart: ShoppingCart = null
	if interaction != null and is_instance_valid(interaction.held_object) and interaction.held_object is ShoppingCart:
		cart = interaction.held_object
	var speed_multiplier: float = interaction.held_object.carrier_speed_multiplier if interaction != null and is_instance_valid(interaction.held_object) and interaction.held_object is CarryableCharacter else 1.0
	var movement_acceleration := acceleration if cart == null else cart.push_acceleration()
	speed_multiplier *= body_control_multiplier()
	movement_acceleration *= body_control_multiplier()
	if is_on_floor():
		movement_acceleration *= SlipState.control(self)
	velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_multiplier, movement_acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_multiplier, movement_acceleration * delta)
	if fire_reaction.active():
		# Keep input/look available; bounded outward nudge lasts only 0.3 seconds.
		velocity += fire_reaction.direction * 30.0 * delta
	if cart != null:
		cart.update_control(self, $Head/Camera3D)
		var controlled := cart.constrain_player_velocity(self, Vector3(velocity.x, 0, velocity.z), delta)
		velocity.x = controlled.x
		velocity.z = controlled.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif controls_active and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	velocity += external_velocity
	if body_bump_left > 0:
		var bump_direction := body_bump_velocity.normalized()
		var impact_speed := body_bump_velocity.length() * (0.3 + 0.7 * body_bump_left / BODY_BUMP_DURATION)
		velocity += bump_direction * maxf(0, impact_speed - velocity.dot(bump_direction))
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster is KingRat:
			velocity = monster.constrain_player_body(self, velocity, delta)
	var incoming_velocity := velocity
	move_and_slide()
	# Sliding can zero the actual velocity at a heavy body. Continue applying
	# bounded effort while walking into it instead of losing the push next tick.
	var push_velocity := direction * move_speed
	if incoming_velocity.length_squared() > push_velocity.length_squared():
		push_velocity = incoming_velocity
	_push_physics_bodies(push_velocity, delta)
	velocity -= external_velocity


func _push_physics_bodies(incoming: Vector3, delta: float) -> void:
	var pushed: Array[RID] = []
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as PhysicsBody3D
		if body == null or pushed.has(body.get_rid()) or absf(contact.get_normal().y) > 0.5:
			continue # Never kick the floor of the cart we are riding.
		if (body is GrabbableBody or body is ShoppingCart or body is CarryableCharacter) and body.holder == get_node_or_null("Interaction"):
			continue
		pushed.append(body.get_rid())
		var direction := -contact.get_normal()
		direction.y = 0
		direction = direction.normalized()
		if body is CharacterBody3D:
			if body is KingRat: continue # Body contact is player-side separation, never combat force.
			if body.has_method("apply_external_impulse"):
				body.apply_external_impulse(direction * minf(max_player_push_impulse, maxf(0, incoming.dot(direction)) * player_push_strength * delta))
			continue
		if not body is RigidBody3D: continue
		var closing_speed: float = (incoming - body.linear_velocity).dot(direction)
		if closing_speed < minimum_push_speed:
			continue
		var body_weight: float = body.effective_mass if body is ShoppingCart else body.mass
		var impulse := minf(max_player_push_impulse, closing_speed * player_push_strength * delta / (1.0 + push_weight_penalty * maxf(0, body_weight - 1)))
		body.apply_central_impulse(direction * impulse)


func apply_external_impulse(impulse: Vector3) -> void:
	if impulse.is_finite(): external_velocity = (external_velocity + impulse).limit_length(2.0)

func receive_body_bump(impulse: Vector3) -> void:
	if not impulse.is_finite() or health.is_downed or knockdown.active(): return
	body_bump_velocity = Vector3(impulse.x, 0, impulse.z).limit_length(3.2)
	body_bump_left = BODY_BUMP_DURATION
	var away := body_bump_velocity.normalized()
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = (horizontal - away * horizontal.dot(away)) * 0.35 + body_bump_velocity
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	$Interaction.camera_impact = maxf($Interaction.camera_impact, 0.045)

func body_control_multiplier() -> float:
	# 0.16 seconds of reduced control, then a quick 0.08 second recovery.
	return lerpf(1.0, 0.35, clampf(body_bump_left / 0.08, 0, 1))
