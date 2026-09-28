extends CharacterBody3D
## Instrumented test dummy only; not an NPC or player health system.

@export var receive_knockback: bool = false
@export var max_hp: float = 100.0
@export var target_mass: float = 3.0
@export var knockback_drag: float = 4.0
var hp: float
var last_damage: float = 0.0
var last_impulse: float = 0.0
var hit_count: int = 0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	hp = max_hp
	$Mesh.material_override = _material
	_update_feedback()


func receive_impact(damage: float, impulse: Vector3) -> void:
	if hp <= 0.0:
		return
	last_damage = damage
	last_impulse = impulse.length()
	hit_count += 1
	hp = maxf(0.0, hp - damage)
	if receive_knockback:
		velocity += impulse / maxf(0.1, target_mass)
	_update_feedback()
	print("%s: damage=%.2f HP=%.2f impulse=%.2f" % [name, damage, hp, last_impulse])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	velocity.x = move_toward(velocity.x, 0.0, knockback_drag * delta)
	velocity.z = move_toward(velocity.z, 0.0, knockback_drag * delta)
	move_and_slide()


func _update_feedback() -> void:
	_material.albedo_color = Color.DIM_GRAY if hp <= 0.0 else (Color.MEDIUM_PURPLE if receive_knockback else Color.INDIAN_RED)
	$Label.text = "%s\nHP %.1f / %.0f\nHit %.2f | Impulse %.2f" % ["KNOCKBACK" if receive_knockback else "DAMAGE", hp, max_hp, last_damage, last_impulse]
