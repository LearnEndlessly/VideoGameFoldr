# Run: Godot --headless --path <project> -s tests/profile_flow.gd   (exit code 1 on failure)
# Plays raids through the real main scene and checks what lands in the profile JSON:
#   extract keeps the backpack, death keeps nothing, leaving the zone resets the hold timer,
#   far-away loot requests are refused, and a freshly started second process reads the
#   same file back ("verify" mode, launched by this script).
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const PATH := "user://test_profile_flow.json"
const EXPECTED := {"ammo": 3, "medkit": 1}

var failures: PackedStringArray = []

func _init() -> void:
	if "verify" in OS.get_cmdline_user_args():
		_verify()
	else:
		await _run()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _finish(label: String) -> void:
	for f in failures:
		printerr(f)
	print("%s: %d failure(s)" % [label, failures.size()])
	quit(1 if failures.size() > 0 else 0)

# Child process: a fresh start must read back what the first process saved.
func _verify() -> void:
	var p := Profile.new(PATH)
	p.load_from_disk()
	_check(p.totals == EXPECTED, "after restart the profile was %s, expected %s" % [p.totals, EXPECTED])
	_finish("profile_flow verify")

func _new_raid(map_seed: int) -> Node:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	main.profile_path = PATH
	root.add_child(main)
	await process_frame  # _ready only runs once the tree is processing
	for c in main.get_children():
		if "stats" in c:  # remove enemies so only the rules under test decide the outcome
			c.queue_free()
	await process_frame
	main.raid.hold_seconds = 0.5
	return main

func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func _read_totals() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return {"unreadable": 1}
	var totals := {}
	for id in data["totals"]:
		totals[id] = int(data["totals"][id])  # JSON numbers parse as floats
	return totals

func _run() -> void:
	Main.show_start = false
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)

	# 1. Extract keeps the backpack.
	var main = await _new_raid(1)
	var results: Array = []
	main.raid.ended.connect(func(r): results.append(r))
	var player = main._player
	player.inventory.add("ammo", 3)
	player.inventory.add("medkit", 1)
	player.global_position = main.extract_pos
	await _wait_until(func(): return results.size() > 0, 120)
	_check(results.size() == 1, "extract: expected one raid result, got %d" % results.size())
	if results.size() == 1:
		_check(results[0]["outcome"] == "extracted", "extract: outcome was %s" % results[0]["outcome"])
		_check(results[0]["items"] == EXPECTED, "extract: result items were %s" % [results[0]["items"]])
	_check(player.inventory.totals().is_empty(), "extract: backpack should be empty afterwards")
	_check(_read_totals() == EXPECTED, "extract: JSON totals were %s" % [_read_totals()])
	main.queue_free()
	await process_frame

	# 2. Leaving the zone resets the hold timer.
	main = await _new_raid(2)
	results = []
	main.raid.ended.connect(func(r): results.append(r))
	player = main._player
	player.global_position = main.extract_pos
	await _wait_until(func(): return main.raid.extract_elapsed >= 0.3, 60)
	_check(main.raid.extracting and results.is_empty(), "timer: should be counting, not finished")
	player.global_position = Vector3.ZERO
	await _wait_until(func(): return not main.raid.extracting, 30)
	_check(not main.raid.extracting and main.raid.extract_elapsed == 0.0, "timer: leaving the zone must reset it")
	player.global_position = main.extract_pos
	await _wait_until(func(): return main.raid.extract_elapsed >= 0.3, 60)
	_check(results.is_empty(), "timer: 0.3 s before and 0.3 s after leaving must not add up to a 0.5 s hold")
	await _wait_until(func(): return results.size() > 0, 120)
	_check(results.size() == 1, "timer: staying long enough must still extract")
	_check(_read_totals() == EXPECTED, "timer: an empty extract must not change totals, got %s" % [_read_totals()])
	main.queue_free()
	await process_frame

	# 3. Loot requests are validated, and death keeps nothing.
	main = await _new_raid(3)
	results = []
	main.raid.ended.connect(func(r): results.append(r))
	player = main._player
	var crate: Node = main.get_children().filter(func(c): return c.is_in_group("lootable"))[0]
	player.global_position = crate.global_position + Vector3(20, 0, 0)
	var before: Dictionary = player.inventory.totals()
	_check(not main.raid.request_loot(crate), "loot: a crate 20 m away must be refused")
	_check(player.inventory.totals() == before, "loot: a refused request must not change the backpack")
	player.global_position = crate.global_position
	_check(main.raid.request_loot(crate), "loot: a crate within reach must be accepted")
	player.inventory.clear()
	player.inventory.add("ammo", main.raid.brought["ammo"] + 10)  # the unspent starting kit does not count as loot
	player.inventory.add("repair_kit", 1)
	player.take_damage(1000)
	_check(results.size() == 1 and results[0]["outcome"] == "dead", "death: expected a dead result")
	if results.size() == 1:
		_check(results[0]["items"] == {"ammo": 10, "repair_kit": 1}, "death: lost items were %s" % [results[0]["items"]])
	_check(player.inventory.totals().is_empty(), "death: backpack should be wiped")
	_check(_read_totals() == EXPECTED, "death: JSON must be unchanged, got %s" % [_read_totals()])
	main.queue_free()
	await process_frame

	# 4. A fresh process reads the same file back.
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(),
		["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/profile_flow.gd", "--", "verify"],
		out, true)
	_check(code == 0, "restart: verify process failed (exit %d): %s" % [code, out])
	_finish("profile_flow")
