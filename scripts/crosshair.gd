extends Control
# Centred crosshair that follows the weapon: a small cross for a tight weapon, and for a spread
# weapon a circle the size of the cone the pellets land in. Anchored at the screen centre, so
# everything draws around (0, 0).

var spread := 0.0  # weapon's cone half-angle in radians
var fov := 75.0  # camera vertical field of view, degrees
var _drawn := -1.0

func _process(_d: float) -> void:
	if spread != _drawn:
		_drawn = spread
		queue_redraw()

func _draw() -> void:
	var color := Color(1, 1, 1, 0.9)
	draw_circle(Vector2.ZERO, 1.5, color)
	if spread <= 0.0:
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(dir * 3.0, dir * 8.0, color, 2.0)
		return
	var radius := tan(spread) / tan(deg_to_rad(fov) / 2.0) * get_viewport_rect().size.y / 2.0
	draw_arc(Vector2.ZERO, maxf(radius, 6.0), 0.0, TAU, 64, color, 2.0)
