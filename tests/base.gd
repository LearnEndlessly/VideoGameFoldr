# Run: Godot --headless --path <project> -s tests/base.gd   (exit code 1 on failure)
# The base of operations and what it saves: weapon upgrades paid from the stash, attribute points
# earned by extracting and spent on speed / constitution / handling, the save round trip (and an old
# save without those fields), the upgrades taking effect in a raid, and the base room itself.
extends SceneTree

const ZoneData = preload("res://data/enemies.gd")

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Upgrades = preload("res://data/upgrades.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_base.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	ZoneData.zones_enabled = false  # these tests count exact damage; tests/enemy_overhaul.gd covers the zones
	await _run()
	for f in failures:
		printerr(f)
	print("base: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _clean() -> void:
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_clean()

	# Weapons are only chosen in the base now; their upgrades are won in the raid.
	var p := Profile.new(PATH)
	p.load_from_disk()
	p.add_items({"ammo": 70, "medkit": 6})
	_check(p.equip("scattergun") and p.equipped == "scattergun" and not p.equip("not_a_weapon"), "equip should accept real weapons only")

	# Attribute points: an extract earns none (clearing rounds does, see tests/attributes.gd), they are spent one level at a time.
	_check(not p.spend_point("speed"), "no points, no level")
	p.record_extract()
	_check(p.points == 0 and p.stats["extracts"] == 1, "an extract alone earns no attribute point, got %d" % p.points)
	p.points = 3
	_check(p.spend_point("speed") and p.spend_point("constitution") and p.spend_point("constitution") and p.points == 0, "three points, three levels")
	_check(not p.spend_point("handling"), "spending needs a point")
	_check(is_equal_approx(p.speed_mult(), 1.06) and p.max_health(100) == 120 and is_equal_approx(p.armor(), 0.08), "attribute effects were wrong")
	p.points = 10
	for i in 10:
		p.spend_point("handling")
	_check(p.attr_level("handling") == Upgrades.ATTR_LEVEL_MAX and p.points == 5, "an attribute stops at its max level")
	_check(is_equal_approx(p.reload_mult(), 0.5), "5 levels of handling should halve reload time")
	_check(not p.spend_point("not_an_attribute"), "unknown attribute must be refused")

	# Save round trip, and a version 1 save (stash only) still loads.
	_check(p.save(), "save failed")
	var q := Profile.new(PATH)
	q.load_from_disk()
	_check(q.totals == p.totals and q.attrs == p.attrs and q.points == p.points \
		and q.equipped == p.equipped and q.stats == p.stats, "reload differed: %s vs %s" % [var_to_str(q.attrs), var_to_str(p.attrs)])
	var old := FileAccess.open(PATH, FileAccess.WRITE)
	old.store_string('{"version": 1, "totals": {"ammo": 4}}')
	old.close()
	q.load_from_disk()
	_check(q.totals == {"ammo": 4} and q.equipped == "pistol" and q.points == 0, "a version 1 save should load with defaults")

	# Attributes carry into a raid: health, armor, speed and reload, and the starting weapon.
	Main.show_start = false
	var prof := Profile.new(PATH)
	prof.attrs = {"constitution": 3, "speed": 2, "handling": 1}
	prof.equipped = "scattergun"
	prof.save()
	var main = await _new_raid(1)
	var player = main._player
	_check(player.max_health == 130 and player.health == 130, "constitution 3 should give 130 max health, got %d" % player.max_health)
	_check(is_equal_approx(player.speed_mult, 1.12) and player.weapon_id == "scattergun", "speed and the equipped weapon should apply")
	player.take_damage(100)
	_check(player.health == 130 - 88, "armor 12%% should turn a 100 hit into 88, health was %d" % player.health)
	_check(is_equal_approx(main.raid.reload_seconds, Tuning.RELOAD_SECONDS * 0.9), "handling 1 should cut reload by 10%")
	player.set_physics_process(false)
	player.select_weapon("pistol")
	var e = _target(main)
	await _frames(20)
	main.raid.request_fire("pistol", player._cam.global_transform)
	_check(is_equal_approx(e.health, 25.0), "a pistol hits for 25 (50 - 25 = 25), grunt health was %s" % e.health)
	main.queue_free()
	await process_frame

	# Extracting saves the run on the scoreboard; the results carry the points earned (none: they come from cleared rounds).
	_clean()
	main = await _new_raid(2)
	var results: Array = []
	main.raid.ended.connect(func(r): results.append(r))
	main.raid.hold_seconds = 0.3
	main._player.kills = 5
	main._player.global_position = main.extract_pos
	for i in 120:
		if not results.is_empty():
			break
		await physics_frame
	_check(results.size() == 1 and results[0]["points"] == 0, "an extract alone should earn no attribute points, results %s" % [results])
	var after := Profile.new(PATH)
	after.load_from_disk()
	_check(after.points == 0 and after.stats["extracts"] == 1, "the extract should be saved, got %d points" % after.points)
	main.queue_free()
	await process_frame

	# The base: a closed room with four stations, no enemies, and panels that change the saved profile.
	_clean()
	var seed_profile := Profile.new(PATH)
	seed_profile.add_items({"ammo": 50, "medkit": 4})
	seed_profile.points = 1
	seed_profile.save()
	Main.show_start = true
	main = load("res://main.tscn").instantiate()
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	var hub = main.get_children().filter(func(c): return "open_station" in c)[0]
	_check(main.get_children().filter(func(c): return "stats" in c or "group_id" in c).is_empty(), "the base must have no enemies or enemy bases")
	_check(get_nodes_in_group("station").size() == 5, "the base should have 4 wall stations (stash, ammo depot, gunsmith, character) and the map device")
	_check(not main.get_children().any(func(c): return "raid_id" in c) and main.raid == null, "the base is not a raid")
	var armory = get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "armory")[0]
	hub._on_station_used(armory)
	_check(hub.open_station == "armory" and hub._panel.visible and hub.player.inventory_open, "using a station should open its panel")
	hub._equip("scattergun")
	hub._on_station_used(get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "character")[0])
	hub._spend("speed")
	var saved := Profile.new(PATH)
	saved.load_from_disk()
	_check(saved.totals == {"ammo": 50, "medkit": 4}, "the stash should be untouched by visiting the armory, stash %s" % [saved.totals])
	_check(saved.equipped == "scattergun" and saved.attr_level("speed") == 1 and saved.points == 0, "equip and attribute changes should be saved")
	var started := [-1]
	hub.start_raid = func(map_seed): started[0] = map_seed
	hub._map_button("play")
	_check(hub.open_station == "raid" and hub._panel.visible, "the map device's play button should open the raid terminal")
	hub._start()
	_check(started[0] == hub.selected_seed, "the raid terminal should start the raid on the selected map, got %s" % started[0])
	hub._close()

	# The map table: a miniature of the selected seed that matches the raid it will play.
	hub._on_station_used(get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "map")[0])
	hub._step_seed(0)
	hub.set_seed(42)
	var pv: Dictionary = main.preview(42)
	_check(hub.selected_seed == 42 and hub.preview_data["w"] == pv["w"] and hub.preview_data["extract"] == pv["extract"], "the table should show the selected map")
	_check(hub._preview != null and hub._preview.get_child_count() >= pv["blocks"].size(), "the miniature should hold every wall and cover box")
	_check(pv["spawners"].size() == Tuning.SPAWNER_COUNT and pv["rooms"] == 2, "the preview should list the bases and loot rooms")
	hub._enter_seed("not a number")
	_check(hub.selected_seed == 42, "a bad map number must be ignored")
	hub._enter_seed("7")
	_check(hub.selected_seed == 7, "typing a map number should select it")
	hub._step_seed(1)
	_check(hub.selected_seed == 8, "Next should step the map number")
	_check(main.preview(1)["extract"] != main.preview(2)["extract"], "different map numbers should make different maps")
	hub._close()

	# The buttons on the table: shoot one from across the room and the map changes, at no cost in ammo.
	var buttons := get_nodes_in_group("shootable")
	_check(buttons.size() == 4, "the table should have previous, random, next and play buttons")
	var hp = hub.player
	var stash_before: Dictionary = main.profile.totals.duplicate()
	var backpack_before: int = hp.inventory.count("ammo")
	for pair in [["next", 1], ["prev", -1]]:
		var button = buttons.filter(func(n): return n.get_meta("action") == pair[0])[0]
		var to: Vector3 = button.global_position - hp._cam.global_position
		hp.rotation.y = atan2(-to.x, -to.z)
		hp._head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		await _frames(2)
		var before: int = hub.selected_seed
		hp._hub_shoot()
		_check(hub.selected_seed == before + pair[1], "shooting the %s button should step the map, %d -> %d" % [pair[0], before, hub.selected_seed])
	_check(main.profile.totals == stash_before and hp.inventory.count("ammo") == backpack_before, "shots in the base must not use any ammo")
	var play = buttons.filter(func(n): return n.get_meta("action") == "play")[0]
	var to_play: Vector3 = play.global_position - hp._cam.global_position
	hp.rotation.y = atan2(-to_play.x, -to_play.z)
	hp._head.rotation.x = atan2(to_play.y, Vector2(to_play.x, to_play.z).length())
	await _frames(2)
	hp._hub_shoot()
	_check(hub.open_station == "raid" and hub._panel.visible, "shooting the play button should open the raid terminal")
	hub._close()
	_check(not hub._panel.visible and not hub.player.inventory_open, "closing should hide the panel and free the mouse look")
	main.queue_free()
	await process_frame
	Main.show_start = false
	_clean()

	# The chosen seed becomes the raid's map, once; and the preview is the same map as the raid.
	Main.chosen_seed = 42
	main = load("res://main.tscn").instantiate()
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	_check(main._seed == 42 and Main.chosen_seed == -1, "the raid should use the chosen seed and clear it, got %d" % main._seed)
	_check(main.half_w * 2.0 == pv["w"] and main.extract_pos == pv["extract"] and main.blocks.size() == pv["blocks"].size(), "the raid map should match the preview of the same seed")
	_check(main._spawners.map(func(sp): return sp.position) == pv["spawners"], "the raid's enemy bases should match the preview")
	main.queue_free()
	await process_frame
	_clean()

func _new_raid(map_seed: int) -> Node:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c:
			c.queue_free()
	await process_frame
	return main

# A grunt 4.5 m in front of the player, standing still.
func _target(main: Node) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = Vector3(0, 0, -4.5)
	main.add_child(e)
	e.set_physics_process(false)
	return e
