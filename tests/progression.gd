# Run: Godot --headless --path <project> -s tests/progression.gd   (exit code 1 on failure)
# Progression in and out of the raid: the lifetime scoreboard (runs, kills, shots, accuracy, deepest level)
# recorded for every raid and shown on the base's wall, the end screen offering a descent only after an extract,
# and descending: the carried loot back in the backpack, more bases, faster spawns, more ammo, a better reward,
# with the map underneath unchanged.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const ScreenUI = preload("res://scripts/screen_ui.gd")
const Tuning = preload("res://data/tuning.gd")
const Difficulty = preload("res://data/difficulty.gd")
const PATH := "user://test_progression_profile.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("progression: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _raid(map_seed: int) -> Node:
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	main.profile_path = PATH
	root.add_child(main)
	return main

func _run() -> void:
	DirAccess.remove_absolute(PATH)

	# The profile: every finished raid counts, an old save without the new fields loads with zeros.
	var p := Profile.new(PATH)
	_check(p.accuracy() == -1 and p.stats["deepest"] == 1, "a new profile has no accuracy yet and has reached level 1")
	p.record_raid(true, 4, 10, 6, 1)
	p.record_raid(false, 2, 10, 2, 1)
	p.record_raid(true, 1, 5, 5, 3)  # a descent: not a new run, but the deepest level
	_check(p.stats == {"runs": 2, "extracts": 0, "deaths": 1, "kills": 7, "shots": 25, "hits": 13, "deepest": 3}, "scoreboard wrong: %s" % [p.stats])
	_check(p.accuracy() == 52, "13 of 25 shots is 52%%, got %d" % p.accuracy())
	p.add_items({"ammo": 5, "medkit": 2})
	p.take_items({"ammo": 5, "medkit": 1})
	_check(p.totals == {"medkit": 1}, "taking items should remove them and drop empty stacks, got %s" % [p.totals])
	_check(p.save(), "save failed")
	var q := Profile.new(PATH)
	q.load_from_disk()
	_check(q.stats == p.stats, "stats should survive a save")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "totals": {}, "stats": {"extracts": 3, "kills": 9}}))
	f.close()
	q.load_from_disk()
	_check(q.stats["extracts"] == 3 and q.stats["kills"] == 9 and q.stats["runs"] == 0 and q.stats["deepest"] == 1, "an old save should load, got %s" % [q.stats])
	DirAccess.remove_absolute(PATH)

	# A raid records itself: a shot into the sky is a miss, then death.
	var main = _raid(4)
	await process_frame
	var raid = main.raid
	main._player.inventory.add("ammo", 20)
	raid.loaded["pistol"] = 5
	_check(raid.request_fire("pistol", Transform3D(Basis.looking_at(Vector3.UP, Vector3.FORWARD), Vector3(0, 1.5, 0))), "the shot should fire")
	_check(raid.shots == 1 and raid.shots_hit == 0, "a shot at the sky is a miss, got %d/%d" % [raid.shots_hit, raid.shots])
	main._player.take_damage(10000)
	var disk := Profile.new(PATH)
	disk.load_from_disk()
	_check(disk.stats["runs"] == 1 and disk.stats["deaths"] == 1 and disk.stats["shots"] == 1 and disk.stats["hits"] == 0 and disk.stats["extracts"] == 0, "a death should be on the scoreboard, got %s" % [disk.stats])
	var base_bases: int = main._spawners.size()
	var base_cover: int = main._cover.size()
	var base_interval: float = main._spawners[0].interval
	var base_ammo: int = raid.start_ammo
	var base_mult: float = raid.reward_mult
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)

	# Two levels down with 3 medkits carried: the same map, with the pressure turned up.
	Main.depth = 2
	Main.carry = {"medkit": 3}
	main = _raid(4)
	await process_frame
	raid = main.raid
	_check(main._cover.size() == base_cover, "descending must not change the map underneath")
	_check(main._spawners.size() == base_bases + 2 * Tuning.DEPTH_EXTRA_SPAWNERS, "two levels down should add %d bases, got %d vs %d" % [2 * Tuning.DEPTH_EXTRA_SPAWNERS, main._spawners.size(), base_bases])
	_check(main._spawners[0].interval < base_interval, "bases should spawn faster")
	_check(raid.start_ammo == base_ammo + 2 * Tuning.DEPTH_AMMO_BONUS and raid.drop_mult > 1.0, "more ammo should be available")
	_check(is_equal_approx(raid.reward_mult, base_mult + 2 * Tuning.DEPTH_REWARD_BONUS), "the reward should grow with depth")
	_check(main._player.inventory.count("medkit") == 3 and raid._loot().get("medkit", 0) == 3, "carried loot should be in the backpack and count as loot again")
	_check(Main.carry.is_empty(), "the carry is handed over once")
	raid.profile.save()
	var extras: Array = main._spawners.slice(base_bases)
	var zones: Array = main.extract_zones
	for sp in extras:
		for z in zones:
			_check(Vector2(z["pos"].x - sp.position.x, z["pos"].z - sp.position.z).length() >= Tuning.EXTRACT_MIN_BASE_DISTANCE, "an extra base is on top of an extract zone")
	main.queue_free()
	await process_frame
	Main.depth = 0
	DirAccess.remove_absolute(PATH)

	# The same depth always builds the same extra bases.
	Main.depth = 3
	var a = _raid(9)
	var b = _raid(9)
	await process_frame
	_check(a._spawners.map(func(s): return s.position) == b._spawners.map(func(s): return s.position), "extra bases should be deterministic")
	a.queue_free()
	b.queue_free()
	await process_frame
	Main.depth = 0
	DirAccess.remove_absolute(PATH)

	# The end screen offers a descent only after an extract, and the safe choice is focused.
	var result := {"outcome": "extracted", "items": {"ammo": 4}, "saved": true, "kills": 3, "points": 2, "reward_mult": 1.0,
		"shots": 8, "hits": 4, "duration": 95.0, "depth": 0}
	var screen := ScreenUI.new()
	root.add_child(screen)
	screen.show_result(result, 1, func(): pass, func(): pass)
	_check(screen.descend_button != null and screen.descend_button.text.contains("LEVEL 2"), "an extract should offer a descent to level 2")
	screen.queue_free()
	var dead := ScreenUI.new()
	root.add_child(dead)
	result["outcome"] = "dead"
	dead.show_result(result, 1, func(): pass, func(): pass)
	_check(dead.descend_button == null and dead.home_button != null, "a death should offer only the way home")
	dead.queue_free()

	# The wall scoreboard shows the profile.
	var seeded := Profile.new(PATH)
	seeded.stats = {"runs": 4, "extracts": 3, "deaths": 1, "kills": 21, "shots": 80, "hits": 20, "deepest": 3}
	seeded.save()
	Main.show_start = true
	var base = load("res://main.tscn").instantiate()
	base.profile_path = PATH
	root.add_child(base)
	await process_frame
	var hub = base.get_children().filter(func(c): return "open_station" in c)[0]
	var rows: Array = hub.scoreboard_rows()
	var shown := {}
	for r in rows:
		shown[r[0]] = r[1]
	_check(shown == {"RUNS": "4", "EXTRACTED": "3", "KILLED IN ACTION": "1", "SURVIVAL": "75%", "KILLS": "21", "SHOTS FIRED": "80", "ACCURACY": "25%", "DEEPEST LEVEL": "3"}, "the board shows %s" % [shown])
	_check(hub.find_children("*", "Label3D", true, false).any(func(l): return l.text == "75%"), "the board's numbers should be on the wall")
	base.queue_free()
	await process_frame
	Main.show_start = false
	DirAccess.remove_absolute(PATH)
