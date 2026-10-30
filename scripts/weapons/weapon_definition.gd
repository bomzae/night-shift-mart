class_name WeaponDefinition
extends Resource
enum WeaponClass { MELEE }
@export var weapon_id: StringName
@export var display_name: String
@export var damage: float = 22
@export var knockback: float = 18
@export var swing_cooldown: float = 0.65
@export var swing_duration: float = 0.3
@export var range: float = 2.2
@export var durability_max: int = 14
@export var durability_cost: int = 1
@export var weight: float = 1.3
@export var throw_damage_multiplier: float = 1.0
@export var throw_value: float = 60 # Prototype input to the existing price/charge formula, not a shop price.
@export var weapon_class: WeaponClass = WeaponClass.MELEE
@export var weapon_tier: int = 1
@export var shaft_size: Vector3 = Vector3(0.12, 0.12, 1.0)
@export var head_size: Vector3 = Vector3(0.18, 0.18, 0.4)
@export var color: Color = Color.SANDY_BROWN
