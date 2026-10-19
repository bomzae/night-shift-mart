class_name TeamLifeManager
extends Node
signal day_failed
@export var reset_delay: float = 2.0
var players: Array[PlayerHealth] = []
var day_failed_active: bool = false
var current_day: int = 1
var consumed_product_value: float = 0
var _reset_left: float = 0
var label: Label

func _ready() -> void:
	add_to_group("team_life")
	for health in get_tree().get_nodes_in_group("player_health"): register_player(health)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(24, 345)
	canvas.add_child(label)

func register_player(health: PlayerHealth) -> void:
	if players.has(health): return
	players.append(health)
	health.team = self

func alive_count() -> int:
	var count := 0
	for health in players:
		if is_instance_valid(health) and not health.is_downed: count += 1
	return count

func all_players_downed() -> bool:
	players = players.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
	return not players.is_empty() and alive_count() == 0

func check_failure() -> void:
	if day_failed_active or not all_players_downed(): return
	day_failed_active = true
	_reset_left = reset_delay
	day_failed.emit() # Final living player down: feeding is now rejected immediately.

func _physics_process(delta: float) -> void:
	if day_failed_active:
		_reset_left -= delta
		if _reset_left <= 0: next_day()
	var hp := players[0] if not players.is_empty() and is_instance_valid(players[0]) else null
	label.text = "DAY FAILED" if day_failed_active else "HP %.0f / %.0f | ALIVE %d | DAY %d | FOOD $%.0f [G]" % [hp.current_health if hp != null else 0, hp.max_health if hp != null else 100, alive_count(), current_day, consumed_product_value]

func next_day() -> void:
	if not day_failed_active: return
	# Prototype player reset only; stock, money and business are not reset.
	var bosses := get_parent().get_node_or_null("Bosses")
	if bosses != null and is_instance_valid(bosses.boss):
		bosses.boss.queue_free()
		bosses.boss = null
	for health in players:
		if not is_instance_valid(health): continue
		for group in ["fires", "spills"]:
			for hazard in get_tree().get_nodes_in_group(group):
				if hazard.global_position.distance_to(health.spawn_transform.origin) < 3: hazard.queue_free()
		health.reset_for_day()
	current_day += 1
	day_failed_active = false
