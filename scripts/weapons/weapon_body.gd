class_name WeaponBody
extends GrabbableBody
@export var weapon: WeaponDefinition
var durability: int
var swing_left: float = 0
var cooldown_left: float = 0
var swing_hits: Dictionary = {}
var _previous_phase: float = 0
var hit_feedback: float = 0

func _ready() -> void:
	display_name = weapon.display_name
	weight = weapon.weight
	price = weapon.throw_value
	flammable = false
	carry_radius = 0.65
	durability = weapon.durability_max
	add_to_group("grabbable")
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var shaft := BoxMesh.new()
	shaft.size = weapon.shaft_size
	mesh.mesh = shaft
	add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = weapon.shaft_size
	shape.shape = box
	add_child(shape)
	var head := Graybox.box(self, "HeadVisual", weapon.head_size, Vector3(0, 0, -weapon.shaft_size.z * 0.35), weapon.color, false)
	var head_shape := CollisionShape3D.new()
	var head_box := BoxShape3D.new()
	head_box.size = weapon.head_size
	head_shape.shape = head_box
	head_shape.position = head.position
	add_child(head_shape)
	var label := Label3D.new()
	label.name = "Label"
	add_child(label)
	tint = weapon.color
	super._ready()
	label.hide()

func swinging() -> bool:
	return swing_left > 0

func start_swing() -> bool:
	if not is_instance_valid(holder) or holder.is_charging or KnockdownState.blocked(holder.player) or cooldown_left > 0 or durability <= 0: return false
	swing_left = weapon.swing_duration
	cooldown_left = weapon.swing_cooldown
	_previous_phase = 0
	swing_hits.clear()
	return true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	$Label.visible = show_debug_label
	cooldown_left = maxf(0, cooldown_left - delta)
	hit_feedback = maxf(0, hit_feedback - delta)
	if not is_instance_valid(holder) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or KnockdownState.blocked(holder.player):
		swing_left = 0
		return
	if swing_left > 0:
		swing_left = maxf(0, swing_left - delta)
		var phase := 1 - swing_left / weapon.swing_duration
		# Subsample the arc, including low-frame-rate sweeps, rather than a single aim ray.
		for i in range(1, 5):
			_sample_arc(lerpf(_previous_phase, phase, i / 4.0))
			if is_queued_for_deletion(): return
		_previous_phase = phase

func hold_offset() -> Vector3:
	var phase := 1 - swing_left / weapon.swing_duration if swinging() else 0.5
	return Vector3(lerpf(0.5, -0.5, phase), -0.35, 0)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	if is_instance_valid(holder):
		var phase := 1 - swing_left / weapon.swing_duration if swinging() else 0.5
		var target: Basis = holder.camera.global_basis * Basis(Vector3.UP, lerpf(-0.65, 0.65, phase))
		var error := (target * state.transform.basis.inverse()).get_rotation_quaternion()
		state.angular_velocity = state.angular_velocity.move_toward(error.get_axis() * error.get_angle() * 10, 35 * state.step)

func _sample_arc(phase: float) -> void:
	if phase < 0.15 or phase > 0.85: return
	var camera: Camera3D = holder.camera
	var origin := camera.global_position - camera.global_basis.y * 0.35
	var direction := -camera.global_basis.z.rotated(camera.global_basis.y, lerpf(-0.65, 0.65, phase))
	var length := weapon.range
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = length
	query.shape = capsule
	query.collision_mask = HumanSeparation.MONSTER_LAYER
	query.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction)), origin + direction * length * 0.5)
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var target = hit.collider
		if not target is CombatTarget or target.is_defeated or swing_hits.has(target.get_instance_id()): continue
		# Walls, shelves and other physical objects occlude the swept arc.
		var ray := PhysicsRayQueryParameters3D.create(origin, target.global_position + Vector3.UP * 0.8, 1 | HumanSeparation.MONSTER_LAYER, [get_rid(), holder.player.get_rid()])
		var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
		if not obstruction.is_empty() and obstruction.collider != target: continue
		swing_hits[target.get_instance_id()] = true
		var away: Vector3 = target.global_position - holder.player.global_position
		away.y = 0
		target.receive_impact(weapon.damage, away.normalized() * weapon.knockback, holder.player)
		hit_feedback = 0.12
		durability = maxi(0, durability - weapon.durability_cost)
		if durability == 0:
			print("WEAPON BROKEN: ", display_name)
			holder.weapon_notice = 1.0
			holder.weapon_notice_text = "BROKEN: " + display_name
			holder.drop_held()
			queue_free()
			return

func end_carry() -> void:
	swing_left = 0
	super.end_carry()

func launch(direction: Vector3, speed: float, damage: float) -> void:
	super.launch(direction, speed, damage * weapon.throw_damage_multiplier)
