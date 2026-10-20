extends Control
# One slot per round in the magazine: brass bullets for loaded rounds, dim outlines for empty ones.
# main.gd sets `total` (clip size) and `filled` (rounds shown) every frame.

const SLOT_W := 5.0
const SLOT_H := 11.0
const GAP := 2.0

var total := 0
var filled := 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # a HUD drawing must never eat clicks meant for the backpack

func _process(_d: float) -> void:
	custom_minimum_size = Vector2(total * (SLOT_W + GAP), SLOT_H)
	queue_redraw()

func _draw() -> void:
	for i in total:
		var x := i * (SLOT_W + GAP)
		if i < filled:
			draw_rect(Rect2(x, 3, SLOT_W, SLOT_H - 3), Color(1.0, 0.8, 0.2))
			draw_rect(Rect2(x + 1, 0, SLOT_W - 2, 3), Color(0.85, 0.5, 0.15))
		else:
			draw_rect(Rect2(x, 3, SLOT_W, SLOT_H - 3), Color(1, 1, 1, 0.35), false, 1.0)
