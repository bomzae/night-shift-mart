extends Node3D
@export var auto_stock_on_start: bool = false
## Runtime primitive geometry; the reusable product/cart/player scenes own behavior.

func _ready() -> void:
	var wall := Color(0.48, 0.51, 0.55)
	Graybox.box($StoreFloor, "Floor", Vector3(72, 0.4, 36), Vector3(0, -0.2, 18), Color(0.4, 0.43, 0.46))
	Graybox.box($Backroom, "Floor", Vector3(18, 0.4, 3), Vector3(0, -0.2, -1.5), Color(0.32, 0.37, 0.4))
	Graybox.box($LoadingArea, "Floor", Vector3(18, 0.4, 3), Vector3(0, -0.2, -4.5), Color(0.28, 0.3, 0.32))
	for x in [-36, 36]:
		Graybox.box(self, "Boundary", Vector3(0.25, 3, 36), Vector3(x, 1.5, 18), wall)
	for x in [-9, 9]:
		Graybox.box(self, "RearBoundary", Vector3(0.25, 3, 6), Vector3(x, 1.5, -3), wall)
	for z in [-6]:
		Graybox.box(self, "Boundary", Vector3(18, 3, 0.25), Vector3(0, 1.5, z), wall)
	Graybox.box(self, "FrontLeft", Vector3(30, 3, 0.25), Vector3(-21, 1.5, 36), wall)
	Graybox.box(self, "FrontRight", Vector3(36, 3, 0.25), Vector3(18, 1.5, 36), wall)
	for x in [-22.5, 22.5]:
		Graybox.box(self, "WingRear", Vector3(27, 3, 0.25), Vector3(x, 1.5, 0), wall)
	Graybox.box(self, "Outside", Vector3(6, 0.4, 4), Vector3(-3, -0.2, 38), Color(0.25, 0.35, 0.3))
	Graybox.sign(self, "EXIT  ~_~ →", Vector3(-3, 2.5, 38), Color.LIME_GREEN)
	# One centered 5m rear door, directly joining dispatch and the main aisle.
	for doorway in [Vector2(0, 0)]:
		var left_end: float = doorway.x - 2.5
		var right_start: float = doorway.x + 2.5
		Graybox.box(self, "Partition", Vector3(left_end + 9, 3, 0.25), Vector3((-9 + left_end) / 2, 1.5, doorway.y), wall)
		Graybox.box(self, "Partition", Vector3(9 - right_start, 3, 0.25), Vector3((9 + right_start) / 2, 1.5, doorway.y), wall)
	Graybox.sign($LoadingArea, "↓ LOADING", Vector3(-3, 2.6, -5), Color.GOLD)
	Graybox.sign($Backroom, "BACKROOM / DELIVERY", Vector3(0, 2.6, -1))
	Graybox.sign($StoreFloor, "STORE", Vector3(0, 2.8, 3))
	Graybox.box($StoreFloor, "CheckoutReserved", Vector3(3, 0.025, 2), Vector3(11, 0.015, 34), Color(0.55, 0.5, 0.25), false)
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
	_build_supermarket_sections()
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

func _build_supermarket_sections() -> void:
	# Adjacent product sections share a rack and its floor-level shopping reservations.
	for definition: ProductDefinition in ProductCatalog.DEFINITIONS:
		if definition.rack_base_name.is_empty(): continue
		var section: StockShelf = $Shelves.get_node(definition.shelf_name)
		var base: StockShelf = $Shelves.get_node(definition.rack_base_name)
		section.position = base.position
		section.rotation = base.rotation
		section.point_owner = base
	# Repeated stock sections put useful products throughout the enlarged floor.
	var rows := [24.0, 30.0]
	var section_types := [[&"rice_bag", &"chips", &"instant_noodles", &"bread", &"frying_pan", &"microwave", &"tv", &"vacuum_cleaner"], [&"cereal", &"can", &"milk", &"juice", &"detergent", &"shampoo", &"toilet_paper", &"cooking_oil"]]
	for row in range(rows.size()):
		for column in range(8):
			var definition: ProductDefinition = ProductCatalog.find(section_types[row][column])
			var shelf := StockShelf.new()
			shelf.name = "ZoneSection%d_%d" % [row, column]
			shelf.use_catalog_tier = false
			shelf.accepted_type = definition.id
			shelf.max_stock = mini(4, definition.shelf_capacity)
			shelf.shelf_color = definition.tint
			shelf.position = Vector3([-29, -21, -13, -6, 6, 13, 21, 29][column], 0, rows[row])
			shelf.rotation_degrees.y = 180
			$Shelves.add_child(shelf)
	for spec in [[&"watermelon", -29, 6], [&"milk", -21, 6], [&"bread", -29, 12], [&"can", -21, 12], [&"detergent", 29.5, 6], [&"tv", 29.5, 18]]:
		var definition := ProductCatalog.find(spec[0])
		var shelf := StockShelf.new()
		shelf.name = "RearZone" + str($Shelves.get_child_count())
		shelf.use_catalog_tier = false
		shelf.accepted_type = definition.id
		shelf.max_stock = mini(4, definition.shelf_capacity)
		shelf.shelf_color = definition.tint
		shelf.position = Vector3(spec[1], 0, spec[2])
		shelf.rotation_degrees.y = 180
		$Shelves.add_child(shelf)
	# Grow upward within existing islands; no loss of cross-aisle clearance.
	var rack_specs := {
		"ZoneSection0_1": [[&"instant_noodles", 0.55], [&"can", 1.0]],
		"ZoneSection0_2": [[&"chips", 0.45], [&"can", 0.95]],
		"ZoneSection0_3": [[&"cereal", 0.55], [&"chips", 1.15]],
		"ZoneSection1_1": [[&"instant_noodles", 0.55], [&"chips", 0.95]],
		"ZoneSection1_2": [[&"juice", 0.65]],
		"ZoneSection1_3": [[&"milk", 0.55]],
		"ZoneSection1_4": [[&"shampoo", 0.75]],
		"RearZone38": [[&"instant_noodles", 0.55], [&"chips", 0.95]],
		"RearZone37": [[&"cereal", 0.55]],
		"ShampooShelf": [[&"cooking_oil", 0.55]]
	}
	for base_name in rack_specs:
		var base: StockShelf = $Shelves.get_node(base_name)
		for spec in rack_specs[base_name]:
			var definition := ProductCatalog.find(spec[0])
			var tier := StockShelf.new()
			tier.name = base_name + "_" + String(definition.id)
			tier.use_catalog_tier = false
			tier.accepted_type = definition.id
			tier.max_stock = definition.shelf_capacity
			tier.tier_height = spec[1]
			tier.tier_clearance = 0.5
			tier.shelf_color = definition.tint
			tier.position = base.position
			tier.rotation = base.rotation
			tier.point_owner = base
			$Shelves.add_child(tier)
	for entry in [["PRODUCE", 7, 3], ["DRINKS / DAIRY", -14, 9], ["SNACKS / PANTRY", -23, 24], ["HOUSEHOLD", 23, 15], ["COOKWARE", -7, 12], ["ELECTRONICS", 23, 25], ["CHECKOUT", 11, 33]]:
		Graybox.sign(self, entry[0], Vector3(entry[1], 3.4, entry[2]), Color.GOLD)
		Graybox.box(self, "ZoneStripe", Vector3(5, 0.015, 0.3), Vector3(entry[1], 0.01, entry[2] - 2), Color(0.5, 0.45, 0.25), false)
	for pad in [[Vector3(7, 0.003, 6), Vector3(5, 0.004, 4), Color(0.29, 0.43, 0.33)], [Vector3(-14, 0.003, 11), Vector3(6, 0.004, 12), Color(0.3, 0.4, 0.49)], [Vector3(-22, 0.003, 26), Vector3(24, 0.004, 10), Color(0.45, 0.38, 0.3)], [Vector3(26, 0.003, 12), Vector3(12, 0.004, 17), Color(0.36, 0.43, 0.42)], [Vector3(-7, 0.003, 12), Vector3(6, 0.004, 4), Color(0.46, 0.4, 0.3)], [Vector3(20, 0.003, 24), Vector3(29, 0.004, 5), Color(0.4, 0.35, 0.48)]]:
		Graybox.box(self, "ZoneFloor", pad[1], pad[0], pad[2], false)
