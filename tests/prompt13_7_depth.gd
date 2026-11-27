extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	await starter_main()
	player.set_physics_process(false)
	var shelf: StockShelf=mart.get_node("Shelves/CanShelf")
	var product: GrabbableBody=shelf.stocked_objects[0]
	check(product.begin_carry(interaction,player),"actual starter product supplies depth fixture")
	for other in mart.get_node("Products").get_children():
		if other!=product: other.queue_free() # Isolate occupancy separately from bulk physical restocking.
	product.global_rotation=shelf.global_rotation
	product.global_position=shelf.to_global(Vector3(0,0.83,1.3))
	await frames(3)
	var origin:=shelf.to_global(Vector3(0,1.05,2))
	var center:=0.65+product.definition.size.y/2+0.025
	var front_target:=shelf.to_global(Vector3(0,center,0.45))
	var rear_target:=shelf.to_global(Vector3(0,center,-0.4))
	var front:=shelf.placement_point(origin,(front_target-origin).normalized(),product,3)
	var rear:=shelf.placement_point(origin,(rear_target-origin).normalized(),product,3)
	check(not front.is_empty() and not rear.is_empty(),"same opening accepts front and rear sight lines")
	check(absf(shelf.to_local(front.position).z-0.45)<0.03 and absf(shelf.to_local(rear.position).z+0.4)<0.03,"mouse look selects both depths within one tier")
	check(front.shelf==shelf and rear.shelf==shelf,"depth selection never changes tier")
	# A clear endpoint alone is insufficient: a solid row blocks the entry corridor.
	var obstacle:=StaticBody3D.new()
	shelf.add_child(obstacle)
	obstacle.position=Vector3(0,0.83,0.4)
	var shape:=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(2.6,0.35,0.22)
	obstacle.add_child(shape)
	await frames(3)
	var blocked:=shelf.placement_point(origin,(rear_target-origin).normalized(),product,3)
	check(blocked.is_empty(),"empty rear space is rejected when front corridor is physically blocked")
	check(shelf.to_local(product.global_position).z>0.7,"query does not teleport product through front blocker")
	obstacle.queue_free()
	await frames(3)
	check(not shelf.placement_point(origin,(rear_target-origin).normalized(),product,3).is_empty(),"removing obstruction restores rear placement")
	var row: Array[GrabbableBody]=[]
	for x in [-1.05,-0.75,-0.45,-0.15,0.15,0.45,0.75,1.05]:
		var can: GrabbableBody=load("res://scenes/interactables/products/can.tscn").instantiate()
		mart.get_node("Products").add_child(can)
		can.position=shelf.to_global(Vector3(x,0.81,0.45))
		can.freeze=true # Controlled occupied row, with actual product collision shapes.
		row.append(can)
	await frames(3)
	check(shelf.placement_point(origin,(rear_target-origin).normalized(),product,3).is_empty(),"actual front product row also blocks rear placement without product phasing")
	product.end_carry()
	quit(1 if failures else 0)
