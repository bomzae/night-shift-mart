class_name WeaponCrate
extends StaticBody3D
var weapon: WeaponDefinition
var opened: bool = false

func _ready() -> void:
	Graybox.box(self, "Box", Vector3(1.1, 0.55, 1.4), Vector3.ZERO, Color.DARK_OLIVE_GREEN, false)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.55, 1.4)
	shape.shape = box
	add_child(shape)
	Graybox.sign(self, weapon.display_name + "\nE OPEN", Vector3(0, 0.65, 0), Color.GOLD).pixel_size = 0.0025

func open_crate() -> WeaponBody:
	if opened: return null
	# Do not materialize the weapon inside player goods resting on the crate.
	var point := global_position + Vector3.UP * 0.65
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.4, 1.4)
	query.shape = box
	query.transform.origin = point
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return null
	opened = true
	var body := WeaponBody.new()
	body.weapon = weapon
	get_parent().add_child(body)
	body.global_position = point
	queue_free()
	return body
