extends Node3D
const CATALOG = [preload("res://data/weapons/bat.tres"), preload("res://data/weapons/sledgehammer.tres"), preload("res://data/weapons/broom.tres")]
var next_weapon: int = 0
var pending: bool = false
var feedback: Label3D
var order_info: Label
var order_left: float = 0

func _ready() -> void:
	feedback = Graybox.sign(self, "N: WEAPON DELIVERY", Vector3(6, 2.2, 0), Color.GOLD)
	feedback.pixel_size = 0.003
	var canvas := CanvasLayer.new()
	add_child(canvas)
	order_info = Label.new()
	canvas.add_child(order_info)
	order_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	order_info.offset_left = -300
	order_info.offset_top = 65
	order_info.offset_right = -24
	order_info.offset_bottom = 115
	order_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_info.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_order_weapon") and not event.is_echo(): pending = true

func _physics_process(_delta: float) -> void:
	order_left = maxf(0, order_left - _delta)
	order_info.visible = order_left > 0
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
		order_info.text = "ORDERED\n" + crate.weapon.display_name
		order_left = 2.0
		next_weapon = (next_weapon + 1) % CATALOG.size()
		return crate
	feedback.text = "CLEAR WEAPON DELIVERY SPACE"
	return null
