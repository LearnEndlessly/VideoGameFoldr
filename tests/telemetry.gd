# Run: Godot --headless --path <project> -s tests/telemetry.gd   (exit code 1 on failure)
# Plays a short raid and checks the JSONL event log it leaves in user://telemetry, and that
# Telemetry.enabled = false writes nothing.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
const DIR := "user://telemetry"
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
		out.append(f)
	return out

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

func _wait_cooldown(main: Node) -> void:
	for i in 120:
		if main.raid._fire_cooldown <= 0.0:
			return
		await physics_frame

func _run() -> void:
	Main.show_start = false
	Telemetry.enabled = true  # off by default in headless runs
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

	var main = await _new_raid(11)
	var player = main._player
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
	var fired := 0
	var dry := 0
	var last_t := -1.0
	for e in events:
		var parts: PackedStringArray = String(e.get("ev", "")).split(".")
		var ok := parts.size() == 3 and parts[0] in SUBJECTS and parts[1] in VERBS and parts[2] in OBJECTS
		_check(ok, "bad event name: %s" % e.get("ev", ""))
		_check(e.has("t") and float(e["t"]) >= last_t, "t decreased at %s" % e.get("ev", ""))
		last_t = float(e.get("t", last_t))
		if e["ev"] == "player.fire.weapon":
			fired += 1 if e["outcome"] == "fired" else 0
			dry += 1 if e["outcome"] == "dry" else 0
	_check(fired >= 1, "no fired event")
	_check(dry >= 1, "no dry event")

	# Disabled: no new file.
	var before := _files().size()
	Telemetry.enabled = false
	main = await _new_raid(12)
	main._player.take_damage(1000)
	main.queue_free()
	await process_frame
	Telemetry.enabled = true
	_check(_files().size() == before, "telemetry disabled still wrote a file")

	for f in failures:
		printerr(f)
	print("telemetry: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)
