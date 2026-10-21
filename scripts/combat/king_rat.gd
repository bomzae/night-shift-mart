class_name KingRat
extends CombatTarget
enum State { SPAWN, SEEK_FOOD, MOVE_TO_FOOD, EAT, TELEGRAPH, CHARGE, STAGGER, DEFEATED }
@export var move_speed: float = 2.4
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
@export var food_search_radius: float = 24.0
@export var overlap_push: float = 12.0

func _ready() -> void:
	super._ready()
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
		if score < best:
			best = score
			food = body
	if food == null: return
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
	elif state == State.SPAWN or state == State.STAGGER:
		if _left <= 0: state = State.SEEK_FOOD
	elif state == State.TELEGRAPH:
		if _left <= 0:
			state = State.CHARGE
			_left = charge_duration
	elif state == State.CHARGE:
		desired = charge_direction * charge_speed
		if _left <= 0: state = State.SEEK_FOOD
	else:
		if is_instance_valid(player) and _charge_wait <= 0 and global_position.distance_to(player.global_position) <= charge_range:
			begin_telegraph()
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
	velocity.x = desired.x + external_velocity.x
	velocity.z = desired.z + external_velocity.z
	velocity.y = 0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var body := get_slide_collision(i).get_collider()
		if state == State.CHARGE: _charge_hit(body)
		if body is RigidBody3D and desired.length() > 0.1:
			PhysicsPush.apply(body, desired.normalized() * (60 if state == State.CHARGE else 12) * delta)
		elif body is BasicCustomer and desired.length() > 0.1:
			PhysicsPush.apply(body, desired.normalized() * 12 * delta)
	if desired.length() > 0.1: look_at(global_position + desired, Vector3.UP)
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

func _character_contacts(delta: float) -> void:
	if is_defeated: return
	for body in character_zone.get_overlapping_bodies():
		if body.get_node_or_null("Knockdown") == null: continue
		if body is CarryableCharacter and is_instance_valid(body.holder): continue
		if state == State.CHARGE:
			_charge_hit(body)
		else:
			var away: Vector3 = body.global_position - global_position
			away.y = 0
			if away.length_squared() < 0.001: away = Vector3.RIGHT
			PhysicsPush.apply(body, away.normalized() * overlap_push * delta)

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
