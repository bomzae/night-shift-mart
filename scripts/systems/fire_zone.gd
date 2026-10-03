class_name FireZone
extends Area3D

signal extinguished
@export var intensity: float = 0.3
@export var growth_rate: float = 0.025
@export var minimum_radius: float = 0.6
@export var maximum_radius: float = 1.7
var radius: float
var _shape: CylinderShape3D
var _flame: MeshInstance3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _ended: bool = false

func _ready() -> void:
	add_to_group("fires")
	collision_layer = 32
	collision_mask = 1
	var collision := CollisionShape3D.new()
	_shape = CylinderShape3D.new()
	_shape.height = 2.6
	collision.shape = _shape
	collision.position.y = 1.2
	add_child(collision)
	_flame = flame_mesh(Color(1, 0.18, 0.015), 0.65, 1.5)
	_core = flame_mesh(Color(1, 0.85, 0.15), 0.35, 1.0)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.35, 0.07)
	_light.omni_range = 4
	_light.position.y = 0.8
	add_child(_light)
	_refresh()

func flame_mesh(color: Color, width: float, height: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = width
	cone.height = height
	instance.mesh = cone
	instance.position.y = height * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	instance.material_override = material
	add_child(instance)
	return instance

func _physics_process(delta: float) -> void:
	if _ended: return
	intensity = minf(1, intensity + growth_rate * delta)
	_refresh()

func _refresh() -> void:
	radius = lerpf(minimum_radius, maximum_radius, intensity)
	_shape.radius = radius
	_flame.scale = Vector3.ONE * (0.65 + intensity)
	_core.scale = _flame.scale
	_light.light_energy = 0.5 + intensity * 1.5

func suppress(amount: float) -> void:
	if _ended or amount <= 0: return
	intensity = maxf(0, intensity - amount)
	if intensity <= 0:
		_ended = true
		collision_layer = 0
		extinguished.emit()
		queue_free()
	else: _refresh()
