class_name HumanSeparation
extends Resource
## Human-only spacing. Existing world/objects stay on layer 1; no global ghosts.
const HUMAN_LAYER := 64
const MONSTER_LAYER := 128
@export var separation_radius: float = 1.1
@export var personal_space: float = 0.8
@export var separation_strength: float = 1.5
@export var max_separation_speed: float = 0.65
@export var side_bias: float = 0.35
var current_vector := Vector3.ZERO

func setup(body: PhysicsBody3D) -> void:
	body.add_to_group("human_npcs")
	body.collision_layer = HUMAN_LAYER
	body.collision_mask = 1 | MONSTER_LAYER

func correction(body: PhysicsBody3D, desired: Vector3, multiplier: float = 1.0) -> Vector3:
	current_vector = Vector3.ZERO
	if multiplier <= 0 or (body is CarryableCharacter and is_instance_valid(body.holder)):
		return current_vector
	var radius := maxf(0.01, separation_radius)
	var forward := desired.normalized()
	for other in body.get_tree().get_nodes_in_group("human_npcs"):
		if other == body or other.is_queued_for_deletion(): continue
		if other is CarryableCharacter and is_instance_valid(other.holder): continue
		var away: Vector3 = body.global_position - other.global_position
		if absf(away.y) > 1.5: continue
		away.y = 0
		var distance := away.length()
		if distance >= radius: continue
		if distance < 0.001:
			away = Vector3.RIGHT if body.get_instance_id() < other.get_instance_id() else Vector3.LEFT
		else:
			away /= distance
		var weight := 1.0 - distance / radius
		var closeness := clampf(1.0 - distance / maxf(0.01, personal_space), 0, 1)
		current_vector += away * separation_strength * weight * (0.5 + closeness)
		# Always pass on our own right: opposite headings get opposite world sides.
		# No per-frame random choice, including exact head-on encounters.
		if forward != Vector3.ZERO and away.dot(forward) < -0.3:
			current_vector += forward.cross(Vector3.UP) * side_bias * weight
	current_vector = (current_vector * multiplier).limit_length(max_separation_speed * minf(multiplier, 1.0))
	# Spacing cannot cancel goal progress; external pushes are added by the motor later.
	if desired.length() > 0.01:
		var backward := current_vector.dot(forward)
		var minimum := -desired.length() * 0.15
		if backward < minimum: current_vector += forward * (minimum - backward)
	return current_vector
