extends Node3D
const CATALOG = [preload("res://data/weapons/bat.tres"), preload("res://data/weapons/sledgehammer.tres"), preload("res://data/weapons/broom.tres")]
var next_weapon: int = 0
var pending: bool = false
var feedback: Label3D

func _ready() -> void:
	feedback = Graybox.sign(self, "N: WEAPON DELIVERY", Vector3(6, 2.2, 0), Color.GOLD)
	feedback.pixel_size = 0.003

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_order_weapon") and not event.is_echo(): pending = true

func _physics_process(_delta: float) -> void:
	if pending:
		pending = false
		order()

func order() -> WeaponCrate:
	for slot in range(3):
		var point := to_global(Vector3(6, 0.3, 0.2 + (slot - 1) * 1.6))
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 0.5, 1.5)
		query.shape = box
		query.transform.origin = point
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
		var crate := WeaponCrate.new()
		crate.weapon = CATALOG[next_weapon]
		add_child(crate)
		crate.global_position = point
		feedback.text = "DELIVERED: " + crate.weapon.display_name
		next_weapon = (next_weapon + 1) % CATALOG.size()
		return crate
	feedback.text = "CLEAR WEAPON DELIVERY SPACE"
	return null
