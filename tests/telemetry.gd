# Run: Godot --headless --path <project> -s tests/telemetry.gd   (exit code 1 on failure)
# Plays a short raid and checks the JSONL event log it leaves in user://telemetry, and that
# Telemetry.enabled = false writes nothing.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
const DIR := "user://telemetry_test"  # a scratch folder: the real logs are never touched
const VERBS := ["start", "end", "enter", "leave", "open", "fire", "kill", "hit", "alert", "use", "drop", "switch", "toggle", "begin", "cancel", "sample", "die"]
const OBJECTS := ["raid", "zone", "crate", "weapon", "enemy", "group", "item", "backpack", "extract", "clock", "state"]
const SUBJECTS := ["player", "enemy", "raid"]

var failures: PackedStringArray = []

func _init() -> void:
	await _run()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _files() -> Array:
	var out := []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("raid_"):
			out.append(f)
	return out

func _clear() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)

func _newest() -> String:
	var best := ""
	var best_t := 0
	for f in _files():
		var t := FileAccess.get_modified_time(DIR + "/" + f)
		if best == "" or t >= best_t:
			best = f
			best_t = t
	return best

func _new_raid(map_seed: int) -> Node:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c:  # no enemies: only the shots under test matter
			c.queue_free()
	await process_frame
	return main

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _wait_cooldown(main: Node) -> void:
	for i in 120:
		if main.raid._fire_cooldown <= 0.0:
			return
		await physics_frame

func _run() -> void:
	Main.show_start = false
	Telemetry.enabled = true  # off by default in headless runs
	Telemetry.dir = DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_clear()

	var main = await _new_raid(11)
	var player = main._player
	var crate = main.get_children().filter(func(c): return c.is_in_group("lootable") and c.zone_id == "med_post")[0]
	player.global_position = crate.global_position
	_check(main.raid.request_loot(crate), "the med post crate should be lootable")
	player.global_position = Vector3.ZERO
	await _frames(3)
	var aim: Transform3D = player._cam.global_transform
	_check(main.raid.request_fire("pistol", aim), "first shot should fire")
	_check(not main.raid.request_fire("pistol", aim), "second shot in the same frame is on cooldown")
	var guard := 0
	while player.inventory.count("ammo") > 0 and guard < 200:
		await _wait_cooldown(main)
		main.raid.request_fire("pistol", aim)
		guard += 1
	await _wait_cooldown(main)
	main.raid.request_fire("pistol", aim)  # empty: logs a dry fire
	player.take_damage(1000)
	main.queue_free()
	await process_frame

	var fname := _newest()
	_check(fname != "", "no telemetry file written")
	var events: Array = []
	if fname != "":
		for line in FileAccess.get_file_as_string(DIR + "/" + fname).split("\n", false):
			var e = JSON.parse_string(line)
			if typeof(e) == TYPE_DICTIONARY:
				events.append(e)
			else:
				failures.append("unparseable line: %s" % line)
	_check(events.size() >= 4, "expected several events, got %d" % events.size())
	if events.size() >= 2:
		_check(events[0]["ev"] == "raid.start.raid", "first event was %s" % events[0]["ev"])
		_check(events[-1]["ev"] == "raid.end.raid", "last event was %s" % events[-1]["ev"])
		_check(events[-1].get("outcome") == "dead", "raid.end outcome was %s" % events[-1].get("outcome"))
	# The first line carries the map, the tuning and the build.
	if events.size() > 0:
		var first: Dictionary = events[0]
		var map: Dictionary = first.get("map", {})
		_check(map.get("zones", []).size() == 3, "map should list 3 loot zones")
		_check(map.get("crates", []).size() >= 4, "map should list the crates")
		_check(map.get("enemies", []).size() > 0, "map should list the enemies")
		_check(map.get("extract", []).size() == 2 and map.get("shelters", []).size() > 0, "map should list the extract zone and shelters")
		_check(first.get("tuning", {}).has("start_ammo") and first.has("version") and first.has("schema"), "start event should carry tuning, version and schema")
	var samples := 0
	var crate_events := 0
	var fired := 0
	var dry := 0
	var last_t := -1.0
	for e in events:
		var parts: PackedStringArray = String(e.get("ev", "")).split(".")
		var ok := parts.size() == 3 and parts[0] in SUBJECTS and parts[1] in VERBS and parts[2] in OBJECTS
		_check(ok, "bad event name: %s" % e.get("ev", ""))
		_check(e.has("t") and float(e["t"]) >= last_t, "t decreased at %s" % e.get("ev", ""))
		last_t = float(e.get("t", last_t))
		if e["ev"] == "raid.sample.state":
			samples += 1
			_check(e["pos"].size() == 2 and e.has("hp") and e.has("pack") and e.has("near"), "sample is missing fields")
		if e["ev"] == "player.open.crate":
			crate_events += 1
			_check(e.get("zone") == "med_post" and e.get("pos", []).size() == 2, "crate event should carry the zone and position")
		if e["ev"] == "player.fire.weapon":
			fired += 1 if e["outcome"] == "fired" else 0
			dry += 1 if e["outcome"] == "dry" else 0
	_check(samples >= 1, "no position sample was logged")
	_check(crate_events >= 1, "no crate open event")
	_check(fired >= 1, "no fired event")
	_check(dry >= 1, "no dry event")

	# runs.jsonl: one summary line per finished raid, with version and tuning.
	var runs := FileAccess.get_file_as_string(DIR + "/runs.jsonl").split("
", false)
	_check(runs.size() == 1, "runs.jsonl should have one line, has %d" % runs.size())
	if runs.size() > 0:
		var r = JSON.parse_string(runs[-1])
		_check(typeof(r) == TYPE_DICTIONARY and r.get("outcome") == "dead" and int(r.get("seed", -1)) == 11 and r.has("version") and r.has("tuning") and r.has("duration"), "runs.jsonl line is incomplete: %s" % runs[-1])

	# The cache is capped: with more than MAX_RAID_FILES old logs, starting a raid deletes the oldest.
	for i in Telemetry.MAX_RAID_FILES + 5:
		FileAccess.open("%s/raid_%010d_0.jsonl" % [DIR, i + 1], FileAccess.WRITE).store_line("{}")
	Telemetry.start({"seed": 99})
	Telemetry.finish()
	_check(_files().size() <= Telemetry.MAX_RAID_FILES, "cache holds %d raid logs, cap is %d" % [_files().size(), Telemetry.MAX_RAID_FILES])
	_check(not FileAccess.file_exists("%s/raid_%010d_0.jsonl" % [DIR, 1]), "the oldest log should have been deleted")
	_check(FileAccess.file_exists("%s/raid_%010d_0.jsonl" % [DIR, Telemetry.MAX_RAID_FILES + 5]), "the newest dummy log should have been kept")

	# Disabled: no new file.
	var before := _files().size()
	Telemetry.enabled = false
	main = await _new_raid(12)
	main._player.take_damage(1000)
	main.queue_free()
	await process_frame
	Telemetry.enabled = true
	_check(_files().size() == before, "telemetry disabled still wrote a file")
	_clear()

	for f in failures:
		printerr(f)
	print("telemetry: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)
