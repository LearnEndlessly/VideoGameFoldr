extends RefCounted
# Game data collection. Barebones on purpose. Everything lands in user://telemetry/
# (on Windows: %APPDATA%\Godot\app_userdata\VideoGame Beta\telemetry):
#
#   raid_<unix>_<seed>.jsonl  one raid, one JSON object per line: the full event stream. The first
#                             line (raid.start.raid) carries the map (structures, shelters, crates,
#                             enemies, extract) and the tuning values; raid.sample.state lines give
#                             position, health, backpack and nearest enemy every SAMPLE_SECONDS.
#                             Only the newest MAX_RAID_FILES are kept, older ones are deleted.
#   runs.jsonl                one line per finished raid (outcome, duration, loot, kills, shots, seed,
#                             game version, tuning). Never pruned: this is the long-term record for
#                             comparing raids across balance changes.
#
# Event names are subject.verb.object (docs/DESIGN_METRICS.md). Never throws: if a file cannot be
# opened it warns once and every call becomes a no-op.
#
# WHEN YOU BUILD A NEW MECHANIC:
#   1. Log it where the simulation applies it: Telemetry.emit("player.verb.object", {...fields}).
#      Use the existing verbs and objects where they fit; add new ones to the lists in tests/telemetry.gd.
#   2. Add any new tuning constant to tuning() below, so runs can be compared across changes.
#   3. Add anything about the starting map to Main._map_info().
#   4. Bump GAME_VERSION so runs.jsonl shows which build produced each line.

const Tuning = preload("res://data/tuning.gd")

const SCHEMA := 1
const GAME_VERSION := "0.4"
const MAX_RAID_FILES := 100
const SAMPLE_SECONDS := 2.0
static var dir := "user://telemetry"  # tests point this at a scratch folder

static var enabled := DisplayServer.get_name() != "headless"  # off in headless runs (tests, tools) so they don't fill the user folder
static var clock := 0.0     # raid seconds; the raid updates it every physics frame
static var _file: FileAccess = null
static var _warned := false
static var _seed := 0

# The tuning values a run is played under, copied onto every raid so results can be compared
# across balance changes. Add new constants here.
static func tuning() -> Dictionary:
	return {
		"start_ammo": Tuning.STARTING_AMMO, "threat_delay": Tuning.THREAT_DELAY_SECONDS,
		"threat_continuous": Tuning.THREAT_CONTINUOUS, "extract_hold": Tuning.EXTRACT_HOLD_SECONDS,
		"backpack_slots": Tuning.BACKPACK_SLOTS, "groups": Tuning.ENEMY_GROUP_COUNT,
		"sight": Tuning.ENEMY_SIGHT_RANGE, "sprint_noise": Tuning.SPRINT_NOISE_RANGE,
		"walk": Tuning.PLAYER_WALK_SPEED, "sprint": Tuning.PLAYER_SPRINT_SPEED,
	}

static func start(raid_info: Dictionary) -> void:
	finish()
	clock = 0.0
	if not enabled:
		return
	_seed = int(raid_info.get("seed", 0))
	DirAccess.make_dir_recursive_absolute(dir)
	_prune(MAX_RAID_FILES - 1)  # make room for the new file
	var base := "%s/raid_%d_%d" % [dir, int(Time.get_unix_time_from_system()), _seed]
	var path := base + ".jsonl"
	var n := 1
	while FileAccess.file_exists(path):  # two raids in the same second must not overwrite
		path = "%s_%d.jsonl" % [base, n]
		n += 1
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null and not _warned:
		_warned = true
		push_warning("telemetry: cannot open %s, logging disabled" % path)
	var first := raid_info.duplicate()
	first["schema"] = SCHEMA
	first["version"] = GAME_VERSION
	first["tuning"] = tuning()
	emit("raid.start.raid", first)

static func emit(event_name: String, fields: Dictionary = {}) -> void:
	if _file == null:
		return
	var line := {"ev": event_name, "t": snappedf(clock, 0.1)}
	for k in fields:
		line[k] = _round(fields[k])
	_file.store_line(JSON.stringify(line))

static func finish() -> void:
	if _file != null:
		_file.flush()
		_file = null  # releasing the last reference closes the file

# One line per finished raid in runs.jsonl, with the version and tuning, for studying results
# over time. `summary` is the raid's outcome fields (outcome, loot, kills, shots, duration...).
static func record_run(summary: Dictionary) -> void:
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/runs.jsonl"
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var line := {"when": int(Time.get_unix_time_from_system()), "seed": _seed, "schema": SCHEMA,
		"version": GAME_VERSION, "tuning": tuning()}
	for k in summary:
		line[k] = _round(summary[k])
	f.store_line(JSON.stringify(line))

# Deletes the oldest raid_*.jsonl files until at most `keep` remain. The unix time in the
# name makes alphabetical order the same as age.
static func _prune(keep: int) -> void:
	var names: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("raid_") and f.ends_with(".jsonl"):
			names.append(f)
	names.sort()
	for i in maxi(names.size() - keep, 0):
		DirAccess.remove_absolute(dir + "/" + names[i])

# Floats to one decimal, recursively; Vector3 becomes [x, z].
static func _round(v: Variant) -> Variant:
	if v is float:
		return snappedf(v, 0.1)
	if v is Vector3:
		return [snappedf(v.x, 0.1), snappedf(v.z, 0.1)]
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _round(v[k])
		return d
	if v is Array:
		return v.map(_round)
	return v
