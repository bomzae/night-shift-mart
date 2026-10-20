extends Node3D
@export var auto_stock_on_start: bool = false
## Runtime primitive geometry; the reusable product/cart/player scenes own behavior.

func _ready() -> void:
	var wall := Color(0.48, 0.51, 0.55)
	Graybox.box($StoreFloor, "Floor", Vector3(36, 0.4, 18), Vector3(0, -0.2, 9), Color(0.4, 0.43, 0.46))
	Graybox.box($Backroom, "Floor", Vector3(18, 0.4, 3), Vector3(0, -0.2, -1.5), Color(0.32, 0.37, 0.4))
	Graybox.box($LoadingArea, "Floor", Vector3(18, 0.4, 3), Vector3(0, -0.2, -4.5), Color(0.28, 0.3, 0.32))
	for x in [-18, 18]:
		Graybox.box(self, "Boundary", Vector3(0.25, 3, 18), Vector3(x, 1.5, 9), wall)
	for x in [-9, 9]:
		Graybox.box(self, "RearBoundary", Vector3(0.25, 3, 6), Vector3(x, 1.5, -3), wall)
	for z in [-6]:
		Graybox.box(self, "Boundary", Vector3(18, 3, 0.25), Vector3(0, 1.5, z), wall)
	Graybox.box(self, "FrontLeft", Vector3(12, 3, 0.25), Vector3(-12, 1.5, 18), wall)
	Graybox.box(self, "FrontRight", Vector3(18, 3, 0.25), Vector3(9, 1.5, 18), wall)
	for x in [-13.5, 13.5]:
		Graybox.box(self, "WingRear", Vector3(9, 3, 0.25), Vector3(x, 1.5, 0), wall)
	Graybox.box(self, "Outside", Vector3(6, 0.4, 4), Vector3(-3, -0.2, 20), Color(0.25, 0.35, 0.3))
	Graybox.sign(self, "EXIT  ~_~ →", Vector3(-3, 2.5, 20), Color.LIME_GREEN)
	# One centered 5m rear door, directly joining dispatch and the main aisle.
	for doorway in [Vector2(0, 0)]:
		var left_end: float = doorway.x - 2.5
		var right_start: float = doorway.x + 2.5
		Graybox.box(self, "Partition", Vector3(left_end + 9, 3, 0.25), Vector3((-9 + left_end) / 2, 1.5, doorway.y), wall)
		Graybox.box(self, "Partition", Vector3(9 - right_start, 3, 0.25), Vector3((9 + right_start) / 2, 1.5, doorway.y), wall)
	Graybox.sign($LoadingArea, "↓ LOADING", Vector3(-3, 2.6, -5), Color.GOLD)
	Graybox.sign($Backroom, "BACKROOM / DELIVERY", Vector3(0, 2.6, -1))
	Graybox.sign($StoreFloor, "STORE", Vector3(0, 2.8, 3))
	Graybox.box($StoreFloor, "CheckoutReserved", Vector3(3, 0.025, 2), Vector3(11, 0.015, 16), Color(0.55, 0.5, 0.25), false)
	Graybox.box($Entrance, "DoorMarker", Vector3(6, 0.03, 0.3), Vector3(0, -1.23, 0), Color(0.25, 0.5, 0.55), false)
	Graybox.sign($Entrance, "ENTRANCE", Vector3(0, 1.8, -0.1))
	for definition: ProductDefinition in ProductCatalog.DEFINITIONS:
		if $Shelves.has_node(definition.shelf_name): continue
		var shelf: StockShelf = preload("res://scenes/interactables/stock_shelf.tscn").instantiate()
		shelf.name = definition.shelf_name
		shelf.accepted_type = definition.id
		shelf.max_stock = definition.shelf_capacity
		shelf.shelf_color = definition.tint
		shelf.shopping_point_span = 0.8
		shelf.position = definition.shelf_position
		shelf.rotation_degrees.y = definition.shelf_yaw
		$Shelves.add_child(shelf)
	var auto_stock := AutoStock.new()
	auto_stock.name = "AutoStock"
	auto_stock.auto_stock_on_start = auto_stock_on_start
	add_child(auto_stock)
	var families := Node3D.new()
	families.name = "LostFamilies"
	families.set_script(preload("res://scripts/systems/lost_family_manager.gd"))
	add_child(families)
	var accidents := Node3D.new()
	accidents.name = "Accidents"
	accidents.set_script(preload("res://scripts/systems/accident_manager.gd"))
	add_child(accidents)
	var mop := preload("res://scenes/interactables/mop.tscn").instantiate()
	mop.position = Vector3(7.5, 0.85, -1.5)
	add_child(mop)
	var fires := Node3D.new()
	fires.name = "Fires"
	fires.set_script(preload("res://scripts/systems/fire_manager.gd"))
	add_child(fires)
	var thieves := ThiefManager.new()
	thieves.name = "Thieves"
	add_child(thieves)
	var team := TeamLifeManager.new()
	team.name = "TeamLife"
	add_child(team)
	var boss_manager := KingRatManager.new()
	boss_manager.name = "Bosses"
	add_child(boss_manager)
	var tourist_bus := TouristBus.new()
	tourist_bus.name = "TouristBus"
	add_child(tourist_bus)
	for location in [Vector3(6.2, 0.45, -1.5), Vector3(16.0, 0.45, 17.0)]:
		var extinguisher := preload("res://scenes/interactables/fire_extinguisher.tscn").instantiate()
		extinguisher.position = location
		add_child(extinguisher)
		Graybox.sign(self, "[F]", location + Vector3.UP * 1.4, Color.ORANGE_RED)
