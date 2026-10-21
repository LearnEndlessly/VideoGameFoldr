# Run: Godot --headless --path <project> -s tests/ammo_threat.gd   (exit code 1 on failure)
# Ammo cost and cooldown, simulation-applied damage, dry fire, starting kit vs loot,
# enemy group count, and the threat clock (continuous, disabled, wave).
extends SceneTree

const ZoneData = preload("res://data/enemies.gd")

const Main = preload("res://scripts/main.gd")
const Tuning = preload("res://data/tuning.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	ZoneData.zones_enabled = false  # these tests count exact damage; tests/enemy_overhaul.gd covers the zones
	await _run()
	for f in failures:
		printerr(f)
	print("ammo_threat: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _new_raid(map_seed: int, keep_enemies: bool) -> Node:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	root.add_child(main)
	await process_frame
	if not keep_enemies:
		for c in main.get_children():
			if "stats" in c:
				c.queue_free()
		await process_frame
	return main

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _add_target(main: Node) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = Vector3(0, 0, -4.5)
	main.add_child(e)
	e.set_physics_process(false)
	await _frames(2)
	return e

func _enemies(main: Node) -> Array:
	return main.get_children().filter(func(c): return "stats" in c and not c.is_queued_for_deletion())

func _mean_dist(main: Node) -> float:
	var list := _enemies(main)
	var total := 0.0
	for e in list:
		total += e.global_position.distance_to(main._player.global_position)
	return total / maxf(list.size(), 1)

func _finish_raid(main: Node) -> void:
	main.queue_free()
	await process_frame

# Shared by F, G, H: safe player so enemies only react to the threat clock.
func _threat_raid(delay: float, continuous: bool, wave: float) -> Node:
	var main = await _new_raid(7, true)
	main.raid.threat_delay = delay
	main.raid.threat_continuous = continuous
	main.raid.threat_wave_seconds = wave
	main._player.safe = true
	return main

func _run() -> void:
	Main.show_start = false
	var main: Node
	var player
	var aim: Transform3D

	# A. Ammo cost and cooldown.
	main = await _new_raid(1, false)
	player = main._player
	aim = player._cam.global_transform
	_check(player.inventory.count("ammo") == Tuning.STARTING_AMMO, "A: start ammo was %d" % player.inventory.count("ammo"))
	_check(main.raid.request_fire("pistol", aim), "A: first shot should fire")
	_check(player.inventory.count("ammo") == Tuning.STARTING_AMMO - 1, "A: one shot must cost exactly 1 ammo")
	_check(not main.raid.request_fire("pistol", aim), "A: immediate second shot must be refused (cooldown)")
	_check(player.inventory.count("ammo") == Tuning.STARTING_AMMO - 1, "A: refused shot must not cost ammo")
	await _frames(20)
	_check(main.raid.request_fire("pistol", aim), "A: shot after cooldown should fire")
	await _finish_raid(main)

	# B. Damage is applied by the simulation.
	main = await _new_raid(1, false)
	player = main._player
	var e = await _add_target(main)
	await _frames(20)
	_check(main.raid.request_fire("pistol", player._cam.global_transform), "B: shot should fire")
	_check(is_equal_approx(e.health, 25.0), "B: grunt health was %s, expected 25" % e.health)
	await _finish_raid(main)

	# C. Empty weapon cannot fire.
	main = await _new_raid(1, false)
	player = main._player
	e = await _add_target(main)
	player.inventory.remove("ammo", player.inventory.count("ammo"))
	await _frames(20)
	var counts := {"dry": 0, "shot": 0}
	main.raid.dry_fire.connect(func(): counts["dry"] += 1)
	main.raid.shot_fired.connect(func(_id): counts["shot"] += 1)
	_check(not main.raid.request_fire("pistol", player._cam.global_transform), "C: empty weapon must not fire")
	_check(counts["dry"] == 1, "C: dry_fire emitted %d times" % counts["dry"])
	_check(counts["shot"] == 0, "C: shot_fired must not be emitted")
	_check(is_equal_approx(e.health, 50.0), "C: target health changed to %s" % e.health)
	await _finish_raid(main)

	# D. The starting kit is spent first, so found rounds are the loot at stake.
	main = await _new_raid(1, false)
	player = main._player
	var results: Array = []
	main.raid.ended.connect(func(r): results.append(r))
	player.inventory.add("ammo", 5)
	for i in 3:
		await _frames(20)
		_check(main.raid.request_fire("pistol", player._cam.global_transform), "D: shot %d should fire" % i)
	player.take_damage(1000)
	_check(results.size() == 1, "D: expected one raid result, got %d" % results.size())
	if results.size() == 1:
		_check(results[0]["items"] == {"ammo": 5}, "D: lost items were %s, expected {ammo: 5}" % [results[0]["items"]])
	await _finish_raid(main)

	# E. Group count.
	main = await _new_raid(1, true)
	var groups := {}
	for c in _enemies(main):
		if c.group_id < Tuning.ENEMY_GROUP_COUNT:  # the bases' garrisons are groups of their own
			groups[c.group_id] = true
	_check(groups.size() == Tuning.ENEMY_GROUP_COUNT, "E: %d groups, expected %d" % [groups.size(), Tuning.ENEMY_GROUP_COUNT])
	await _finish_raid(main)

	# F. Threat clock, continuous: everyone converges.
	main = await _threat_raid(0.5, true, 1.0)
	var started := [0]
	main.raid.threat_started.connect(func(): started[0] += 1)
	await _frames(18)
	var before := _mean_dist(main)
	await _frames(360)
	var after := _mean_dist(main)
	_check(started[0] == 1, "F: threat_started fired %d times" % started[0])
	_check(main.raid.threat_active, "F: threat should be active")
	for c in _enemies(main):
		_check(c.converging, "F: an enemy is not converging")
	_check(after <= 0.75 * before, "F: mean distance %.1f -> %.1f, expected at least 25%% closer" % [before, after])
	# Continuous mode follows the player: move them and the target must follow.
	main._player.global_position += Vector3(8, 0, 0)
	await _frames(5)
	for c in _enemies(main):
		_check(c.converge_target.distance_to(main._player.global_position) < 0.5, "F: an enemy's target did not follow the player")
	await _finish_raid(main)

	# G. Threat control: a far-off threat clock changes nothing.
	main = await _threat_raid(1000.0, true, 1.0)
	await _frames(18)
	before = _mean_dist(main)
	await _frames(360)
	after = _mean_dist(main)
	_check(after > 0.75 * before, "G: mean distance %.1f -> %.1f, should not have closed in" % [before, after])
	for c in _enemies(main):
		_check(not c.converging, "G: an enemy is converging without a threat")
	await _finish_raid(main)

	# H. Threat clock, wave: starts, then ends and releases everyone.
	main = await _threat_raid(0.3, false, 1.0)
	started = [0]
	var ended := [0]
	main.raid.threat_started.connect(func(): started[0] += 1)
	main.raid.threat_ended.connect(func(): ended[0] += 1)
	await _frames(180)
	_check(started[0] == 1, "H: threat_started fired %d times" % started[0])
	_check(ended[0] == 1, "H: threat_ended fired %d times" % ended[0])
	_check(not main.raid.threat_active, "H: threat should be over")
	for c in _enemies(main):
		_check(not c.converging, "H: an enemy is still converging after the wave")
	await _finish_raid(main)

	# I. Wave mode goes to where the player WAS when it started, and does not follow.
	main = await _threat_raid(0.3, false, 30.0)
	await _frames(30)
	var start_pos: Vector3 = main._player.global_position
	main._player.global_position += Vector3(8, 0, 0)
	await _frames(5)
	_check(main.raid.threat_active, "I: the wave should be running")
	for c in _enemies(main):
		_check(c.converge_target.distance_to(start_pos) < 0.5, "I: an enemy's target moved with the player in wave mode")
	await _finish_raid(main)
