# Run: Godot --headless --path <project> -s tests/seed_golden.gd   (exit code 1 on failure)
# Pins map generation: the same seed must give the same map (twice in a row, and against
# tests/fixtures/seed_golden.json). A refactor of the generator in main.gd must keep this green.
# After an INTENDED generation change (it changes every old seed), regenerate the fixture with:
#   Godot --headless --path <project> -s tests/seed_golden.gd -- --write
extends SceneTree

const Main = preload("res://scripts/main.gd")
const FIXTURE := "res://tests/fixtures/seed_golden.json"
const SEEDS := 8

func _init() -> void:
	Main.show_start = false
	var got := {}
	var failures := 0
	for s in SEEDS:
		var a: String = await _fingerprint(s)
		var b: String = await _fingerprint(s)
		if a != b:
			printerr("seed %d: two builds of the same seed differ" % s)
			failures += 1
		got[str(s)] = a
	if "--write" in OS.get_cmdline_user_args():
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(got, "\t"))
		f.close()
		print("seed_golden: wrote %s" % FIXTURE)
		quit(failures)
		return
	var want = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not want is Dictionary:
		printerr("seed_golden: fixture missing or unreadable; run with -- --write")
		quit(1)
		return
	for k in got:
		if want.get(k) != got[k]:
			printerr("seed %s: map differs from the golden fixture" % k)
			failures += 1
	print("seed_golden: %d failure(s) over %d seeds" % [failures, SEEDS])
	quit(1 if failures > 0 else 0)

func _fingerprint(s: int) -> String:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = s
	root.add_child(main)
	await process_frame
	var info: Dictionary = main._map_info()
	# Enemies start patrolling during the awaited frame (unseeded), so pin their spawn point, not where they are now.
	info["enemies"] = main.get_children().filter(func(n): return "stats" in n).map(
		func(n): return [n.stats["type"], n.stats["modifier"], n.group_id, n.home])
	var text := var_to_str(info) + var_to_str(main.solids)
	main.queue_free()
	await process_frame
	return text.md5_text()
