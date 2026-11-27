extends "res://tests/fixture13_7.gd"

func run_checks() -> void:
	await starter_main()
	var drunk: DrunkCustomer=mart.get_node("Drunks").spawn_drunk()
	var planner:=RatAisleRoute.new(drunk)
	planner.shape.radius=0.30
	for name in ["TVShelf","MicrowaveShelf","ZoneSection0_6"]:
		var shelf: StockShelf=mart.get_node("Shelves/"+name)
		check(DrunkCustomer.single_low_deck(shelf),"rear route identifies real single deck "+name)
		var a:=shelf.to_global(Vector3(-1.85,0.01,-1.13))
		var b:=shelf.to_global(Vector3(1.85,0.01,-1.13))
		planner.refresh_exclusions(true)
		check(planner.clear_segment(a,b),"local-orientation rear aisle is reachable "+name)
		var obstruction:=StaticBody3D.new()
		var shape:=CollisionShape3D.new()
		shape.shape=BoxShape3D.new()
		shape.shape.size=Vector3(0.7,1.5,0.7)
		obstruction.add_child(shape)
		mart.add_child(obstruction)
		obstruction.position=(a+b)*0.5+Vector3.UP*0.7
		await frames(2)
		check(not planner.clear_segment(a,b),"blocked rear aisle is excluded rather than phased "+name)
		obstruction.queue_free()
		await frames(2)
	check(not DrunkCustomer.single_low_deck(mart.get_node("Shelves/CanShelf")),"multi-tier rack cannot receive low rear multiplier")
	quit(1 if failures else 0)
