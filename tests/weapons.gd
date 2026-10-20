# Run: Godot --headless --path <project> -s tests/weapons.gd   (exit code 1 on failure)
# The loadout (only the weapon chosen at the base goes into a raid), the sniper rifle, zooming with the right
# mouse button (and the scope for the sniper), and the Ammo Depot name.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const WeaponData = preload("res://data/weapons.gd")
const LootZones = preload("res://data/loot_zones.gd")
const Hub = preload("res://scripts/hub.gd")
const PATH := "user://test_weapons.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("weapons: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _raid(equipped: String, with_profile = null) -> Node:
	var p: Profile = with_profile if with_profile != null else Profile.new(PATH)
	p.equipped = equipped
	p.save()
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
	return main

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e

func _run() -> void:
	DirAccess.remove_absolute(PATH)
	_check(LootZones.DATA["armory"]["name"] == "AMMO DEPOT" and Hub.STATIONS["armory"]["name"] == "AMMO DEPOT", "the armory should be called the Ammo Depot")
	var sniper: Dictionary = WeaponData.DATA["sniper"]
	_check(bool(sniper["scope"]) and sniper["damage"] >= 100 and sniper["clip"] <= 5, "the sniper should be a scoped, hard-hitting, small-clip rifle")
	for id in WeaponData.DATA:
		_check(float(WeaponData.DATA[id]["zoom_fov"]) < 75.0, "%s should zoom in" % id)

	# Only the chosen weapon is in the raid: the number keys cannot bring in another.
	var main = await _raid("pistol")
	var player = main._player
	_check(player.loadout == ["pistol"] and player.weapon_id == "pistol", "the loadout is the equipped weapon")
	player._unhandled_input(_key(KEY_2))
	player._unhandled_input(_key(KEY_3))
	_check(player.weapon_id == "pistol", "the scattergun and sniper must not be reachable in a raid with the pistol, got %s" % player.weapon_id)
	main.queue_free()
	await process_frame
	main = await _raid("sniper")
	player = main._player
	player._unhandled_input(_key(KEY_1))
	_check(player.weapon_id == "sniper", "the sniper raid should stay on the sniper, got %s" % player.weapon_id)

	# The sniper: one shot kills a grunt (50 health) at range.
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = Vector3(0, 0, -6)
	main.add_child(e)
	e.set_physics_process(false)
	player.set_physics_process(false)
	await _frames(10)
	main.raid.request_fire("sniper", player._cam.global_transform)
	_check(e.health <= 0 or e.is_queued_for_deletion(), "one sniper shot should kill a grunt at 6 m, health %s" % e.health)

	# Zoom: hold the right mouse button.
	player.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(is_equal_approx(player._cam.fov, 75.0) and not player.scoped, "no zoom until the button is held")
	player.zoom_input_test = true
	await _frames(20)
	_check(is_equal_approx(player._cam.fov, float(sniper["zoom_fov"])) and player.scoped and main._scope.shown and not main._cross.visible, "holding RMB with the sniper should look through the scope, fov %s" % player._cam.fov)
	player.zoom_input_test = false
	await _frames(20)
	_check(is_equal_approx(player._cam.fov, 75.0) and not player.scoped and not main._scope.shown, "letting go should return the view")
	player.select_weapon("pistol")
	player.zoom_input_test = true
	await _frames(20)
	_check(is_equal_approx(player._cam.fov, float(WeaponData.DATA["pistol"]["zoom_fov"])) and not player.scoped and main._cross.visible, "the pistol zooms a little with no scope, fov %s" % player._cam.fov)
	player.zoom_input_test = false
	main.queue_free()
	await process_frame

	# A Scope attachment zooms any weapon twice as far and gives it the scope view; broken, it does nothing.
	var kit := Profile.new(PATH)
	kit.add_items({"att_scope": 1})
	kit.attach("pistol", "att_scope")
	main = await _raid("pistol", kit)
	player = main._player
	player.set_physics_process(true)
	player.zoom_input_test = true
	await _frames(20)
	_check(is_equal_approx(player._cam.fov, float(WeaponData.DATA["pistol"]["zoom_fov"]) * 0.5) and player.scoped and main._scope.shown, "a Scope should zoom the pistol twice as far, through the scope view, fov %s" % player._cam.fov)
	main.raid.att_left["att_scope"] = 0  # broken
	main.raid.weapon_changed()
	await _frames(20)
	_check(is_equal_approx(player._cam.fov, float(WeaponData.DATA["pistol"]["zoom_fov"])) and not player.scoped, "a broken Scope does nothing")
	player.zoom_input_test = false
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)

	# The Ammo Depot offers every weapon, and the choice is saved.
	DirAccess.remove_absolute(PATH)
	Main.show_start = true
	var base = load("res://main.tscn").instantiate()
	base.profile_path = PATH
	root.add_child(base)
	await process_frame
	var hub = base.get_children().filter(func(c): return "open_station" in c)[0]
	hub._on_station_used(get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "armory")[0])
	var buttons: Array = hub._content.find_children("*", "Button", true, false)
	_check(buttons.size() == WeaponData.DATA.size(), "one button per weapon, got %d" % buttons.size())
	hub._equip("sniper")
	var disk := Profile.new(PATH)
	disk.load_from_disk()
	_check(disk.equipped == "sniper", "the sniper should be selectable and saved")
	base.queue_free()
	await process_frame
	Main.show_start = false
	DirAccess.remove_absolute(PATH)
