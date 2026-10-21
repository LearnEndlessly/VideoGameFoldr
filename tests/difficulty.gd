# Run: Godot --headless --path <project> -s tests/difficulty.gd   (exit code 1 on failure)
# Raid difficulty chosen at the base: the reward multiplier, the saved choices, the options taking effect in
# a raid (patrol size, enemy damage, alarm time, base respawns, starting ammo) without changing the map, the
# multiplier scaling an extract's loot and points (and not what is lost on death), and the base's controls.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Difficulty = preload("res://data/difficulty.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_difficulty.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await _run()
	for f in failures:
		printerr(f)
	print("difficulty: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _clean() -> void:
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)

func _all(level: int) -> Dictionary:
	var d := {}
	for id in Difficulty.OPTIONS:
		d[id] = level
	return d

# A raid on map 3 with every option at `level`, the profile saved to PATH first.
func _raid(level: int, keep_enemies := true) -> Node:
	var p := Profile.new(PATH)
	p.difficulty = _all(level)
	p.save()
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 3
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	if not keep_enemies:
		for c in main.get_children():
			if "stats" in c:
				c.queue_free()
	await process_frame
	return main

func _patrol(main: Node) -> Array:
	return main.get_children().filter(func(c): return "stats" in c and not c.is_queued_for_deletion() and c.group_id < Tuning.ENEMY_GROUP_COUNT)

func _per_group(enemies: Array) -> Dictionary:
	var out := {}
	for e in enemies:
		out[e.group_id] = out.get(e.group_id, 0) + 1
	return out

func _run() -> void:
	Main.show_start = false
	_clean()

	# The multiplier: 1.0 on Normal, above 1 on Hard, below on Easy; real rewards never round to nothing.
	_check(is_equal_approx(Difficulty.reward_mult({}), 1.0) and is_equal_approx(Difficulty.reward_mult(_all(1)), 1.0), "Normal everywhere should be x1.0")
	_check(Difficulty.reward_mult(_all(2)) > 1.5 and Difficulty.reward_mult(_all(0)) < 1.0 and Difficulty.reward_mult(_all(0)) > 0.0, "Hard should pay more, Easy less, never nothing")
	_check(Difficulty.scale(3, 0.5) == 2 and Difficulty.scale(1, 0.6) == 1 and Difficulty.scale(0, 2.0) == 0 and Difficulty.scale(4, 1.9) == 8, "reward scaling rounds and keeps at least 1")
	_check(Difficulty.level_of({"damage": 9}, "damage") == 2 and Difficulty.level_of({"damage": -4}, "damage") == 0, "levels clamp into range")

	# The profile keeps the choices.
	var p := Profile.new(PATH)
	p.load_from_disk()
	_check(p.difficulty_level("damage") == 1 and is_equal_approx(p.reward_mult(), 1.0), "a fresh profile is on Normal")
	_check(p.set_difficulty("damage", 2) and p.set_difficulty("ammo", 0) and not p.set_difficulty("damage", 3) and not p.set_difficulty("nope", 1), "set_difficulty should accept real levels only")
	p.save()
	var q := Profile.new(PATH)
	q.load_from_disk()
	_check(q.difficulty_level("damage") == 2 and q.difficulty_level("ammo") == 0 and q.difficulty_level("patrols") == 1, "choices should survive a save and load")
	_clean()

	# In a raid. The same map number gives the same terrain, bases and patrol homes on every difficulty.
	var normal = await _raid(1)
	var base_groups := _per_group(_patrol(normal))
	var base_terrain := [normal.blocks.size(), normal.extract_pos, normal._spawners.map(func(sp): return sp.position)]
	_check(is_equal_approx(normal.raid.reward_mult, 1.0) and normal.raid.start_ammo == Tuning.STARTING_AMMO, "Normal should leave the raid as it was")
	normal.queue_free()
	await process_frame
	for level in [0, 2]:
		var m = await _raid(level)
		var label: String = ["Easy", "", "Hard"][level]
		var vals: Dictionary = Difficulty.values(_all(level))
		var groups := _per_group(_patrol(m))
		for g in base_groups:
			var want := maxi(1, int(round(base_groups[g] * float(vals["patrols"]))))
			_check(groups.get(g, 0) == want, "%s: group %d had %d enemies, expected %d" % [label, g, groups.get(g, 0), want])
		_check([m.blocks.size(), m.extract_pos, m._spawners.map(func(sp): return sp.position)] == base_terrain, "%s: the map must not change with difficulty" % label)
		var enemies := m.get_children().filter(func(c): return "stats" in c and not c.is_queued_for_deletion())
		var dmg_ok := enemies.all(func(e): return e.stats["damage"] == int(round(Enemies.TYPES[e.stats["type"]]["damage"] * float(vals["damage"]))))
		_check(dmg_ok, "%s: enemy damage should be scaled by %s" % [label, vals["damage"]])
		_check(enemies.all(func(e): return e.detect_seconds == float(vals["awareness"])), "%s: alarm time should be %s s" % [label, vals["awareness"]])
		_check(m._spawners.all(func(sp): return sp.interval == float(vals["bases"]["interval"]) and sp.max_alive == int(vals["bases"]["max_alive"])), "%s: base respawn settings" % label)
		_check(m.raid.start_ammo == int(vals["ammo"]) and m._player.inventory.count("ammo") == int(vals["ammo"]), "%s: start ammo should be %s" % [label, vals["ammo"]])
		_check(is_equal_approx(m.raid.reward_mult, Difficulty.reward_mult(_all(level))), "%s: the raid should carry the reward multiplier" % label)
		m.queue_free()
		await process_frame
	_clean()

	# The multiplier scales what an extract keeps; death still loses exactly what was carried.
	var hard = await _raid(2, false)
	var results: Array = []
	hard.raid.ended.connect(func(r): results.append(r))
	hard.raid.hold_seconds = 0.3
	hard._player.inventory.add("medkit", 4)
	hard._player.kills = 5
	hard._player.global_position = hard.extract_pos
	for i in 120:
		if not results.is_empty():
			break
		await physics_frame
	var mult := Difficulty.reward_mult(_all(2))
	_check(results.size() == 1 and results[0]["items"] == {"medkit": Difficulty.scale(4, mult)}, "Hard should scale the kept loot, got %s" % [results])
	_check(results.size() == 1 and is_equal_approx(results[0]["reward_mult"], mult), "Hard should carry its reward multiplier")
	var saved := Profile.new(PATH)
	saved.load_from_disk()
	_check(saved.totals.get("medkit", 0) == Difficulty.scale(4, mult), "the scaled reward should be what is saved")
	hard.queue_free()
	await process_frame
	var dying = await _raid(2, false)
	var died: Array = []
	dying.raid.ended.connect(func(r): died.append(r))
	dying._player.inventory.add("medkit", 3)
	dying._player.take_damage(10000)
	_check(died.size() == 1 and died[0]["items"] == {"medkit": 3}, "death loses exactly what was carried, got %s" % [died])
	dying.queue_free()
	await process_frame
	_clean()

	# The base's raid terminal: one button per level, choices saved, multiplier shown.
	Main.show_start = true
	var main = load("res://main.tscn").instantiate()
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	var hub = main.get_children().filter(func(c): return "open_station" in c)[0]
	hub._map_button("play")
	var buttons: Array = hub._content.find_children("*", "Button", true, false)
	_check(buttons.size() == Difficulty.OPTIONS.size() * 3 + 1, "the terminal should have 3 buttons per option and START RAID, got %d" % buttons.size())
	hub._set_difficulty("damage", 2)
	hub._set_difficulty("ammo", 2)
	var disk := Profile.new(PATH)
	disk.load_from_disk()
	_check(disk.difficulty_level("damage") == 2 and disk.difficulty_level("ammo") == 2, "terminal choices should be saved")
	_check(is_equal_approx(hub.profile.reward_mult(), 1.0 + 0.2 + 0.15), "the terminal should know the new multiplier")
	main.queue_free()
	await process_frame
	Main.show_start = false
	_clean()
