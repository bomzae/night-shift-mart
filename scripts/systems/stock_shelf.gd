class_name StockShelf
extends Node3D

@export var accepted_type: StringName = &"can"
@export var max_stock: int = 8
@export var shelf_color: Color = Color.CORNFLOWER_BLUE
@export var settle_time: float = 0.4
@export var max_stock_speed: float = 0.35
@export var max_stock_spin: float = 1.0
@export var use_catalog_tier: bool = true
@export var tier_height: float = 0.0
@export var tier_clearance: float = 1.2
var point_owner: StockShelf
var stock_count: int = 0
var stocked_objects: Array[GrabbableBody] = []
var _settled: Dictionary = {}
var placement_reason: String = ""
var zone: Area3D
var _label: Label3D
@export_range(2, 4) var shopping_point_count: int = 3
@export var shopping_front_distance: float = 1.35
@export var shopping_point_span: float = 0.95
var _shopping_users: Dictionary = {}
var _shopping_reserved_frame: Dictionary = {}

func shopping_point(index: int) -> Vector3:
	if is_instance_valid(point_owner): return point_owner.shopping_point(index)
	return to_global(Vector3(lerpf(-shopping_point_span, shopping_point_span, float(index) / (shopping_point_count - 1)), 0.01, shopping_front_distance))

func reserve_shopping_point(customer: Node3D, product_position: Vector3) -> int:
	if is_instance_valid(point_owner): return point_owner.reserve_shopping_point(customer, product_position)
	prune_shopping_points()
	var selected := -1
	var nearest := INF
	for i in range(shopping_point_count):
		if _shopping_users.has(i) and is_instance_valid(_shopping_users[i]):
			continue
		var distance := shopping_point(i).distance_squared_to(product_position)
		if distance < nearest:
			nearest = distance
			selected = i
	if selected >= 0:
		_shopping_users[selected] = customer
		_shopping_reserved_frame[selected] = Engine.get_physics_frames()
	return selected

func prune_shopping_points() -> void:
	if is_instance_valid(point_owner):
		point_owner.prune_shopping_points()
		return
	for index in _shopping_users.keys():
		var user = _shopping_users[index]
		if not is_instance_valid(user) or user.is_queued_for_deletion():
			_shopping_users.erase(index)
		elif user is BasicCustomer and not user is ThiefCustomer:
			var active_shelf = user.shopping_shelf
			var leaving = user._leaving_shelf
			var active_owner = active_shelf.point_owner if is_instance_valid(active_shelf) and is_instance_valid(active_shelf.point_owner) else active_shelf
			var leaving_owner = leaving.point_owner if is_instance_valid(leaving) and is_instance_valid(leaving.point_owner) else leaving
			var age: float = (Engine.get_physics_frames()-int(_shopping_reserved_frame.get(index,0)))/float(Engine.physics_ticks_per_second)
			if active_owner != self and leaving_owner != self and age >= 3: _shopping_users.erase(index)
	for index in _shopping_reserved_frame.keys():
		if not _shopping_users.has(index): _shopping_reserved_frame.erase(index)

func release_shopping_point(customer: Node) -> void:
	if is_instance_valid(point_owner):
		point_owner.release_shopping_point(customer)
		return
	for i in _shopping_users.keys():
		if not is_instance_valid(_shopping_users[i]) or _shopping_users[i] == customer:
			_shopping_users.erase(i)
			_shopping_reserved_frame.erase(i)

func _ready() -> void:
	add_to_group("stock_shelves")
	var definition := ProductCatalog.find(accepted_type)
	if definition != null and use_catalog_tier:
		tier_height = definition.shelf_tier_height
		tier_clearance = definition.shelf_tier_clearance
	Graybox.box(self, "Deck", Vector3(2.8, 0.14, 0.9 if tier_height > 0 else 1.4), Vector3(0, 0.58 + tier_height, -0.25 if tier_height > 0 else 0), shelf_color)
	Graybox.box(self, "Back", Vector3(2.8, 1.2, 0.12), Vector3(0, 0.65, -0.7), Color.DIM_GRAY)
	for x in [-1.34, 1.34]:
		Graybox.box(self, "Leg", Vector3(0.12, 0.55 + tier_height, 1.2), Vector3(x, (0.55 + tier_height) / 2, 0), Color.DIM_GRAY)
	zone = Area3D.new()
	zone.name = "StockZone"
	zone.position.y = 0.65 + tier_height + tier_clearance / 2
	zone.collision_layer = 0
	zone.collision_mask = 1
	var collision := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(2.8, tier_clearance, 1.4)
	collision.shape = bounds
	zone.add_child(collision)
	add_child(zone)
	_label = Graybox.sign(self, definition.display_name.to_upper() if definition != null else String(accepted_type).to_upper(), Vector3(0, tier_height + 0.61, 0.76), Color.WHITE)
	_label.font_size = 24
	_label.pixel_size = 0.003

func _physics_process(delta: float) -> void:
	refresh_stock(delta)

func refresh_stock(delta: float) -> void:
	var present: Dictionary = {}
	stocked_objects.clear()
	for candidate in zone.get_overlapping_bodies():
		if not candidate is GrabbableBody:
			continue
		var body := candidate as GrabbableBody
		if not stock_eligible(body):
			continue
		var id := body.get_instance_id()
		present[id] = float(_settled.get(id, 0.0)) + delta
		if present[id] >= settle_time and stocked_objects.size() < max_stock:
			stocked_objects.append(body)
	_settled = present
	stock_count = stocked_objects.size()

func stock_eligible(body: GrabbableBody) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_meta("sold", false):
		return false
	var local := to_local(body.global_position)
	return body.product_type == accepted_type and not is_instance_valid(body.holder) and absf(local.x) <= 1.4 and absf(local.z) <= 0.7 and local.y >= 0.65 + tier_height and local.y <= 0.65 + tier_height + tier_clearance and body.linear_velocity.length() <= max_stock_speed and body.angular_velocity.length() <= max_stock_spin

func has_stock(body: GrabbableBody) -> bool:
	# Recheck live physics/ownership at pickup, not just last tick's cached count.
	return stock_eligible(body) and stocked_objects.has(body)

func slot_position(slot: Vector3) -> Vector3:
	# Upper decks step back: the player can see/reach goods on the lower tier.
	if tier_height > 0: slot.z = slot.z * (5.0 / 6.0) - 0.25
	slot.y += tier_height
	return slot

func opening_clearance() -> float:
	var clearance := tier_clearance
	for other in get_tree().get_nodes_in_group("stock_shelves"):
		if other == self or other.global_position.distance_squared_to(global_position)>0.001: continue
		if other.tier_height > tier_height:
			clearance = minf(clearance,other.tier_height-tier_height-0.14)
	return clearance

func aim_region(origin: Vector3, direction: Vector3, reach: float) -> Dictionary:
	# Geometric intent is selected before occupancy or product fit. Lower decks
	# cannot claim the volume belonging to an actual deck above them.
	var local_origin := to_local(origin)
	var local_direction := global_basis.inverse()*direction
	var front := 0.2 if tier_height>0 else 0.7
	if local_origin.z<=front or local_direction.z>=-0.01: return {}
	var distance := (front-local_origin.z)/local_direction.z
	if distance<0 or distance>reach: return {}
	var entry := local_origin+local_direction*distance
	var floor_y := 0.65+tier_height
	if absf(entry.x)>1.35 or entry.y<floor_y or entry.y>floor_y+opening_clearance(): return {}
	return {"entry":entry,"distance":distance}

func placement_point(origin: Vector3, direction: Vector3, body: GrabbableBody, reach: float) -> Dictionary:
	var region := aim_region(origin,direction,reach)
	placement_reason = "outside_opening"
	if region.is_empty(): return {}
	placement_reason = "capacity"
	if stock_count>=max_stock: return {}
	var entry: Vector3 = region.entry
	var front := 0.2 if tier_height>0 else 0.7
	var floor_y := 0.65+tier_height
	var ray := PhysicsRayQueryParameters3D.create(origin,to_global(entry),1,[body.get_rid()])
	if is_instance_valid(body._ignored_player): ray.exclude.append(body._ignored_player.get_rid())
	var space := get_world_3d().direct_space_state
	placement_reason = "opening_occluded"
	if not space.intersect_ray(ray).is_empty(): return {}
	placement_reason = "size_or_occupied"
	var upright := Basis.from_euler(Vector3(0,body.global_rotation.y,0))
	for orientation: Basis in [body.global_basis,upright]:
		var bounds := AABB()
		var first := true
		for child in body.get_children():
			if not child is CollisionShape3D or child.disabled: continue
			var relative: Transform3D = Transform3D(global_basis.inverse()*orientation,Vector3.ZERO)*child.transform
			var shape_bounds: AABB = relative * child.shape.get_debug_mesh().get_aabb()
			bounds = shape_bounds if first else bounds.merge(shape_bounds)
			first = false
		if first or bounds.size.y>opening_clearance()-0.03 or bounds.size.z>(0.9 if tier_height>0 else 1.4)-0.08 or bounds.size.x>2.5: continue
		# Search only this tier, nearest to the aimed opening first.
		for offset in [0.0,-0.35,0.35,-0.7,0.7,-1.05,1.05,-1.4,1.4]:
			var point := Vector3(clampf(entry.x+offset,-1.27-bounds.position.x,1.27-bounds.end.x),floor_y-bounds.position.y+0.025,front-bounds.end.z-0.035)
			var world_point := to_global(point)
			if origin.distance_to(world_point)>reach: continue
			var clear := true
			for child in body.get_children():
				if not child is CollisionShape3D or child.disabled: continue
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = child.shape
				query.transform = Transform3D(orientation,world_point)*child.transform
				query.exclude = ray.exclude
				query.margin = 0.005
				if not space.intersect_shape(query,1).is_empty():
					clear = false
					break
			if not clear: continue
			if not orientation.is_equal_approx(body.global_basis):
				placement_reason = "aligning"
				return {"shelf":self,"position":body.global_position,"distance":region.distance,"align":orientation}
			placement_reason = "valid"
			return {"shelf":self,"position":world_point,"distance":region.distance}
	return {}
