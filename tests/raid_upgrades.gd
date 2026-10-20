# Run: Godot --headless --path <project> -s tests/raid_upgrades.gd   (exit code 1 on failure)
# Upgrades won in the raid and lost with it, powerups with a 5 s pickup window, hold-R reloading, the pistol's
# smaller clip, and the rule that only the real save file is reset on launch.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Powerup = preload("res://scripts/powerup.gd")
const Powerups = preload("res://data/powerups.gd")
const Upgrades = preload("res://data/upgrades.gd")
const WeaponData = preload("res://data/weapons.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_raid_upgrades.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("raid_upgrades: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _raid() -> Node:
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 4
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c:
			c.queue_free()
	await process_frame
	main._player.set_physics_process(false)
	return main

func _grunt(main: Node) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = Vector3(0, 0, -4.5)
	main.add_child(e)
	e.set_physics_process(false)
	return e

func _run() -> void:
	DirAccess.remove_absolute(PATH)
	_check(WeaponData.DATA["pistol"]["clip"] == int(round(30 * 0.45)), "the pistol should hold 45%% of 30 rounds, got %d" % WeaponData.DATA["pistol"]["clip"])
	_check(Main.resets_profile(Tuning.PROFILE_PATH, false) and not Main.resets_profile(Tuning.PROFILE_PATH, true) and not Main.resets_profile(PATH, false),
		"only the first launch's real save file should be reset")

	# Level-ups: every RAID_KILLS_PER_PICK kills earns one pick, of up to 3 distinct upgrades.
	var main = await _raid()
	var raid = main.raid
	var player = main._player
	_check(raid.upgrades.is_empty() and raid.picks_pending == 0, "a fresh raid has no upgrades")
	_check(not raid.choose_upgrade("damage"), "no pick is pending, so nothing is bought")
	for i in Upgrades.RAID_KILLS_PER_PICK:
		raid._on_kill(Vector3(50, 0, 50))
	_check(raid.picks_pending == 1, "%d kills should earn a pick, got %d" % [Upgrades.RAID_KILLS_PER_PICK, raid.picks_pending])
	var choices: Array = raid.pick_choices()
	_check(choices.size() == Upgrades.RAID_PICK_CHOICES and choices.duplicate().size() == choices.size(), "three choices expected, got %s" % [choices])
	_check(raid.choose_upgrade("damage") and raid.picks_pending == 0 and raid.upgrades == {"damage": 1}, "taking a pick should spend it")
	var e = _grunt(main)
	await _frames(10)
	raid.request_fire("pistol", player._cam.global_transform)
	_check(is_equal_approx(e.health, 50.0 - round(25 * 1.15)), "Heavy rounds 1 should make the pistol hit for 29, grunt health %s" % e.health)
	raid.picks_pending = 2
	var hp0: int = player.max_health
	player.health = 50
	raid.choose_upgrade("vitality")
	_check(player.max_health == hp0 + 20 and player.health == 70, "Vitality should add 20 max health and heal 20, got %d/%d" % [player.health, player.max_health])
	raid.choose_upgrade("hands")
	_check(is_equal_approx(raid.reload_seconds, Tuning.RELOAD_SECONDS * 0.85), "Quick hands should cut reload by 15%%, got %s" % raid.reload_seconds)
	raid.upgrades["firerate"] = 3
	raid.picks_pending = 1
	_check(not raid.choose_upgrade("firerate"), "an upgrade at its max cannot be taken again")
	_check(not raid.pick_choices().has("firerate"), "a maxed upgrade is not offered")

	# A pending pick pauses the game and opens the level-up screen; taking one resumes.
	raid.picks_pending = 1
	await process_frame
	await process_frame
	_check(paused and main._pick_layer != null and not main._pick_layer.get_children().is_empty(), "a pending pick should pause the game behind the level-up screen")
	main._picked("sprint")
	_check(not paused and main._pick_layer == null and raid.upgrades.get("sprint", 0) == 1 and raid.picks_pending == 0, "taking a pick should resume the game")

	# Powerups: a timed effect, applied on top of the upgrades and gone when it runs out.
	var base_speed: float = player.speed_mult
	var p = Powerup.new()
	p.id = "haste"
	p.position = Vector3(40, 0, 40)
	main.add_child(p)
	await _frames(2)
	_check(raid.collect_powerup(p) and raid.powerups.has("haste"), "collecting should start the effect")
	_check(is_equal_approx(player.speed_mult, base_speed * Powerups.DATA["haste"]["mult"]), "Haste should multiply speed")
	var s := Powerup.new()
	s.id = "shield"
	main.add_child(s)
	raid.collect_powerup(s)
	_check(is_equal_approx(player.armor, 0.5), "Shield should halve damage taken, armor %s" % player.armor)
	raid.powerups["haste"] = 0.05
	raid.powerups["shield"] = 0.05
	await _frames(6)
	_check(raid.powerups.is_empty() and is_equal_approx(player.speed_mult, base_speed) and is_equal_approx(player.armor, 0.0), "effects should end and the numbers return")
	_check(raid.powerup_text() == "", "no powerups, no HUD text")

	# A powerup on the ground disappears after its pickup time, uncollected.
	var gone := Powerup.new()
	gone.id = "damage"
	gone.position = Vector3(40, 0, 40)
	main.add_child(gone)
	_check(is_equal_approx(gone.left, 5.0), "a powerup lies on the ground for 5 s")
	gone.left = 0.05
	await _frames(6)
	_check(not is_instance_valid(gone) or gone.is_queued_for_deletion(), "an expired powerup should be removed")

	# Kills sometimes drop one.
	var before := get_nodes_in_group("powerup").size()
	for i in 200:
		raid._on_kill(Vector3(55, 0, 55))
	await _frames(2)
	var dropped := get_nodes_in_group("powerup").size() - before
	_check(dropped > 20 and dropped < 90, "about %d%% of 200 kills should drop a powerup, got %d" % [int(Tuning.POWERUP_DROP_CHANCE * 100.0), dropped])
	main.queue_free()
	await process_frame

	# Upgrades die with the raid: a new run starts clean, a descent keeps them.
	DirAccess.remove_absolute(PATH)
	Main.run_upgrades = {"damage": 2}
	main = await _raid()
	_check(main.raid.upgrades == {"damage": 2} and is_equal_approx(main.raid._dmg_factor, 1.3), "a descent keeps the run's upgrades")
	main.queue_free()
	await process_frame
	Main.run_upgrades = {}
	main = await _raid()
	_check(main.raid.upgrades.is_empty(), "a fresh run starts without upgrades")
	var profile := Profile.new(PATH)
	profile.load_from_disk()
	_check(not "weapons" in profile and profile.attrs.is_empty(), "upgrades must not leak into the profile")
	main.queue_free()
	await process_frame

	# Holding R reloads, letting go cancels.
	main = await _raid()
	raid = main.raid
	player = main._player
	player.set_physics_process(true)
	player.inventory.add("ammo", 30)
	raid.loaded["pistol"] = 4
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(10)
	_check(raid.reload_weapon == "pistol", "holding R should start a reload")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(10)
	_check(raid.reload_weapon == "" and raid.loaded_rounds("pistol") == 4, "letting go of R should cancel the reload")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)
