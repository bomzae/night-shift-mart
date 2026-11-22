class_name EventBanner
extends CanvasLayer
## Session-local introductions; queued messages never stop the simulation.
const MESSAGES := {
	&"drunk": ["DRUNK CUSTOMER", "물건을 쓰러뜨리지 않도록 확인하세요."],
	&"family": ["LOST CHILD", "부모를 찾아 아이를 데려다 주세요."],
	&"accident": ["SPILL", "대걸레를 움직여 바닥의 물기를 닦으세요."],
	&"fire": ["FIRE", "소화기를 찾아 불을 끄세요."],
	&"thief": ["THIEF", "상품을 훔쳐 달아나기 전에 붙잡으세요."],
	&"tourist": ["TOURIST BUS", "많은 손님이 한꺼번에 들어옵니다."],
	&"boss": ["KING RAT", "상품을 집어 던져 쥐를 공격하세요."]
}
var seen: Dictionary = {}
var pending: Array[StringName] = []
var current: StringName = &""
var remaining: float = 0
var gap_left: float = 0
var panel: PanelContainer
var title: Label
var description: Label

func _ready() -> void:
	layer = 20
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = 88
	panel.offset_bottom = 160
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	for item in range(2):
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 20 if item == 0 else 16)
		rows.add_child(label)
		if item == 0: title = label
		else: description = label
	panel.hide()

func announce(type: StringName) -> void:
	if not MESSAGES.has(type) or current == type or pending.has(type): return
	pending.append(type)
	if current == &"" and gap_left <= 0: _show_next()

func _show_next() -> void:
	if pending.is_empty(): return
	current = pending.pop_front()
	title.text = MESSAGES[current][0]
	description.text = "" if seen.has(current) else MESSAGES[current][1]
	description.visible = not description.text.is_empty()
	title.modulate = Color.GOLD if current == &"boss" else Color.WHITE
	remaining = 3.0 if current == &"boss" else (2.8 if not seen.has(current) else 2.0)
	seen[current] = true
	panel.show()

func _process(delta: float) -> void:
	if current != &"":
		remaining = maxf(0, remaining - delta)
		if remaining == 0:
			current = &""
			gap_left = 0.5
			panel.hide()
	else:
		gap_left = maxf(0, gap_left - delta)
		if gap_left == 0: _show_next()

func busy() -> bool:
	return current != &"" or not pending.is_empty() or gap_left > 0

func clear_pending() -> void:
	pending.clear()
	current = &""
	remaining = 0
	gap_left = 0
	panel.hide()
