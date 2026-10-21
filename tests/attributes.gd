# Run: Godot --headless --path <project> -s tests/attributes.gd   (exit code 1 on failure)
# The character screen's 35 attributes: the data table, the caps (5 levels each, 15 points in all), attribute points
# earned only by clearing every 5th round (with the screen message), and that every stat is really used by the game.
extends SceneTree

const ZoneData = preload("res://data/enemies.gd")

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Powerup = preload("res://scripts/powerup.gd")
const Upgrades = preload("res://data/upgrades.gd")
const WeaponData = preload("res://data/weapons.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_attributes.json"
const FAR := Vector3(5000, 50, 5000)  # an empty corner of the world to shoot in

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
	print("attributes: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _clean() -> void:
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)

# A raid at `level` rounds down with every enemy and enemy base removed.
func _raid(depth := 0, attrs := {}) -> Node:
	_clean()
	var prof := Profile.new(PATH)
	prof.attrs = attrs
	prof.save()
	Main.show_start = false
	Main.depth = depth
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 4
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	Main.depth = 0
	for c in main.get_children():
		if "stats" in c or "group_id" in c:
			c.free()
	await process_frame
	main._player.set_physics_process(false)
	return main

func _grunt(main: Node, pos: Vector3) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = pos
	main.add_child(e)
	e.set_physics_process(false)
	return e

# Moves the player to the empty corner, facing -Z.
func _arena(main: Node) -> void:
	main._player.global_position = FAR
	main._player.rotation = Vector3.ZERO
	main._player._head.rotation = Vector3.ZERO

# One shot with `weapon` at a standing grunt `dist` metres ahead; returns the damage it dealt.
func _shoot(main: Node, weapon: String, dist: float) -> int:
	var player = main._player
	player.select_weapon(weapon)
	if player.inventory.count("ammo") < 40:
		player.inventory.add("ammo", 40)
	main.raid.loaded[weapon] = WeaponData.DATA[weapon]["clip"]
	var e = _grunt(main, FAR + Vector3(0, 0, -dist))
	e.health = 1000000
	await _frames(3)
	main.raid._fire_cooldown = 0.0
	main.raid.request_fire(weapon, player._cam.global_transform)
	var dealt: int = 1000000 - e.health
	e.free()
	return dealt

func _run() -> void:
	# --- the table ---
	_check(Upgrades.ATTRS.size() == 35, "the character screen should have 35 attributes, got %d" % Upgrades.ATTRS.size())
	_check(Upgrades.ATTR_LEVEL_MAX == 5 and Upgrades.ATTR_TOTAL_MAX == 15 and Upgrades.ATTR_ROUNDS_PER_POINT == 5, "caps: 5 levels each, 15 points, a point every 5 rounds")
	var used := {}
	for id in Upgrades.ATTRS:
		var at: Dictionary = Upgrades.ATTRS[id]
		_check(Upgrades.ATTR_GROUPS.has(at["group"]) and not at["stats"].is_empty(), "%s needs a group and stats" % id)
		for stat in at["stats"]:
			_check(Upgrades.STATS.has(stat), "%s uses an unknown stat %s" % [id, stat])
			used[stat] = true
		var text := Upgrades.attr_text(id)
		_check(text != "" and not text.contains("{"), "%s has no readable description: '%s'" % [id, text])
	for stat in Upgrades.STATS:
		_check(used.has(stat), "no attribute gives %s" % stat)
	_check(Upgrades.attr_text("speed") == "+6% move speed" and Upgrades.attr_text("constitution") == "+10 max health, 4% less damage taken", "descriptions come from the numbers, got '%s' / '%s'" % [Upgrades.attr_text("speed"), Upgrades.attr_text("constitution")])

	# --- the caps ---
	var p := Profile.new(PATH)
	p.points = 30
	for id in ["marksman", "trigger", "handling", "steady"]:
		for i in 7:
			p.spend_point(id)
	_check(p.attr_level("marksman") == 5 and p.attr_level("trigger") == 5 and p.attr_level("handling") == 5, "an attribute stops at 5 levels")
	_check(p.attr_total() == 15 and p.attr_level("steady") == 0 and p.points == 15, "15 points can be spent in all, got %d spent, steady %d" % [p.attr_total(), p.attr_level("steady")])
	_check(not p.grant_point() and p.points == 15, "no point is granted once points held and spent reach 15")
	var q := Profile.new(PATH)
	q.attrs = {"marksman": 5, "trigger": 5}
	var granted := 0
	for i in 20:
		if q.grant_point():
			granted += 1
	_check(granted == 5 and q.points == 5, "10 spent leaves room for 5 more points, got %d" % granted)
	_check(is_equal_approx(q.bonus("damage"), 0.2) and is_equal_approx(q.bonus("firerate"), 0.2) and q.bonus("reload") == 0.0, "bonus sums level x per-level")
	q.attrs = {"speed": 2, "constitution": 3}
	_check(is_equal_approx(q.bonus("speed"), 0.12) and is_equal_approx(q.bonus("hp"), 30.0) and is_equal_approx(q.bonus("armor"), 0.12), "constitution gives health and armor")
	q.attrs = {"tinkerer": 3}
	_check(q.repair_cost() == 2, "Tinkerer 3 cuts a repair to 2 scrap, got %d" % q.repair_cost())
	q.attrs = {"tinkerer": 5}
	_check(q.repair_cost() == 1, "a repair never costs less than 1 scrap")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	var over := {}
	for id in Upgrades.ATTRS.keys().slice(0, 8):
		over[id] = 5
	f.store_string(JSON.stringify({"version": 2, "totals": {}, "attrs": over, "points": 0}))
	f.close()
	var r := Profile.new(PATH)
	r.load_from_disk()
	_check(r.attr_total() == 15, "a hand-edited save cannot spend more than 15 points, got %d" % r.attr_total())

	# --- points come from clearing every 5th round ---
	var main = await _raid(4)  # round 5
	var raid = main.raid
	var earned := [0]
	raid.point_earned.connect(func(): earned[0] += 1)
	_check(raid.round_number() == 5 and raid.profile.points == 0, "this is round 5 with no points yet")
	await _frames(45)  # the raid checks twice a second by itself
	_check(raid.round_cleared and raid.profile.points == 1 and raid.points_earned == 1 and earned[0] == 1, "clearing round 5 should earn one point, got %d" % raid.profile.points)
	_check(main._banner.text.contains("NEW ATTRIBUTE POINT AT THE CHARACTER SCREEN") and main._banner_time > 0.0, "the screen should say a new attribute point is waiting, got '%s'" % main._banner.text)
	var disk := Profile.new(PATH)
	disk.load_from_disk()
	_check(disk.points == 1, "the point is saved at once, so dying afterwards keeps it")
	_check(not raid.check_round_clear() and raid.profile.points == 1, "a round pays its point once")
	main.queue_free()
	await process_frame

	main = await _raid(4)
	raid = main.raid
	var e = _grunt(main, Vector3(0, 0, -20))
	_check(not raid.check_round_clear() and raid.profile.points == 0, "an enemy still alive: the round is not cleared")
	e.free()
	var base := Node3D.new()
	base.add_to_group("spawner")
	main.add_child(base)
	_check(not raid.check_round_clear(), "an enemy base still standing: the round is not cleared")
	base.free()
	_check(raid.check_round_clear() and raid.profile.points == 1, "all enemies and bases gone: cleared")
	main.queue_free()
	await process_frame

	main = await _raid(3)  # round 4
	_check(not main.raid.check_round_clear() and main.raid.profile.points == 0, "round 4 earns nothing")
	main.queue_free()
	await process_frame
	main = await _raid(9)  # round 10
	_check(main.raid.check_round_clear() and main.raid.profile.points == 1, "round 10 earns a point too: it repeats every 5 rounds")
	main.queue_free()
	await process_frame
	main = await _raid(4, {"marksman": 5, "trigger": 5, "handling": 5})
	main.raid.profile.points = 0
	_check(main.raid.check_round_clear() and main.raid.profile.points == 0 and main.raid.points_earned == 0, "at 15 spent no more points are granted")
	main.queue_free()
	await process_frame

	# --- every stat does something in a raid ---
	main = await _raid(0)
	raid = main.raid
	var player = main._player
	var prof: Profile = raid.profile
	raid.profile.save()
	_arena(main)

	_check(await _shoot(main, "pistol", 10.0) == 25, "a bare pistol hits for 25")
	prof.attrs = {"marksman": 5}
	raid._apply_upgrades()
	_check(await _shoot(main, "pistol", 10.0) == 30, "Marksman 5: +20% damage makes a pistol hit 30")
	prof.attrs = {"sidearm": 5}
	raid._apply_upgrades()
	_check(await _shoot(main, "pistol", 10.0) == 35, "Sidearm training 5: +40% for the pistol")
	prof.attrs = {"longgun": 5}
	raid._apply_upgrades()
	_check(await _shoot(main, "pistol", 10.0) == 25, "Long gun training does nothing for the pistol")
	_check(await _shoot(main, "sniper", 10.0) == 140, "Long gun training 5: +40% for the sniper")
	prof.attrs = {"ambush": 2}
	raid._apply_upgrades()
	_check(await _shoot(main, "pistol", 10.0) == 30, "Ambusher 2: +20% against an enemy that has not noticed you")
	prof.attrs = {"longshot": 5}
	raid._apply_upgrades()
	var far: Dictionary = WeaponData.DATA["pistol"].duplicate()
	far["effective"] = 25.0 * 1.3
	far["max"] = 60.0 * 1.3
	var plain: int = WeaponData.damage_at(WeaponData.DATA["pistol"], 40.0)
	var longer: int = WeaponData.damage_at(far, 40.0)
	_check(longer > plain, "the test distance should sit in the falloff band (%d vs %d)" % [plain, longer])
	_check(await _shoot(main, "pistol", 40.0) == longer, "Long shot 5: +30%% range, the pistol should hit for %d at 40 m" % longer)

	prof.attrs = {}
	raid._apply_upgrades()
	var cd0: float = raid.cooldown_mult
	prof.attrs = {"trigger": 5}
	raid._apply_upgrades()
	_check(is_equal_approx(cd0, 1.0) and is_equal_approx(raid.cooldown_mult, 0.8), "Trigger discipline 5 shortens the wait between shots by 20%%, got %s" % raid.cooldown_mult)

	# A tighter cone puts more pellets on a target: same random numbers, same grunt, scattergun at 9 m.
	var tight := 0
	var loose := 0
	for s in range(1, 30):
		prof.attrs = {}
		raid._apply_upgrades()
		seed(s)
		loose = await _shoot(main, "scattergun", 9.0)
		if loose < 112:
			prof.attrs = {"steady": 5}
			seed(s)
			tight = await _shoot(main, "scattergun", 9.0)
			break
	_check(loose < 112 and tight == 112, "Steady hands 5 should land all 8 pellets that spread out otherwise (%d vs %d)" % [tight, loose])

	# Chances use their own seeded stream: the same seed gives the same shots, which a test can mirror.
	prof.attrs = {"lethal": 5}
	raid._apply_upgrades()
	var crit_seed := 1
	var expect := 0
	for s in range(1, 40):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var crits := 0
		for i in 10:
			crits += 1 if rng.randf() < 0.2 else 0
		if crits >= 2 and crits <= 4:
			crit_seed = s
			expect = 10 * 25 + crits * 25
			break
	raid._luck.seed = crit_seed
	var dealt := 0
	for i in 10:
		dealt += await _shoot(main, "pistol", 10.0)
	_check(dealt == expect, "Lethal 5: 20%% of shots do double, expected %d got %d" % [expect, dealt])

	prof.attrs = {"thrifty": 5}
	raid._apply_upgrades()
	var spent0: int = raid.ammo_spent
	var ammo0: int = player.inventory.count("ammo")
	var paid := 0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 6
	for i in 10:
		paid += 0 if rng2.randf() < 0.2 else 1
	raid._luck.seed = 6
	player.select_weapon("pistol")
	raid.loaded["pistol"] = 14
	for i in 10:
		raid._fire_cooldown = 0.0
		raid.request_fire("pistol", player._cam.global_transform)
	_check(paid < 10 and raid.ammo_spent - spent0 == paid and ammo0 - player.inventory.count("ammo") == paid, "Thrifty 5: 20%% of shots cost nothing, expected %d rounds spent, got %d" % [paid, raid.ammo_spent - spent0])

	# Attachment wear: Careful hands skips some of it.
	prof.attrs = {"careful": 5}
	prof.attached = {"pistol": "att_heavy_barrel"}
	raid.att_left = {"att_heavy_barrel": 100}
	raid._apply_upgrades()
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 8
	var worn := 0
	for i in 10:
		worn += 0 if rng3.randf() < 0.4 else 1
	raid._luck.seed = 8
	raid.loaded["pistol"] = 14
	for i in 10:
		raid._fire_cooldown = 0.0
		raid.request_fire("pistol", player._cam.global_transform)
	_check(worn < 10 and raid.att_left["att_heavy_barrel"] == 100 - worn, "Careful hands 5: 40%% of shots do not wear the attachment, expected %d left, got %d" % [100 - worn, raid.att_left["att_heavy_barrel"]])
	prof.attached = {}
	raid.att_left = {}

	prof.attrs = {"eagle": 5}
	_check(is_equal_approx(raid.fov_mult("pistol"), 0.7) and is_equal_approx(raid.zoom_mult("pistol"), 1.0), "Eagle eye 5: the zoomed view is 30%% tighter, got %s" % raid.fov_mult("pistol"))
	player.select_weapon("pistol")
	player.zoom_input_test = true
	player._update_zoom(10.0)
	_check(is_equal_approx(player._cam.fov, 55.0 * 0.7) and not player.scoped, "the camera should zoom to the tighter view, got %s" % player._cam.fov)
	player.zoom_input_test = false
	player._update_zoom(10.0)

	prof.attrs = {"magazine": 5}
	_check(raid.clip_size("pistol") == 21 and raid.clip_size("sniper") == 8, "Extended mags 5: +50%% magazine, pistol %d sniper %d" % [raid.clip_size("pistol"), raid.clip_size("sniper")])
	player.inventory.add("ammo", 40)
	raid.loaded["pistol"] = 0
	raid.request_reload()
	raid.reload_left = 0.01
	await _frames(3)
	_check(raid.loaded["pistol"] == 21, "a reload fills the bigger magazine, got %d" % raid.loaded["pistol"])

	prof.attrs = {"regen": 5}
	player.health = 10
	for i in 4:
		raid._regen(0.25)
	_check(player.health == 11, "Regeneration 5: 1.5 health a second, got %d after one second" % player.health)
	for i in 4:
		raid._regen(0.25)
	_check(player.health == 13, "and 3 after two, got %d" % player.health)

	prof.attrs = {"bloodlust": 5}
	player.health = 50
	var hp_target = _grunt(main, FAR + Vector3(0, 0, -10))
	hp_target.health = 25
	await _frames(3)
	raid._fire_cooldown = 0.0
	player.select_weapon("pistol")
	raid.loaded["pistol"] = 14
	raid.request_fire("pistol", player._cam.global_transform)
	_check(player.health == 58, "Bloodlust 5: a kill heals 8, got %d" % player.health)

	prof.attrs = {"study": 5}
	raid.xp = 0
	for i in 9:
		raid.add_xp(1)
	_check(raid.xp == 11, "Quick study 5: 9 orbs give 11 xp, got %d" % raid.xp)

	prof.attrs = {"quickexit": 5}
	_check(is_equal_approx(raid.hold_seconds_for("A"), raid.hold_seconds * 0.75) and is_equal_approx(raid.hold_seconds_for("B"), raid.hold_seconds * 0.75 * raid.b_hold_seconds / Tuning.EXTRACT_HOLD_SECONDS), "Quick exit 5: 25%% shorter holds")

	prof.attrs = {"lasting": 5}
	var pw := Powerup.new()
	pw.id = "haste"
	main.add_child(pw)
	await _frames(2)
	raid.collect_powerup(pw)
	_check(is_equal_approx(raid.powerups["haste"], 15.0), "Lasting power 5: powerups last 50%% longer, got %s" % raid.powerups["haste"])
	raid.powerups.clear()
	raid._apply_upgrades()

	# Drop rates: the same kills drop more with the attribute. Ammo (the same random numbers each time):
	var stats := {"drop_chance": 0.5, "drop": [1, 1]}
	var counts := []
	for attrs in [{}, {"scavenger": 5}]:
		prof.attrs = attrs
		raid._drop_rng.seed = 5
		var n := 0
		for i in 200:
			if raid._drop_ammo(Vector3(60, 0, 60), stats):
				n += 1
		counts.append(n)
	_check(counts[1] > counts[0] + 25, "Scavenger 5: +50%% ammo drops, got %s" % [counts])
	# Scrap, attachments and powerups:
	var scrap_stats := {"health": 1, "speed": 0, "damage": 0, "scrap_chance": 0.35, "scrap": [1, 1]}
	var results := []
	for attrs in [{}, {"salvage": 5, "prospector": 5, "lucky": 5}]:
		prof.attrs = attrs
		for n in main.get_children():
			if n.is_in_group("powerup") or ("qty" in n and "id" in n) or n.is_in_group("xp"):
				n.free()
		raid._loot_rng.seed = 21
		raid._power_rng.seed = 22
		for i in 1000:
			raid._on_kill(Vector3(70, 0, 70), scrap_stats)
		await _frames(2)
		var scrap := 0
		var atts := 0
		for n in main.get_children():
			if "qty" in n and "id" in n:
				if n.id == "scrap":
					scrap += 1
				elif n.id.begins_with("att_"):
					atts += 1
		results.append({"scrap": scrap, "att": atts, "power": get_nodes_in_group("powerup").size()})
	_check(results[1]["scrap"] > results[0]["scrap"] + 80, "Salvager 5: +50%% scrap, got %s" % [results])
	_check(results[1]["att"] > results[0]["att"] + 5, "Prospector 5: +100%% attachment drops, got %s" % [results])
	_check(results[1]["power"] > results[0]["power"] + 40, "Lucky 5: +40%% powerup drops, got %s" % [results])
	for n in main.get_children():
		if n.is_in_group("powerup") or ("qty" in n and "id" in n) or n.is_in_group("xp"):
			n.free()

	# --- on the player ---
	prof.attrs = {"sprint": 5, "jump": 5, "ghost": 5, "dodge": 5, "laststand": 5, "medic": 5, "speed": 0}
	player.apply_profile(prof)
	_check(is_equal_approx(player.sprint_mult, 1.3) and is_equal_approx(player.jump_mult, 1.3) and is_equal_approx(player.stealth, 0.3), "sprint, jump and stealth carry into the raid")
	_check(is_equal_approx(player.dodge, 0.1) and is_equal_approx(player.last_stand, 0.3) and is_equal_approx(player.heal_mult, 1.5), "dodge, last stand and medic carry into the raid")
	player.dodge = 0.0
	player.health = player.max_health
	player.take_damage(10)
	_check(player.health == player.max_health - 10, "above 30%% health a hit is a hit, got %d" % player.health)
	player.health = 20
	player.take_damage(10)
	_check(player.health == 13, "Last stand 5: below 30%% health hits do 30%% less (10 -> 7), got %d" % player.health)
	player.dodge = 1.0
	player.take_damage(10)
	_check(player.health == 13, "a dodged hit does nothing")
	player.dodge = 0.0
	player.health = 10
	player.inventory.add("medkit", 1)
	for i in player.inventory.slots.size():
		if player.inventory.slots[i] != null and player.inventory.slots[i]["id"] == "medkit":
			player.use_slot(i)
			break
	_check(player.health == 70, "Field medic 5: a medkit heals 60 instead of 40, got %d" % player.health)

	# Ghost: a heard sprinter fills an enemy's suspicion more slowly.
	var watcher = _grunt(main, FAR + Vector3(0, 0, -30))
	player.sprinting = true
	var fills := []
	for st in [0.0, 0.3]:
		player.stealth = st
		watcher.suspicion = 0.0
		watcher._update_suspicion(player, 5.0, 0.1)
		fills.append(watcher.suspicion)
	_check(fills[0] > 0.0 and is_equal_approx(fills[1], fills[0] * 0.7), "Ghost 5: 30%% slower to be spotted, got %s" % [fills])
	player.sprinting = false
	watcher.free()

	# Sprint and jump speed in the real movement code (keys pressed through the input system).
	main.queue_free()
	await process_frame
	main = await _raid(0, {"sprint": 5, "jump": 5})
	player = main._player
	player.set_physics_process(true)
	await _frames(30)  # settle on the floor
	Input.parse_input_event(_key(KEY_W, true))
	Input.parse_input_event(_key(KEY_SHIFT, true))
	await _frames(2)
	var run_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.parse_input_event(_key(KEY_W, false))
	Input.parse_input_event(_key(KEY_SHIFT, false))
	await _frames(2)
	_check(is_equal_approx(run_speed, Tuning.PLAYER_SPRINT_SPEED * 1.3), "Sprinter 5: sprinting at 13 m/s, got %s" % run_speed)
	Input.parse_input_event(_key(KEY_SPACE, true))
	var rise := 0.0
	for i in 4:
		await _frames(1)
		rise = maxf(rise, player.velocity.y)
	Input.parse_input_event(_key(KEY_SPACE, false))
	_check(rise > Tuning.PLAYER_JUMP_SPEED * 1.25, "Spring legs 5: jump speed 30%% higher, got %s" % rise)
	player.set_physics_process(false)
	main.queue_free()
	await process_frame

	# A new raid: Quartermaster adds starting ammo.
	main = await _raid(0)
	var plain_ammo: int = main.raid.start_ammo
	main.queue_free()
	await process_frame
	main = await _raid(0, {"quartermaster": 5})
	_check(main.raid.start_ammo == plain_ammo + 30, "Quartermaster 5: +30 starting ammo, got %d vs %d" % [main.raid.start_ammo, plain_ammo])
	main.queue_free()
	await process_frame
	_clean()

func _key(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev
