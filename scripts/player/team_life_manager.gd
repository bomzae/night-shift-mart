class_name TeamLifeManager
extends Node
signal day_failed
var players: Array[PlayerHealth] = []
var day_failed_active: bool = false
var current_day: int = 1
var consumed_product_value: float = 0
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
	if not DayManager.allows_activity(self): return
	if day_failed_active or not all_players_downed(): return
	day_failed_active = true
	day_failed.emit() # Final living player down: feeding is now rejected immediately.

func _physics_process(_delta: float) -> void:
	var hp := players[0] if not players.is_empty() and is_instance_valid(players[0]) else null
	label.text = "DAY FAILED" if day_failed_active else "HP %.0f / %.0f | ALIVE %d" % [hp.current_health if hp != null else 0, hp.max_health if hp != null else 100, alive_count()]

func next_day() -> void:
	var day := get_parent().get_node_or_null("DayManager")
	if day != null: day.confirm_result()
