class_name NPCProgressWatchdog
extends RefCounted
## Measures real horizontal progress, independently of obstacle-specific steering.
var check_window: float = 3.0
var minimum_progress: float = 0.4
var recovery_attempts: int = 0
var recovery_count: int = 0
var elapsed: float = 0
var last_progress: float = 0
var _key: String = ""
var _origin := Vector3.ZERO
var _distance: float = 0

func observe(position: Vector3, target: Vector3, key: String, required: bool, delta: float) -> int:
	if key != _key:
		_key = key
		recovery_attempts = 0
		elapsed = 0
	if not required:
		elapsed = 0
		return 0
	var distance := Vector2(target.x-position.x,target.z-position.z).length()
	if elapsed == 0:
		_origin = position
		_distance = distance
	elapsed += delta
	if elapsed < check_window: return 0
	last_progress = maxf(Vector2(position.x-_origin.x,position.z-_origin.z).length(),_distance-distance)
	elapsed = 0
	if last_progress >= minimum_progress or recovery_attempts >= 6: return 0
	recovery_attempts += 1
	recovery_count += 1
	return recovery_attempts
