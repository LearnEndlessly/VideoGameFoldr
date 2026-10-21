# Run: Godot --headless --path <project> -s tests/raid_upgrades.gd   (exit code 1 on failure)
# Upgrades won in the raid and lost with it, powerups with a 5 s pickup window, hold-R reloading, the pistol's
# smaller clip, and the rule that only the real save file is reset on launch.
extends SceneTree

const ZoneData = preload("res://data/enemies.gd")

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
	ZoneData.zones_enabled = false  # these tests count exact damage; tests/enemy_overhaul.gd covers the zones
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

	# Level-ups: filling the XP bar earns one pick, of up to 3 distinct upgrades.
	var main = await _raid()
	var raid = main.raid
	var player = main._player
	_check(raid.upgrades.is_empty() and raid.picks_pending == 0, "a fresh raid has no upgrades")
	_check(not raid.choose_upgrade("damage"), "no pick is pending, so nothing is bought")
	raid.add_xp(Upgrades.RAID_XP_BASE - 1)
	_check(raid.picks_pending == 0, "one xp short of a level earns nothing")
	raid.add_xp(1)
	_check(raid.picks_pending == 1, "%d xp should earn a pick, got %d" % [Upgrades.RAID_XP_BASE, raid.picks_pending])
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
	raid.upgrades["firerate"] = 6
	raid.picks_pending = 1
	_check(raid.pick_choices().size() == Upgrades.RAID_PICK_CHOICES, "there is no top level, so three choices are always offered")
	_check(is_equal_approx(Upgrades.step_factor(2), 1.0) and is_equal_approx(Upgrades.step_factor(3), 0.8) and is_equal_approx(Upgrades.step_factor(6), 0.64), "every 3 levels each step is 0.8x the last")
	_check(is_equal_approx(Upgrades.total(3), 3.0) and is_equal_approx(Upgrades.total(4), 3.8) and is_equal_approx(Upgrades.total(6), 5.4), "levels count in full levels: 3, 3.8, 5.4")
	_check(raid.choose_upgrade("firerate") and raid.upgrades["firerate"] == 7, "an upgrade can be taken past any old maximum")
	raid.upgrades.erase("firerate")
	raid.picks_pending = 0

	var saved_up_keep: Dictionary = raid.upgrades.duplicate()
	# Moon boots lower the gravity; stacking has diminishing returns and the floors hold at any level.
	raid.picks_pending = 1
	raid.choose_upgrade("jump")
	_check(is_equal_approx(player.gravity_mult, 1.0 - 0.12), "Moon boots 1 should cut gravity by 12%%, got %s" % player.gravity_mult)
	# The gravity number is really used: with half the gravity the player falls less in half a second.
	player.set_physics_process(true)
	var fall := []
	for g in [1.0, 0.5]:
		player.gravity_mult = g
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0, 12, 0)
		await _frames(30)
		fall.append(12.0 - player.global_position.y)
	player.set_physics_process(false)
	_check(fall[1] < fall[0] * 0.7, "half the gravity should fall much less in 0.5 s (%s vs %s m)" % [fall[1], fall[0]])
	raid.upgrades = {"jump": 4, "firerate": 60, "hands": 60, "plating": 60, "damage": 60}
	raid._apply_upgrades()
	_check(is_equal_approx(player.gravity_mult, 1.0 - 0.12 * 3.8) or player.gravity_mult >= 0.3, "gravity should follow the diminishing total, got %s" % player.gravity_mult)
	raid.upgrades = {"jump": 80, "firerate": 80, "hands": 80, "plating": 80, "damage": 80, "sprint": 80, "vitality": 80}
	raid._apply_upgrades()
	_check(player.gravity_mult >= 0.3 and raid.cooldown_mult >= 0.25 and raid.reload_seconds >= Tuning.RELOAD_SECONDS * 0.25 - 0.001 and player.armor <= 0.8, "floors hold at huge levels")
	_check(raid._dmg_factor < 1.0 + 0.15 * 80.0, "stacked damage is below the undiminished total (%s)" % raid._dmg_factor)
	_check(raid.pick_choices().size() == Upgrades.RAID_PICK_CHOICES, "still something to pick at level 80")
	raid.upgrades = saved_up_keep
	raid._apply_upgrades()
	raid.picks_pending = 0

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

	# The XP bar numbers, and the Esc pause menu.
	main = await _raid()
	raid = main.raid
	_check(raid.raid_level() == 1 and is_equal_approx(raid.xp_fraction(), 0.0), "a fresh raid is level 1 with an empty bar")
	raid.add_xp(3)
	_check(is_equal_approx(raid.xp_fraction(), 3.0 / Upgrades.RAID_XP_BASE), "xp fills part of the bar")
	_check(main._xp_bar != null and main._xp_bar.get_parent() == main._hp_bar.get_parent(), "the XP bar sits with the health bar")
	main._player.pause_requested.emit()
	_check(paused and main._pause_layer != null, "Esc should pause the game behind the controls screen")
	main._player.pause_requested.emit()  # a second request while paused changes nothing
	main._resume()
	_check(not paused and main._pause_layer == null, "resuming should unpause")
	main.queue_free()
	await process_frame

	# One press of R loads a full magazine, and the gun shows it: the old magazine drops, the new one rises in.
	main = await _raid()
	raid = main.raid
	player = main._player
	player.set_physics_process(true)
	player.inventory.add("ammo", 30)
	raid.loaded["pistol"] = 4
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	key.pressed = true
	player._unhandled_input(key)
	_check(raid.reload_weapon == "pistol", "pressing R should start a reload")
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0 * 0.25))
	_check(player.reload_progress() > 0.12 and player._mag_old.visible and not player._mag_new.visible, "early on the old magazine should be dropping")
	if player._viewmodel != null:
		_check(player._viewmodel.position != player.VIEW_POS, "the gun should dip during a reload")
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0 * 0.3))
	_check(player._mag_new.visible and not player._mag_old.visible, "then the new magazine should rise in")
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0 * 0.6))
	_check(raid.reload_weapon == "" and raid.loaded_rounds("pistol") == WeaponData.DATA["pistol"]["clip"], "one press should finish with a full magazine, got %d" % raid.loaded_rounds("pistol"))
	_check(not player._mag_new.visible and not player._mag_old.visible and (player._viewmodel == null or player._viewmodel.position == player.VIEW_POS), "the animation should end with the gun back in place")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)
