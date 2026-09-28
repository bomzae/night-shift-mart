extends Node3D
@export var interact_distance: float = 2.8
@export var scan_interval: float = 0.5
var manager: Node
var player: CharacterBody3D
var _panel: PanelContainer
var _title: Label
var _icons: Control
var _hint: Label
var _money: Label
var _pay_material: StandardMaterial3D

func _ready() -> void:
	player = manager.get_parent().get_node("Player")
	Graybox.box(self, "Counter", Vector3(2.4, 0.95, 0.85), Vector3(0, 0.475, 0), Color(0.35, 0.4, 0.45))
	var scan := Graybox.box(self, "Scanner", Vector3(0.55, 0.16, 0.45), Vector3(-0.55, 1.03, 0), Color.CORNFLOWER_BLUE)
	scan.set_meta("checkout_action", "scan")
	var pay := Graybox.box(self, "Payment", Vector3(0.45, 0.16, 0.4), Vector3(0.6, 1.03, 0), Color.DIM_GRAY)
	pay.set_meta("checkout_action", "pay")
	_pay_material = pay.get_child(0).mesh.material
	Graybox.sign(self, "SCAN", Vector3(-0.55, 1.25, 0)).pixel_size = 0.003
	Graybox.sign(self, "PAY", Vector3(0.6, 1.25, 0)).pixel_size = 0.003
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_panel = PanelContainer.new()
	_panel.position = Vector2(24, 110)
	_panel.custom_minimum_size = Vector2(230, 135)
	canvas.add_child(_panel)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	rows.add_child(_title)
	_icons = Control.new()
	_icons.set_script(preload("res://scripts/systems/purchase_icons.gd"))
	_icons.manager = manager
	_icons.custom_minimum_size = Vector2(220, 52)
	rows.add_child(_icons)
	_hint = Label.new()
	rows.add_child(_hint)
	_money = Label.new()
	_money.position = Vector2(24, 60)
	canvas.add_child(_money)

func in_operator_area() -> bool:
	var local := to_local(player.global_position)
	return absf(local.x) < 1.8 and local.z > 0.45 and local.z < 2.1 and absf(local.y) < 0.5

func aimed_action() -> String:
	if not in_operator_area() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return ""
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * interact_distance)
	ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not is_ancestor_of(hit.collider):
		return ""
	return str(hit.collider.get_meta("checkout_action", ""))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		var action := aimed_action()
		if not action.is_empty():
			use_station(action)
			get_viewport().set_input_as_handled()

func use_station(action: String) -> bool:
	if not in_operator_area() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var customer: BasicCustomer = manager.current_customer()
	if customer == null or customer.scan_wait > 0:
		return false
	if not manager.valid_goods(customer):
		manager.out_of_stock(customer)
		return false
	if action == "scan" and customer.scanned < customer.purchase_types.size():
		customer.scanned += 1
		customer.scan_wait = maxf(0.05, scan_interval)
		return true
	if action == "pay":
		return manager.finish(customer, true)
	return false

func _process(_delta: float) -> void:
	var customer: BasicCustomer = manager.current_customer()
	_panel.visible = in_operator_area() and customer != null
	_money.text = "SALES $%.2f   |   UNPAID LOSS $%.2f" % [manager.sales, manager.unpaid_loss]
	var ready_to_pay := customer != null and customer.scanned == customer.purchase_types.size() and customer.scan_wait <= 0
	_pay_material.albedo_color = Color.LIME_GREEN if ready_to_pay else Color.DIM_GRAY
	if customer != null:
		_title.text = "SCAN %d / %d   $%.2f" % [customer.scanned, customer.purchase_types.size(), customer.purchase_total]
		_icons.customer = customer
		_icons.queue_redraw()
		_hint.text = "E → PAY" if ready_to_pay else "E → SCAN"
