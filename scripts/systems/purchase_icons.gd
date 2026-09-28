extends Control
var customer: BasicCustomer
var manager: Node

func _draw() -> void:
	if not is_instance_valid(customer):
		return
	for i in range(customer.purchase_types.size()):
		var type := customer.purchase_types[i]
		var at := Vector2(12 + i * 64, 9)
		var color: Color = manager.product_color(type)
		if type == &"watermelon":
			draw_circle(at + Vector2(16, 16), 14, color)
			draw_line(at + Vector2(12, 3), at + Vector2(12, 29), color.darkened(0.4), 3)
		elif type == &"can":
			draw_rect(Rect2(at + Vector2(5, 0), Vector2(22, 32)), color)
			draw_line(at + Vector2(6, 5), at + Vector2(26, 5), Color.LIGHT_GRAY, 3)
		else:
			draw_rect(Rect2(at, Vector2(32, 28)), color)
			draw_line(at + Vector2(16, 0), at + Vector2(16, 28), color.darkened(0.4), 3)
		if i < customer.scanned:
			draw_line(at + Vector2(22, 22), at + Vector2(28, 29), Color.WHITE, 4)
			draw_line(at + Vector2(28, 29), at + Vector2(39, 13), Color.WHITE, 4)
