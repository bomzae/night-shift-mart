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
var wander_route: Array[Vector3] = []
var wander_target := Vector3.ZERO
var visited_racks: Array[StringName] = []
var progress_watchdog := NPCProgressWatchdog.new()
var _planner: RatAisleRoute
var _wobble_bias: float = 0
var _wobble_frequency: float = 2.1

func _ready() -> void:
	super._ready()
	knockdown.minimum_fall_speed = 1.2
	can_sleep = false
	_rng.randomize()
	body_entered.connect(_contact)
	progress_watchdog.check_window = 5.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if knockdown.active() or fire_reaction.active():
		progress_watchdog.observe(global_position, wander_target, "wander", false, delta)
		return
	_contact_wait = maxf(0, _contact_wait - delta)
	if is_instance_valid(holder) or supported_by_cart:
		$Mood.text = "@_@"
		reset_wander_route()
		return
	_phase += delta
	$Mesh.rotation.z = sin(_phase * 3.5) * 0.12
	$Mood.text = "~_~"
	_direction_wait -= delta
	if _direction_wait <= 0:
		_direction_wait = maxf(0.2, direction_interval)
		_wobble_bias = _rng.randf_range(-0.12, 0.12)
		_wobble_frequency = _rng.randf_range(1.8, 2.4)
		if wander_route.is_empty(): _choose_aisle()
		direction_changes += 1
	if not wander_route.is_empty():
		var offset := wander_route[0] - global_position
		offset.y = 0
		if offset.length() < 0.35:
			wander_route.pop_front()
		else: wander_direction = offset.normalized()
		var level := progress_watchdog.observe(global_position, wander_target, str(wander_target), grounded and wander_speed > 0.1 and external_push_time <= 0, delta)
		if level > 0:
			if level < 3:
				wander_route = _planner.build(global_position, wander_target)
				if wander_route.is_empty(): _direction_wait = 0
			else:
				reset_wander_route()
				_choose_aisle()
			print("DRUNK RECOVERY level=",level," pos=",global_position," target=",wander_target)
	_incoming_speed = Vector2(linear_velocity.x, linear_velocity.z).length()

func reset_wander_route() -> void:
	wander_route.clear()
	progress_watchdog.observe(global_position, wander_target, "", false, 0)

static func store_zone(at: Vector3) -> String:
	if absf(at.x)<10: return "MAIN"
	return ("WEST" if at.x<0 else "EAST") + ("_REAR" if at.z<21 else "_FRONT")

func _choose_aisle() -> void:
	var world := get_parent().get_parent()
	var shelves := world.get_node_or_null("Shelves")
	if shelves == null: return
	if _planner == null:
		_planner = RatAisleRoute.new(self) # Reuse the existing store intersections and swept world/cart checks.
		_planner.shape.radius = 0.30 # Inside the real 0.32 capsule: a resting contact must permit departure.
	_planner.refresh_exclusions()
	var repeated_zone := ""
	if visited_racks.size()>=2:
		var last: Node3D = shelves.get_node(NodePath(visited_racks[-1]))
		var prior: Node3D = shelves.get_node(NodePath(visited_racks[-2]))
		if store_zone(last.global_position)==store_zone(prior.global_position): repeated_zone=store_zone(last.global_position)
	var choices: Array[Dictionary] = []
	for shelf: StockShelf in shelves.get_children():
		if is_instance_valid(shelf.point_owner) or visited_racks.has(shelf.name): continue
		# Front aisle, never rack contents: stocking/food/value do not influence selection.
		var a := shelf.to_global(Vector3(-1.85,0.01,1.1))
		var b := shelf.to_global(Vector3(1.85,0.01,1.1))
		if not _planner.clear_segment(a,b): continue
		if global_position.distance_squared_to(b)<global_position.distance_squared_to(a):
			var swap := a
			a = b
			b = swap
		var repeat_cost := 24.0 if store_zone(shelf.global_position)==repeated_zone else 0.0
		choices.append({"name":shelf.name,"a":a,"b":b,"score":global_position.distance_to(a)+repeat_cost+_rng.randf_range(0,4)})
	choices.sort_custom(func(a,b): return a.score<b.score)
	for choice in choices:
		var route := _planner.build(global_position,choice.a)
		if route.is_empty() or route.back().distance_to(choice.a)>0.1: continue
		route.append(choice.b)
		wander_route = route
		wander_target = choice.b
		visited_racks.append(choice.name)
		if visited_racks.size()>5: visited_racks.pop_front()
		return

func _free_motion(state: PhysicsDirectBodyState3D) -> void:
	# No seat or velocity attachment: a cart-supported character is passive cargo.
	if not grounded or supported_by_cart:
		return
	var wobble := 0.58 * (wet_wobble_multiplier if SlipState.wet(self) else 1.0)
	var desired := wander_direction.rotated(Vector3.UP, sin(_phase * _wobble_frequency) * wobble + _wobble_bias) * wander_speed
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
