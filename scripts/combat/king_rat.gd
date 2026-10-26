class_name KingRat
extends CombatTarget
enum State { SPAWN, SEEK_FOOD, MOVE_TO_FOOD, EAT, TELEGRAPH, CHARGE, STAGGER, DEFEATED, TRAVEL_ZONE, PURSUIT, CHARGE_RECOVERY, REPOSITION, RECOIL }
@export var desired_attack_distance: float = 3.2
@export var reposition_speed: float = 3.5
@export var post_hit_grace: float = 0.35
@export var separation_push_interval: float = 0.4
var _spacing_grace: float = 0
var _push_waits: Dictionary = {}
var separation_push_count: int = 0
var _reposition_side: float = 1.0
var _reposition_blocked: float = 0.0
@export var move_speed: float = 3.6
@export var eat_time: float = 1.5
@export var eat_reach: float = 1.9
@export var max_food_height: float = 2.25
@export var charge_cooldown: float = 8.0
@export var charge_range: float = 7.0
@export var telegraph_time: float = 0.65
@export var charge_speed: float = 7.5
@export var charge_duration: float = 0.8
@export var charge_damage: float = 30.0
@export var charge_push: float = 3.5
@export var stagger_threshold: float = 45.0
@export var stagger_time: float = 0.45
@export var defeat_time: float = 1.5
@export var stuck_time: float = 2.5
var state := State.SPAWN
var food: GrabbableBody
var director: Node
var player: CharacterBody3D
var route: Array[Vector3] = []
var charge_direction := Vector3.FORWARD
var _left: float = 0.5
var _charge_wait: float = 4.0
var _hit_targets := {}
var _blocked: float = 0
var _last_position: Vector3
var _ignored_food := {}
var _flash: float = 0
var visual: Node3D
var material := StandardMaterial3D.new()
var mood: Label3D
var _character_pairs: Dictionary = {}
var character_zone: Area3D
@export var food_search_radius: float = 42.0
@export var overlap_push: float = 12.0

# Clear aisle entries around the store, not destinations inside shelf geometry.
const ZONE_ENTRIES: Array[Vector3] = [Vector3(0, 0.01, 6), Vector3(26, 0.01, 6), Vector3(26, 0.01, 27), Vector3(0, 0.01, 27), Vector3(-26, 0.01, 27), Vector3(-26, 0.01, 6)]
const ZONE_NAMES := ["Produce/Cookware", "Household", "Electronics", "Front/Dairy", "Pantry", "Rear Snacks"]
@export var zone_dwell_time: float = 18.0
@export var zone_eat_limit: int = 2
@export var player_awareness_radius: float = 22.0
@export var pursuit_speed: float = 4.8
@export var target_memory_time: float = 6.0
@export var charge_recovery_time: float = 0.3
@export var recoil_duration: float = 0.25
@export var max_recoil_speed: float = 4.5
@export var recoil_damage_scale: float = 0.055
@export var recoil_cooldown: float = 0.3
var target_memory: float = 0.0
var last_known_position := Vector3.ZERO
var pursuit_route: Array[Vector3] = []
var pursuit_planner: RatAisleRoute
var _route_wait: float = 0
var _pursuit_blocked: float = 0
var _pursuit_detour_left: float = 0
var _recoil_left: float = 0
var _recoil_wait: float = 0
var recoil_velocity := Vector3.ZERO
var last_recoil_speed: float = 0
var _sees_player: bool = false
var current_zone: int = 0
var destination_zone: int = -1
var zone_age: float = 0
var zone_eaten: int = 0
var visited_zones: Array[int] = []

func nearest_zone(at: Vector3) -> int:
	var result := 0
	for i in range(ZONE_ENTRIES.size()):
		if at.distance_squared_to(ZONE_ENTRIES[i]) < at.distance_squared_to(ZONE_ENTRIES[result]): result = i
	return result

func change_zone() -> void:
	destination_zone = (current_zone + 1) % ZONE_ENTRIES.size()
	food = null
	var entry := ZONE_ENTRIES[destination_zone]
	if absf(global_position.x) > 20 and signf(global_position.x) == signf(entry.x):
		route = [Vector3(entry.x, 0.01, global_position.z), entry]
	else:
		route = StoreRoutes.via_main(global_position, entry)
	state = State.TRAVEL_ZONE
	_blocked = 0

func travel_zone(delta: float) -> Vector3:
	if global_position.distance_to(ZONE_ENTRIES[destination_zone]) < 1.0:
		current_zone = destination_zone
		destination_zone = -1
		zone_age = 0
		zone_eaten = 0
		if not visited_zones.has(current_zone): visited_zones.append(current_zone)
		state = State.SEEK_FOOD
		return Vector3.ZERO
	_blocked = _blocked + delta if global_position.distance_to(_last_position) < 0.005 else 0
	if _blocked >= stuck_time or route.is_empty():
		# Try the next clear sector instead of retrying one blocked entry forever.
		current_zone = destination_zone
		change_zone()
	if route.is_empty(): return Vector3.ZERO
	var offset := route[0] - global_position
	offset.y = 0
	if offset.length() < 0.25:
		route.pop_front()
		return Vector3.ZERO
	return offset.normalized() * minf(move_speed, offset.length() * 4)

func _ready() -> void:
	super._ready()
	pursuit_planner = RatAisleRoute.new(self)
	collision_mask &= ~HumanSeparation.HUMAN_LAYER
	character_zone = Area3D.new()
	character_zone.name = "CharacterHitArea"
	character_zone.collision_layer = 0
	character_zone.collision_mask = 1 | HumanSeparation.HUMAN_LAYER
	var hit_shape := CollisionShape3D.new()
	var hit_capsule := CapsuleShape3D.new()
	hit_capsule.radius = 1.0
	hit_capsule.height = 1.8
	hit_shape.shape = hit_capsule
	hit_shape.position.y = 0.9
	character_zone.add_child(hit_shape)
	add_child(character_zone)
	_sync_character_exceptions()
	floor_snap_length = 0.2
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	material.albedo_color = Color(0.5, 0.27, 0.45)
	_part(Vector3(1.3, 1.3, 1.6), Vector3(0, 0.72, 0))
	_part(Vector3(0.7, 0.6, 0.65), Vector3(0, 0.65, -0.8))
	for side in [-1, 1]:
		_part(Vector3(0.42, 0.5, 0.2), Vector3(side * 0.43, 1.4, -0.4))
		Graybox.box(visual, "Eye", Vector3(0.12, 0.12, 0.1), Vector3(side * 0.23, 0.85, -1.1), Color.GOLD, false)
	Graybox.box(visual, "Tail", Vector3(0.16, 0.16, 1.4), Vector3(0, 0.25, 1.1), Color.SALMON, false)
	mood = Graybox.sign(self, "KING RAT", Vector3(0, 2, 0), Color.GOLD)
	damaged.connect(_on_damage)
	defeated.connect(_on_defeat)
	_last_position = global_position
	current_zone = nearest_zone(global_position)
	visited_zones.append(current_zone)

func _part(size: Vector3, at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	mesh.mesh = sphere
	mesh.scale = size
	mesh.position = at
	mesh.material_override = material
	visual.add_child(mesh)

func valid_food(body: GrabbableBody) -> bool:
	return is_instance_valid(body) and not body.is_queued_for_deletion() and body.product_type != &"" and not is_instance_valid(body.holder) and not body.get_meta("sold", false) and not body.get_meta("stolen", false) and not body.get_meta("broken", false) and not body.get_meta("boss_eaten", false)

func seek_food() -> void:
	food = null
	var best := INF
	for body in get_tree().get_nodes_in_group("grabbable"):
		if not body is GrabbableBody or not valid_food(body): continue
		if _ignored_food.get(body.get_instance_id(), 0) > Time.get_ticks_msec(): continue
		var at: Vector3 = body.global_position
		if absf(at.x) > 35.5 or at.z < 0 or at.z > 36: continue
		var score := global_position.distance_squared_to(at)
		if score > food_search_radius * food_search_radius: continue
		if nearest_zone(at) != current_zone: score += food_search_radius * food_search_radius
		if score < best:
			best = score
			food = body
	if food == null:
		change_zone()
		return
	var destination := food.global_position
	for shelf: StockShelf in director.get_parent().get_node("Shelves").get_children():
		if shelf.zone.overlaps_body(food):
			var nearest := INF
			for i in range(shelf.shopping_point_count):
				var point := shelf.shopping_point(i)
				var distance := point.distance_squared_to(food.global_position)
				if distance < nearest:
					nearest = distance
					destination = point
			break
	destination.y = 0.01
	route = StoreRoutes.via_main(global_position, destination)
	_blocked = 0
	state = State.MOVE_TO_FOOD

func can_eat() -> bool:
	if not valid_food(food): return false
	var offset := food.global_position - global_position
	if absf(offset.y) > max_food_height: return false
	offset.y = 0
	if offset.length() > eat_reach: return false
	# Reach each physical tier from its approach, without biting through a deck.
	var mouth_height := clampf(food.global_position.y - global_position.y, 1.05, 2.1)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * mouth_height, food.global_position, 1)
	query.exclude = [get_rid(), food.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func finish_eating() -> bool:
	if not can_eat(): return false
	food.set_meta("boss_eaten", true)
	food.hide()
	director.boss_product_loss_value += food.price
	food.queue_free() # Synchronous queued flag invalidates sale/theft/fire in this tick.
	for shelf: StockShelf in director.get_parent().get_node("Shelves").get_children(): shelf.refresh_stock(0)
	food = null
	zone_eaten += 1
	return true

func begin_telegraph() -> void:
	state = State.TELEGRAPH
	_left = telegraph_time
	charge_direction = player.global_position - global_position
	charge_direction.y = 0
	charge_direction = charge_direction.normalized()
	_hit_targets.clear()
	_charge_wait = charge_cooldown

func _physics_process(delta: float) -> void:
	update_awareness(delta)
	_recoil_left = maxf(0, _recoil_left - delta)
	_recoil_wait = maxf(0, _recoil_wait - delta)
	_spacing_grace = maxf(0, _spacing_grace - delta)
	for id in _push_waits.keys():
		_push_waits[id] -= delta
		if _push_waits[id] <= 0: _push_waits.erase(id)
	_sync_character_exceptions()
	_character_contacts(delta)
	contact_push(delta)
	_left -= delta
	_charge_wait -= delta
	_flash = maxf(0, _flash - delta)
	external_velocity *= exp(-push_drag * delta) # Preserve small continuous spray forces.
	var desired := Vector3.ZERO
	if state == State.DEFEATED:
		visual.rotation.z = lerp_angle(visual.rotation.z, 1.3, minf(1, delta * 7))
		if _left <= 0: queue_free()
	elif _recoil_left > 0:
		pass # Impact motion owns this tick; no pursuit or charge transitions.
	elif state == State.RECOIL or state == State.STAGGER:
		if state == State.RECOIL or _left <= 0:
			_spacing_grace = post_hit_grace
			resume_combat()
	elif state == State.SPAWN:
		if _left <= 0: state = State.SEEK_FOOD
	elif state == State.TELEGRAPH:
		if _left <= 0:
			state = State.CHARGE
			_left = charge_duration
	elif state == State.CHARGE:
		desired = charge_direction * charge_speed
		if _left <= 0:
			state = State.CHARGE_RECOVERY
			_left = charge_recovery_time
	elif state == State.CHARGE_RECOVERY:
		if _left <= 0: resume_combat()
	elif state == State.REPOSITION:
		if target_memory <= 0:
			state = State.SEEK_FOOD
		elif combat_distance() >= desired_attack_distance:
			state = State.PURSUIT
		else:
			var away := global_position - last_known_position
			away.y = 0
			if away.length_squared() < 0.01: away = global_basis.z
			# A stable lateral component prevents backing straight into a shelf.
			_reposition_blocked = _reposition_blocked + delta if global_position.distance_to(_last_position) < 0.008 else 0
			if _reposition_blocked > 0.6:
				_reposition_side *= -1
				_reposition_blocked = 0
			var side := away.normalized().cross(Vector3.UP) * _reposition_side
			var direction := (away.normalized() + side * 0.45).normalized()
			if test_move(global_transform, direction * 0.7):
				direction = side if not test_move(global_transform, side * 0.7) else -side
			desired = direction * reposition_speed
	else:
		if destination_zone < 0: zone_age += delta
		if target_memory > 0 and _sees_player and combat_distance() < desired_attack_distance - 0.25:
			state = State.REPOSITION
		elif is_instance_valid(player) and _sees_player and _spacing_grace <= 0 and _charge_wait <= 0 and combat_distance() >= desired_attack_distance - 0.25 and combat_distance() <= charge_range:
			begin_telegraph()
		elif target_memory > 0:
			state = State.PURSUIT
			desired = pursue_player(delta)
		elif state == State.PURSUIT:
			pursuit_route.clear()
			state = State.SEEK_FOOD
		elif destination_zone >= 0:
			state = State.TRAVEL_ZONE
			desired = travel_zone(delta)
		elif zone_age >= zone_dwell_time or zone_eaten >= zone_eat_limit:
			change_zone()
		elif state == State.SEEK_FOOD:
			seek_food()
		elif not valid_food(food):
			food = null
			state = State.SEEK_FOOD
		elif state == State.EAT:
			if not can_eat(): state = State.SEEK_FOOD
			elif _left <= 0:
				finish_eating()
				state = State.SEEK_FOOD
		elif can_eat():
			state = State.EAT
			_left = eat_time
		else:
			if not route.is_empty():
				var offset := route[0] - global_position
				offset.y = 0
				if offset.length() < 0.25: route.pop_front()
				else: desired = offset.normalized() * minf(move_speed, offset.length() * 4)
			_blocked = _blocked + delta if global_position.distance_to(_last_position) < 0.005 else 0
			if _blocked >= stuck_time or route.is_empty():
				_ignored_food[food.get_instance_id()] = Time.get_ticks_msec() + 5000
				state = State.SEEK_FOOD
	_last_position = global_position
	var motion := desired + external_velocity
	if _recoil_left > 0 and not is_defeated:
		motion = (recoil_velocity * (_recoil_left / recoil_duration) + external_velocity).limit_length(max_recoil_speed)
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var body := get_slide_collision(i).get_collider()
		if state == State.CHARGE: _charge_hit(body)
		if body is RigidBody3D and desired.length() > 0.1:
			PhysicsPush.apply(body, desired.normalized() * (60 if state == State.CHARGE else 12) * delta)
		elif body is BasicCustomer and desired.length() > 0.1:
			PhysicsPush.apply(body, desired.normalized() * 12 * delta)
	if state in [State.TELEGRAPH, State.PURSUIT, State.REPOSITION] and target_memory > 0 and combat_distance() > 0.1:
		look_at(Vector3(last_known_position.x, global_position.y, last_known_position.z), Vector3.UP)
	elif desired.length() > 0.1:
		look_at(global_position + desired, Vector3.UP)
	material.albedo_color = Color.WHITE if _flash > 0 else (Color.ORANGE_RED if state == State.TELEGRAPH else Color(0.5, 0.27, 0.45))
	visual.position.y = sin(Time.get_ticks_msec() * 0.025) * 0.06 if state == State.EAT else 0
	if _flash <= 0: mood.text = "✓" if is_defeated else ("!" if state == State.TELEGRAPH else State.keys()[state])

func _charge_hit(body: Node) -> void:
	if _hit_targets.has(body.get_instance_id()): return
	var knockdown := body.get_node_or_null("Knockdown") as KnockdownState
	if knockdown == null: return
	_hit_targets[body.get_instance_id()] = true
	var health := body.get_node_or_null("PlayerHealth") as PlayerHealth
	if health != null: health.receive_damage(charge_damage, self)
	if knockdown.try_start(charge_direction):
		if body is CharacterBody3D: body.velocity += charge_direction * charge_push
		else: PhysicsPush.apply(body, charge_direction * charge_push * 3)

func _on_damage(amount: float) -> void:
	_flash = 0.18
	mood.text = "-%.0f" % amount
	if amount >= stagger_threshold:
		state = State.STAGGER
		_left = stagger_time

func _on_defeat() -> void:
	state = State.DEFEATED
	_left = defeat_time
	food = null
	route.clear()

# Pair exceptions keep the shared world/product layer intact. Never ghost carts.
func _sync_character_exceptions() -> void:
	var characters := get_tree().get_nodes_in_group("human_npcs")
	for health in get_tree().get_nodes_in_group("player_health"):
		characters.append(health.get_parent())
	for body in characters:
		if body is PhysicsBody3D and not body.is_queued_for_deletion():
			var id := body.get_instance_id()
			if not _character_pairs.has(id):
				_character_pairs[id] = weakref(body)
				add_collision_exception_with(body)
				body.add_collision_exception_with(self)
				body.tree_exiting.connect(_forget_character.bind(body), CONNECT_ONE_SHOT)

func _character_contacts(_delta: float) -> void:
	if is_defeated or _recoil_left > 0 or state in [State.STAGGER, State.RECOIL, State.REPOSITION, State.CHARGE_RECOVERY]: return
	for body in character_zone.get_overlapping_bodies():
		if body.get_node_or_null("Knockdown") == null: continue
		if body is CarryableCharacter and is_instance_valid(body.holder): continue
		var health := body.get_node_or_null("PlayerHealth") as PlayerHealth
		if health != null and health.is_downed: continue
		if state == State.CHARGE:
			_charge_hit(body)
		else:
			if _push_waits.has(body.get_instance_id()): continue
			_push_waits[body.get_instance_id()] = separation_push_interval
			separation_push_count += 1
			var away: Vector3 = body.global_position - global_position
			away.y = 0
			if away.length_squared() < 0.001: away = Vector3.RIGHT
			PhysicsPush.apply(body, away.normalized() * minf(overlap_push / 60.0, 0.3))

func _forget_character(body: PhysicsBody3D) -> void:
	if not is_instance_valid(body): return
	_character_pairs.erase(body.get_instance_id())
	remove_collision_exception_with(body)
	body.remove_collision_exception_with(self)

func _exit_tree() -> void:
	for ref: WeakRef in _character_pairs.values():
		var body := ref.get_ref() as PhysicsBody3D
		if is_instance_valid(body):
			remove_collision_exception_with(body)
			body.remove_collision_exception_with(self)
	_character_pairs.clear()

func update_awareness(delta: float) -> void:
	target_memory = maxf(0, target_memory - delta)
	_route_wait = maxf(0, _route_wait - delta)
	_sees_player = false
	if is_defeated or not is_instance_valid(player) or player_awareness_radius <= 0: return
	var health := player.get_node_or_null("PlayerHealth") as PlayerHealth
	if health != null and health.is_downed:
		target_memory = 0
		return
	if global_position.distance_to(player.global_position) > player_awareness_radius: return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, player.global_position + Vector3.UP, 1)
	query.exclude = [get_rid(), player.get_rid()]
	_sees_player = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if _sees_player:
		if target_memory <= 0: _route_wait = 0
		target_memory = target_memory_time
		last_known_position = player.global_position

func pursue_player(delta: float) -> Vector3:
	if _sees_player and combat_distance() <= desired_attack_distance: return Vector3.ZERO
	_pursuit_detour_left = maxf(0, _pursuit_detour_left - delta)
	_pursuit_blocked = _pursuit_blocked + delta if global_position.distance_to(_last_position) < 0.008 else 0
	if _route_wait <= 0 or _pursuit_blocked >= 1.0:
		if _pursuit_blocked >= 1.0:
			_pursuit_detour_left = 4.0
			_pursuit_blocked = 0
		pursuit_route = pursuit_planner.build(global_position, last_known_position, _pursuit_detour_left > 0)
		_route_wait = 0.8
	if pursuit_route.is_empty(): return Vector3.ZERO
	var offset := pursuit_route[0] - global_position
	offset.y = 0
	if offset.length() < 0.35:
		pursuit_route.pop_front()
		return Vector3.ZERO
	return offset.normalized() * minf(pursuit_speed, offset.length() * 4)

func receive_impact(amount: float, impulse: Vector3) -> void:
	if is_defeated: return
	# Combat impacts have direction; continuous spray remains receive_impulse only.
	if impulse.is_finite() and impulse.length_squared() > 0.001 and amount > 0 and _recoil_wait <= 0:
		var direction := Vector3(impulse.x, 0, impulse.z).normalized()
		last_recoil_speed = minf(max_recoil_speed, amount * recoil_damage_scale + impulse.length() / target_mass * 0.25)
		recoil_velocity = direction * last_recoil_speed
		_recoil_left = recoil_duration
		_recoil_wait = recoil_cooldown
		state = State.RECOIL
	# Preserve shared damage/weak external-force contract without stacking recoil.
	super.receive_impact(amount, impulse)

func combat_distance() -> float:
	var offset := last_known_position - global_position
	offset.y = 0
	return offset.length()

func resume_combat() -> void:
	_route_wait = 0
	if target_memory <= 0:
		state = State.SEEK_FOOD
	elif combat_distance() < desired_attack_distance:
		state = State.REPOSITION
	else:
		state = State.PURSUIT
