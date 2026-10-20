extends RefCounted
# Raid event log: one JSON object per line in user://telemetry/raid_<unix>_<seed>.jsonl.
# Event names are subject.verb.object (docs/DESIGN_METRICS.md). Never throws: if the file
# cannot be opened it warns once and every call becomes a no-op.

static var enabled := DisplayServer.get_name() != "headless"  # off in headless runs (tests, tools) so they don't fill the user folder
static var clock := 0.0     # raid seconds; the raid updates it every physics frame
static var _file: FileAccess = null
static var _warned := false

static func start(raid_info: Dictionary) -> void:
	finish()
	clock = 0.0
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute("user://telemetry")
	var base := "user://telemetry/raid_%d_%d" % [int(Time.get_unix_time_from_system()), int(raid_info.get("seed", 0))]
	var path := base + ".jsonl"
	var n := 1
	while FileAccess.file_exists(path):  # two raids in the same second must not overwrite
		path = "%s_%d.jsonl" % [base, n]
		n += 1
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null and not _warned:
		_warned = true
		push_warning("telemetry: cannot open %s, logging disabled" % path)
	emit("raid.start.raid", raid_info)

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
