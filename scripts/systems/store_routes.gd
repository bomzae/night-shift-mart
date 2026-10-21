class_name StoreRoutes
extends RefCounted
## Small fixed aisle graph; no dynamic pathfinding or crowd solver.
static func lane(at: Vector3) -> float:
	return signf(at.x) * 26 if absf(at.x) > 20 and at.z < 21 else 0.0

static func via_main(from: Vector3, destination: Vector3) -> Array[Vector3]:
	var start_lane := lane(from)
	var end_lane := lane(destination)
	var result: Array[Vector3] = [Vector3(start_lane, 0.01, from.z)]
	if start_lane != end_lane:
		# Both full-width cross aisles are clear of shelves. Choose the shorter one.
		var rear_cost := absf(from.z - 1) + absf(destination.z - 1)
		var middle_cost := absf(from.z - 21) + absf(destination.z - 21)
		var cross_z := 1.0 if rear_cost < middle_cost else 21.0
		result.append(Vector3(start_lane, 0.01, cross_z))
		result.append(Vector3(end_lane, 0.01, cross_z))
	result.append(Vector3(end_lane, 0.01, destination.z))
	result.append(destination)
	return result
