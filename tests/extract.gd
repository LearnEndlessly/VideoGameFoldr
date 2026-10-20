# Run: Godot --headless --path <project> -s tests/extract.gd   (exit code 1 on failure)
# The extract decision: two zones per map placed within the tuning constraints (40 seeds, the playbot's), the
# same seed giving the same zones (and the same ones on the base's map pit), zone B alerting nearby groups when
# a hold starts and not before, leaving either zone resetting its hold, beams respecting the reveal radius and
# the always-visible setting, and the threat clock HUD (countdown colours, converging, the arrow). That changing
# the extract tuning leaves the rest of the map alone is tests/layout_isolation.gd.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const SEEDS := 40  # 1..40, the playbot baseline's seeds

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("extract: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# A raid on `map_seed`. Reads of the finished map can happen straight away; frames only matter for physics.
func _map(map_seed: int, cfg := {}) -> Node:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	main.profile_path = "user://test_extract_profile.json"
	for k in cfg:
		main.extract_cfg[k] = cfg[k]
	root.add_child(main)
	return main

func _zone(main: Node, id: String) -> Dictionary:
	return main.extract_zones.filter(func(z): return z["id"] == id)[0]

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _grunt(main: Node, group: int, pos: Vector3) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.group_id = group
	e.position = pos
	main.add_child(e)
	e.set_physics_process(false)
	return e

func _run() -> void:
	Main.show_start = false

	# Placement constraints on every seed.
	for s in range(1, SEEDS + 1):
		var main = _map(s)
		var a: Dictionary = _zone(main, "A")
		var b: Dictionary = _zone(main, "B")
		var grid: Dictionary = main._walk_grid()
		var da: int = main._walk_dist(grid, a["pos"])
		var db: int = main._walk_dist(grid, b["pos"])
		_check(main.extract_errors.is_empty(), "seed %d: placement logged %s" % [s, main.extract_errors])
		_check(main.extract_zones.size() == 2 and main.extract_pos == a["pos"], "seed %d: expected zones A and B, with extract_pos at A" % s)
		_check(da >= Tuning.EXTRACT_A_MIN_PATH, "seed %d: A is %d m (path) from the start, minimum %s" % [s, da, Tuning.EXTRACT_A_MIN_PATH])
		_check(db >= Tuning.EXTRACT_B_MIN_PATH and db <= Tuning.EXTRACT_B_MAX_PATH, "seed %d: B is %d m (path) from the start, window %s-%s" % [s, db, Tuning.EXTRACT_B_MIN_PATH, Tuning.EXTRACT_B_MAX_PATH])
		_check(float(da) >= _flat(a["pos"], Vector3.ZERO) and float(db) >= _flat(b["pos"], Vector3.ZERO) - 1.0, "seed %d: a path cannot be shorter than a straight line" % s)
		_check(_flat(a["pos"], b["pos"]) >= Tuning.EXTRACT_MIN_SEPARATION, "seed %d: A and B are only %.1f m apart" % [s, _flat(a["pos"], b["pos"])])
		for sp in main._spawners:
			for z in [a, b]:
				_check(_flat(z["pos"], sp.position) >= Tuning.EXTRACT_MIN_BASE_DISTANCE, "seed %d: zone %s is %.1f m from an enemy base" % [s, z["id"], _flat(z["pos"], sp.position)])
		for z in [a, b]:
			_check(absf(z["pos"].x) <= main.half_w - Tuning.EXTRACT_ZONE_SIZE / 2.0 and absf(z["pos"].z) <= main.half_d - Tuning.EXTRACT_ZONE_SIZE / 2.0, "seed %d: zone %s pokes through the wall" % [s, z["id"]])
		main.queue_free()
		await process_frame

	# Determinism, and the base's map pit agrees with the raid.
	for s in [5, 17, 33]:
		var m1 = _map(s)
		var p1: Array = m1.extract_zones.map(func(z): return z["pos"])
		var preview: Dictionary = m1.preview(s)
		m1.queue_free()
		await process_frame
		var m2 = _map(s)
		_check(m2.extract_zones.map(func(z): return z["pos"]) == p1, "seed %d: the same seed gave different extract zones" % s)
		_check(preview["extracts"].map(func(z): return z["pos"]) == p1 and preview["extracts"].map(func(z): return z["id"]) == ["A", "B"], "seed %d: the map pit preview should show the same two zones" % s)
		m2.queue_free()
		await process_frame

	# Zone B is loud when a hold starts, A is not, and nothing is alerted before.
	var main = _map(3)
	await process_frame
	for c in main.get_children():
		if "stats" in c:
			c.queue_free()
	await process_frame
	var player = main._player
	player.set_physics_process(false)
	player.safe = true  # so only the noise can alert anyone
	var raid = main.raid
	raid.hold_seconds = 60.0
	var bpos: Vector3 = _zone(main, "B")["pos"]
	var near := [_grunt(main, 10, bpos + Vector3(10, 0, 0)), _grunt(main, 10, bpos + Vector3(12, 0, 0))]
	var edge_in := _grunt(main, 11, bpos + Vector3(29, 0, 0))
	var edge_out := _grunt(main, 12, bpos + Vector3(31, 0, 0))
	var split := [_grunt(main, 13, bpos + Vector3(25, 0, 0)), _grunt(main, 13, bpos + Vector3(80, 0, 0))]  # one member in range, one far
	var all := near + [edge_in, edge_out] + split
	await _frames(30)
	_check(all.all(func(e): return not e.alert), "nobody should be alerted before anyone holds an extract")
	raid.request_extract("A")
	_check(all.all(func(e): return not e.alert), "holding the safe route must be quiet")
	raid.cancel_extract()
	raid.request_extract("B")
	_check(near.all(func(e): return e.alert) and edge_in.alert, "starting a hold in B should alert groups with a member within %s m" % raid.b_noise_radius)
	_check(split.all(func(e): return e.alert), "a group with one member in range is alerted whole")
	_check(not edge_out.alert, "a group 31 m away must not be alerted")
	for e in near:
		e.set_alert(false)
	raid.request_extract("B")  # still holding: this is not a new hold
	_check(near.all(func(e): return not e.alert), "continuing a hold must not alert again")
	raid.cancel_extract()
	_check(is_equal_approx(raid.hold_seconds_for("B"), raid.hold_seconds_for("A") * Tuning.EXTRACT_B_HOLD_SECONDS / Tuning.EXTRACT_HOLD_SECONDS), "B's hold should be longer by the tuning ratio")

	# Leaving either zone resets its hold timer (through the real trigger volumes).
	raid.hold_seconds = 60.0
	for id in ["A", "B"]:
		player.global_position = _zone(main, id)["pos"]
		for i in 120:
			if raid.extracting and raid.extract_elapsed > 0.2:
				break
			await physics_frame
		_check(raid.extracting and raid.extract_zone == id and raid.extract_elapsed > 0.2, "zone %s: standing in it should start the hold (zone %s, %.2f s)" % [id, raid.extract_zone, raid.extract_elapsed])
		player.global_position = Vector3(0, 0, 0)
		for i in 60:
			if not raid.extracting:
				break
			await physics_frame
		_check(not raid.extracting and raid.extract_elapsed == 0.0 and raid.extract_zone == "", "zone %s: leaving it should reset the hold" % id)

	# Beams: visible within the reveal radius, hidden beyond it, unless the always-visible setting is on.
	var apos: Vector3 = _zone(main, "A")["pos"]
	var r: float = main.extract_cfg["beam_reveal_radius"]
	player.global_position = apos + Vector3(r - 5.0, 0, 0)
	await process_frame
	await process_frame
	_check(main.beam_shown(_zone(main, "A")) and _zone(main, "A")["beam"].visible and _zone(main, "A")["label"].visible, "a beam within the reveal radius should show")
	_check(not main.beam_shown(_zone(main, "B")) and not _zone(main, "B")["beam"].visible, "the far zone's beam should be hidden")
	player.global_position = apos + Vector3(r + 5.0, 0, 0)
	await process_frame
	await process_frame
	_check(not main.beam_shown(_zone(main, "A")) and not _zone(main, "A")["beam"].visible and not _zone(main, "A")["label"].visible, "a beam beyond the reveal radius should hide")
	main.extract_cfg["beam_always_visible"] = true
	await process_frame
	await process_frame
	_check(_zone(main, "A")["beam"].visible and _zone(main, "B")["beam"].visible, "the always-visible setting should show both beams from anywhere")
	main.extract_cfg["beam_always_visible"] = false

	# Threat clock HUD.
	player.global_position = Vector3.ZERO
	var delay: float = raid.threat_delay
	raid.elapsed = 0.0
	var st: Dictionary = main.threat_hud_state()
	_check(st["mode"] == "countdown" and is_equal_approx(st["seconds"], delay) and st["tone"] == "normal", "the countdown should start at the full delay, got %s" % [st])
	raid.elapsed = delay - Tuning.THREAT_COUNTDOWN_AMBER_SECONDS - 1.0
	_check(main.threat_hud_state()["tone"] == "normal", "more than 30 s left should be normal")
	raid.elapsed = delay - Tuning.THREAT_COUNTDOWN_AMBER_SECONDS + 1.0
	_check(main.threat_hud_state()["tone"] == "amber", "30 s or less should be amber")
	raid.elapsed = delay - Tuning.THREAT_COUNTDOWN_RED_SECONDS + 1.0
	_check(main.threat_hud_state()["tone"] == "red", "10 s or less should be red")
	_check(not main.tick_shown(), "no arrow before the clock fires")
	raid._start_threat()
	st = main.threat_hud_state()
	_check(st["mode"] == "converging" and st["tone"] == "red", "after the clock fires the HUD should say converging, got %s" % [st])
	_check(main.tick_shown(), "after the clock fires the arrow should show")
	main.extract_cfg["threat_tick"] = false
	_check(not main.tick_shown(), "the arrow setting should turn it off")
	main.extract_cfg["threat_tick"] = true
	var b: Dictionary = main.nearest_extract_bearing()
	var to: Vector3 = b["zone"]["pos"] - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)  # face it
	_check(absf(main.nearest_extract_bearing()["angle"]) < 0.05, "facing the nearest zone the arrow should point straight ahead")
	player.rotation.y += PI / 2.0  # turn left: the zone is now on the right
	var turned: float = main.nearest_extract_bearing()["angle"]
	_check(turned > 1.4 and turned < 1.75, "after turning left the zone should be to the right, angle %.2f" % turned)
	var nearest_id: String = b["zone"]["id"]
	player.global_position = _zone(main, "B" if nearest_id == "A" else "A")["pos"]
	_check(main.nearest_extract_bearing()["zone"]["id"] != nearest_id, "the arrow should follow whichever zone is nearest")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test_extract_profile.json")
