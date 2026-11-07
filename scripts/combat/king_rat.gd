class_name KingRat
extends CombatTarget
enum State { SPAWN, SEEK_FOOD, MOVE_TO_FOOD, EAT, TELEGRAPH, CHARGE, STAGGER, DEFEATED, TRAVEL_ZONE, PURSUIT, CHARGE_RECOVERY, REPOSITION, RECOIL, HOLD }
enum AttackPhase { NONE, COMBAT_APPROACH, TELEGRAPH, CHARGE }
@export var desired_attack_distance: float = 3.2
@export var too_close_distance: float = 2.5
@export var combat_repath_interval: float = 0.4
@export var combat_stuck_time: float = 0.8
@export var orbit_speed: float = 2.0
var _retreating: bool = false
var _lane_wait: float = 0
var _clear_attack_lane: bool = false
@export var reposition_speed: float = 3.5
@export var post_hit_grace: float = 0.2
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
@export var charge_cooldown: float = 4.5
@export var charge_range: float = 7.0
@export var telegraph_time: float = 0.65
@export var committed_path_timeout: float = 1.25
var attack_committed: bool = false
var _charge_started: bool = false
var telegraph_remaining: float = 0
var attack_instance_id: int = 0
var telegraph_start_count: int = 0
var approach_interrupt_count: int = 0
var _attack_stagger_left: float = 0
var telegraph_active: bool:
	get: return attack_committed and not _charge_started
var attack_phase: AttackPhase:
	get:
		if telegraph_active: return AttackPhase.TELEGRAPH
		if state == State.CHARGE: return AttackPhase.CHARGE
		if state in [State.PURSUIT, State.REPOSITION]: return AttackPhase.COMBAT_APPROACH
		return AttackPhase.NONE
var new_attack_commit_count: int:
	get: return attack_commit_count
var telegraph_resume_count: int:
	get: return attack_resume_count
var charge_start_count: int:
	get: return charge_count
var attack_commit_count: int = 0
var attack_cancel_count: int = 0
var attack_resume_count: int = 0
var charge_count: int = 0
var last_attack_cancel: String = ""
var _attack_target: CharacterBody3D
var _attack_resume_pending: bool = false
var _attack_path_blocked: float = 0
@export var charge_speed: float = 7.5
@export var charge_duration: float = 0.8
@export var charge_damage: float = 30.0
@export var charge_push: float = 3.5
@export var stagger_threshold: float = 45.0
@export var stagger_time: float = 0.45
@export var stagger_rearm_time: float = 2.0
var _stagger_wait: float = 0
@export var defeat_time: float = 1.5
@export var stuck_time: float = 2.5
var state := State.SPAWN
var food: GrabbableBody
var director: Node
var player: CharacterBody3D
@export var aggro_memory_time: float = 12.0
@export var close_threat_distance: float = 2.5
@export var close_threat_time: float = 1.25
var is_aggro: bool = false
var aggro_target: CharacterBody3D
var _close_threats: Dictionary = {}
var route: Array[Vector3] = []
var charge_direction := Vector3.FORWARD
var _left: float = 0.5
var _charge_wait: float = 0.0
var _hit_targets := {}
var _blocked: float = 0
var _last_position: Vector3
var _ignored_food := {}
var _flash: float = 0
var _flash_material := StandardMaterial3D.new()
var _flash_meshes: Array[MeshInstance3D] = []
var _saved_overlays: Array[Material] = []
var _reaction_left: float = 0
var _pose_left: float = 0
var _reaction_duration: float = 0.1
var _reaction_wait: float = 0
var _reaction_tilt: float = 0
var _impact_mass: float = 0
@export var body_contact_radius: float = 1.2
@export var body_separation_speed: float = 2.0
@export var contact_damage: float = 10.0
@export var contact_knockback: float = 2.8
@export var contact_damage_cooldown: float = 1.0
var _contact_waits: Dictionary = {}
var contact_damage_count: int = 0
var last_ai_velocity := Vector3.ZERO
var last_impact_impulse := Vector3.ZERO
var _recoil_weapon: WeakRef
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
@export var charge_recovery_time: float = 0.55
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
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1, 0.95, 0.65)
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		_flash_meshes.append(child)
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
	if attack_committed or not is_aggro or not valid_attacker(aggro_target): return
	attack_committed = true
	_charge_started = false
	_attack_target = aggro_target
	telegraph_remaining = telegraph_time
	_attack_resume_pending = false
	_attack_path_blocked = 0
	attack_commit_count += 1
	attack_instance_id = attack_commit_count
	telegraph_start_count += 1
	state = State.TELEGRAPH
	mood.text = "!"
	material.albedo_color = Color.ORANGE_RED
	_left = telegraph_time
	charge_direction = _attack_target.global_position - global_position
	charge_direction.y = 0
	charge_direction = charge_direction.normalized()
	_hit_targets.clear()
	_charge_wait = charge_cooldown

func _physics_process(delta: float) -> void:
	if attack_committed and not valid_attacker(_attack_target): cancel_attack("target_invalid")
	update_awareness(delta)
	_stagger_wait = maxf(0, _stagger_wait - delta)
	_attack_stagger_left = maxf(0, _attack_stagger_left - delta)
	_recoil_left = maxf(0, _recoil_left - delta)
	if _recoil_weapon != null:
		var held_weapon := _recoil_weapon.get_ref() as WeaponBody
		if _recoil_left <= 0 or not is_instance_valid(held_weapon) or not is_instance_valid(held_weapon.holder):
			_release_recoil_weapon()
	_recoil_wait = maxf(0, _recoil_wait - delta)
	_reaction_left = maxf(0, _reaction_left - delta)
	_pose_left = maxf(0, _pose_left - delta)
	_reaction_wait = maxf(0, _reaction_wait - delta)
	_spacing_grace = maxf(0, _spacing_grace - delta)
	_lane_wait = maxf(0, _lane_wait - delta)
	for id in _push_waits.keys():
		_push_waits[id] -= delta
		if _push_waits[id] <= 0: _push_waits.erase(id)
	for id in _contact_waits.keys():
		_contact_waits[id] -= delta
		if _contact_waits[id] <= 0: _contact_waits.erase(id)
	_sync_character_exceptions()
	_character_contacts(delta)
	contact_push(delta)
	# Reaction overlays pause the current execution clock, never restart it.
	if not (attack_committed and damage_reaction_active()): _left -= delta
	_charge_wait -= delta
	_flash = maxf(0, _flash - delta)
	external_velocity *= exp(-push_drag * delta) # Preserve small continuous spray forces.
	var desired := Vector3.ZERO
	if state == State.DEFEATED:
		visual.rotation.z = lerp_angle(visual.rotation.z, 1.3, minf(1, delta * 7))
		if _left <= 0: queue_free()
	elif damage_reaction_active():
		pass # Impact motion owns this tick; no pursuit or charge transitions.
	elif attack_committed and state != State.CHARGE:
		advance_committed_attack(delta)
		if state == State.CHARGE: desired = charge_direction * charge_speed
	elif state == State.RECOIL or state == State.STAGGER:
		if state == State.RECOIL or _left <= 0:
			_spacing_grace = post_hit_grace
			state = State.HOLD
			_retreating = false
	elif state == State.HOLD and _spacing_grace > 0:
		pass # Recover at the impact position; do not add automatic retreat.
	elif state == State.SPAWN:
		if _left <= 0: state = State.SEEK_FOOD
	elif state == State.TELEGRAPH:
		state = State.HOLD # A canceled preparation cannot execute a stale charge.
	elif state == State.CHARGE:
		desired = charge_direction * charge_speed
		if _left <= 0:
			attack_committed = false
			_attack_target = null
			_charge_started = false
			state = State.CHARGE_RECOVERY
			_left = charge_recovery_time
	elif state == State.CHARGE_RECOVERY:
		if _left <= 0: desired = combat_move(delta) if is_aggro else Vector3.ZERO
		if _left <= 0 and not is_aggro: state = State.SEEK_FOOD
	elif is_aggro:
		desired = combat_move(delta)
	else:
		if destination_zone < 0: zone_age += delta
		if destination_zone >= 0:
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
	last_ai_velocity = desired
	var motion := desired + external_velocity
	if _recoil_left > 0 and not is_defeated:
		var direction := recoil_velocity.normalized()
		var impact_external := external_velocity - direction * minf(0, external_velocity.dot(direction))
		motion = (recoil_velocity * (_recoil_left / recoil_duration) + impact_external).limit_length(max_recoil_speed)
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var body := get_slide_collision(i).get_collider()
		if state == State.CHARGE and not damage_reaction_active(): _charge_hit(body)
		if body is RigidBody3D and desired.length() > 0.1:
			PhysicsPush.apply(body, desired.normalized() * (60 if state == State.CHARGE else 12) * delta)
		elif body is BasicCustomer and desired.length() > 0.1:
			PhysicsPush.apply(body, desired.normalized() * 12 * delta)
	if state in [State.TELEGRAPH, State.PURSUIT, State.REPOSITION, State.HOLD] and target_memory > 0 and combat_distance() > 0.1:
		look_at(Vector3(last_known_position.x, global_position.y, last_known_position.z), Vector3.UP)
	elif desired.length() > 0.1:
		look_at(global_position + desired, Vector3.UP)
	material.albedo_color = Color.ORANGE_RED if telegraph_active else Color(0.5, 0.27, 0.45)
	if _flash <= 0: _restore_flash()
	visual.position.y = sin(Time.get_ticks_msec() * 0.025) * 0.06 if state == State.EAT else 0
	if not is_defeated:
		# Local pose only: collision, player and world clocks keep running.
		var reaction := _pose_left / _reaction_duration
		visual.rotation.x = -_reaction_tilt * reaction
		visual.position.z = _reaction_tilt * 0.35 * reaction
	if telegraph_active:
		mood.text = "!  -%.0f" % last_damage if _flash > 0 else "!"
	elif _flash <= 0:
		mood.text = "✓" if is_defeated else ("COMBAT_APPROACH" if state == State.PURSUIT else State.keys()[state])

func _charge_hit(body: Node) -> void:
	if _hit_targets.has(body.get_instance_id()): return
	var knockdown := body.get_node_or_null("Knockdown") as KnockdownState
	if knockdown == null: return
	_hit_targets[body.get_instance_id()] = true
	var health := body.get_node_or_null("PlayerHealth") as PlayerHealth
	if health != null:
		health.receive_damage(charge_damage, self)
		_contact_waits[body.get_instance_id()] = contact_damage_cooldown
	if is_aggro and body == aggro_target and state == State.CHARGE: _left = minf(_left, 0.12)
	if knockdown.try_start(charge_direction):
		if body is CharacterBody3D: body.velocity += charge_direction * charge_push
		else: PhysicsPush.apply(body, charge_direction * charge_push * 3)

func _on_damage(amount: float) -> void:
	var heavy := amount >= stagger_threshold or _impact_mass >= 6
	var medium := amount >= 15 or _impact_mass >= 1
	_flash = 0.15 if heavy else (0.12 if medium else 0.1)
	_flash_material.albedo_color = Color.WHITE if heavy else Color(1, 0.95, 0.65)
	if _saved_overlays.is_empty():
		for mesh in _flash_meshes:
			_saved_overlays.append(mesh.material_overlay)
			mesh.material_overlay = _flash_material
	# Every hit has a visual response; only AI interruption has a rearm gate.
	_reaction_duration = 0.24 if heavy else (0.16 if medium else 0.1)
	_pose_left = _reaction_duration
	_reaction_tilt = 0.24 if heavy else (0.13 if medium else 0.055)
	visual.rotation.x = -_reaction_tilt
	visual.position.z = _reaction_tilt * 0.35
	# Do not extend AI interruption every frame when a cart rubs or hits arrive in a burst.
	if _reaction_wait <= 0:
		_reaction_left = _reaction_duration
		_reaction_wait = maxf(0.35, stagger_rearm_time if heavy else 0.35)
		if not attack_committed and state != State.STAGGER: state = State.RECOIL
	mood.text = ("!  -%.0f" if telegraph_active else "-%.0f") % amount
	if amount >= stagger_threshold and _stagger_wait <= 0:
		if attack_committed:
			_attack_stagger_left = stagger_time
		else:
			state = State.STAGGER
			_left = stagger_time
		_stagger_wait = stagger_rearm_time
	if telegraph_active and damage_reaction_active():
		_attack_resume_pending = true

func damage_reaction_active() -> bool:
	return _recoil_left > 0 or _reaction_left > 0 or _attack_stagger_left > 0 or (state == State.STAGGER and _left > 0)

func _restore_flash() -> void:
	for i in range(_saved_overlays.size()):
		_flash_meshes[i].material_overlay = _saved_overlays[i]
	_saved_overlays.clear()

# BODY_SEPARATION never enters receive_impulse / COMBAT_IMPACT. The player's
# motor removes inward motion, retains tangent/escape input, and resolves any
# existing overlap through move_and_slide, so world walls remain authoritative.
func constrain_player_body(body: CharacterBody3D, motion: Vector3, delta: float) -> Vector3:
	if is_defeated or state == State.CHARGE or delta <= 0: return motion
	var offset := body.global_position - global_position
	if offset.y > 1.5 or offset.y < -1.8: return motion
	var sample := body_contact_sample(body.global_position)
	var normal := Vector3(sample.x, 0, sample.z)
	var radial := motion.dot(normal)
	var allowed := sample.w / delta
	if sample.w >= 0 and radial >= -allowed: return motion
	var outward := minf(body_separation_speed, maxf(0, -allowed))
	var minimum := outward if sample.w < 0 else -allowed
	return motion + normal * maxf(0, minimum - radial)

func body_contact_sample(at: Vector3) -> Vector4:
	# Horizontal body shell plus the visible tail; radii include the player capsule.
	var local := to_local(at)
	local.y = 0
	var offset := local
	var gap := offset.length() - body_contact_radius
	var tail_offset := local - Vector3(0, 0, clampf(local.z, 0.65, 1.8))
	var tail_gap := tail_offset.length() - 0.42
	if tail_gap < gap:
		offset = tail_offset
		gap = tail_gap
	var normal := global_basis * (offset.normalized() if offset.length_squared() > 0.0001 else Vector3.RIGHT)
	return Vector4(normal.x, 0, normal.z, gap)

func _on_defeat() -> void:
	cancel_attack("defeated")
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
	if not contact_enabled(): return
	# Tail contact is normal body contact only; the charge hit area stays unchanged.
	if state != State.CHARGE:
		for health in get_tree().get_nodes_in_group("player_health"):
			_resolve_body_contact.call_deferred(weakref(health.get_parent()))
	for body in character_zone.get_overlapping_bodies():
		if body.get_node_or_null("Knockdown") == null: continue
		if body is CarryableCharacter and is_instance_valid(body.holder): continue
		var health := body.get_node_or_null("PlayerHealth") as PlayerHealth
		if health != null and health.is_downed: continue
		if state == State.CHARGE:
			_charge_hit(body)
		elif health != null:
			continue # Deferred above, after this tick's weapon sweeps.
		else:
			if state in [State.REPOSITION, State.CHARGE_RECOVERY]: continue
			if _push_waits.has(body.get_instance_id()): continue
			_push_waits[body.get_instance_id()] = separation_push_interval
			separation_push_count += 1
			var away: Vector3 = body.global_position - global_position
			away.y = 0
			if away.length_squared() < 0.001: away = Vector3.RIGHT
			PhysicsPush.apply(body, away.normalized() * minf(overlap_push / 60.0, 0.3))

func contact_enabled() -> bool:
	return not is_defeated and not damage_reaction_active() and state not in [State.RECOIL, State.STAGGER, State.DEFEATED]

func _resolve_body_contact(reference: WeakRef) -> void:
	var body := reference.get_ref() as CharacterBody3D
	if not is_instance_valid(body) or body.is_queued_for_deletion() or not contact_enabled() or state == State.CHARGE: return
	var id := body.get_instance_id()
	if _contact_waits.has(id): return
	var health := body.get_node_or_null("PlayerHealth") as PlayerHealth
	if health == null or health.is_downed or KnockdownState.blocked(body): return
	var away := body.global_position - global_position
	if away.y > 1.5 or away.y < -1.8: return
	away.y = 0
	var sample := body_contact_sample(body.global_position)
	if sample.w > 0.03 or not can_see(body): return
	away = Vector3(sample.x, 0, sample.z)
	var before := health.current_health
	health.receive_damage(contact_damage, self)
	if health.current_health >= before: return
	_contact_waits[id] = contact_damage_cooldown
	contact_damage_count += 1
	if body.has_method("receive_body_bump"):
		body.receive_body_bump(away.normalized() * contact_knockback)
	else:
		PhysicsPush.apply(body, away.normalized() * contact_knockback)

func _forget_character(body: PhysicsBody3D) -> void:
	if not is_instance_valid(body): return
	_character_pairs.erase(body.get_instance_id())
	_contact_waits.erase(body.get_instance_id())
	remove_collision_exception_with(body)
	body.remove_collision_exception_with(self)

func _exit_tree() -> void:
	_release_recoil_weapon()
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
	if is_defeated: return
	if not is_aggro:
		var nearby := {}
		for health in get_tree().get_nodes_in_group("player_health"):
			var candidate := health.get_parent() as CharacterBody3D
			if not valid_attacker(candidate): continue
			var id := candidate.get_instance_id()
			if global_position.distance_to(candidate.global_position) <= close_threat_distance and can_see(candidate):
				nearby[id] = float(_close_threats.get(id, 0)) + delta
				if nearby[id] >= close_threat_time:
					provoke(candidate)
					break
		_close_threats = nearby
		if not is_aggro: return
	if not valid_attacker(aggro_target):
		clear_aggro()
		return
	player = aggro_target
	if global_position.distance_to(player.global_position) <= player_awareness_radius:
		_sees_player = can_see(player)
	if _sees_player:
		if target_memory <= 0: _route_wait = 0
		target_memory = aggro_memory_time
		last_known_position = player.global_position
	elif target_memory <= 0:
		clear_aggro()

func can_see(candidate: CharacterBody3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.1, candidate.global_position + Vector3.UP, 1)
	query.exclude = [get_rid(), candidate.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func valid_attacker(candidate) -> bool:
	if not is_instance_valid(candidate) or not candidate is CharacterBody3D or candidate.is_queued_for_deletion(): return false
	var health := candidate.get_node_or_null("PlayerHealth") as PlayerHealth
	return health != null and not health.is_downed

func provoke(attacker) -> void:
	if is_defeated or not valid_attacker(attacker): return
	if not is_aggro and state == State.SPAWN: state = State.PURSUIT
	is_aggro = true
	aggro_target = attacker as CharacterBody3D
	player = aggro_target
	target_memory = aggro_memory_time
	last_known_position = player.global_position
	pursuit_route.clear()
	_route_wait = 0
	_close_threats.clear()
	_lane_wait = 0

func clear_aggro() -> void:
	cancel_attack("aggro_ended")
	is_aggro = false
	aggro_target = null
	player = null
	target_memory = 0
	_sees_player = false
	_close_threats.clear()
	pursuit_route.clear()
	route.clear()
	food = null
	destination_zone = -1
	current_zone = nearest_zone(global_position)
	zone_age = 0
	zone_eaten = 0
	_retreating = false
	if state not in [State.RECOIL, State.STAGGER, State.DEFEATED]: state = State.SEEK_FOOD

func receive_damage(amount: float, source: Node = null, instigator = null) -> void:
	if amount > 0: interrupt_approach()
	var before := current_health
	super.receive_damage(amount, source, instigator)
	if current_health < before and not is_defeated: provoke(instigator)

func pursue_player(delta: float) -> Vector3:
	_pursuit_detour_left = maxf(0, _pursuit_detour_left - delta)
	_pursuit_blocked = _pursuit_blocked + delta if global_position.distance_to(_last_position) < 0.008 else 0
	if _route_wait <= 0 or _pursuit_blocked >= combat_stuck_time:
		if _pursuit_blocked >= combat_stuck_time:
			_pursuit_detour_left = 4.0
			_pursuit_blocked = 0
		var goal := last_known_position
		if _sees_player and _clear_attack_lane:
			var away := global_position - last_known_position
			away.y = 0
			goal += away.normalized() * desired_attack_distance
		pursuit_route = pursuit_planner.build(global_position, goal, _pursuit_detour_left > 0)
		_route_wait = combat_repath_interval
	if pursuit_route.is_empty(): return Vector3.ZERO
	var offset := pursuit_route[0] - global_position
	offset.y = 0
	if offset.length() < 0.35:
		pursuit_route.pop_front()
		return Vector3.ZERO
	return offset.normalized() * minf(pursuit_speed, offset.length() * 4)

func receive_impact(amount: float, impulse: Vector3, instigator = null, impact_mass: float = 0, melee_hit: bool = false) -> void:
	if is_defeated: return
	if amount > 0: interrupt_approach()
	last_impact_impulse = impulse
	# Combat impacts have direction; continuous spray remains receive_impulse only.
	# Fresh once-per-swing melee is never suppressed by the environmental/stagger rearm gate.
	var can_recoil := melee_hit or (_recoil_wait <= 0 and (amount < stagger_threshold or _stagger_wait <= 0))
	if impulse.is_finite() and impulse.length_squared() > 0.001 and amount > 0 and can_recoil:
		var direction := Vector3(impulse.x, 0, impulse.z).normalized()
		last_recoil_speed = minf(max_recoil_speed, amount * recoil_damage_scale + impulse.length() / target_mass * 0.25)
		recoil_velocity = direction * last_recoil_speed
		_recoil_left = recoil_duration
		_recoil_wait = recoil_cooldown
		if melee_hit and is_instance_valid(instigator):
			var interaction: Node = instigator.get_node_or_null("Interaction")
			if interaction != null and interaction.held_object is WeaponBody:
				_release_recoil_weapon()
				var weapon: WeaponBody = interaction.held_object
				_recoil_weapon = weakref(weapon)
				add_collision_exception_with(weapon)
				weapon.add_collision_exception_with(self)
				weapon.carry_ended.connect(_release_recoil_weapon)
				weapon.tree_exiting.connect(_release_recoil_weapon)
		if not attack_committed and state != State.STAGGER: state = State.RECOIL
		external_velocity -= direction * minf(0, external_velocity.dot(direction))
	# Preserve shared damage/weak external-force contract without stacking recoil.
	_impact_mass = impact_mass
	super.receive_impact(amount, impulse, instigator, impact_mass, melee_hit)
	_impact_mass = 0

func _release_recoil_weapon() -> void:
	if _recoil_weapon == null: return
	var weapon := _recoil_weapon.get_ref() as WeaponBody
	if is_instance_valid(weapon):
		if weapon.carry_ended.is_connected(_release_recoil_weapon): weapon.carry_ended.disconnect(_release_recoil_weapon)
		if weapon.tree_exiting.is_connected(_release_recoil_weapon): weapon.tree_exiting.disconnect(_release_recoil_weapon)
		remove_collision_exception_with(weapon)
		weapon.remove_collision_exception_with(self)
	_recoil_weapon = null

func combat_distance() -> float:
	var offset := last_known_position - global_position
	offset.y = 0
	return offset.length()

func interrupt_approach() -> void:
	if not is_aggro or attack_phase != AttackPhase.COMBAT_APPROACH: return
	approach_interrupt_count += 1
	pursuit_route.clear()
	_route_wait = 0
	_spacing_grace = post_hit_grace
	state = State.HOLD # Subsequent damage/recoil owns recovery before a fresh decision.

func resume_combat() -> void:
	_route_wait = 0
	_lane_wait = 0
	if not is_aggro or target_memory <= 0:
		state = State.SEEK_FOOD
	else:
		combat_move(0)

func combat_move(delta: float) -> Vector3:
	if attack_committed:
		advance_committed_attack(delta)
		return charge_direction * charge_speed if state == State.CHARGE else Vector3.ZERO
	if not is_aggro or not valid_attacker(aggro_target):
		state = State.SEEK_FOOD
		return Vector3.ZERO
	var distance := combat_distance()
	if _lane_wait <= 0:
		pursuit_planner.refresh_exclusions()
		_clear_attack_lane = _sees_player and pursuit_planner.clear_segment(global_position, last_known_position)
		_lane_wait = 0.2
	var lane := _sees_player and _clear_attack_lane
	var ready := _charge_wait <= 0 and _spacing_grace <= 0
	_retreating = false
	# Only a blocked attack path warrants local repositioning, never proximity alone.
	if not lane and _sees_player and distance < charge_range and _pursuit_detour_left <= 0:
		state = State.REPOSITION
		return reposition_move(delta, distance)
	_reposition_blocked = 0
	var action := CombatDecision.choose(distance, lane, ready, body_contact_radius + 0.15, charge_range)
	match action:
		CombatDecision.Action.ATTACK:
			begin_telegraph()
			return Vector3.ZERO
		CombatDecision.Action.HOLD:
			state = State.HOLD
			return Vector3.ZERO
		_:
			state = State.PURSUIT
			return pursue_player(delta)

func reposition_move(delta: float, _distance: float) -> Vector3:
	var away := global_position - last_known_position
	away.y = 0
	if away.length_squared() < 0.01: away = global_basis.z
	away = away.normalized()
	var side := away.cross(Vector3.UP) * _reposition_side
	_reposition_blocked += delta
	# Bound one adjustment to 0.75m at the default speed, then reuse aisle escape.
	if _reposition_blocked >= 0.375 or (test_move(global_transform, side * 0.7) and test_move(global_transform, -side * 0.7)):
		_reposition_blocked = 0
		_pursuit_detour_left = 1.0
		_route_wait = 0
		state = State.PURSUIT
		return pursue_player(delta)
	if test_move(global_transform, side * 0.7):
		_reposition_side *= -1
		side = -side
	return side * orbit_speed

func cancel_attack(reason: String) -> void:
	# Explicit cancellation is reserved for impossible attacks, never ordinary damage.
	if attack_committed:
		attack_cancel_count += 1
		last_attack_cancel = reason
	attack_committed = false
	_charge_started = false
	_attack_target = null
	_attack_resume_pending = false
	_attack_path_blocked = 0
	telegraph_remaining = 0
	if state in [State.TELEGRAPH, State.CHARGE]: state = State.HOLD

func resume_telegraph() -> void:
	# One logical warning stays visible through the overlay; no enter or timer reset.
	_attack_resume_pending = false
	_attack_path_blocked = 0
	attack_resume_count += 1

func advance_committed_attack(delta: float) -> void:
	if not telegraph_active: return # Executing charge must never re-enter preparation.
	if not is_aggro or not valid_attacker(_attack_target):
		cancel_attack("target_invalid")
		return
	# Recheck from the recoil position, including the full boss width, before execution.
	pursuit_planner.refresh_exclusions()
	var destination := _attack_target.global_position
	var offset := destination - global_position
	offset.y = 0
	var clear := offset.length_squared() > 0.01 and can_see(_attack_target) and pursuit_planner.clear_segment(global_position, destination)
	if not clear:
		_attack_path_blocked += delta
		if _attack_path_blocked >= committed_path_timeout:
			cancel_attack("path_blocked")
			_lane_wait = 0
		return
	last_known_position = destination
	if _attack_resume_pending or _attack_path_blocked > 0:
		resume_telegraph()
		_left = telegraph_remaining
		return # Preserve the exact paused progress on the resume tick.
	telegraph_remaining = maxf(0, telegraph_remaining - delta)
	_left = telegraph_remaining
	if _left > 0: return
	# The warning tracks the current target. Only actual charge motion locks direction.
	charge_direction = offset.normalized()
	look_at(global_position + charge_direction, Vector3.UP)
	# Phase, direction lock, start count and motor all begin on this same tick.
	_charge_started = true
	charge_count += 1
	state = State.CHARGE
	_left = charge_duration
