# Run: Godot --headless --path <project> -s tests/layout_isolation.gd   (exit code 1 on failure)
# The extract zones are placed from their own RNG stream, so everything else a seed builds (terrain boxes,
# loot rooms, crates, enemy patrols and bases, shelters) must stay exactly what it was before the extract
# work. tests/fixtures/layout_golden.json was written from the build that had a single extract zone, with
# the extract positions left out. The test checks the current build against it, and that changing the
# extract tuning (Main.extract_cfg) moves the zones without touching anything else.
# After an INTENDED change to the rest of generation, regenerate with `-- --write`.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const FIXTURE := "res://tests/fixtures/layout_golden.json"
const SEEDS := 12

func _init() -> void:
	Main.show_start = false
	await process_frame  # the tree is not running yet inside _init: a node added now would not have run _ready
	var got := {}
	for s in SEEDS:
		got[str(s)] = await _fingerprint(s, {})
	if "--write" in OS.get_cmdline_user_args():
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(got, "\t"))
		f.close()
		print("layout_isolation: wrote %s" % FIXTURE)
		quit(0)
		return
	var failures := 0
	var want = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not want is Dictionary:
		printerr("layout_isolation: fixture missing or unreadable; run with -- --write")
		quit(1)
		return
	for k in got:
		if want.get(k) != got[k]:
			printerr("seed %s: the layout (not the extract zones) differs from the pre-extract-work build" % k)
			failures += 1
	# Different extract tuning: same layout, different zones.
	var moved := 0
	for s in range(0, SEEDS, 3):
		var altered := {"a_min_path": 25.0, "b_max_path": 30.0, "b_min_path": 4.0, "min_separation": 15.0, "min_base_distance": 6.0, "b_hold": 20.0, "b_noise_radius": 5.0}
		if await _fingerprint(s, altered) != got[str(s)]:
			printerr("seed %d: changing the extract tuning changed the layout" % s)
			failures += 1
		if await _extract_positions(s, altered) != await _extract_positions(s, {}):
			moved += 1
	if moved == 0:
		printerr("changing the extract tuning never moved an extract zone, so the isolation check proves nothing")
		failures += 1
	print("layout_isolation: %d failure(s) over %d seeds" % [failures, SEEDS])
	quit(1 if failures > 0 else 0)

func _build(s: int, cfg: Dictionary) -> Node:  # not async: callers read the map before awaiting anything
	var main = load("res://main.tscn").instantiate()
	main.seed_override = s
	if "extract_cfg" in main:
		for k in cfg:
			main.extract_cfg[k] = cfg[k]
	root.add_child(main)  # _ready builds the whole map now; no frame has run, so enemies are still where they spawned
	return main

# Everything a seed builds except where the extract zones are.
func _fingerprint(s: int, cfg: Dictionary) -> String:
	var main = _build(s, cfg)
	var info: Dictionary = main._map_info()
	info.erase("extract")
	info.erase("extracts")
	info["enemies"] = main.get_children().filter(func(n): return "stats" in n).map(
		func(n): return [n.stats["type"], n.stats["modifier"], n.group_id, n.home, n.position])
	var text := var_to_str(info) + var_to_str(main.solids) + var_to_str(main.blocks) + var_to_str(main.structures)
	main.queue_free()
	await process_frame
	return text.md5_text()

func _extract_positions(s: int, cfg: Dictionary) -> Array:
	var main = _build(s, cfg)
	var out: Array = main.extract_zones.map(func(z): return z["pos"]) if "extract_zones" in main else [main.extract_pos]
	main.queue_free()
	await process_frame
	return out
