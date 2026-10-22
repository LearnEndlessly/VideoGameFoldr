# Run (headless): Godot --headless --path <project> -s tools/count_buildings.gd
# Prints how many buildings and building crates each of 40 seeds gets, to tune data/buildings.gd.
extends SceneTree

const Main = preload("res://scripts/main.gd")

func _init() -> void:
	Main.show_start = false
	await process_frame
	var hist := {}
	var crates := 0
	for s in 40:
		var main = load("res://main.tscn").instantiate()
		main.seed_override = s
		root.add_child(main)
		var n: int = main.buildings.size()
		hist[n] = hist.get(n, 0) + 1
		if n == 0:
			print("no building: seed %d %s %.0fx%.0f gap %.1f taken %d" % [s, main.map_type, main.half_w * 2.0, main.half_d * 2.0, main._gap, main._taken.size()])
		crates += main.get_children().filter(func(c): return "zone_id" in c and c.zone_id == "building").size()
		main.queue_free()
		await process_frame
	print("buildings per map (count: maps): ", hist, "  building crates over 40 maps: ", crates)
	quit()
