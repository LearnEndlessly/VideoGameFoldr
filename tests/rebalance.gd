# Run: Godot --headless --path <project> -s tests/rebalance.gd   (exit code 1 on failure)
# Checks the design changes from docs/DESIGN_METRICS.md: repair kits never drop, scrap crafts
# into medkits through the raid, sight needs line of sight but sprinting is heard through
# walls, the armory is guarded, the backpack is smaller, and the scattergun/"fast" numbers.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Tuning = preload("res://data/tuning.gd")
const Loot = preload("res://data/loot.gd")
const LootZones = preload("res://data/loot_zones.gd")
const WeaponData = preload("res://data/weapons.gd")
const Enemies = preload("res://data/enemies.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Inventory = preload("res://scripts/inventory.gd")

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _new_raid(map_seed: int) -> Node:
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	root.add_child(main)
	await process_frame
	return main

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	await _run()
	for f in failures:
		printerr(f)
	print("rebalance: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _enemy_at(main: Node, pos: Vector3) -> Node:
	var e = Enemy.new()
	e.stats = Enemies.TYPES["grunt"].duplicate()
	e.stats["type"] = "grunt"
	e.stats["modifier"] = ""
	e.position = pos
	main.add_child(e)
	e.set_physics_process(false)
	return e

func _run() -> void:
	Main.show_start = false

	# Data rules.
	_check(Inventory.SLOTS == 8, "backpack should have 8 slots, has %d" % Inventory.SLOTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 4000:
		_check(Loot.roll(rng)[0] != "repair_kit", "repair_kit dropped from the default pool")
		for zone_id in LootZones.DATA:
			var zone: Dictionary = LootZones.DATA[zone_id]
			if Loot.roll(rng, zone["pool"], zone["qty_mult"])[0] == "repair_kit":
				_check(false, "repair_kit dropped from %s" % zone_id)
				break
	var grunt_speed: float = Enemies.TYPES["grunt"]["speed"]
	_check(grunt_speed * Enemies.MODIFIERS["fast"]["speed_mult"] > Tuning.PLAYER_WALK_SPEED, "a fast grunt should outrun a walking player")
	_check(grunt_speed * Enemies.MODIFIERS["fast"]["speed_mult"] < Tuning.PLAYER_SPRINT_SPEED, "a fast grunt should not outrun a sprinting player")
	var pistol: Dictionary = WeaponData.DATA["pistol"]
	var scatter: Dictionary = WeaponData.DATA["scattergun"]
	var per_ammo_pistol: float = float(pistol["damage"] * pistol["pellets"]) / pistol["ammo_per_shot"]
	var per_ammo_scatter: float = float(scatter["damage"] * scatter["pellets"]) / scatter["ammo_per_shot"]
	_check(per_ammo_scatter > 1.5 * per_ammo_pistol, "scattergun should be much better per ammo up close")
	_check(scatter["effective"] < 0.5 * pistol["effective"], "scattergun should have well under half the pistol's range")

	# Crafting.
	var main = await _new_raid(1)
	var player = main._player
	var fed: Array = []
	main.raid.picked_up.connect(func(id, _qty): fed.append(id))
	player.inventory.clear()
	player.inventory.add("scrap", 9)
	_check(not main.raid.request_craft("medkit"), "craft: 9 scrap must not be enough")
	_check(player.inventory.count("scrap") == 9 and player.inventory.count("medkit") == 0, "craft: a refused craft changed the backpack")
	player.inventory.add("scrap", 6)  # 15 scrap
	_check(main.raid.request_craft("medkit"), "craft: 15 scrap should craft a medkit")
	_check(player.inventory.count("scrap") == 5 and player.inventory.count("medkit") == 1, "craft: wrong result, scrap %d medkit %d" % [player.inventory.count("scrap"), player.inventory.count("medkit")])
	_check(fed == ["medkit"], "craft: the result should be announced like a pickup")
	_check(not main.raid.request_craft("not_a_thing"), "craft: unknown recipe must be refused")
	# Through the player's click path.
	player.inventory.clear()
	player.inventory.add("scrap", 12)
	player.use_slot(0)
	_check(player.inventory.count("medkit") == 1 and player.inventory.count("scrap") == 2, "craft: clicking scrap should craft")
	# No room for the result: ingredients come back.
	player.inventory.clear()
	player.inventory.add("scrap", 15)
	player.inventory.add("medkit", 3 * (Inventory.SLOTS - 1))  # every other slot full of medkits
	_check(not main.raid.request_craft("medkit"), "craft: a full backpack must refuse")
	_check(player.inventory.count("scrap") == 15, "craft: a refused full-backpack craft must give the scrap back")
	# Kills are reported on the results screen data.
	var results: Array = []
	main.raid.ended.connect(func(r): results.append(r))
	player.kills = 3
	player.take_damage(1000)
	_check(results.size() == 1 and results[0]["kills"] == 3, "results should carry the kill count")
	main.queue_free()
	await process_frame

	# Sight needs line of sight; sprinting is heard through walls. Everything is placed
	# high above the map so only our wall can block.
	main = await _new_raid(2)
	player = main._player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 50, 0)
	var seer = _enemy_at(main, Vector3(0, 50, -12))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.global_position = Vector3(0, 51.5, -6)
	await _frames(2)
	_check(not seer._notices(player, 12.0), "sight: an enemy behind a wall must not see the player")
	player.sprinting = true
	_check(seer._notices(player, 10.0), "sight: sprinting within the noise range must be heard through a wall")
	_check(not seer._notices(player, 16.0), "sight: sprinting beyond the noise range must not be heard")
	player.sprinting = false
	wall.global_position = Vector3(0, 80, -6)  # move the wall away
	await _frames(2)
	_check(seer._notices(player, 12.0), "sight: with a clear line the player must be seen")
	_check(not seer._notices(player, 25.0), "sight: beyond sight range must not be seen")
	_enemy_at(main, Vector3(0, 50, -6))  # another enemy in between
	await _frames(2)
	_check(seer._notices(player, 12.0), "sight: another enemy in the way must not block sight")
	main.queue_free()
	await process_frame

	# The armory is guarded: group 0 usually spawns GUARD_DISTANCE outside its door.
	var guarded := 0
	var seeds := 30
	for s in seeds:
		main = await _new_raid(s)
		for st in main.structures:
			if st["id"] != Tuning.GUARDED_ZONE:
				continue
			for e in main.get_children().filter(func(c): return "stats" in c and c.group_id == 0):
				if e.home.distance_to(st["door"]) <= Tuning.GUARD_DISTANCE + 4.0 + 0.1:
					guarded += 1
					break
		main.queue_free()
		await process_frame
	print("rebalance: the %s was guarded on %d of %d maps" % [Tuning.GUARDED_ZONE, guarded, seeds])
	_check(guarded >= seeds * 0.8,   # measured 29 of 30 after the door side is picked by guard room
"the %s was guarded on only %d of %d maps" % [Tuning.GUARDED_ZONE, guarded, seeds])
