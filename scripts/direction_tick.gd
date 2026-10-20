extends Control
# A small arrow on a ring around the crosshair, pointing toward something in the world relative to where the
# player is facing (up = straight ahead), with a short label. Anchored at the screen centre; main.gd sets
# `angle` (radians, 0 = ahead, positive = to the right), `text`, `radius` (px) and `shown` every frame.

var angle := 0.0
var text := ""
var radius := 110.0
var shown := false
var color := Color(1, 0.75, 0.1)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # a HUD drawing must never eat clicks meant for the backpack

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not shown:
		return
	var dir := Vector2(sin(angle), -cos(angle))
	var side := Vector2(-dir.y, dir.x)
	var base := dir * radius
	draw_colored_polygon(PackedVector2Array([base + dir * 12.0, base - dir * 4.0 + side * 8.0, base - dir * 4.0 - side * 8.0]), color)
	var label_at := dir * (radius + 26.0) + Vector2(-28.0, 5.0)
	draw_string(ThemeDB.fallback_font, label_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)
