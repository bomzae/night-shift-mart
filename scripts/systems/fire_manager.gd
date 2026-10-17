class_name FireManager
extends Node3D

@export var enable_dangerous_test_spawn: bool = true
@export var max_dangerous_customers: int = 2
@export var max_active_fires: int = 10
@export var minimum_fire_spacing: float = 1.2
@export var damage_interval: float = 0.5
@export var burn_exposure: float = 6.0
@export var spread_interval: float = 2.0
@export var spread_exposure: float = 3.0
@export var spread_intensity: float = 0.55
@export var spread_distance: float = 2.6
@export var fire_reaction_cooldown: float = 1.1
@export var player_reaction_duration: float = 0.3
@export var npc_reaction_duration: float = 0.65
@export var retreat_speed: float = 2.6
var fires_created: int = 0
var fires_extinguished: int = 0
var fire_damage_value: float = 0
var fires: Array[FireZone] = []
var _heat: Dictionary = {}
var _spread_heat: Dictionary = {}
var _panic: Dictionary = {}
var _damage_clock: float = 0
var _spread_clock: float = 0
var _label: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	canvas.add_child(_label)
	_label.position = Vector2(24, 118)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if enable_dangerous_test_spawn and event.is_action_pressed("debug_spawn_dangerous") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_dangerous()
		get_viewport().set_input_as_handled()

func spawn_dangerous(requested: Array[StringName] = []) -> DangerousCustomer:
	var customers: CustomerManager = get_parent().get_node("Customers")
	var count := 0
	for customer in customers.customers:
		if customer is DangerousCustomer: count += 1
	if count >= max_dangerous_customers: return null
	var customer := customers.spawn_customer(requested, preload("res://scenes/interactables/dangerous_customer.tscn")) as DangerousCustomer
	if customer != null: customer.fire_manager = self
	return customer

func create_fire(at: Vector3, excluded: Array[RID] = []) -> FireZone:
	_prune()
	if fires.size() >= max_active_fires: return null
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at - Vector3.UP * 2.5, 1, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.9: return null
	for fire in fires:
		if fire.global_position.distance_to(hit.position) < minimum_fire_spacing: return null
	var fire: FireZone = preload("res://scenes/interactables/fire_zone.tscn").instantiate()
	add_child(fire)
	fire.global_position = hit.position
	fire.extinguished.connect(func():
		fires_extinguished += 1
		_update_label())
	fires.append(fire)
	fires_created += 1
	_update_label()
	return fire

func _prune() -> void:
	fires = fires.filter(func(fire): return is_instance_valid(fire) and not fire.is_queued_for_deletion())

func visible_between(from: Vector3, to: Vector3, excluded: Array[RID] = []) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1 | HumanSeparation.HUMAN_LAYER, excluded)).is_empty()

func _physics_process(delta: float) -> void:
	_prune()
	for id in _panic.keys():
		_panic[id] -= delta
		if _panic[id] <= 0: _panic.erase(id)
	_damage_clock += delta
	_spread_clock += delta
	# Contact reactions are checked every physics tick, independent of burn ticks.
	for fire in fires:
		for body in fire.get_overlapping_bodies():
			if not body.get("fire_reaction") is FireReaction: continue
			var target: Vector3 = body.global_position + (Vector3.UP * 0.8 if body is CharacterBody3D else Vector3.ZERO)
			if visible_between(fire.global_position + Vector3.UP * 0.5, target, [body.get_rid()]): _react(body, fire)
	if _damage_clock < damage_interval: return
	var elapsed := _damage_clock
	_damage_clock = 0
	var exposure := {}
	var candidates := {}
	for fire in fires:
		for body in fire.get_overlapping_bodies():
			# CharacterBody origins are feet and may sit microscopically inside
			# the floor after sliding. Check the torso, not an occluded foot point.
			var target_position: Vector3 = body.global_position + (Vector3.UP * 0.8 if body is CharacterBody3D else Vector3.ZERO)
			if not visible_between(fire.global_position + Vector3.UP * 0.5, target_position, [body.get_rid()]): continue
			if _burnable(body): exposure[body] = maxf(exposure.get(body, 0), fire.intensity)
		if fire.intensity >= spread_intensity:
			for body in get_tree().get_nodes_in_group("grabbable"):
				if not _burnable(body) or body.global_position.distance_to(fire.global_position) > spread_distance: continue
				if visible_between(fire.global_position + Vector3.UP * 0.5, body.global_position, [body.get_rid()]): candidates[body] = true
	for body in _heat.keys():
		if not is_instance_valid(body) or body.is_queued_for_deletion(): _heat.erase(body)
	for body in _heat:
		if is_instance_valid(body) and not exposure.has(body):
			var mark: Label3D = body.get_node_or_null("BurnFeedback")
			if mark != null: mark.visible = false
	for body in exposure:
		_heat[body] = _heat.get(body, 0.0) + exposure[body] * elapsed
		_burn_feedback(body, minf(1, _heat[body] / maxf(0.01, burn_exposure)))
		if _heat[body] >= burn_exposure:
			_destroy_feedback(body)
			body.set_meta("broken", true)
			fire_damage_value += body.price
			body.queue_free()
			_heat.erase(body)
			_update_label()
	for body in _spread_heat.keys():
		if not is_instance_valid(body) or not candidates.has(body): _spread_heat.erase(body)
	for body in candidates:
		if _burnable(body): _spread_heat[body] = _spread_heat.get(body, 0.0) + elapsed
	if _spread_clock >= spread_interval:
		_spread_clock = 0
		for body in _spread_heat:
			if _burnable(body) and _spread_heat[body] >= spread_exposure:
				if create_fire(body.global_position, [body.get_rid()]) != null: break

func _burnable(body: Node) -> bool:
	return is_instance_valid(body) and body is GrabbableBody and body.flammable and body.product_type != &"" and not body.is_queued_for_deletion() and not body.get_meta("broken", false) and not body.get_meta("sold", false)

func _react(body: PhysicsBody3D, fire: FireZone) -> void:
	var reaction = body.get("fire_reaction")
	if not reaction is FireReaction: return
	reaction.cooldown = fire_reaction_cooldown
	reaction.duration = player_reaction_duration if body.has_node("Interaction") else npc_reaction_duration
	reaction.retreat_speed = retreat_speed
	if reaction.begin(fire.global_position):
		_panic[body.get_instance_id()] = fire_reaction_cooldown

func _burn_feedback(body: GrabbableBody, progress: float) -> void:
	var mark := body.get_node_or_null("BurnFeedback") as Label3D
	if mark == null:
		mark = Graybox.sign(body, "", Vector3.ZERO, Color.ORANGE_RED)
		mark.name = "BurnFeedback"
		mark.pixel_size = 0.004
	mark.visible = true
	# Keep the indicator above the opaque graybox flame, even if goods rotate.
	mark.global_position = body.global_position + Vector3.UP * 2.2
	mark.text = "🔥 %.0f%%" % (progress * 100)

func _destroy_feedback(body: GrabbableBody) -> void:
	var mark := Graybox.sign(self, "🔥 -$%.0f" % body.price, Vector3.ZERO, Color.ORANGE_RED)
	mark.global_position = body.global_position + Vector3.UP * 2.2
	var tween := create_tween()
	tween.tween_property(mark, "position:y", mark.position.y + 0.5, 0.65)
	tween.parallel().tween_property(mark, "modulate:a", 0.0, 0.65)
	tween.tween_callback(mark.queue_free)
func _update_label() -> void:
	_label.text = "[P] FIRE %d / OUT %d / FIRE LOSS: $%.0f" % [fires_created, fires_extinguished, fire_damage_value]
