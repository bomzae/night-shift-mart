class_name DayManager
extends Node
## Owns shift lifetime; existing managers continue owning their gameplay.
enum State { PRE_DAY, ACTIVE, ENDING, RESULT, RESETTING }
signal state_changed(state: State)
signal event_started(type: StringName)
var event_banner: EventBanner
var economy_hud: EconomyHud
var starter_stock_count: int = 0
var _intro_step: int = 0
var _intro_retry_hour: float = 1.0
var _intro_cooldown: float = 0
const INTRO_HOURS := {"drunk":1.0,"family":2.5,"thief":4.0,"boss":6.0}
var intro_states: Dictionary = {}
var _intro_actors: Dictionary = {}
var intro_last_event: String = ""
var intro_last_end: String = ""
var intro_spawn_failure: String = ""
@export var drunk_exclusive_hours: float = 1.25
var drunk_slot_release_count: int = 0
var _drunk_slots: Dictionary = {} # Compatibility view of drunk leases; shared records.
var _event_slots: Dictionary = {}
@export var family_exclusive_hours: float = 1.25
@export var thief_exclusive_hours: float = 1.25
var event_slot_release_counts: Dictionary = {}
var intro_spawn_attempts: Dictionary = {}
@export var shift_duration_seconds: float = 1200.0
@export var ending_duration: float = 2.0
@export var timeline_enabled: bool = true
@export var max_active_events: int = 2
var state: State = State.PRE_DAY
var day_number: int = 1
var shift_elapsed_seconds: float = 0
var failed: bool = false
var boss_spawned_today: bool = false
var automatic_events: int = 0
var automatic_bosses: int = 0
var paid_customers: int = 0
var closing_returned_count: int = 0
var closing_returned_value: float = 0
var baseline: Dictionary = {}
var result: Dictionary = {}
var clock_label: Label
var result_panel: Control
var result_label: Label
var _ending_left: float = 0
var _finalizing: bool = false
var _next_event_hour: float = 2.0
var _event_cursor: int = 0
var _boss_retry_hour: float = 6.0
var _homes: Dictionary = {}
var _player_modes: Dictionary = {}
var _start_left: float = 0
@onready var world: Node3D = get_parent()

static func allows_activity(context: Node) -> bool:
	var owner_world := context
	while owner_world != null:
		var day := owner_world.get_node_or_null("DayManager") as DayManager
		if day != null: return day.state == State.ACTIVE
		owner_world = owner_world.get_parent()
	return true # Standalone physics test rooms have no shift lifecycle.

static func notify_event(context: Node, type: StringName) -> void:
	var ancestor := context
	while ancestor != null:
		var day := ancestor.get_node_or_null("DayManager") as DayManager
		if day != null:
			if day.state == State.ACTIVE: day.event_started.emit(type)
			return
		ancestor = ancestor.get_parent()

func _ready() -> void:
	add_to_group("day_manager")
	_build_ui()
	event_banner = EventBanner.new()
	add_child(event_banner)
	event_started.connect(event_banner.announce)
	economy_hud = EconomyHud.new()
	economy_hud.day = self
	add_child(economy_hud)
	world.get_node("TeamLife").day_failed.connect(func(): end_day(true))
	world.get_node("Customers").customer_paid.connect(func(_customer): paid_customers += 1)
	get_tree().node_added.connect(_track_later)
	for node in world.find_children("*", "RigidBody3D", true, false): _remember_home(node)
	if world.starter_stock_enabled: _prepare_first_day()
	else: start_day()

func _prepare_first_day() -> void:
	# Register shelf shapes before querying safe stock slots. No business runs in PRE_DAY.
	await get_tree().physics_frame
	await get_tree().physics_frame
	starter_stock_count = world.get_node("AutoStock").top_up(world.initial_fill_ratio)
	world.get_node("AutoStock")._label.text = "[I] AUTO STOCK"
	# Goods stay real RigidBodies; allow landing and shelf settlement before customers.
	await get_tree().create_timer(1.0, false, true).timeout
	start_day()

func _track_later(node: Node) -> void:
	if node is RigidBody3D: _remember_home.call_deferred(node)
	var kind := _lease_kind(node)
	if not kind.is_empty():
		var slot := {"body":weakref(node),"kind":kind,"hour":elapsed_hours(),"released":false}
		_event_slots[node.get_instance_id()] = slot
		if kind == "drunk": _drunk_slots[node.get_instance_id()] = slot

func _remember_home(node: Node) -> void:
	if not is_instance_valid(node) or not world.is_ancestor_of(node): return
	if node is ShoppingCart or (node is GrabbableBody and node.product_type == &""):
		_homes[node.get_instance_id()] = {"body": weakref(node), "transform": node.global_transform}

func _set_state(value: State) -> void:
	state = value
	state_changed.emit(state)

func elapsed_hours() -> float:
	return clampf(shift_elapsed_seconds / maxf(0.1, shift_duration_seconds), 0, 1) * 8.0

func clock_text() -> String:
	var minutes := 22 * 60 + int(floor(elapsed_hours() * 60.0 + 0.00001))
	return "%02d:%02d" % [(minutes / 60) as int % 24, minutes % 60]

func timeline_phase() -> String:
	var hour := elapsed_hours()
	if hour < (1.0 if day_number == 1 else 2.0): return "NORMAL WORK"
	if hour < 4: return "LIGHT EVENTS"
	if hour < 6: return "LATE EVENTS"
	if hour < 7.5: return "BOSS WINDOW"
	return "CLOSING"

func start_day() -> void:
	shift_elapsed_seconds = 0
	failed = false
	_finalizing = false
	boss_spawned_today = false
	automatic_events = 0
	automatic_bosses = 0
	_next_event_hour = 2.0
	_boss_retry_hour = 6.0
	_event_cursor = 0
	_intro_step = 0
	intro_states = {"drunk":"NOT_STARTED","family":"NOT_STARTED","thief":"NOT_STARTED","boss":"NOT_STARTED"}
	_intro_actors.clear()
	intro_last_event = ""
	intro_last_end = ""
	intro_spawn_failure = ""
	_drunk_slots.clear()
	_event_slots.clear()
	event_slot_release_counts.clear()
	intro_spawn_attempts.clear()
	drunk_slot_release_count = 0
	_intro_retry_hour = 1.0
	_intro_cooldown = 0
	event_banner.clear_pending()
	result = {}
	var team = world.get_node("TeamLife")
	team.day_failed_active = false
	team.current_day = day_number
	for health in team.players:
		if not is_instance_valid(health): continue
		health.reset_for_day()
		if health.get_parent().has_method("reset_stance"): health.get_parent().reset_stance()
		var body: Node = health.get_parent()
		if _player_modes.has(body.get_instance_id()): body.process_mode = _player_modes[body.get_instance_id()]
		if body.get("external_velocity") != null:
			body.knockdown.phase = KnockdownState.Phase.UPRIGHT
			body.knockdown.elapsed = 0
			body.external_velocity = Vector3.ZERO
			body.body_bump_velocity = Vector3.ZERO
			body.body_bump_left = 0
			body.fire_reaction.remaining = 0
			body.fire_reaction.cooldown_left = 0
			body.fire_reaction._show(false)
		var slip := body.get_node_or_null("SlipState") as SlipState
		if slip != null:
			slip.sources.clear()
			slip.refresh()
	_player_modes.clear()
	var customers = world.get_node("Customers")
	customers.spawning_enabled = true
	customers.event_spawn_paused = false
	customers._reset_timer()
	var delivery = world.get_node("Delivery")
	delivery._timer = delivery.first_delivery_delay
	delivery.summary_left = 0
	delivery.last_result = {}
	baseline = _stats()
	result_panel.hide()
	_start_left = 2.0
	_set_state(State.ACTIVE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_clock()

func end_day(as_failure: bool = false) -> void:
	if state != State.ACTIVE: return
	failed = as_failure
	_ending_left = maxf(0.1, ending_duration)
	_set_state(State.ENDING)
	event_banner.clear_pending()
	world.get_node("Customers").spawning_enabled = false
	# Settle the live shipment using the ordinary pallet accounting first.
	var delivery = world.get_node("Delivery")
	if delivery.truck_present: delivery.depart()
	_update_clock()

func confirm_result() -> void:
	if state != State.RESULT: return
	_set_state(State.RESETTING)
	day_number += 1
	_reset_persistent_bodies()
	start_day()

func _input(event: InputEvent) -> void:
	if state == State.RESULT:
		get_viewport().set_input_as_handled()
		if not event.is_echo() and (event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_E])):
			confirm_result.call_deferred()
	elif state == State.ACTIVE and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		shift_elapsed_seconds = minf(shift_duration_seconds, shift_elapsed_seconds + shift_duration_seconds / 8.0)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if state == State.ACTIVE:
		_intro_cooldown = maxf(0, _intro_cooldown - delta)
		shift_elapsed_seconds = minf(shift_duration_seconds, shift_elapsed_seconds + delta)
		_start_left = maxf(0, _start_left - delta)
		if is_instance_valid(world.get_node("Bosses").boss): boss_spawned_today = true
		if shift_elapsed_seconds >= shift_duration_seconds: end_day()
		elif timeline_enabled: _tick_timeline()
	elif state == State.ENDING:
		_ending_left -= delta
		if _ending_left <= 0 and not _finalizing:
			_finalizing = true # Stay ENDING while queued actors leave the tree.
			_finish_day.call_deferred()
	_update_clock()

func active_event_count() -> int:
	var count := 0
	for node in world.find_children("*", "Node3D", true, false):
		if node.is_queued_for_deletion(): continue
		if node is DrunkCustomer or node is LostChild or node is ThiefCustomer or node is AccidentCustomer or node is DangerousCustomer: count += 1
	if world.get_node("TouristBus").state != TouristBus.State.IDLE: count += 1
	if not world.get_node("Fires").fires.is_empty(): count += 1
	return count

func _tick_timeline() -> void:
	if day_number == 1:
		_tick_introduction()
		return
	var hour := elapsed_hours()
	if hour >= 6 and hour < 7.5 and not boss_spawned_today and hour >= _boss_retry_hour:
		_boss_retry_hour = hour + 0.1
		if world.get_node("Bosses").spawn_boss() != null:
			boss_spawned_today = true
			automatic_bosses += 1
	if hour < _next_event_hour or hour >= 7.5: return
	_next_event_hour = hour + (1.0 if hour < 4 else 0.75)
	if active_event_count() >= max_active_events: return
	var events: Array = [["Drunks", "spawn_drunk"], ["LostFamilies", "spawn_pair"], ["Accidents", "spawn_accident"]] if hour < 4 else [["Thieves", "spawn_thief"], ["Fires", "spawn_dangerous"], ["TouristBus", "start_event"], ["Accidents", "spawn_accident"]]
	var choice: Array = events[_event_cursor % events.size()]
	_event_cursor += 1
	var spawned = world.get_node(choice[0]).call(choice[1])
	if (typeof(spawned) == TYPE_BOOL and spawned) or (typeof(spawned) == TYPE_OBJECT and is_instance_valid(spawned)): automatic_events += 1

func _lease_kind(actor: Node) -> String:
	if actor is DrunkCustomer: return "drunk"
	if actor is LostChild: return "family"
	if actor is ThiefCustomer: return "thief"
	return ""

func _goal_resolved(actor: Node) -> bool:
	if actor is LostChild: return actor.reunited
	if actor is ThiefCustomer: return actor.theft_state == ThiefCustomer.TheftState.CAPTURED
	return false

func _lease_blocks(actor: Node) -> bool:
	if _goal_resolved(actor): return false
	var slot: Dictionary = _event_slots.get(actor.get_instance_id(),{})
	if slot.is_empty(): return true
	if slot.released: return false
	var grace: float = {"drunk":drunk_exclusive_hours,"family":family_exclusive_hours,"thief":thief_exclusive_hours}[slot.kind]
	if elapsed_hours()-float(slot.hour) < grace: return true
	slot.released = true
	event_slot_release_counts[slot.kind] = int(event_slot_release_counts.get(slot.kind,0))+1
	if slot.kind == "drunk": drunk_slot_release_count += 1
	print("EVENT SLOT RELEASED kind=",slot.kind," id=",actor.get_instance_id()," clock=",clock_text()," unresolved=",not _goal_resolved(actor))
	return false

func introduction_event_count() -> int:
	# World actors keep their lifecycle. Only the finite scheduling lease expires.
	var count := active_event_count()
	for id in _event_slots.keys():
		var slot: Dictionary = _event_slots[id]
		var actor: Node = slot.body.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			_event_slots.erase(id)
			_drunk_slots.erase(id)
			continue
		if not _lease_blocks(actor): count -= 1
	return maxi(0,count)

func _tick_introduction() -> void:
	_refresh_intro_states()
	var hour := elapsed_hours()
	if hour >= 7.5 or hour < _intro_retry_hour or _intro_cooldown > 0 or event_banner.busy(): return
	if introduction_event_count() > 0 or max_active_events <= 0: return
	if is_instance_valid(world.get_node("Bosses").boss): return
	# One automatic special event at a time. A late boss has priority over missed introductions.
	if hour >= 6:
		_intro_retry_hour = hour + 0.1
		if not boss_spawned_today:
			var spawned = world.get_node("Bosses").spawn_boss()
			_record_intro_attempt("boss",spawned,world.get_node("Bosses").last_spawn_failure)
			if spawned == null: return
			boss_spawned_today = true
			automatic_bosses += 1
			for kind in ["drunk", "family", "thief"]:
				if intro_states[kind] in ["NOT_STARTED", "ELIGIBLE", "FAILED_TO_SPAWN"]:
					intro_states[kind] = "SKIPPED_LATE_WINDOW"
					print("INTRO SKIPPED late window: ", kind)
		return
	var schedule := [[1.0, "Drunks", "spawn_drunk"], [2.5, "LostFamilies", "spawn_pair"], [4.0, "Thieves", "spawn_thief"]]
	if _intro_step >= schedule.size() or hour < float(schedule[_intro_step][0]): return
	var event: Array = schedule[_intro_step]
	_intro_retry_hour = hour + 0.1
	var spawned = world.get_node(event[1]).call(event[2])
	var kind: String = ["drunk","family","thief"][_intro_step]
	_record_intro_attempt(kind,spawned,world.get_node("Thieves").last_spawn_failure if kind == "thief" else "spawn_unavailable")
	if spawned != null:
		automatic_events += 1
		_intro_step += 1
		_intro_cooldown = 12.0 # Real seconds: debug time skips cannot stack introductions.

func _record_intro_attempt(kind: String, actor: Node, failure: String) -> void:
	intro_spawn_attempts[kind] = int(intro_spawn_attempts.get(kind,0))+1
	if not is_instance_valid(actor):
		intro_states[kind] = "FAILED_TO_SPAWN"
		intro_spawn_failure = kind+":"+failure
		return # The schedule cursor/quota is consumed only after successful spawn.
	intro_states[kind] = "ACTIVE"
	_intro_actors[kind] = weakref(actor)
	intro_last_event = kind
	intro_spawn_failure = ""

func _refresh_intro_states() -> void:
	for kind in INTRO_HOURS:
		var status: String = intro_states.get(kind,"NOT_STARTED")
		if status == "NOT_STARTED" and elapsed_hours() >= INTRO_HOURS[kind]: intro_states[kind] = "ELIGIBLE"
		if status != "ACTIVE" or not _intro_actors.has(kind): continue
		var actor: Node = _intro_actors[kind].get_ref()
		var resolved := not is_instance_valid(actor) or actor.is_queued_for_deletion()
		if not resolved and actor is LostChild: resolved = actor.reunited
		if not resolved and actor is KingRat: resolved = actor.is_defeated
		if resolved:
			intro_states[kind] = "RESOLVED"
			intro_last_end = clock_text()
			print("INTRO RESOLVED ",kind," at=",intro_last_end)

func introduction_status() -> Dictionary:
	var owners: Array[String] = []
	var leases: Array[Dictionary] = []
	introduction_event_count() # Prune freed actors and record one-time lease expiry.
	for slot in _event_slots.values():
		var actor: Node = slot.body.get_ref()
		if not is_instance_valid(actor): continue
		var blocks := _lease_blocks(actor)
		if blocks: owners.append(slot.kind+":"+str(actor.get_instance_id()))
		leases.append({"kind":slot.kind,"resolved":_goal_resolved(actor),"released":slot.released,"blocks":blocks,"age_hours":elapsed_hours()-float(slot.hour)})
	var next: String = "boss" if elapsed_hours() >= 6 else (["drunk","family","thief"][_intro_step] if _intro_step < 3 else "boss")
	var blocked := "ready"
	if state != State.ACTIVE: blocked = "shift_inactive"
	elif max_active_events <= 0: blocked = "events_disabled"
	elif introduction_event_count() > 0: blocked = "exclusive_event"
	elif is_instance_valid(world.get_node("Bosses").boss): blocked = "boss_present"
	elif _intro_cooldown > 0: blocked = "minimum_spacing"
	elif event_banner.busy(): blocked = "notification"
	elif elapsed_hours() < _intro_retry_hour: blocked = "retry_wait"
	elif elapsed_hours() < INTRO_HOURS[next]: blocked = "before_schedule"
	return {"clock":clock_text(),"states":intro_states.duplicate(),"leases":leases,"attempts":intro_spawn_attempts.duplicate(),"owners":owners,"blocked":blocked,"next":next,"last_event":intro_last_event,"last_end":intro_last_end,"spacing":_intro_cooldown,"failure":intro_spawn_failure,"entities":active_event_count(),"exclusive":introduction_event_count(),"thief_eligible":elapsed_hours()>=4 and _intro_step==2,"boss_eligible":elapsed_hours()>=6 and not boss_spawned_today}

func _stats() -> Dictionary:
	return {"sales": world.get_node("Customers").sales, "unpaid": world.get_node("Customers").unpaid_loss,
		"stolen": world.get_node("Thieves").stolen_goods_value, "fire": world.get_node("Fires").fire_damage_value,
		"boss": world.get_node("Bosses").boss_product_loss_value, "broken": world.get_node("Drunks").broken_product_value,
		"food": world.get_node("TeamLife").consumed_product_value, "served": paid_customers,
		"tourists": world.get_node("TouristBus").tourist_customers_served, "caught": world.get_node("Thieves").thieves_caught,
		"children": world.get_node("LostFamilies").lost_children_found, "fires": world.get_node("Fires").fires_extinguished,
		"defeated": world.get_node("Bosses").bosses_defeated, "returns": closing_returned_count, "return_value": closing_returned_value}

func _finish_day() -> void:
	_cleanup_runtime()
	# Actor deletion runs before Result; managers/geometry and cumulative totals survive.
	await get_tree().process_frame
	result = _stats()
	for key in result: result[key] -= baseline.get(key, 0)
	result["net"] = result.sales - result.unpaid - result.stolen - result.fire - result.boss - result.broken - result.food
	result["day"] = day_number
	result["failed"] = failed
	result["time"] = clock_text()
	_set_state(State.RESULT)
	for health in world.get_node("TeamLife").players:
		if not is_instance_valid(health): continue
		var body: Node = health.get_parent()
		_player_modes[body.get_instance_id()] = body.process_mode
		body.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ("NIGHT %d %s\n%s\n\n" % [day_number, "FAILED" if failed else "COMPLETE", "ALL WORKERS DOWN" if failed else "06:00 — SHIFT CLOSED"]) + ("SALES  $%.0f\nLOSSES  Unpaid $%.0f / Stolen $%.0f\nFire $%.0f / Boss $%.0f / Broken $%.0f\nFood consumed $%.0f\nPROTOTYPE NET  $%.0f\n\nCUSTOMERS PAID  %d  (Tourists %d)\nThieves caught %d / Children found %d\nFires extinguished %d / Bosses defeated %d\nClosing returns %d items ($%.0f, no penalty)\n\n[E / ENTER]  NEXT DAY" % [result.sales, result.unpaid, result.stolen, result.fire, result.boss, result.broken, result.food, result.net, result.served, result.tourists, result.caught, result.children, result.fires, result.defeated, result.returns, result.return_value])
	result_panel.show()

func _cleanup_runtime() -> void:
	for health in world.get_node("TeamLife").players:
		if not is_instance_valid(health): continue
		var interaction: Node = health.get_parent().get_node_or_null("Interaction")
		if interaction != null: interaction.reset_for_shift()
	var customers = world.get_node("Customers")
	for customer in customers.customers:
		if not is_instance_valid(customer): continue
		closing_returned_count += customer.picked_items.size()
		closing_returned_value += customers.basket_total(customer)
		customer.picked_items.clear()
		customer.resolved = true
		customers.release_claims(customer)
		customer.queue_free()
	customers.customers.clear()
	customers.queue.clear()
	customers._claims.clear()
	var families = world.get_node("LostFamilies")
	families._release_exceptions(null, null, true)
	families.pairs.clear()
	var bosses = world.get_node("Bosses")
	if is_instance_valid(bosses.boss): bosses.boss.queue_free()
	bosses.boss = null
	world.get_node("TouristBus").reset_for_shift()
	for actor in world.find_children("*", "Node3D", true, false):
		if actor is ThiefCustomer:
			if not actor.stolen_item.is_empty():
				closing_returned_count += 1
				closing_returned_value += float(actor.stolen_item.get("price", 0))
				actor.stolen_item.clear()
			customers.release_claims(actor)
		if actor is BasicCustomer:
			customers.release_claims(actor)
		if actor is CarryableCharacter or actor is BasicCustomer or actor.is_in_group("fires") or actor.is_in_group("spills"): actor.queue_free()
	var fires = world.get_node("Fires")
	fires.fires.clear()
	fires._heat.clear()
	fires._spread_heat.clear()
	fires._panic.clear()
	fires._damage_clock = 0
	fires._spread_clock = 0
	var kept: Dictionary = {}
	for shelf in world.get_node("Shelves").get_children():
		if not shelf is StockShelf: continue
		for product in shelf.stocked_objects:
			if shelf.has_stock(product): kept[product.get_instance_id()] = true
	for product in world.find_children("*", "RigidBody3D", true, false):
		if product is GrabbableBody and product.product_type != &"" and not kept.has(product.get_instance_id()): product.queue_free()
	var weapons = world.get_node("Delivery/WeaponDelivery")
	weapons.pending = false
	weapons.order_left = 0

func _reset_persistent_bodies() -> void:
	for id in _homes.keys():
		var body: RigidBody3D = _homes[id].body.get_ref()
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			_homes.erase(id)
			continue
		if body.get("holder") != null: body.end_carry()
		body.global_transform = _homes[id].transform
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
		if body is GrabbableBody:
			body._armed_seconds = 0
			body.throw_damage = 0
			body._recent_velocities.clear()
		if body is WeaponBody:
			body.swing_left = 0
			body.cooldown_left = 0
			body.hit_stop_left = 0
			body.hit_feedback = 0
			body.swing_hits.clear()
		if body is ShoppingCart:
			body.cargo.clear()
			body.drive_velocity = Vector3.ZERO
			body._launch_remaining = 0
			body._launch_hits.clear()
			body._recent_velocities.clear()
			body._impact_wait = 0

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	clock_label = Label.new()
	canvas.add_child(clock_label)
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -300
	clock_label.offset_right = -24
	clock_label.offset_top = 12
	clock_label.offset_bottom = 60
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.add_theme_font_size_override("font_size", 16)
	result_panel = ColorRect.new()
	result_panel.color = Color(0.025, 0.035, 0.055, 0.97)
	canvas.add_child(result_panel)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_label = Label.new()
	result_panel.add_child(result_label)
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_label.offset_left = -340
	result_label.offset_right = 340
	result_label.offset_top = -260
	result_label.offset_bottom = 260
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 22)
	result_panel.hide()

func _update_clock() -> void:
	var notice := ""
	if state == State.ENDING: notice = "DAY FAILED" if failed else "SHIFT CLOSED"
	elif state == State.ACTIVE:
		if _start_left > 0: notice = "SHIFT START"
		elif elapsed_hours() >= 7: notice = "SHIFT ENDS SOON"
	clock_label.text = "DAY %d  %s\n%s" % [day_number, clock_text(), notice]
