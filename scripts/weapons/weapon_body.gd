class_name WeaponBody
extends GrabbableBody
@export var weapon: WeaponDefinition
var durability: int
var swing_left: float = 0
var cooldown_left: float = 0
var swing_hits: Dictionary = {}
var _previous_phase: float = 0
var hit_feedback: float = 0
var hit_stop_left: float = 0

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
	_previous_phase = -1
	hit_stop_left = 0
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
	if hit_stop_left > 0:
		hit_stop_left = maxf(0, hit_stop_left - delta)
		return # Only this weapon animation pauses; physics, player and boss remain live.
	if swing_left > 0:
		swing_left = maxf(0, swing_left - delta)
		var phase := sweep_phase()
		# Subsample the arc, including low-frame-rate sweeps, rather than a single aim ray.
		for i in range(1, 5):
			_sample_arc(lerpf(_previous_phase, phase, i / 4.0))
			if is_queued_for_deletion(): return
		_previous_phase = phase

func sweep_phase() -> float:
	var elapsed := weapon.swing_duration - swing_left
	if elapsed < weapon.windup_time: return -1
	if elapsed > weapon.swing_duration - weapon.recovery_time: return 1.1
	return (elapsed - weapon.windup_time) / maxf(0.01, weapon.swing_duration - weapon.windup_time - weapon.recovery_time)

func motion_pose() -> Transform3D:
	var idle := Vector3(0.25, -0.35, 0)
	if not swinging(): return Transform3D(Basis.IDENTITY, idle)
	var elapsed := weapon.swing_duration - swing_left
	var offset: Vector3
	var angles: Vector3
	if elapsed < weapon.windup_time:
		var t := smoothstep(0, weapon.windup_time, elapsed)
		offset = idle.lerp(weapon.windup_offset, t)
		angles = weapon.windup_rotation * t
	elif elapsed < weapon.swing_duration - weapon.recovery_time:
		var t := smoothstep(0, 1, sweep_phase())
		offset = weapon.windup_offset.lerp(weapon.followthrough_offset, t)
		angles = weapon.windup_rotation.lerp(weapon.followthrough_rotation, t)
	else:
		var t := smoothstep(0, weapon.recovery_time, elapsed - (weapon.swing_duration - weapon.recovery_time))
		offset = weapon.followthrough_offset.lerp(idle, t)
		angles = weapon.followthrough_rotation * (1 - t)
	offset.z += 0.06 * hit_feedback / 0.12
	return Transform3D(Basis.from_euler(angles * PI / 180.0), offset)

func hold_offset() -> Vector3:
	return motion_pose().origin

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	if is_instance_valid(holder):
		var target: Basis = holder.camera.global_basis * motion_pose().basis
		var error := (target * state.transform.basis.inverse()).get_rotation_quaternion()
		state.angular_velocity = state.angular_velocity.move_toward(error.get_axis() * error.get_angle() * 10, 35 * state.step)

func _sample_arc(phase: float) -> void:
	if phase < 0 or phase > 1: return
	var camera: Camera3D = holder.camera
	var origin := camera.global_position - camera.global_basis.y * 0.35
	var direction := -camera.global_basis.z.rotated(camera.global_basis.y, lerpf(-weapon.sweep_angle, weapon.sweep_angle, phase))
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
		hit_stop_left = weapon.hit_stop_time
		holder.camera_impact = maxf(holder.camera_impact, weapon.camera_kick)
		if spend_durability(): return

func spend_durability() -> bool:
	durability = maxi(0, durability - weapon.durability_cost)
	if durability > 0: return false
	print("WEAPON BROKEN: ", display_name)
	var controller := holder
	if not is_instance_valid(controller):
		var attacker = attack_attribution.current()
		if is_instance_valid(attacker): controller = attacker.get_node_or_null("Interaction")
	if is_instance_valid(controller):
		controller.weapon_notice = 1.0
		controller.weapon_notice_text = "BROKEN: " + display_name
	if is_instance_valid(holder): holder.drop_held()
	queue_free()
	return true

func _deliver_impact(body, damage: float, impulse: Vector3, instigator) -> void:
	var before: float = body.current_health if is_instance_valid(body) and body is CombatTarget else -1
	super._deliver_impact(body, damage, impulse, instigator)
	# Damage completes before break, including a killing hit. World/miss costs nothing.
	if is_instance_valid(body) and body is CombatTarget and body.current_health < before:
		spend_durability()

func end_carry() -> void:
	swing_left = 0
	hit_stop_left = 0
	super.end_carry()

func launch(direction: Vector3, speed: float, damage: float) -> void:
	super.launch(direction, speed, damage * weapon.throw_damage_multiplier)
