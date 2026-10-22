# Run: Godot --headless --path <project> -s tests/enemy_scaling.gd   (exit code 1 on failure)
# Enemies get tougher each round (damage and health +0.1x per round, speed +0.15x every 3 rounds, all capped at
# 1.5x the base), and experience: an enemy's XP value follows its difficulty, a kill leaves one orb per point,
# collecting orbs fills the level, and levels get slower.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Upgrades = preload("res://data/upgrades.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_enemy_scaling.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("enemy_scaling: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _stats(type: String, modifier := "") -> Dictionary:
	var s: Dictionary = Enemies.TYPES[type].duplicate()
	s["type"] = type
	s["modifier"] = modifier
	if modifier == "armored":
		s["health"] = int(s["health"] * 2.0)
	elif modifier == "fast":
		s["speed"] = s["speed"] * 2.4
	return s

func _raid(depth: int) -> Node:
	DirAccess.remove_absolute(PATH)
	Main.depth = depth
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 4
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	await process_frame
	return main

func _run() -> void:
	# The per-round numbers.
	var r0 := Enemies.round_scale(0)
	_check(r0["damage"] == 1.0 and r0["health"] == 1.0 and r0["speed"] == 1.0, "the first round is the base")
	var r1 := Enemies.round_scale(1)
	_check(is_equal_approx(r1["damage"], 1.1) and is_equal_approx(r1["health"], 1.1) and r1["speed"] == 1.0, "round 1: +0.1 damage and health, no speed yet, got %s" % [r1])
	var r3 := Enemies.round_scale(3)
	_check(is_equal_approx(r3["damage"], 1.3) and is_equal_approx(r3["health"], 1.3) and is_equal_approx(r3["speed"], 1.15), "round 3: speed +0.15, got %s" % [r3])
	var r6 := Enemies.round_scale(6)
	_check(is_equal_approx(r6["damage"], 1.5) and is_equal_approx(r6["speed"], 1.3), "round 6: damage at the cap, speed 1.3, got %s" % [r6])
	var r9 := Enemies.round_scale(9)
	_check(is_equal_approx(r9["speed"], 1.45), "round 9: speed 1.45, got %s" % [r9])
	for rd in [10, 12, 30]:
		var s := Enemies.round_scale(rd)
		_check(s["damage"] == 1.5 and s["health"] == 1.5 and s["speed"] <= 1.5, "round %d must not pass 1.5x, got %s" % [rd, s])
	_check(Enemies.round_scale(30)["speed"] == 1.5, "speed reaches the cap in the end")

	# XP follows difficulty.
	var grunt := Enemies.xp_value(_stats("grunt"))
	_check(grunt == 3, "a plain grunt is worth 3 xp, got %d" % grunt)
	_check(Enemies.xp_value(_stats("brute")) > Enemies.xp_value(_stats("grunt", "armored")) and Enemies.xp_value(_stats("grunt", "armored")) > grunt, "tougher enemies are worth more")
	_check(Enemies.xp_value(_stats("grunt", "fast")) > grunt, "a fast grunt is worth more")
	var deep := _stats("grunt")
	deep["health"] = int(round(deep["health"] * 1.5))
	deep["damage"] = int(round(deep["damage"] * 1.5))
	_check(Enemies.xp_value(deep) > grunt, "a deeper-level grunt is worth more")

	# Levels are slower than the old two kills: a plain grunt gives 3, the first level needs 12.
	_check(Upgrades.RAID_XP_BASE >= 4 * grunt, "the first level should take at least 4 grunts")

	# In a raid: a kill leaves one orb per point, each worth 1, and collecting them fills the level.
	var main = await _raid(0)
	var raid = main.raid
	var player = main._player
	player.set_physics_process(false)
	_check(raid.xp_needed() == Upgrades.RAID_XP_BASE, "level 1 needs %d xp" % Upgrades.RAID_XP_BASE)
	var before := get_nodes_in_group("xp").size()
	raid._on_kill(Vector3(50, 0, 50), _stats("brute"))
	await _frames(2)
	var orbs := get_nodes_in_group("xp")
	_check(orbs.size() - before == Enemies.xp_value(_stats("brute")) and orbs.all(func(o): return o.amount == 1), "a brute should leave %d orbs worth 1 each, got %d" % [Enemies.xp_value(_stats("brute")), orbs.size() - before])
	_check(raid.xp == 0, "orbs give nothing until they are picked up")
	for o in orbs:
		raid.collect_xp(o)
	var orb_xp: int = Enemies.xp_value(_stats("brute"))
	_check(raid.xp == orb_xp + int(orb_xp * Tuning.XP_DROP_BONUS) and is_equal_approx(raid.xp_fraction(), float(raid.xp) / raid.xp_needed()), "collecting orbs should fill the bar")
	# A walk-in collects it too, and orbs drift toward the player.
	var orb := preload("res://scripts/xp_orb.gd").new()
	orb.position = player.global_position + Vector3(2.5, 0, 0)
	main.add_child(orb)
	await _frames(40)
	_check(not is_instance_valid(orb) or orb.is_queued_for_deletion() or orb.global_position.distance_to(player.global_position) < 2.0, "an orb should drift toward the player")
	raid.xp = 0
	raid._xp_extra = 0.0
	var need: int = raid.xp_needed()  # the next level needs more, so read it before
	raid.add_xp(need)
	_check(raid.picks_pending == 1 and raid.xp == int(need * Tuning.XP_DROP_BONUS), "a full bar earns a pick, and the XP_DROP_BONUS left over carries on")
	_check(raid.xp_needed() == Upgrades.RAID_XP_BASE + Upgrades.RAID_XP_GROWTH, "the next level needs %d more xp" % Upgrades.RAID_XP_GROWTH)
	main.queue_free()
	await process_frame

	# Three rounds down: the map's enemies carry the round's health, speed and damage, and a spawner's defenders too.
	main = await _raid(3)
	raid = main.raid
	var s3 := Enemies.round_scale(3)
	var mine: Array = main.get_children().filter(func(c): return "stats" in c and not c.is_queued_for_deletion())
	_check(not mine.is_empty(), "the map should have enemies")
	var ok := true
	for e in mine:
		var base: Dictionary = Enemies.TYPES[e.stats["type"]]
		var health_base: int = int(round(base["health"] * (2.0 if e.stats["modifier"] == "armored" else 1.0)))
		ok = ok and e.max_health == int(round(health_base * s3["health"])) and e.health == e.max_health
		ok = ok and e.stats["damage"] == int(round(round(base["damage"] * 1.0) * s3["damage"]))
	_check(ok, "every enemy on a round-3 map should be 1.3x health and damage")
	var sp = main._spawners[0]
	sp._clock = sp.interval
	sp.max_alive = 99
	await _frames(3)
	var born: Array = get_nodes_in_group("pack_%d" % sp.group_id).filter(func(e): return e.group_id == sp.group_id)
	_check(not born.is_empty() and born.all(func(e): return e.max_health >= int(round(Enemies.TYPES[e.stats["type"]]["health"] * s3["health"]))), "a spawner's defenders should be toughened too")
	_check(Enemies.xp_value(mine[0].stats) >= Enemies.xp_value(_stats(mine[0].stats["type"], mine[0].stats["modifier"])), "xp follows the toughened stats")
	main.queue_free()
	await process_frame
	Main.depth = 0
	DirAccess.remove_absolute(PATH)
