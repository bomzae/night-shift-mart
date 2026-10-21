class_name AutoStock
extends Node3D
@export var auto_stock_on_start: bool = false
var last_added: int = 0
var _label: Label
var _pending: Array[Dictionary] = []

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	canvas.add_child(_label)
	_label.position = Vector2(24, 286)
	_label.text = "[I] AUTO STOCK"
	if auto_stock_on_start: call_deferred("_stock_after_physics")

func _stock_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	top_up()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_auto_stock") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		top_up()
		get_viewport().set_input_as_handled()

func physical_count(shelf: StockShelf) -> int:
	var count := 0
	var seen := {}
	for body in get_parent().get_node("Products").get_children() + shelf.zone.get_overlapping_bodies():
		if not body is GrabbableBody or body.is_queued_for_deletion() or is_instance_valid(body.holder) or body.get_meta("sold", false): continue
		if seen.has(body.get_instance_id()): continue
		seen[body.get_instance_id()] = true
		var p: Vector3 = shelf.to_local(body.global_position)
		if body.product_type == shelf.accepted_type and absf(p.x) <= 1.4 and absf(p.z) <= 0.7 and p.y >= 0.65 + shelf.tier_height and p.y <= 0.65 + shelf.tier_height + shelf.tier_clearance:
			count += 1 # Includes newly spawned/unsettled goods, so repeated I cannot overfill.
	return count

func top_up() -> int:
	last_added = 0
	_pending = _pending.filter(func(entry): return is_instance_valid(entry.body.get_ref()) and Engine.get_physics_frames() - entry.frame < 3)
	for shelf: StockShelf in get_parent().get_node("Shelves").get_children():
		var definition := ProductCatalog.find(shelf.accepted_type)
		if definition == null: continue
		var missing := maxi(0, shelf.max_stock - physical_count(shelf))
		for slot in definition.stock_slots():
			if missing <= 0: break
			var transform_at := Transform3D(shelf.global_basis, shelf.to_global(shelf.slot_position(slot)))
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = definition.collision_shape()
			query.transform = transform_at
			query.margin = 0.005
			var bounds: AABB = transform_at * AABB(-definition.size / 2, definition.size)
			var occupied := not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
			for entry in _pending:
				if bounds.intersects(entry.bounds): occupied = true
			if occupied: continue # Never delete, move or snap player-created chaos.
			var product: GrabbableBody = load(definition.scene_path).instantiate()
			get_parent().get_node("Products").add_child(product)
			product.global_transform = transform_at
			_pending.append({"body": weakref(product), "bounds": bounds, "frame": Engine.get_physics_frames()})
			missing -= 1
			last_added += 1
	_label.text = "[I] AUTO STOCK +%d ITEMS" % last_added
	print("AUTO STOCK COMPLETE: ", last_added, " products")
	return last_added
