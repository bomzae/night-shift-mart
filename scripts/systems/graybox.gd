class_name Graybox
extends RefCounted
## Small primitive builder shared by the prototype fixtures; no gameplay state.

static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color, solid: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = label
	body.position = at
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	shape.material = material
	mesh.mesh = shape
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
	parent.add_child(body)
	return body

static func sign(parent: Node3D, text: String, at: Vector3, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 42
	label.pixel_size = 0.007
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
