class_name CombatTarget
extends CharacterBody3D
signal defeated
signal damaged(amount: float)
@export var max_health: float = 300.0
@export var target_mass: float = 18.0
@export var max_push_speed: float = 5.0
@export var push_drag: float = 3.0
var current_health: float
var is_defeated: bool = false
var hit_count: int = 0
var last_damage: float = 0
var external_velocity := Vector3.ZERO
var contact_zone: Area3D

func _ready() -> void:
	current_health = max_health
	collision_layer = HumanSeparation.MONSTER_LAYER
	collision_mask = 1 | HumanSeparation.HUMAN_LAYER | HumanSeparation.MONSTER_LAYER
	add_to_group("monsters")
	contact_zone = Area3D.new()
	contact_zone.collision_layer = 0
	contact_zone.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.85
	capsule.height = 1.5
	shape.shape = capsule
	shape.position.y = 0.75
	contact_zone.add_child(shape)
	add_child(contact_zone)

func contact_push(delta: float) -> void:
	for body in contact_zone.get_overlapping_bodies():
		if not body is RigidBody3D: continue
		var away := global_position - body.global_position
		away.y = 0
		var closing: float = body.linear_velocity.dot(away.normalized())
		if closing > 0.1:
			receive_impulse(away.normalized() * minf(40, closing * body.mass) * delta * 12)

func receive_damage(amount: float) -> void:
	if is_defeated or amount <= 0 or not is_finite(amount): return
	last_damage = amount
	hit_count += 1
	current_health = maxf(0, current_health - amount)
	damaged.emit(amount)
	if current_health <= 0:
		is_defeated = true
		defeated.emit()

func receive_impact(amount: float, impulse: Vector3) -> void:
	if is_defeated: return
	receive_impulse(impulse)
	receive_damage(amount)

func receive_impulse(impulse: Vector3) -> void:
	if is_defeated or not impulse.is_finite(): return
	external_velocity = (external_velocity + impulse / maxf(0.1, target_mass)).limit_length(max_push_speed)

func apply_external_impulse(impulse: Vector3) -> void:
	receive_impulse(impulse)
