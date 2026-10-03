class_name FireReaction
extends RefCounted
## Short interruption; never replaces the owner's business/family state.
var duration: float = 0.65
var cooldown: float = 1.1
var retreat_speed: float = 2.6
var remaining: float = 0
var cooldown_left: float = 0
var direction := Vector3.ZERO
var reaction_count: int = 0
var _body: PhysicsBody3D
var _player: bool = false
var feedback: CanvasItem
var sign: Label3D

func setup(body: PhysicsBody3D, player: bool = false) -> void:
	_body = body
	_player = player
	if player:
		duration = 0.3
		var canvas := CanvasLayer.new()
		body.add_child(canvas)
		var edges := Control.new()
		canvas.add_child(edges)
		edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for right in [false, true]:
			var edge := ColorRect.new()
			edge.color = Color(1, 0.22, 0.02, 0.45)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			edges.add_child(edge)
			edge.anchor_left = 0.97 if right else 0
			edge.anchor_right = 1 if right else 0.03
			edge.anchor_bottom = 1
		feedback = edges
		feedback.visible = false
	else:
		sign = Graybox.sign(body, ":O !!", Vector3.UP * (1.5 if body is RigidBody3D else 2.15), Color.ORANGE_RED)
		sign.pixel_size = 0.007
		sign.visible = false

func active() -> bool:
	return remaining > 0

func begin(origin: Vector3) -> bool:
	if active() or cooldown_left > 0 or KnockdownState.blocked(_body) or _body.get("holder") != null:
		return false
	direction = _body.global_position - origin
	direction.y = 0
	direction = direction.normalized() if direction.length() > 0.1 else Vector3.RIGHT
	remaining = duration
	cooldown_left = maxf(cooldown, duration)
	reaction_count += 1
	if _body is RigidBody3D: _body.sleeping = false
	_show(true)
	return true

func tick(delta: float) -> bool:
	cooldown_left = maxf(0, cooldown_left - delta)
	remaining = maxf(0, remaining - delta)
	if KnockdownState.blocked(_body) or _body.get("holder") != null: remaining = 0
	_show(active())
	return active()

func motion(velocity: Vector3, delta: float) -> Vector3:
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(direction * retreat_speed, 18 * delta)
	return Vector3(horizontal.x, velocity.y, horizontal.z)

func _show(on: bool) -> void:
	if is_instance_valid(feedback): feedback.visible = on
	if is_instance_valid(sign): sign.visible = on
