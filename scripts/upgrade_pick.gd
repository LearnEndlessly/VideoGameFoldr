extends Control
# The level-up screen: the game is paused and three upgrade cards are offered (click one, or press 1 2 3).
# Raid upgrades last until the raid ends. Built with scripts/ui_kit.gd.

const UIKit = preload("res://scripts/ui_kit.gd")
const Upgrades = preload("res://data/upgrades.gd")

var _choices: Array = []
var _on_pick := Callable()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # clickable while the raid is paused

# `choices` upgrade ids, `levels` the current levels (id -> int), `on_pick` called with the chosen id.
func show_choices(choices: Array, levels: Dictionary, on_pick: Callable) -> void:
	_choices = choices
	_on_pick = on_pick
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.theme = UIKit.theme(UIKit.AMBER)
	var title := UIKit.label("LEVEL UP", 56, UIKit.AMBER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UIKit.label("PICK ONE  -  LOST WHEN THE RAID ENDS", 14, UIKit.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for i in choices.size():
		var id: String = choices[i]
		var u: Dictionary = Upgrades.RAID_UPGRADES[id]
		var accent: Color = UIKit.AMBER if u["group"] == "weapon" else UIKit.GOOD
		var level := int(levels.get(id, 0))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.slab(UIKit.BG, accent, 0, 16, 5))
		row.add_child(card)
		var v := VBoxContainer.new()
		v.custom_minimum_size = Vector2(210, 0)
		v.add_theme_constant_override("separation", 8)
		card.add_child(v)
		v.add_child(UIKit.label(str(u["group"]).to_upper(), 12, accent))
		v.add_child(UIKit.label(str(u["name"]).to_upper(), 26, UIKit.TEXT, true))
		var desc := UIKit.label(u["desc"], 15, UIKit.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(0, 60)
		v.add_child(desc)
		v.add_child(UIKit.pips(level + 1, int(u["max"]), accent))
		var b := Button.new()
		b.text = "[%d]  TAKE" % (i + 1)
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(_pick.bind(id))
		v.add_child(b)
		if i == 0:
			b.grab_focus.call_deferred()

func _pick(id: String) -> void:
	if _on_pick.is_valid():
		_on_pick.call(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < _choices.size():
			get_viewport().set_input_as_handled()
			_pick(_choices[i])
