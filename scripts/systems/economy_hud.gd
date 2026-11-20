class_name EconomyHud
extends CanvasLayer
## Daily read-only summary of the same cumulative managers used by Day Result.
const LOSS_KEYS := ["unpaid", "stolen", "fire", "boss", "broken", "food"]
var day: DayManager
var sales_label: Label
var losses_label: Label
var delta_label: Label
var sales: float = 0
var losses: float = 0
var delta_left: float = 0
var _previous: Dictionary = {}
var _day_number: int = 0

func _ready() -> void:
	for row in range(3):
		var label := Label.new()
		add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		label.offset_left = -390
		label.offset_right = -24
		label.offset_top = 64 + row * 23
		label.offset_bottom = 86 + row * 23
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size",18 if row<2 else 15)
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		if row==0: sales_label=label
		elif row==1: losses_label=label
		else: delta_label=label
	sales_label.modulate = Color.LIGHT_GREEN
	losses_label.modulate = Color.SALMON
	delta_label.hide()

func _process(delta: float) -> void:
	var visible_now := day.state == DayManager.State.ACTIVE or day.state == DayManager.State.ENDING
	sales_label.visible = visible_now
	losses_label.visible = visible_now
	var values := day._stats()
	for key in values: values[key] -= day.baseline.get(key,0)
	sales = values.sales
	losses = 0
	for key in LOSS_KEYS: losses += values[key]
	sales_label.text = "SALES  $%.0f" % sales
	losses_label.text = "LOSSES  $%.0f" % losses
	delta_left = maxf(0,delta_left-delta)
	if _day_number != day.day_number or not visible_now:
		_day_number = day.day_number
		_previous = values.duplicate()
		delta_left = 0
	if not _previous.is_empty() and visible_now:
		var sale_change: float = values.sales - _previous.sales
		var loss_change := 0.0
		var reasons: Array[String] = []
		for key in LOSS_KEYS:
			var change: float = values[key] - _previous[key]
			if change>0:
				loss_change += change
				reasons.append(key.to_upper())
		if sale_change>0 or loss_change>0:
			var parts: Array[String] = []
			if sale_change>0: parts.append("+$%.0f SALE" % sale_change)
			if loss_change>0: parts.append("-$%.0f %s" % [loss_change,reasons[0] if reasons.size()==1 else "LOSSES"])
			delta_label.text = "  /  ".join(parts)
			delta_label.modulate = Color.SALMON if loss_change>0 else Color.LIGHT_GREEN
			delta_left = 1.6 # Latest batch replaces previous feedback; no unbounded money queue.
	_previous = values.duplicate()
	delta_label.visible = visible_now and delta_left>0
