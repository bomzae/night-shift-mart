extends Node3D
## Runtime primitive geometry; the reusable product/cart/player scenes own behavior.

func _ready() -> void:
	var wall := Color(0.48, 0.51, 0.55)
	Graybox.box($StoreFloor, "Floor", Vector3(18, 0.4, 12), Vector3(0, -0.2, 6), Color(0.4, 0.43, 0.46))
	Graybox.box($Backroom, "Floor", Vector3(18, 0.4, 3), Vector3(0, -0.2, -1.5), Color(0.32, 0.37, 0.4))
	Graybox.box($LoadingArea, "Floor", Vector3(18, 0.4, 3), Vector3(0, -0.2, -4.5), Color(0.28, 0.3, 0.32))
	for x in [-9, 9]:
		Graybox.box(self, "Boundary", Vector3(0.25, 3, 18), Vector3(x, 1.5, 3), wall)
	for z in [-6]:
		Graybox.box(self, "Boundary", Vector3(18, 3, 0.25), Vector3(0, 1.5, z), wall)
	Graybox.box(self, "FrontLeft", Vector3(4, 3, 0.25), Vector3(-7, 1.5, 12), wall)
	Graybox.box(self, "FrontRight", Vector3(10, 3, 0.25), Vector3(4, 1.5, 12), wall)
	Graybox.box(self, "Outside", Vector3(6, 0.4, 4), Vector3(-3, -0.2, 14), Color(0.25, 0.35, 0.3))
	Graybox.sign(self, "EXIT  ~_~ →", Vector3(-3, 2.5, 14), Color.LIME_GREEN)
	# One centered 5m rear door, directly joining dispatch and the main aisle.
	for doorway in [Vector2(0, 0)]:
		var left_end: float = doorway.x - 2.5
		var right_start: float = doorway.x + 2.5
		Graybox.box(self, "Partition", Vector3(left_end + 9, 3, 0.25), Vector3((-9 + left_end) / 2, 1.5, doorway.y), wall)
		Graybox.box(self, "Partition", Vector3(9 - right_start, 3, 0.25), Vector3((9 + right_start) / 2, 1.5, doorway.y), wall)
	Graybox.sign($LoadingArea, "↓ LOADING", Vector3(-3, 2.6, -5), Color.GOLD)
	Graybox.sign($Backroom, "BACKROOM / DELIVERY", Vector3(0, 2.6, -1))
	Graybox.sign($StoreFloor, "STORE", Vector3(0, 2.8, 3))
	Graybox.box($StoreFloor, "CheckoutReserved", Vector3(3, 0.025, 2), Vector3(5, 0.015, 10), Color(0.55, 0.5, 0.25), false)
	Graybox.box($Entrance, "DoorMarker", Vector3(3, 0.03, 0.3), Vector3(0, -1.23, 0), Color(0.25, 0.5, 0.55), false)
	Graybox.sign($Entrance, "ENTRANCE", Vector3(0, 1.8, -0.1))
