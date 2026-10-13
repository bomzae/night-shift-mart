class_name ThiefCustomer
extends BasicCustomer

enum TheftState { APPROACH, STEAL, ESCAPING, CAPTURED, LEAVING }
@export var escape_speed: float = 3.8
@export var steal_time: float = 0.6
@export var capture_distance: float = 1.8
@export var capture_feedback_time: float = 0.7
var theft_state := TheftState.APPROACH
var theft_manager: Node
var target_product: GrabbableBody
var target_shelf: StockShelf
var stolen_item: Dictionary = {}
var _steal_left: float = 0
var _capture_left: float = 0
var loot_icon: MeshInstance3D

func _ready() -> void:
	state = State.EXIT # Reuse waypoint walking without purchase/queue logic.
	super._ready()
	_mesh.material_override.albedo_color = Color(0.42, 0.46, 0.53)
	add_to_group("thieves")
	update_mood()

func _physics_process(delta: float) -> void:
	if theft_state == TheftState.CAPTURED:
		_capture_left -= delta
		velocity = Vector3.ZERO
		if _capture_left <= 0: queue_free()
		return
	if knockdown.active() or fire_reaction.active():
		super._physics_process(delta)
		return
	if theft_state == TheftState.APPROACH or theft_state == TheftState.STEAL:
		if not is_instance_valid(target_product) or not target_shelf.has_stock(target_product):
			leave_empty()
	if theft_state == TheftState.STEAL:
		var facing := target_shelf.global_position
		facing.y = global_position.y
		look_at(facing)
		_steal_left -= delta
		if _steal_left <= 0: steal()
	# Physical tools/products can shove the same NPC motor; no scripted stun.
	for body in _contact_zone.get_overlapping_bodies():
		if body is RigidBody3D and not body is ShoppingCart:
			var away := global_position - body.global_position
			away.y = 0
			var closing: float = body.linear_velocity.dot(away.normalized())
			if closing > 0.1: apply_external_impulse(away.normalized() * minf(5, closing * body.mass) * delta * 8)
	super._physics_process(delta)

func finish_exit() -> void:
	if theft_state == TheftState.APPROACH:
		theft_state = TheftState.STEAL
		state = State.EVENT_WAIT
		_steal_left = steal_time
	else:
		theft_manager.finish_escape(self)

func steal() -> void:
	if theft_state != TheftState.STEAL: return
	if not is_instance_valid(target_product) or not target_shelf.has_stock(target_product):
		leave_empty()
		return
	stolen_item = theft_manager.snapshot(target_product)
	if stolen_item.is_empty():
		leave_empty()
		return
	loot_icon = MeshInstance3D.new()
	loot_icon.mesh = target_product.get_node("Mesh").mesh
	loot_icon.material_override = target_product.get_node("Mesh").material_override
	loot_icon.scale = Vector3.ONE * 0.45
	loot_icon.position = Vector3(0, 1.95, 0)
	add_child(loot_icon)
	target_product.set_meta("stolen", true)
	target_product.hide()
	target_product.queue_free() # Existing sale/fire validation rejects queued nodes.
	target_shelf.refresh_stock(0)
	target_shelf.release_shopping_point(self)
	theft_state = TheftState.ESCAPING
	move_speed = escape_speed
	start_exit()

func leave_empty() -> void:
	if is_instance_valid(target_shelf): target_shelf.release_shopping_point(self)
	theft_state = TheftState.LEAVING
	start_exit()

func start_exit() -> void:
	super.start_exit()
	var outside: Vector3 = theft_manager.escape_position()
	if absf(global_position.x - outside.x) < 1.2 and global_position.z >= 10.5:
		waypoints.clear()
	# Normal customer's final waypoint is inside the entrance; theft resolves outside.
	waypoints.append(outside)

func capturable() -> bool:
	return theft_state == TheftState.ESCAPING and not resolved and not stolen_item.is_empty()

func capture(player_body: CharacterBody3D) -> bool:
	if not capturable() or KnockdownState.blocked(player_body): return false
	if player_body.global_position.distance_to(global_position) > capture_distance: return false
	if not theft_manager.recover(self, player_body): return false
	resolved = true
	theft_state = TheftState.CAPTURED
	state = State.EVENT_WAIT
	_capture_left = capture_feedback_time
	velocity = Vector3.ZERO
	fire_reaction.remaining = 0
	fire_reaction.cooldown_left = capture_feedback_time + 1
	fire_reaction.tick(0)
	if is_instance_valid(loot_icon): loot_icon.hide()
	update_mood()
	return true

func update_mood() -> void:
	if not is_instance_valid(_mood): return
	_mood.text = "✓" if theft_state == TheftState.CAPTURED else ("!!" if theft_state == TheftState.ESCAPING else ":|")
	_mood.modulate = Color.LIME_GREEN if theft_state == TheftState.CAPTURED else (Color.ORANGE_RED if theft_state == TheftState.ESCAPING else Color.WHITE)

func _exit_tree() -> void:
	if is_instance_valid(target_shelf): target_shelf.release_shopping_point(self)
	super._exit_tree()
