class_name AttackAttribution
extends RefCounted
## Short-lived responsibility, independent of carry/collision exceptions.
var actor: WeakRef
var expires_frame: int = 0
var timeout: float = 8.0

func remember(player: Node) -> void:
	actor = weakref(player) if is_instance_valid(player) else null
	expires_frame = Engine.get_physics_frames() + int(timeout * Engine.physics_ticks_per_second)

func current() -> Node:
	if actor == null or Engine.get_physics_frames() >= expires_frame: return null
	return actor.get_ref() as Node
