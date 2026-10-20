extends Control
# Full-screen panel used for the start screen and the end-of-raid results.
# Add it to a CanvasLayer first, then call show_screen().

const ItemIcon = preload("res://scripts/item_icon.gd")

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # still clickable while the raid is paused

# items_header == "" hides the raid-items section (the start screen has none).
func show_screen(title: String, subtitle: String, items_header: String, items: Dictionary,
		totals: Dictionary, button_text: String, on_press: Callable) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	box.add_child(t)
	var sub := Label.new()
	sub.text = subtitle
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	if items_header != "":
		_section(box, items_header, items, "(nothing)")
	_section(box, "Stored total", totals, "(nothing yet)")

	var button := Button.new()
	button.text = button_text
	button.pressed.connect(on_press)
	box.add_child(button)
	button.grab_focus.call_deferred()  # Enter / Space also work

func _section(box: VBoxContainer, header: String, items: Dictionary, empty_text: String) -> void:
	var h := Label.new()
	h.text = header
	h.add_theme_font_size_override("font_size", 18)
	box.add_child(h)
	if items.is_empty():
		var none := Label.new()
		none.text = empty_text
		box.add_child(none)
		return
	var ids := items.keys()
	ids.sort()
	for id in ids:
		var row := HBoxContainer.new()
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.item_id = id
		row.add_child(icon)
		var label := Label.new()
		label.text = "%s x%d" % [str(id).replace("_", " "), items[id]]
		row.add_child(label)
		box.add_child(row)
