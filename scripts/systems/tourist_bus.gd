class_name TouristBus
extends Node3D
## External debug event. Passengers retain the ordinary customer business rules.
enum State { IDLE, ARRIVING, UNLOADING, RUSH_ACTIVE, DEPARTING }
@export var tourist_count: int = 10
@export var passenger_spawn_interval: float = 0.4
@export var min_purchase_units: int = 2
@export var max_purchase_units: int = 4
@export var arrival_time: float = 2.0
@export var departure_time: float = 2.0
@export var max_rush_duration: float = 100.0
@export_range(0.1, 1.0) var completion_ratio: float = 0.8
var state: State = State.IDLE
var tourist_buses_arrived: int = 0
var tourist_customers_served: int = 0
var spawned_count: int = 0
var passengers: Array[BasicCustomer] = []
var manager: CustomerManager
var bus: Node3D
var door: Node3D
var _label: Label
var _phase_left: float = 0
var _elapsed: float = 0
var _spawn_left: float = 0
var _target_count: int = 0
var _paid_passengers: Dictionary = {}
var parking_position := Vector3(2, 0, 39)
var road_position := Vector3(16, 0, 39)

func _ready() -> void:
	manager = get_parent().get_node("Customers")
	manager.customer_paid.connect(_on_customer_paid)
	# Extend around the existing 6x4 entrance pad, without coplanar floor overlap.
	var paving := Color(0.24, 0.27, 0.29)
	Graybox.box(self, "ApronLeft", Vector3(3, 0.4, 8), Vector3(-7.5, -0.2, 40), paving)
	Graybox.box(self, "ApronRight", Vector3(15, 0.4, 8), Vector3(7.5, -0.2, 40), paving)
	Graybox.box(self, "ApronRear", Vector3(6, 0.4, 4), Vector3(-3, -0.2, 42), paving)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	canvas.add_child(_label)
	_label.position = Vector2(24, 260) # Below the active checkout panel.
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_tourist_bus") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		start_event()
		get_viewport().set_input_as_handled()

func start_event() -> bool:
	if state != State.IDLE: return false
	passengers.clear()
	spawned_count = 0
	_target_count = clampi(tourist_count, 1, manager.absolute_customer_cap)
	_elapsed = 0
	_spawn_left = 0
	manager.event_spawn_paused = true # Never overwrite the user's U preference.
	_build_bus()
	state = State.ARRIVING
	_phase_left = maxf(0.01, arrival_time)
	_update_label()
	return true

func _build_bus() -> void:
	bus = Node3D.new()
	bus.name = "Bus"
	add_child(bus)
	bus.position = road_position
	Graybox.box(bus, "Body", Vector3(8, 2.6, 2.4), Vector3(0, 1.5, 0), Color(0.95, 0.65, 0.15))
	for x in [-2.5, -1.2, 0.1, 1.4, 2.7]:
		Graybox.box(bus, "Window", Vector3(1, 0.9, 0.04), Vector3(x, 2, -1.22), Color(0.2, 0.55, 0.75), false)
	for x in [-2.6, 2.6]:
		for z in [-1.2, 1.2]:
			Graybox.box(bus, "Wheel", Vector3(0.8, 0.8, 0.16), Vector3(x, 0.45, z), Color(0.08, 0.08, 0.09), false)
	door = Graybox.box(bus, "PassengerDoor", Vector3(0.8, 1.8, 0.06), Vector3(-3.4, 1.15, -1.24), Color(0.15, 0.35, 0.45), false)
	Graybox.sign(bus, "BUS", Vector3(0, 3.1, 0), Color.GOLD)

func spawn_position() -> Vector3:
	return Vector3(-1.4, 0.01, 37)

func _physics_process(delta: float) -> void:
	if state == State.IDLE: return
	_elapsed += delta
	if state == State.ARRIVING:
		_phase_left = maxf(0, _phase_left - delta)
		bus.position = road_position.lerp(parking_position, 1 - _phase_left / maxf(0.01, arrival_time))
		if _phase_left <= 0:
			tourist_buses_arrived += 1
			door.position.x += 0.7
			state = State.UNLOADING
	elif state == State.UNLOADING:
		_spawn_left -= delta
		if _spawn_left <= 0 and spawned_count < _target_count:
			_spawn_left = maxf(0.1, passenger_spawn_interval)
			var passenger := manager.spawn_customer([], null, {
				"tourist": true, "position": spawn_position(),
				"min_units": maxi(1, min_purchase_units), "max_units": maxi(1, max_purchase_units),
				"entry_waypoints": [Vector3(-4.15, 0.01, 37), Vector3(-4.15, 0.01, 34.8)]})
			if passenger != null:
				passengers.append(passenger)
				spawned_count += 1
		if spawned_count >= _target_count: state = State.RUSH_ACTIVE
	elif state == State.RUSH_ACTIVE:
		if completed_count() >= ceili(spawned_count * completion_ratio): _depart()
	elif state == State.DEPARTING:
		_phase_left = maxf(0, _phase_left - delta)
		bus.position = parking_position.lerp(road_position, 1 - _phase_left / maxf(0.01, departure_time))
		if _phase_left <= 0:
			bus.queue_free()
			state = State.IDLE
			manager.event_spawn_paused = false
	# Includes blocked unloading: one blocked doorway must never lock normal business.
	if state != State.DEPARTING and state != State.IDLE and _elapsed >= maxf(arrival_time + 0.1, max_rush_duration): _depart()
	_update_label()

func completed_count() -> int:
	var count := 0
	for customer in passengers:
		if not is_instance_valid(customer) or customer.resolved: count += 1
	return count

func _depart() -> void:
	state = State.DEPARTING
	_phase_left = maxf(0.01, departure_time)
	door.position.x = -3.4

func _on_customer_paid(customer: BasicCustomer) -> void:
	if not customer.get_meta("tourist", false): return
	# Signals fire only after the existing settlement succeeds, including late payments.
	var id := customer.get_instance_id()
	if _paid_passengers.has(id): return
	_paid_passengers[id] = true
	tourist_customers_served += 1
	_update_label()

func _update_label() -> void:
	_label.text = "[B] BUS: %s | PASSENGERS %d/%d | ACTIVE %d | ARRIVED %d / SERVED %d" % [State.keys()[state], spawned_count, _target_count, spawned_count - completed_count(), tourist_buses_arrived, tourist_customers_served]

func _exit_tree() -> void:
	if is_instance_valid(manager): manager.event_spawn_paused = false
