extends Node
## Input/selection and tuning; the object owns physical carry and impact behavior.

@export_range(0.5, 5.0) var grab_distance: float = 2.8
@export_range(0.8, 3.0) var hold_distance: float = 1.7
@export var hold_strength: float = 12.0
@export var max_carry_speed: float = 8.0
@export var max_carry_acceleration: float = 45.0
@export var break_distance: float = 4.0
@export var hard_break_distance: float = 6.0
@export var break_grace_time: float = 0.5
@export var stalled_release_time: float = 3.0
@export var hold_obstruction_margin: float = 0.03
@export var hold_target_speed: float = 12.0
@export var hold_distance_return_speed: float = 6.0
@export var base_throw_force: float = 18.0
@export var weight_throw_penalty: float = 0.25
@export var base_damage: float = 2.0
@export var price_damage_multiplier: float = 0.04
@export var impact_min_speed: float = 2.0
@export var knockback_multiplier: float = 0.15
@export var max_knockback_impulse: float = 18.0
@export_range(0.05, 5.0) var max_charge_time: float = 1.2
@export_range(0.0, 3.0) var min_throw_multiplier: float = 0.35
@export_range(0.0, 3.0) var max_throw_multiplier: float = 1.5
@export_range(0.0, 3.0) var min_charge_damage_multiplier: float = 0.5
@export_range(0.0, 3.0) var max_charge_damage_multiplier: float = 1.5

@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = player.get_node("Head/Camera3D")
@onready var crosshair: Label = $Feedback/Crosshair
@onready var charge_bar: ProgressBar = $Feedback/ChargeBar
var camera_impact: float = 0
var _camera_rest_position: Vector3
var weapon_info: Label
var weapon_notice: float = 0
var weapon_notice_text: String = ""
var _drop_requested: bool = false
var _interact_requested: bool = false
var product_info: Label
var held_object: RigidBody3D
var is_charging: bool = false
var charge_ratio: float = 0.0
var _charge_object: RigidBody3D
var _grab_requested: bool = false
var _consume_requested: bool = false
var _release_requested: bool = false
var _probe := SphereShape3D.new()
var desired_hold_position: Vector3
var safe_hold_position: Vector3
var hold_obstructed: bool = false
var break_timer: float = 0.0
var _stalled_timer: float = 0.0
var _tracked_hold: RigidBody3D
var _hold_goal: Vector3
var _active_hold_distance: float = 0.0
var _last_hold_position: Vector3


func _ready() -> void:
	_camera_rest_position = camera.position
	product_info = Label.new()
	product_info.name = "ProductInfo"
	$Feedback.add_child(product_info)
	product_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	product_info.offset_left = -130
	product_info.offset_top = 30
	product_info.offset_right = 130
	product_info.offset_bottom = 130
	product_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	product_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product_info.add_theme_font_size_override("font_size", 18)
	product_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	product_info.add_theme_constant_override("shadow_offset_x", 1)
	product_info.add_theme_constant_override("shadow_offset_y", 1)
	product_info.hide()
	weapon_info = Label.new()
	weapon_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Feedback.add_child(weapon_info)
	weapon_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_info.offset_left = -340
	weapon_info.offset_top = -100
	weapon_info.offset_right = -24
	weapon_info.offset_bottom = -30
	weapon_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	weapon_info.add_theme_constant_override("shadow_offset_x", 1)
	weapon_info.add_theme_constant_override("shadow_offset_y", 1)
	weapon_info.hide()

func update_product_info(candidate: PhysicsBody3D, active: bool) -> void:
	product_info.hide()
	if not active or not candidate is GrabbableBody or candidate.product_type == &"": return
	product_info.text = "%s\n$%.0f  |  %.1f kg" % [candidate.display_name, candidate.price, candidate.weight]
	var data := ProductCatalog.find(candidate.product_type)
	if data != null and data.is_food:
		product_info.text += "\n+%.0f HP" % data.heal_value
	product_info.show()


func _unhandled_input(event: InputEvent) -> void:
	if KnockdownState.blocked(player):
		cancel_charge()
		return
	if event.is_action_pressed("toggle_mouse_capture"):
		cancel_charge()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		cancel_charge()
		return
	if event.is_action_pressed("drop_item"):
		_drop_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_interact_requested = true
	elif event.is_action_pressed("consume_item") and not event.is_echo():
		_consume_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("grab"):
		_grab_requested = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("throw"):
		if not is_charging and is_instance_valid(held_object) and not held_object is CarryableCharacter and held_object.holder == self and not (held_object is WeaponBody and held_object.swinging()):
			is_charging = true
			charge_ratio = 0.0
			_charge_object = held_object
		get_viewport().set_input_as_handled()
	elif event.is_action_released("throw"):
		_release_requested = is_charging
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	camera_impact = move_toward(camera_impact, 0, delta * 0.25)
	camera.position = _camera_rest_position + Vector3(0, 0, camera_impact)
	var active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not KnockdownState.blocked(player)
	if not active:
		cancel_charge()
	if active and _drop_requested: drop_held(true)
	_drop_requested = false
	if active and _interact_requested:
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * grab_distance)
		ray.exclude = [player.get_rid()]
		if is_instance_valid(held_object): ray.exclude = [player.get_rid(), held_object.get_rid()]
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is WeaponCrate: hit.collider.open_crate()
	_interact_requested = false
	if active and _grab_requested:
		if held_object is WeaponBody:
			if not is_charging: held_object.start_swing()
		else: toggle_grab()
	_grab_requested = false
	if active and _consume_requested:
		consume_held_food()
	_consume_requested = false
	# Validate ownership and safety BEFORE a queued throw.
	if is_instance_valid(held_object):
		if held_object.holder != self:
			held_object = null
			cancel_charge()
		elif held_object is ShoppingCart and camera.global_position.distance_to(held_object.global_position) > held_object.emergency_break_distance:
			drop_held()
		else:
			_update_hold_target(delta)
			if not held_object is ShoppingCart:
				_update_hold_safety(delta)
	else:
		held_object = null
	if not is_instance_valid(held_object):
		_reset_hold_tracking()
	if not is_instance_valid(held_object) or held_object != _charge_object:
		cancel_charge()
	if is_charging:
		if _release_requested:
			throw_held(charge_ratio)
		else:
			charge_ratio = clampf(charge_ratio + delta / maxf(0.05, max_charge_time), 0.0, 1.0)
	_release_requested = false
	charge_bar.visible = active and is_charging
	charge_bar.value = charge_ratio
	crosshair.visible = active
	var candidate := find_candidate() if active and not is_instance_valid(held_object) else null
	crosshair.modulate = Color.ORANGE if is_instance_valid(held_object) else (Color.LIME_GREEN if candidate != null else Color.WHITE)
	update_product_info(candidate, active)
	weapon_notice = maxf(0, weapon_notice - delta)
	weapon_info.visible = active and (held_object is WeaponBody or weapon_notice > 0)
	if active and held_object is WeaponBody:
		weapon_info.text = "%s  %d / %d\nLMB SWING | Q DROP | RMB THROW" % [held_object.display_name, held_object.durability, held_object.weapon.durability_max]
		weapon_info.modulate = Color.GOLD if held_object.hit_feedback > 0 else (Color.SALMON if held_object.durability <= held_object.weapon.durability_max * 0.25 else Color.WHITE)
	elif weapon_notice > 0:
		weapon_info.text = weapon_notice_text
		weapon_info.modulate = Color.ORANGE


func find_candidate() -> PhysicsBody3D:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * grab_distance)
	query.collision_mask = 3 | HumanSeparation.HUMAN_LAYER | HumanSeparation.MONSTER_LAYER # Bodies + handles + humans, not hazard sensors.
	query.exclude = [player.get_rid()]
	query.collide_with_areas = true
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is ThiefCustomer and hit.collider.capturable() and player.global_position.distance_to(hit.collider.global_position) <= hit.collider.capture_distance:
		return hit.collider
	if not hit.is_empty() and hit.collider is CarryableCharacter and not is_instance_valid(hit.collider.holder):
		return hit.collider
	if not hit.is_empty() and hit.collider is GrabbableBody and not is_instance_valid(hit.collider.holder):
		return hit.collider as GrabbableBody
	if not hit.is_empty() and hit.collider is Area3D and hit.collider.is_in_group("cart_handle"):
		var cart := hit.collider.get_parent() as ShoppingCart
		if cart != null and not is_instance_valid(cart.holder):
			return cart
	return null


func toggle_grab() -> void:
	if is_instance_valid(held_object):
		drop_held(true)
		return
	var candidate := find_candidate()
	if candidate is ThiefCustomer:
		candidate.capture(player)
		return
	if candidate == null or not candidate.begin_carry(self, player):
		return
	held_object = candidate
	if held_object is GrabbableBody:
		held_object.follow_strength = hold_strength
		held_object.max_carry_speed = max_carry_speed
		held_object.max_carry_acceleration = max_carry_acceleration
	_update_hold_target()


func drop_held(player_drop: bool = false) -> void:
	cancel_charge()
	var released := held_object
	held_object = null
	_reset_hold_tracking()
	if is_instance_valid(released):
		released.end_carry()
		if player_drop and released is CarryableCharacter:
			released.on_player_drop()


func throw_speed(weight: float, charge: float = 0.0) -> float:
	return maxf(0.0, base_throw_force) * throw_multiplier(charge) / (1.0 + maxf(0.0, weight_throw_penalty) * maxf(0.0, weight - 1.0))


func throw_multiplier(charge: float) -> float:
	var minimum := maxf(0.0, min_throw_multiplier)
	return lerpf(minimum, maxf(minimum, max_throw_multiplier), clampf(charge, 0.0, 1.0))


func damage_for(price: float, charge: float = 0.0) -> float:
	var price_damage := maxf(0.0, base_damage) + maxf(0.0, price) * maxf(0.0, price_damage_multiplier)
	var multiplier := lerpf(maxf(0.0, min_charge_damage_multiplier), maxf(min_charge_damage_multiplier, max_charge_damage_multiplier), clampf(charge, 0.0, 1.0))
	return price_damage * multiplier


func throw_held(charge: float) -> void:
	if not is_instance_valid(held_object) or held_object is CarryableCharacter or held_object.holder != self:
		cancel_charge()
		return
	var object := held_object
	held_object = null
	cancel_charge()
	if object is ShoppingCart:
		object.launch_cart(-camera.global_basis.z, throw_multiplier(charge), charge, self)
		return
	object.impact_min_speed = impact_min_speed
	# Charge scales the feedback impulse as well as launch speed; keep the cap.
	object.knockback_multiplier = knockback_multiplier * throw_multiplier(charge)
	object.max_knockback_impulse = max_knockback_impulse
	object.launch(-camera.global_basis.z, throw_speed(object.weight, charge), damage_for(object.price, charge))


func cancel_charge() -> void:
	is_charging = false
	charge_ratio = 0.0
	_charge_object = null
	_release_requested = false
	if is_instance_valid(charge_bar):
		charge_bar.value = 0.0
		charge_bar.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_charge()


func _reset_hold_tracking() -> void:
	_tracked_hold = null
	break_timer = 0.0
	_stalled_timer = 0.0
	hold_obstructed = false


func _update_hold_safety(delta: float) -> void:
	var distance := camera.global_position.distance_to(held_object.global_position)
	var actual_speed := held_object.global_position.distance_to(_last_hold_position) / maxf(delta, 0.001)
	_last_hold_position = held_object.global_position
	if distance > maxf(break_distance, hard_break_distance):
		break_timer += delta
		# Never launch a remotely separated body while its safety grace is running.
		cancel_charge()
	elif distance < break_distance:
		break_timer = 0.0
	var stuck: bool = distance > break_distance or (hold_obstructed and distance > hold_distance + held_object.carry_radius and held_object.global_position.distance_to(desired_hold_position) > 1.0)
	# Measure actual progress: contact/frozen bodies can retain a requested velocity.
	_stalled_timer = _stalled_timer + delta if stuck and actual_speed < 0.25 else 0.0
	if break_timer >= maxf(0.05, break_grace_time) or _stalled_timer >= maxf(break_grace_time, stalled_release_time):
		drop_held()


func _update_hold_target(delta: float = 1.0 / 60.0) -> void:
	if held_object is ShoppingCart:
		held_object.update_control(player, camera)
		return
	if _tracked_hold != held_object:
		_reset_hold_tracking()
		_tracked_hold = held_object
		_hold_goal = held_object.global_position
		_last_hold_position = held_object.global_position
		_active_hold_distance = hold_distance
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	if held_object is WeaponBody: origin += camera.global_basis * held_object.hold_offset()
	desired_hold_position = origin + forward * hold_distance
	hold_obstructed = false
	# Prefer a conservative camera sweep, but overlap at its origin is NOT a drop.
	_probe.radius = held_object.carry_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.margin = hold_obstruction_margin
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.exclude = [player.get_rid(), held_object.get_rid()]
	var space := camera.get_world_3d().direct_space_state
	var available := hold_distance
	if not space.intersect_shape(query, 1).is_empty():
		hold_obstructed = true
		# A large sphere may overlap a shelf even while the actual held shape fits.
		# Bound the forward center ray, then sweep the real body below.
		var ray := PhysicsRayQueryParameters3D.create(origin, desired_hold_position)
		ray.exclude = query.exclude
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			available = maxf(0, origin.distance_to(hit.position) - held_object.carry_radius - hold_obstruction_margin)
	else:
		query.motion = forward * hold_distance
		var sweep := space.cast_motion(query)
		available = maxf(0, hold_distance * sweep[0] - hold_obstruction_margin)
		hold_obstructed = sweep[0] < 1.0
	_active_hold_distance = minf(available, move_toward(_active_hold_distance, available, hold_distance_return_speed * delta))
	var candidate := _hold_goal.move_toward(origin + forward * _active_hold_distance, hold_target_speed * delta)
	# Also test the path from the body's CURRENT position: a turn can sweep across
	# a shelf corner even when the camera-to-target ray itself is unobstructed.
	query.motion = candidate - held_object.global_position
	var safe_fraction := 1.0
	for shape in held_object.get_children():
		if shape is CollisionShape3D and not shape.disabled:
			query.shape = shape.shape
			query.transform = shape.global_transform
			safe_fraction = minf(safe_fraction, space.cast_motion(query)[0])
	if safe_fraction < 1.0:
		hold_obstructed = true
		candidate = held_object.global_position + query.motion * safe_fraction
	_hold_goal = candidate
	safe_hold_position = candidate
	held_object.hold_target = candidate


func _exit_tree() -> void:
	drop_held()



func consume_held_food() -> bool:
	if not held_object is GrabbableBody or KnockdownState.blocked(player): return false
	var health := player.get_node_or_null("PlayerHealth") as PlayerHealth
	if health == null: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * (health.feed_distance + 0.5), 1 | 64 | 128, [player.get_rid(), held_object.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var target: PlayerHealth
	if not hit.is_empty(): target = hit.collider.get_node_or_null("PlayerHealth") as PlayerHealth
	# Only a valid downed teammate takes priority. An alive, distant or
	# obstructed target must not prevent eating the food in our own hand.
	if target != null and target != health and target.is_downed:
		if health.use_food(held_object, target): return true
	return health.use_food(held_object)
