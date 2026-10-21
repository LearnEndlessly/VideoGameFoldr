extends Control
# The ready indicator for slow weapons (the "ready" field in data/weapons.gd): a ring around the crosshair, also
# drawn inside the scope. While the next shot is not ready it is an orange arc that fills as the wait (or the reload)
# runs down; ready, it is a whole green ring with four ticks; out of ammo it is a dim red ring. main.gd sets the
# fields every frame. Anchored at the screen centre, so it draws around (0, 0).

var shown := false
var fraction := 1.0  # how far the wait has got, 0..1
var is_ready := true
var empty := false  # nothing to fire
var radius := 24.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	visible = shown
	if shown:
		queue_redraw()

func _draw() -> void:
	if not shown:
		return
	if empty:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.9, 0.2, 0.2, 0.55), 2.0)
		return
	if is_ready:
		var green := Color(0.3, 1.0, 0.4, 0.95)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, green, 3.0)
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(dir * (radius - 3.0), dir * (radius + 6.0), green, 3.0)
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
	draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * clampf(fraction, 0.0, 1.0), 48, Color(1.0, 0.55, 0.1, 0.95), 3.0)
