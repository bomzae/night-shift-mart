class_name AccidentCustomer
extends BasicCustomer

@export var embarrassment_time: float = 0.8
var accident_manager: Node
var accident_triggered: bool = false
var _embarrassed_left: float = 0.0

func _physics_process(delta: float) -> void:
	if knockdown.active():
		super._physics_process(delta)
		return
	_embarrassed_left = maxf(0, _embarrassed_left - delta)
	var regular_speed := move_speed
	if _embarrassed_left > 0:
		move_speed = 0
	super._physics_process(delta)
	move_speed = regular_speed
	if not accident_triggered and not visited_types.is_empty() and is_instance_valid(accident_manager):
		var excluded: Array[RID] = [get_rid()]
		if accident_manager.create_spill(global_position, excluded) != null:
			accident_triggered = true
			_embarrassed_left = embarrassment_time
			update_mood()

func update_mood() -> void:
	super.update_mood()
	if _embarrassed_left > 0 and is_instance_valid(_mood):
		_mood.text = ":O  !"
		_mood.modulate = Color.CYAN
