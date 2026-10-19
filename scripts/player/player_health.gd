class_name PlayerHealth
extends Node
signal downed
signal restored
signal changed
@export var max_health: float = 100.0
@export var revive_multiplier: float = 2.0
@export var feed_distance: float = 2.0
var current_health: float = 100
var is_downed: bool = false
var team: TeamLifeManager
var spawn_transform: Transform3D

func _ready() -> void:
	name = "PlayerHealth"
	current_health = max_health
	spawn_transform = get_parent().global_transform
	add_to_group("player_health")
	_register.call_deferred()

func _register() -> void:
	var manager := get_tree().get_first_node_in_group("team_life") as TeamLifeManager
	if manager != null: manager.register_player(self)

func receive_damage(amount: float, _source: Node = null) -> void:
	if is_downed or amount <= 0 or not is_finite(amount) or (is_instance_valid(team) and team.day_failed_active): return
	current_health = maxf(0, current_health - amount)
	if current_health <= 0: enter_downed()
	changed.emit()

func heal(amount: float) -> bool:
	if is_downed or amount <= 0 or not is_finite(amount) or current_health >= max_health: return false
	current_health = minf(max_health, current_health + amount)
	changed.emit()
	return true

func enter_downed() -> void:
	if is_downed: return
	is_downed = true
	current_health = 0
	var pose := get_parent().get_node_or_null("Knockdown") as KnockdownState
	if pose != null: pose.hold_downed()
	downed.emit()
	changed.emit()
	if is_instance_valid(team): team.check_failure()

func revive(amount: float) -> bool:
	if not is_downed or amount <= 0 or not is_finite(amount) or (is_instance_valid(team) and team.day_failed_active): return false
	is_downed = false
	current_health = minf(max_health, amount)
	var pose := get_parent().get_node_or_null("Knockdown") as KnockdownState
	if pose != null: pose.release_downed()
	restored.emit()
	changed.emit()
	return true

func reset_for_day() -> void:
	is_downed = false
	current_health = max_health
	var body := get_parent() as CharacterBody3D
	body.global_transform = spawn_transform
	body.velocity = Vector3.ZERO
	var pose := body.get_node_or_null("Knockdown") as KnockdownState
	if pose != null:
		pose.persistent_down = false
		pose.finish_recovery()
	var head := body.get_node_or_null("Head") as Node3D
	if head != null: head.rotation = Vector3.ZERO
	restored.emit()
	changed.emit()

func use_food(food: GrabbableBody, target: PlayerHealth = null) -> bool:
	if is_downed or KnockdownState.blocked(get_parent()) or not is_instance_valid(team) or team.day_failed_active: return false
	var interaction := get_parent().get_node_or_null("Interaction")
	if not is_instance_valid(food) or food.is_queued_for_deletion() or interaction == null: return false
	if interaction.held_object != food or food.holder != interaction: return false
	var definition := ProductCatalog.find(food.product_type)
	if definition == null or not definition.is_food or definition.heal_value <= 0: return false
	if food.get_meta("consumed", false) or food.get_meta("sold", false) or food.get_meta("stolen", false) or food.get_meta("broken", false) or food.get_meta("boss_eaten", false): return false
	if target == null: target = self
	if target != self:
		if not team.players.has(target) or not target.is_downed: return false
		if get_parent().global_position.distance_to(target.get_parent().global_position) > feed_distance: return false
		# API callers cannot feed through a wall. The input path also requires aiming.
		var query := PhysicsRayQueryParameters3D.create(interaction.camera.global_position, target.get_parent().global_position + Vector3.UP * 0.7, 1 | 64 | 128, [get_parent().get_rid(), food.get_rid(), target.get_parent().get_rid()])
		if not get_parent().get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
		if not target.revive(definition.heal_value * revive_multiplier): return false
	elif not heal(definition.heal_value): return false
	food.set_meta("consumed", true)
	team.consumed_product_value += food.price
	interaction.drop_held()
	food.hide()
	food.queue_free()
	return true
