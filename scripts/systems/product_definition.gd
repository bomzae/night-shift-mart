class_name ProductDefinition
extends Resource
## Shared prototype data; live products retain editable instance values.
@export var id: StringName
@export var display_name: String
@export var scene_path: String
@export var shelf_name: String
@export var price: float
@export var weight: float
@export var is_food: bool = false
@export var heal_value: float = 0
@export var flammable: bool = true
@export var size := Vector3(0.3, 0.3, 0.3)
@export_enum("Box", "Cylinder", "Sphere") var shape_kind: int = 0
@export var tint: Color = Color.WHITE
@export var carry_radius: float = 0.3
@export var shelf_capacity: int = 8
@export var slot_columns: int = 4
@export var slot_rows: int = 2
@export var shelf_position: Vector3
@export var shelf_yaw: float = 180
@export var shelf_tier_height: float = 0.0
@export var shelf_tier_clearance: float = 1.2
@export var rack_base_name: String = ""
@export var legacy: bool = false

func mesh() -> PrimitiveMesh:
	if shape_kind == 1:
		var result := CylinderMesh.new()
		result.top_radius = size.x / 2
		result.bottom_radius = size.x / 2
		result.height = size.y
		return result
	if shape_kind == 2:
		var result := SphereMesh.new()
		result.radius = size.x / 2
		result.height = size.y
		return result
	var result := BoxMesh.new()
	result.size = size
	return result

func collision_shape() -> Shape3D:
	if shape_kind == 1:
		var result := CylinderShape3D.new()
		result.radius = size.x / 2
		result.height = size.y
		return result
	if shape_kind == 2:
		var result := SphereShape3D.new()
		result.radius = size.x / 2
		return result
	var result := BoxShape3D.new()
	result.size = size
	return result

func stock_slots() -> Array[Vector3]:
	var slots: Array[Vector3] = []
	for row in range(slot_rows):
		for column in range(slot_columns):
			if slots.size() >= shelf_capacity: break
			var x := (column - (slot_columns - 1) * 0.5) * (2.5 / slot_columns)
			var z := (row - (slot_rows - 1) * 0.5) * (1.2 / slot_rows)
			slots.append(Vector3(x, 0.65 + size.y / 2 + 0.015, z))
	return slots
