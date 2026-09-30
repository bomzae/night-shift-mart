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
var knockdown := KnockdownState.new()

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	knockdown.setup(self, head, true)
	knockdown.started.connect(func(): $Interaction.drop_held())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse_capture"):
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
	if is_on_floor():
		movement_acceleration *= SlipState.control(self)
	velocity.x = move_toward(velocity.x, direction.x * move_speed * speed_multiplier, movement_acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed * speed_multiplier, movement_acceleration * delta)
	if cart != null:
		cart.update_control(self, $Head/Camera3D)
		var controlled := cart.constrain_player_velocity(self, Vector3(velocity.x, 0, velocity.z), delta)
		velocity.x = controlled.x
		velocity.z = controlled.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif controls_active and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var incoming_velocity := velocity
	move_and_slide()
	# Sliding can zero the actual velocity at a heavy body. Continue applying
	# bounded effort while walking into it instead of losing the push next tick.
	var push_velocity := direction * move_speed
	if incoming_velocity.length_squared() > push_velocity.length_squared():
		push_velocity = incoming_velocity
	_push_physics_bodies(push_velocity, delta)


func _push_physics_bodies(incoming: Vector3, delta: float) -> void:
	var pushed: Array[RID] = []
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as RigidBody3D
		if body == null or pushed.has(body.get_rid()) or absf(contact.get_normal().y) > 0.5:
			continue # Never kick the floor of the cart we are riding.
		if (body is GrabbableBody or body is ShoppingCart or body is CarryableCharacter) and body.holder == get_node_or_null("Interaction"):
			continue
		pushed.append(body.get_rid())
		var direction := -contact.get_normal()
		direction.y = 0
		direction = direction.normalized()
		var closing_speed := (incoming - body.linear_velocity).dot(direction)
		if closing_speed < minimum_push_speed:
			continue
		var body_weight: float = body.effective_mass if body is ShoppingCart else body.mass
		var impulse := minf(max_player_push_impulse, closing_speed * player_push_strength * delta / (1.0 + push_weight_penalty * maxf(0, body_weight - 1)))
		body.apply_central_impulse(direction * impulse)

