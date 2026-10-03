class_name DangerousCustomer
extends BasicCustomer

@export var panic_time: float = 0.8
var fire_manager: Node
var accident_triggered: bool = false
var panic_left: float = 0.0

func _physics_process(delta: float) -> void:
	if knockdown.active() or fire_reaction.active():
		super._physics_process(delta)
		return
	panic_left = maxf(0, panic_left - delta)
	var regular_speed := move_speed
	if panic_left > 0: move_speed = 0
	super._physics_process(delta)
	move_speed = regular_speed
	if not accident_triggered and not visited_types.is_empty() and is_instance_valid(fire_manager):
		accident_triggered = true # One attempt even when the fire limit is full.
		var excluded: Array[RID] = [get_rid()]
		fire_manager.create_fire(global_position, excluded)
		panic_left = panic_time
		update_mood()

func update_mood() -> void:
	super.update_mood()
	if panic_left > 0 and is_instance_valid(_mood):
		_mood.text = ":O !"
		_mood.modulate = Color.ORANGE_RED
