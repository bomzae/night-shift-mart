class_name Mop
extends GrabbableBody

@export var clean_rate: float = 0.6
@export var minimum_clean_speed: float = 0.3
@export var maximum_clean_speed: float = 8.0
var head_speed: float = 0.0
var _previous_head: Vector3

func _ready() -> void:
	super._ready()
	$Label.text = "MOP"
	_previous_head = $CleaningHead.global_position

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var current: Vector3 = $CleaningHead.global_position
	# Actual head movement includes rotation; a stationary tool cannot clean.
	head_speed = Vector2(current.x - _previous_head.x, current.z - _previous_head.z).length() / maxf(delta, 0.001)
	_previous_head = current
	if not is_instance_valid(holder) or head_speed < minimum_clean_speed or head_speed > maximum_clean_speed:
		return
	for area in $CleaningHead.get_overlapping_areas():
		if area is SpillZone:
			area.clean(clean_rate * delta)

func _on_body_entered(_body: Node) -> void:
	pass # Tool contacts remain physical; no scripted combat damage yet.
