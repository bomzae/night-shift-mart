class_name DrunkCustomer
extends CarryableCharacter

signal product_broken(value: float)
@export var wander_speed: float = 1.8
@export var wander_acceleration: float = 14.0
@export var direction_interval: float = 2.0
@export var product_push_impulse: float = 2.5
@export var low_shelf_impulse_multiplier: float = 1.25
@export var contact_cooldown: float = 1.0
@export var break_min_speed: float = 2.7
@export var wet_wobble_multiplier: float = 1.8
var wander_direction := Vector3.FORWARD
var direction_changes: int = 0
var _direction_wait: float = 0
var _contact_wait: float = 0
var _phase: float = 0
var _incoming_speed: float = 0
var _motion_intent := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var wander_route: Array[Vector3] = []
var wander_target := Vector3.ZERO
var visited_racks: Array[StringName] = []
var progress_watchdog := NPCProgressWatchdog.new()
var _planner: RatAisleRoute
var _wobble_bias: float = 0
var _wobble_frequency: float = 2.1
var shelf_contact_time: float = 0
var bump_remaining: float = 0
var bump_cooldown: float = 0
var bump_count: int = 0
var bump_normal := Vector3.ZERO
var bump_direction := Vector3.ZERO
var avoided_shelves: Dictionary = {}
var _contact_wall: Node
var _bump_origin := Vector3.ZERO
var low_shelf_impacts: int = 0
var rear_routes_selected: int = 0
var rear_shelf_impacts: int = 0
var last_shelf_impact: Dictionary = {}

func _ready() -> void:
	super._ready()
	knockdown.minimum_fall_speed = 1.2
	can_sleep = false
	_rng.randomize()
	body_entered.connect(_contact)
	progress_watchdog.check_window = 5.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_incoming_speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	bump_cooldown = maxf(0, bump_cooldown-delta)
	for key in avoided_shelves.keys():
		avoided_shelves[key] -= delta
		if avoided_shelves[key] <= 0: avoided_shelves.erase(key)
	if knockdown.active() or fire_reaction.active():
		_cancel_bump()
		progress_watchdog.observe(global_position, wander_target, "wander", false, delta)
		return
	_contact_wait = maxf(0, _contact_wait - delta)
	if is_instance_valid(holder) or supported_by_cart:
		_cancel_bump()
		$Mood.text = "@_@"
		reset_wander_route()
		return
	if bump_remaining > 0:
		bump_remaining = maxf(0,bump_remaining-delta)
		progress_watchdog.observe(global_position,wander_target,"bump",false,delta)
		if bump_remaining == 0:
			_direction_wait = 0
			# A failed short escape must yield long enough for the existing 5s watchdog.
			if Vector2(global_position.x-_bump_origin.x,global_position.z-_bump_origin.z).length()<0.15:
				bump_cooldown = progress_watchdog.check_window+1.0
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
		if is_instance_valid(shelf.point_owner) or visited_racks.has(shelf.name) or avoided_shelves.has(shelf.name): continue
		# Occasionally pass an accessible rear aisle of a single low deck.
		# Selection never reads product stock, price or type.
		var sides: Array[float]=[1.1]
		if single_low_deck(shelf) and _rng.randf()<0.45: sides.push_front(-1.13)
		for side in sides:
			var a := shelf.to_global(Vector3(-1.85,0.01,side))
			var b := shelf.to_global(Vector3(1.85,0.01,side))
			_planner.refresh_exclusions(side<0)
			if not _planner.clear_segment(a,b): continue
			if global_position.distance_squared_to(b)<global_position.distance_squared_to(a):
				var swap := a
				a = b
				b = swap
			var repeat_cost := 24.0 if store_zone(shelf.global_position)==repeated_zone else 0.0
			choices.append({"name":shelf.name,"a":a,"b":b,"rear":side<0,"score":global_position.distance_to(a)+repeat_cost+_rng.randf_range(0,4)})
			break
	choices.sort_custom(func(a,b): return a.score<b.score)
	for choice in choices:
		var route := _planner.build(global_position,choice.a,choice.rear)
		if route.is_empty() or route.back().distance_to(choice.a)>0.1: continue
		route.append(choice.b)
		wander_route = route
		if choice.rear: rear_routes_selected+=1
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
	_motion_intent=desired
	_update_shelf_contact(state, desired)
	if bump_remaining > 0: desired = bump_direction * minf(wander_speed,1.5)
	desired += human_separation.correction(self, desired, separation_multiplier)
	desired = cart_recovery.steer(desired, state.step, 0.6)
	desired = product_recovery.steer(desired, state.step, 0.6)
	var horizontal := Vector3(state.linear_velocity.x, 0, state.linear_velocity.z)
	horizontal = horizontal.move_toward(desired, wander_acceleration * SlipState.control(self) * state.step)
	state.linear_velocity.x = horizontal.x
	state.linear_velocity.z = horizontal.z

func _cancel_bump() -> void:
	bump_remaining = 0
	shelf_contact_time = 0
	_contact_wall = null

func begin_carry(controller: Node, player: PhysicsBody3D) -> bool:
	var accepted := super.begin_carry(controller,player)
	if accepted: _cancel_bump()
	return accepted

func _update_shelf_contact(state: PhysicsDirectBodyState3D, desired: Vector3) -> void:
	# Only fixed horizontal geometry. Products/cart retain their own recovery.
	if bump_remaining > 0 or bump_cooldown > 0 or wander_speed <= 0.1:
		shelf_contact_time = 0
		return
	var wall: Node = null
	var normal := Vector3.ZERO
	for index in range(state.get_contact_count()):
		var body = state.get_contact_collider_object(index)
		var n := state.transform.basis * state.get_contact_local_normal(index)
		if body is StaticBody3D and absf(n.y)<0.4 and desired.dot(n)<-0.1:
			wall = body
			normal = Vector3(n.x,0,n.z).normalized()
			break
	if wall == null:
		shelf_contact_time = 0
		_contact_wall = null
		return
	if wall != _contact_wall: shelf_contact_time = 0
	_contact_wall = wall
	# Into-wall displacement is constrained even while sliding tangentially.
	if state.linear_velocity.dot(normal) > 0.2:
		shelf_contact_time = 0
		return
	shelf_contact_time += state.step
	if shelf_contact_time < 0.35: return
	bump_normal = normal
	var tangent := desired.slide(normal).normalized()
	if tangent.length_squared()<0.1:
		tangent = normal.cross(Vector3.UP) * (-1 if _rng.randf()<0.5 else 1)
	bump_direction = (normal*0.8+tangent*0.6).normalized()
	if _planner != null:
		_planner.refresh_exclusions()
		if not _planner.clear_segment(global_position,global_position+bump_direction*0.9):
			bump_direction = (normal*0.8-tangent*0.6).normalized()
			if not _planner.clear_segment(global_position,global_position+bump_direction*0.9): bump_direction = normal
	if wall.get_parent() is StockShelf:
		avoided_shelves[wall.get_parent().name] = 5.0
	reset_wander_route()
	wander_target = global_position+bump_direction*0.9
	wander_direction = bump_direction
	bump_remaining = 0.6
	_bump_origin = global_position
	bump_cooldown = 1.3
	bump_count += 1
	shelf_contact_time = 0

func _contact(body: Node) -> void:
	if knockdown.active() or is_instance_valid(holder) or supported_by_cart or _contact_wait > 0:
		return
	if body is GrabbableBody:
		_contact_wait = contact_cooldown
		_disturb_product(body)
	elif body.get_parent() is StockShelf:
		_contact_wait = contact_cooldown
		if _jolt_low_shelf(body.get_parent(),body): return
		# Jolt only nearby real goods; Shelf remains the sole stock authority.
		for product in body.get_parent().zone.get_overlapping_bodies():
			if product is GrabbableBody and product.global_position.distance_to(global_position) < 2.0:
				_disturb_product(product)

static func single_low_deck(shelf: StockShelf) -> bool:
	if shelf.tier_height>0: return false
	for other in shelf.get_tree().get_nodes_in_group("stock_shelves"):
		if other!=shelf and other.global_position.distance_squared_to(shelf.global_position)<0.001 and other.tier_height>0: return false
	return true

func _jolt_low_shelf(shelf: StockShelf, collider: PhysicsBody3D) -> bool:
	if not single_low_deck(shelf): return false
	if _incoming_speed<0.45: return true
	var state := PhysicsServer3D.body_get_direct_state(get_rid())
	for index in range(state.get_contact_count()):
		if state.get_contact_collider_object(index)!=collider: continue
		var normal := state.get_contact_local_normal(index)
		if absf(normal.y)>0.4: continue
		var point := state.get_contact_local_position(index)
		var affected := 0
		var front := shelf.global_basis.z.normalized()
		var rear := shelf.to_local(point).z < -0.6 and normal.dot(front)<-0.7 and _motion_intent.dot(front)>0.1
		var impulses:=[]
		var impulse_size := product_push_impulse*clampf(low_shelf_impulse_multiplier,1.0,1.25)*clampf(_incoming_speed/maxf(0.1,wander_speed),0.4,1.0)
		for product in shelf.zone.get_overlapping_bodies():
			if not product is GrabbableBody or is_instance_valid(product.holder) or product.is_queued_for_deletion() or product.get_meta("sold",false) or product.get_meta("broken",false): continue
			# Distance to the real product shape, not only its center: large goods can
			# be close to the impact face even with their center outside the old radius.
			var shape: CollisionShape3D=product.get_node("CollisionShape3D")
			var bounds: AABB=shape.shape.get_debug_mesh().get_aabb()
			var local_point:=shape.to_local(point)
			var closest:=Vector3(clampf(local_point.x,bounds.position.x,bounds.end.x),clampf(local_point.y,bounds.position.y,bounds.end.y),clampf(local_point.z,bounds.position.z,bounds.end.z))
			if (shape.to_global(closest).distance_to(point)>1.2 if rear else product.global_position.distance_to(point)>1.25): continue
			var tangent := normal.cross(Vector3.UP)
			if tangent.dot(product.global_position-point)<0: tangent=-tangent
			var impulse := (normal*0.75+tangent*0.65+Vector3.UP*0.12).normalized()*impulse_size
			if rear:
				var strength:=minf(12.0*sqrt(product.mass),product.mass*4.8)*clampf(_incoming_speed/maxf(0.1,wander_speed),0.0,1.0)
				impulse=(front+Vector3.UP*0.16).normalized()*strength
			product.apply_impulse(impulse,Vector3.UP*0.025)
			impulses.append({"id":product.get_instance_id(),"mass":product.mass,"impulse":impulse})
			affected+=1
		low_shelf_impacts+=1
		if rear: rear_shelf_impacts+=1
		last_shelf_impact={"shelf":shelf.name,"point":point,"normal":normal,"speed":_incoming_speed,"impulse":impulses.reduce(func(value,item):return maxf(value,item.impulse.length()),0.0),"products":affected,"rear":rear,"impulses":impulses}
		return true
	return true

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
