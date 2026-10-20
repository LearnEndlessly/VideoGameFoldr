extends Control
# The pause menu, opened with Esc during a raid: the game is paused and the controls are listed as key caps.
# Esc or the button resumes. Built with scripts/ui_kit.gd.

const UIKit = preload("res://scripts/ui_kit.gd")

# [key, what it does]
const CONTROLS := [
	["W A S D", "Move"], ["MOUSE", "Look around"], ["SHIFT", "Sprint (loud: enemies hear it through walls)"],
	["SPACE", "Jump"], ["LEFT CLICK", "Shoot"], ["HOLD R", "Reload (letting go cancels it)"],
	["HOLD RMB", "Zoom in (the sniper rifle looks through its scope)"], ["E", "Open a crate you are looking at"], ["TAB", "Backpack (click an item to use it, right-click to drop)"],
	["ESC", "This menu"],
]

var _on_resume := Callable()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # works while the raid is paused

func show_menu(on_resume: Callable) -> void:
	_on_resume = on_resume
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme = UIKit.theme(UIKit.AMBER)
	panel.add_theme_stylebox_override("panel", UIKit.slab(UIKit.BG, UIKit.AMBER, 10, 22))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UIKit.header("PAUSED", "controls", UIKit.AMBER, 48))
	for c in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var cap := PanelContainer.new()
		cap.custom_minimum_size = Vector2(150, 0)
		cap.add_theme_stylebox_override("panel", UIKit.slab(UIKit.CARD, UIKit.AMBER, 0, 6, 3))
		row.add_child(cap)
		var key := UIKit.label(c[0], 16, UIKit.TEXT, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(key)
		var what := UIKit.label(c[1], 15, UIKit.DIM)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(what)
	box.add_child(UIKit.label("Gamepads are not supported yet.", 12, UIKit.DIM))
	var resume := UIKit.big_button("Resume", UIKit.AMBER, 56)
	resume.pressed.connect(_resume)
	box.add_child(resume)
	resume.grab_focus.call_deferred()

func _resume() -> void:
	if _on_resume.is_valid():
		_on_resume.call()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_resume()
