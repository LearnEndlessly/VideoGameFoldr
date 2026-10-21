extends Control
# The end-of-raid screen, in the style of scripts/ui_kit.gd: a stamped verdict, a row of stat tiles, the loot as
# tiles, and the choice. After an extract the choice is to go home with the loot or to descend with it, still
# unbanked, into a harder level. Add it to a CanvasLayer first, then call show_result().

const UIKit = preload("res://scripts/ui_kit.gd")
const Tuning = preload("res://data/tuning.gd")

var descend_button: Button  # null after a death
var home_button: Button

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # still clickable while the raid is paused

# `result` is Raid's `ended` dictionary, `level` the level just played (1 = first), `on_home` / `on_descend` the choices.
func show_result(result: Dictionary, level: int, on_home: Callable, on_descend: Callable) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var extracted: bool = result["outcome"] == "extracted"
	var accent: Color = UIKit.GOOD if extracted else UIKit.BAD
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme = UIKit.theme(accent)
	panel.add_theme_stylebox_override("panel", UIKit.slab(UIKit.BG, accent, 10, 22))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(UIKit.header("EXTRACTED" if extracted else "K.I.A.", "level %d" % level, accent, 64))
	var verdict := "The loot is stored in the base." if extracted else "Everything you carried this raid is lost."
	if extracted and not result["saved"]:
		verdict = "WARNING: your profile could not be saved."
	box.add_child(UIKit.label(verdict, 18, UIKit.DIM))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	box.add_child(stats)
	var shots: int = result["shots"]
	stats.add_child(UIKit.tile("kills", str(result["kills"]), accent))
	stats.add_child(UIKit.tile("accuracy", "-" if shots == 0 else "%d%%" % int(round(100.0 * result["hits"] / shots)), accent))
	stats.add_child(UIKit.tile("shots", str(shots), accent))
	stats.add_child(UIKit.tile("time", "%d:%02d" % [int(result["duration"]) / 60, int(result["duration"]) % 60], accent))
	stats.add_child(UIKit.tile("score", str(result.get("score", 0)), accent))
	if result["points"] > 0:  # a cleared round earns an attribute point, kept even if the raid is lost
		stats.add_child(UIKit.tile("attribute pts", "+%d" % result["points"], UIKit.AMBER, UIKit.AMBER))
	if extracted:
		stats.add_child(UIKit.tile("reward", "x%.2f" % result["reward_mult"], UIKit.AMBER, UIKit.AMBER))

	box.add_child(UIKit.label("KEPT THIS RAID" if extracted else "LOST THIS RAID", 14, UIKit.DIM))
	var loot := HFlowContainer.new()
	loot.add_theme_constant_override("h_separation", 8)
	loot.add_theme_constant_override("v_separation", 8)
	box.add_child(loot)
	var items: Dictionary = result["items"]
	if items.is_empty():
		loot.add_child(UIKit.label("nothing", 18, UIKit.DIM))
	var ids := items.keys()
	ids.sort()
	for id in ids:
		loot.add_child(UIKit.item_tile(id, items[id], accent))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	home_button = Button.new()
	home_button.text = "RETURN TO BASE"
	home_button.custom_minimum_size = Vector2(220, 64)
	home_button.pressed.connect(on_home)
	row.add_child(home_button)
	if extracted:
		var stay := VBoxContainer.new()
		stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stay.add_theme_constant_override("separation", 4)
		row.add_child(stay)
		descend_button = UIKit.big_button("Descend to level %d" % (level + 1), UIKit.AMBER)
		descend_button.pressed.connect(on_descend)
		stay.add_child(descend_button)
		stay.add_child(UIKit.label("Your loot comes along, at risk. More bases, faster spawns, more ammo; rewards +%d%%." % int(Tuning.DEPTH_REWARD_BONUS * 100.0), 12, UIKit.DIM))
	home_button.grab_focus.call_deferred()  # Enter / Space take the safe choice
