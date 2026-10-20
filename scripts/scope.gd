extends Control
# The sniper scope: black everywhere outside a circle, with a thin crosshair and range ticks inside it.
# main.gd sets `shown` every frame (true while the player is scoped in). Anchored to the full screen.

var shown := false : set = _set_shown

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # never eats clicks

func _set_shown(v: bool) -> void:
	if v != shown:
		shown = v
		visible = v
		queue_redraw()

func _draw() -> void:
	if not shown:
		return
	var size := get_viewport_rect().size
	var centre := size / 2.0
	var radius := minf(size.x, size.y) * 0.46
	var reach := centre.length() + 4.0  # far enough to cover the corners
	# One thick black ring from the edge of the lens out past the corners.
	draw_arc(centre, (radius + reach) / 2.0, 0.0, TAU, 128, Color.BLACK, reach - radius)
	draw_arc(centre, radius, 0.0, TAU, 128, Color(0, 0, 0, 1), 3.0)
	var line := Color(0, 0, 0, 0.9)
	draw_line(centre - Vector2(radius, 0), centre + Vector2(radius, 0), line, 1.5)
	draw_line(centre - Vector2(0, radius), centre + Vector2(0, radius), line, 1.5)
	for i in range(1, 6):  # ticks down the vertical line, for holding over at range
		var y := i * radius / 6.0
		draw_line(centre + Vector2(-6, y), centre + Vector2(6, y), line, 1.5)
	draw_circle(centre, 2.0, Color(1, 0.2, 0.2))
