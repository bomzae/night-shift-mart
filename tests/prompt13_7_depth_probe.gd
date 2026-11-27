extends "res://tests/fixture13_7.gd"
func run_checks() -> void:
	await starter_main()
	var shelf: StockShelf=mart.get_node("Shelves/ZoneSection0_3_cereal")
	var product: GrabbableBody=shelf.stocked_objects[0]
	product.begin_carry(interaction,player)
	var origin:=shelf.to_global(Vector3(0,1.62,1.5))
	for depth in [-0.4,0.05]:
		var direction: Vector3=(shelf.to_global(Vector3(0,1.425,depth))-origin).normalized()
		var result:=shelf.placement_point(origin,direction,product,2.8)
		print("DEPTH137 aim=",depth," result=",result," local=",shelf.to_local(result.position) if not result.is_empty() else Vector3.ZERO)
	quit(0)
