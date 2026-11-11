class_name HudLayout
extends RefCounted
## Reserved right column for prototype/event statistics; jobs stay on the left.
static func stat(label: Label, row: int) -> void:
	label.anchor_left = 1
	label.anchor_right = 1
	label.offset_left = -400
	label.offset_right = -24
	label.offset_top = 120 + row * 26
	label.offset_bottom = 144 + row * 26
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
