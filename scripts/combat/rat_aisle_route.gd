class_name RatAisleRoute
extends RefCounted
## Fixed supermarket aisle intersections, connected only when the boss capsule fits.
## Local route planning for pursuit; does not replace customer/food routes.
const X := [-34.0, -26.0, -17.0, -10.0, 0.0, 10.0, 17.0, 26.0, 34.0]
const Z := [1.0, 3.0, 9.0, 15.0, 21.0, 27.0, 33.0]
var boss: CharacterBody3D
var exclusions: Array[RID] = []
var shape := SphereShape3D.new()

func _init(owner_body: CharacterBody3D) -> void:
	boss = owner_body
	shape.radius = 0.63 # Slightly inside the physical 0.65 capsule, allowing departure from contact.

func refresh_exclusions(include_products: bool = false) -> void:
	exclusions = [boss.get_rid()]
	for group in ["grabbable", "human_npcs", "monsters", "player_health"]:
		for node in boss.get_tree().get_nodes_in_group(group):
			var body: Node = node.get_parent() if group == "player_health" else node
			if body is GrabbableBody and include_products and not is_instance_valid(body.holder): continue
			if body is PhysicsBody3D: exclusions.append(body.get_rid())
	# Carts remain obstacles for the swept route as well as the physical body.

func clear_segment(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = Vector3(a.x, 0.65, a.z)
	query.motion = Vector3(b.x - a.x, 0, b.z - a.z)
	query.collision_mask = 1
	query.exclude = exclusions
	var space := boss.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	return space.cast_motion(query)[0] >= 0.999

func build(from: Vector3, target: Vector3, include_products: bool = false) -> Array[Vector3]:
	refresh_exclusions(include_products)
	from.y = 0.01
	target.y = 0.01
	if clear_segment(from, target): return [target]
	var points: Array[Vector3] = [from, target]
	for z in Z:
		for x in X: points.append(Vector3(x, 0.01, z))
	var edges: Array = []
	for i in points.size(): edges.append([])
	for i in range(2, points.size()):
		for j in [i + 1 if (i - 2) % X.size() < X.size() - 1 else -1, i + X.size()]:
			if j < 2 or j >= points.size(): continue
			if clear_segment(points[i], points[j]):
				edges[i].append(j)
				edges[j].append(i)
	for endpoint in [0, 1]:
		var candidates: Array[int] = []
		for i in range(2, points.size()): candidates.append(i)
		candidates.sort_custom(func(a, b): return points[endpoint].distance_squared_to(points[a]) < points[endpoint].distance_squared_to(points[b]))
		var connected := 0
		for i in candidates:
			if connected >= 6: break
			if clear_segment(points[endpoint], points[i]):
				edges[endpoint].append(i)
				edges[i].append(endpoint)
				connected += 1
	var distances: Array[float] = []
	var previous: Array[int] = []
	var remaining: Array[int] = []
	for i in points.size():
		distances.append(INF)
		previous.append(-1)
		remaining.append(i)
	distances[0] = 0
	while not remaining.is_empty():
		var at := remaining[0]
		for i in remaining:
			if distances[i] < distances[at]: at = i
		remaining.erase(at)
		if at == 1 or distances[at] == INF: break
		for next: int in edges[at]:
			var cost := distances[at] + points[at].distance_to(points[next])
			if cost < distances[next]:
				distances[next] = cost
				previous[next] = at
	var route: Array[Vector3] = []
	var cursor := 1
	# If the target itself is obstructed, approach the closest reachable aisle.
	if previous[cursor] < 0:
		var closest := INF
		for i in range(2, points.size()):
			if distances[i] == INF: continue
			var distance := points[i].distance_squared_to(target)
			if distance < closest:
				closest = distance
				cursor = i
	while cursor > 0 and previous[cursor] >= 0:
		route.push_front(points[cursor])
		cursor = previous[cursor]
	return route
