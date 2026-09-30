class_name LostParent
extends BasicCustomer

var family_id: int
var family_symbol: Label3D
var reunited: bool = false
var handoff_ready: bool = false
var exit_arrived: bool = false
var exit_direction: Vector3 = Vector3.FORWARD

func uses_customer_separation() -> bool:
	return not reunited

func _physics_process(delta: float) -> void:
	if not knockdown.active() and state == State.EXIT and not waypoints.is_empty():
		var direction := waypoints[0] - global_position
		direction.y = 0
		if direction.length() > 0.05:
			exit_direction = direction.normalized()
			look_at(global_position + exit_direction, Vector3.UP)
	super._physics_process(delta)

func _ready() -> void:
	state = State.EVENT_WAIT
	super._ready()
	move_speed = 1.5
	knockdown.minimum_fall_speed = 1.3

func update_mood() -> void:
	if is_instance_valid(_mood):
		_mood.text = "♥" if reunited else ("✓" if handoff_ready else "? :(")
		_mood.modulate = Color.PINK if reunited else (Color.LIME_GREEN if handoff_ready else Color.WHITE)

func finish_exit() -> void:
	exit_arrived = true
	state = State.EVENT_WAIT
