class_name KingRatManager
extends Node3D
var boss: KingRat
var bosses_defeated: int = 0
var boss_product_loss_value: float = 0
var health_bar: ProgressBar
var status: Label
var boss_title: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	status = Label.new()
	status.position = Vector2(24, 312)
	canvas.add_child(status)
	boss_title = Label.new()
	boss_title.position = Vector2(470, 16)
	boss_title.text = "KING RAT"
	canvas.add_child(boss_title)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(400, 45)
	health_bar.size = Vector2(280, 20)
	canvas.add_child(health_bar)
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spawn_king_rat") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_boss()
		get_viewport().set_input_as_handled()

func spawn_boss() -> KingRat:
	if is_instance_valid(boss): return null
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	if player == null: player = get_parent().get_node("Player")
	for at in [Vector3(0, 0.02, 2), Vector3(-4, 0.02, 2), Vector3(4, 0.02, 2)]:
		if at.distance_to(player.global_position) < 3: continue
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.75
		shape.height = 1.5
		query.shape = shape
		query.transform.origin = at + Vector3.UP * 0.8
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
		boss = preload("res://scenes/combat/king_rat.tscn").instantiate()
		boss.director = self
		boss.player = player
		boss.position = at
		add_child(boss)
		boss.defeated.connect(func(): bosses_defeated += 1; _update_ui())
		_update_ui()
		return boss
	return null

func _physics_process(_delta: float) -> void:
	_update_ui()

func _update_ui() -> void:
	var active := is_instance_valid(boss) and not boss.is_defeated
	health_bar.visible = active
	boss_title.visible = active
	if active:
		health_bar.max_value = boss.max_health
		health_bar.value = boss.current_health
	status.text = "[R] KING RAT | DEFEATED %d | BOSS LOSS $%.0f" % [bosses_defeated, boss_product_loss_value]
