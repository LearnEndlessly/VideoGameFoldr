extends Control
# Draws an item's symbol from its "shape" and "color" in data/loot.gd.

const Loot = preload("res://data/loot.gd")

var item_id := "":
	set(v):
		item_id = v
		queue_redraw()

func _draw() -> void:
	if item_id == "":
		return
	var d: Dictionary = Loot.ITEMS[item_id]
	var c: Color = d["color"]
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	match d["shape"]:
		"gear":
			draw_circle(size / 2.0, s * 0.32, c)
			for i in 8:
				var a := i * TAU / 8.0
				draw_circle(size / 2.0 + Vector2(cos(a), sin(a)) * s * 0.36, s * 0.08, c)
			draw_circle(size / 2.0, s * 0.12, Color(0.15, 0.15, 0.15))
		"bullet":
			draw_rect(Rect2(o + Vector2(s * 0.35, s * 0.4), Vector2(s * 0.3, s * 0.45)), c)
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(s * 0.35, s * 0.4), o + Vector2(s * 0.5, s * 0.12), o + Vector2(s * 0.65, s * 0.4)]), c)
		"cross":
			draw_rect(Rect2(o + Vector2(s * 0.12, s * 0.12), Vector2(s * 0.76, s * 0.76)), Color.WHITE)
			draw_rect(Rect2(o + Vector2(s * 0.42, s * 0.2), Vector2(s * 0.16, s * 0.6)), c)
			draw_rect(Rect2(o + Vector2(s * 0.2, s * 0.42), Vector2(s * 0.6, s * 0.16)), c)
		"diamond":
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(s * 0.5, s * 0.1), o + Vector2(s * 0.9, s * 0.5),
				o + Vector2(s * 0.5, s * 0.9), o + Vector2(s * 0.1, s * 0.5)]), c)
