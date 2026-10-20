class_name StoreRoutes
extends RefCounted
## Fixed graybox waypoints, not a navigation/avoidance solver.
## Shopping faces open onto cross aisles; x=0 connects them to the front.
static func via_main(from: Vector3, destination: Vector3) -> Array[Vector3]:
	return [Vector3(0, 0.01, from.z), Vector3(0, 0.01, destination.z), destination]
