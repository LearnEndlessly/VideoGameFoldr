# Run: Godot --headless --path <project> -s tests/enemy_overhaul.gd   (exit code 1 on failure)
# Hit zones (armor in front, weak points on the head and back, painted in two colours), the flying scout that raises the
# alarm, the super brute's slow projectiles, narrow maps, and watch towers with climbable ladders.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const Scenery = preload("res://data/scenery.gd")
const Projectile = preload("res://scripts/projectile.gd")
const PATH := "user://test_overhaul.json"
const FAR := Vector3(5000, 50, 5000)

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("enemy_overhaul: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _clean() -> void:
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)

func _raid(map_seed := 4) -> Node:
	_clean()
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c or "group_id" in c:
			c.free()
	await process_frame
	main._player.set_physics_process(false)
	return main

func _enemy(main: Node, type: String, pos: Vector3, group := 0) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES[type].duplicate(true)
	stats["type"] = type
	stats["modifier"] = ""
	e.stats = stats
	e.position = pos
	e.group_id = group
	e.home = pos
	main.add_child(e)
	e.set_physics_process(false)
	return e

func _floor(main: Node) -> void:  # something to stand on in the empty corner
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	col.shape = box
	body.add_child(col)
	body.position = FAR + Vector3(0, -0.5, 0)
	main.add_child(body)

func _key(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev

# A pistol shot from the player at FAR along -Z at a grunt `dist` ahead, turned `turn` radians and `lift` metres up;
# returns the damage dealt.
func _shot(main: Node, dist: float, turn: float, lift: float) -> int:
	var player = main._player
	player.global_position = FAR
	player.rotation = Vector3.ZERO
	player._head.rotation = Vector3.ZERO
	var e = _enemy(main, "grunt", FAR + Vector3(0, lift, -dist))
	e.rotation.y = turn
	e.health = 100000
	await _frames(3)
	player.select_weapon("pistol")
	main.raid.loaded["pistol"] = 14
	main.raid._fire_cooldown = 0.0
	main.raid.request_fire("pistol", player._cam.global_transform)
	var dealt: int = 100000 - e.health
	e.free()
	return dealt

func _run() -> void:
	# --- hit zones ---
	var main = await _raid()
	var raid = main.raid
	var player = main._player
	player.inventory.add("ammo", 40)
	var mid := 0.8  # a grunt standing 0.8 m higher is hit at the chest by a shot from head height
	_check(await _shot(main, 10.0, PI, mid) == 15, "a shot at the chest from the front hits the armor: 25 x 0.6 = 15")
	_check(await _shot(main, 10.0, 0.0, mid) == 38, "a shot at the chest from behind hits the weak back: 25 x 1.5 = 38")
	_check(await _shot(main, 10.0, PI / 2.0, mid) == 25, "from the side it is a plain hit")
	_check(await _shot(main, 10.0, PI, 0.0) == 50, "a shot at the head is a head shot from any side: 25 x 2 = 50")
	var seen: Array = []
	raid.zone_hit.connect(func(z: String): seen.append(z))
	await _shot(main, 10.0, PI, mid)
	await _shot(main, 10.0, 0.0, mid)
	await _shot(main, 10.0, 0.0, 0.0)
	_check(seen == ["front", "back", "head"], "each hit reports its zone, got %s" % [seen])
	await process_frame
	_check(main._zone_label != null, "the HUD has a hit label")
	main._on_zone_hit("head")
	_check(main._zone_label.text == "HEADSHOT" and main._zone_time > 0.0, "a head shot says so under the crosshair")
	main._on_zone_hit("front")
	_check(main._zone_label.text == "ARMORED", "a shot on the armor says so")

	var g = _enemy(main, "grunt", FAR + Vector3(0, 0, -30))
	var front_dir := Vector3(0, 0, -5)  # in front of a grunt that faces -Z
	_check(g.zone_at(g.global_position + Vector3(0, 0.8, 0), g.global_position + front_dir) == "front", "standing ahead of it is the front")
	_check(g.zone_at(g.global_position + Vector3(0, 0.8, 0), g.global_position - front_dir) == "back", "standing behind it is the back")
	_check(g.zone_at(g.global_position + Vector3(0, 1.8, 0), g.global_position + front_dir) == "head", "the top of the body is the head from the front")
	_check(is_equal_approx(g.zone_mult("front"), 0.6) and is_equal_approx(g.zone_mult("head"), 2.0) and g.zone_mult("") == 1.0, "zone multipliers come from the data")
	var sb = _enemy(main, "super_brute", FAR + Vector3(0, 0, -40))
	_check(is_equal_approx(sb.zone_mult("front"), 0.4) and is_equal_approx(sb.zone_mult("back"), 1.5), "a type can change a zone")
	var sc = _enemy(main, "scout", FAR + Vector3(0, 0, -50))
	_check(sc.zone_at(sc.global_position, FAR) == "" and sc.zone_mult("") == 1.0, "a scout has no zones")
	Enemies.zones_enabled = false
	_check(g.zone_at(g.global_position + Vector3(0, 1.8, 0), FAR) == "", "zones can be switched off for tests")
	Enemies.zones_enabled = true

	# The zones are painted in two clearly different colours.
	var armor: MeshInstance3D = g.get_node("ArmorFront")
	var weak_back: MeshInstance3D = g.get_node("WeakBack")
	var weak_head: MeshInstance3D = g.get_node("WeakHead")
	var strong: Color = armor.material_override.albedo_color
	_check(strong == Enemies.STRONG_COLOR and weak_back.material_override.albedo_color == Enemies.WEAK_COLOR and weak_head.material_override.albedo_color == Enemies.WEAK_COLOR, "armor and weak points use the data colours")
	var cd := Vector3(strong.r - Enemies.WEAK_COLOR.r, strong.g - Enemies.WEAK_COLOR.g, strong.b - Enemies.WEAK_COLOR.b).length()
	_check(cd > 0.5, "the strong and weak colours are far apart (%s)" % cd)
	_check(weak_back.material_override.emission_enabled and not armor.material_override.emission_enabled, "weak points glow, armor does not")
	_check(not sc.has_node("ArmorFront") and not sc.has_node("WeakHead"), "the scout has nothing painted on it")
	g.free()

	# --- the scout ---
	_floor(main)
	await _frames(2)
	var s = _enemy(main, "scout", FAR + Vector3(0, 0, -20), 7)
	_check(s.stats["flying"] and s.collision_mask == 0, "a scout flies over walls and cover")
	_check(absf(s.global_position.y - (FAR.y + float(Enemies.TYPES["scout"]["hover"]))) < 0.01, "it starts high above the ground, at y %s" % s.global_position.y)
	_check(Enemies.TYPES["scout"]["health"] < Enemies.TYPES["grunt"]["health"] and Enemies.TYPES["scout"]["size"] < 0.6 and Enemies.TYPES["scout"]["damage"] <= 10, "small, weak and light-hitting")
	var grunt_peer = _enemy(main, "grunt", FAR + Vector3(0, 0, -20), 8)
	player.global_position = FAR
	player.sprinting = true  # heard: no cone needed
	grunt_peer.detect_seconds = 5.0
	s.detect_seconds = 5.0
	grunt_peer.suspicion = 0.0
	s.suspicion = 0.0
	grunt_peer._update_suspicion(player, 5.0, 0.1)
	s._update_suspicion(player, 5.0, 0.1)
	_check(is_equal_approx(grunt_peer._detect() / s._detect(), 4.0) and s.suspicion > grunt_peer.suspicion, "a scout needs a quarter of the time to notice the player (%s vs %s s)" % [s._detect(), grunt_peer._detect()])
	player.sprinting = false
	# The alarm: a grunt near the player turns alert, a far one heads for the spot.
	var near_g = _enemy(main, "grunt", FAR + Vector3(5, 0, -10), 9)
	var far_g = _enemy(main, "grunt", FAR + Vector3(0, 0, -50), 10)
	var out_g = _enemy(main, "grunt", FAR + Vector3(0, 0, -200), 11)
	s.raise_alarm(FAR)
	_check(near_g.alert and not far_g.alert and far_g.converging and far_g.converge_target == FAR, "the alarm alerts the groups near the player and sends the rest to the spot")
	_check(not out_g.converging and not out_g.alert, "an enemy out of the scout's reach hears nothing")
	for e in [near_g, far_g, out_g, grunt_peer]:
		e.free()
	# An alerted scout keeps doing it, by itself, and stays up.
	var pending = _enemy(main, "grunt", FAR + Vector3(0, 0, -25), 12)
	s.set_alert(true)
	s.set_physics_process(true)
	await _frames(20)
	_check(pending.alert, "an alerted scout raises the alarm on its own")
	_check(absf(s.global_position.y - (FAR.y + 7.0)) < 1.0, "and stays in the air, at y %s" % s.global_position.y)
	_check(not s.is_queued_for_deletion(), "the scout survives its own flight")
	pending.free()
	s.free()

	# --- the super brute ---
	player.global_position = FAR
	var brute = _enemy(main, "super_brute", FAR + Vector3(0, 0, -15), 20)
	brute.set_alert(true)
	brute.health = 1000
	await _frames(2)
	var base_hp: int = player.health
	brute._shot_cd = 0.0
	brute._try_shoot(0.0, player, 15.0)
	var shots := get_nodes_in_group("projectile")
	_check(shots.size() == 1, "an alerted super brute in range and in the open fires")
	if shots.size() == 1:
		var shot = shots[0]
		var expect: Vector3 = (FAR + Vector3(0, 1.2, 0) - shot.position).normalized()
		_check(shot.direction.is_equal_approx(expect) and is_equal_approx(shot.speed, 7.0), "it flies at the player at 7 m/s")
		_check(shot.speed < 15.0, "slow enough to dodge")
		var dir0: Vector3 = shot.direction
		player.global_position = FAR + Vector3(6, 0, 0)  # the player steps aside
		await _frames(30)
		_check(shot.direction == dir0, "it does not follow the player")
		_check(player.health == base_hp, "so a player who steps aside is not hit")
		await _frames(400)
		_check(not is_instance_valid(shot) or shot.is_queued_for_deletion(), "a shot that misses is gone after a while")
	_check(get_nodes_in_group("projectile").all(func(p): return p.is_queued_for_deletion()), "no shots left over")
	brute._try_shoot(0.0, player, 15.0)
	_check(get_nodes_in_group("projectile").filter(func(p): return not p.is_queued_for_deletion()).is_empty(), "it reloads between shots")
	brute._shot_cd = 0.0
	brute._try_shoot(0.0, player, 40.0)
	brute._try_shoot(0.0, player, 2.0)
	_check(get_nodes_in_group("projectile").filter(func(p): return not p.is_queued_for_deletion()).is_empty(), "no shots too far away or point-blank")
	# Standing still, the shot lands.
	player.global_position = FAR
	brute.global_position = FAR + Vector3(0, 0, -12)
	brute._shot_cd = 0.0
	brute._try_shoot(0.0, player, 12.0)
	await _frames(150)
	var dmg: int = int(round(float(brute.stats["damage"]) * float(Enemies.TYPES["super_brute"]["ranged"]["damage_mult"])))
	_check(player.health == base_hp - dmg, "a shot that hits does %d damage, health %d of %d" % [dmg, player.health, base_hp])
	# A wall stops it.
	var wall := StaticBody3D.new()
	var wcol := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(10, 6, 1)
	wcol.shape = wbox
	wall.add_child(wcol)
	wall.position = FAR + Vector3(0, 3, -6)
	main.add_child(wall)
	player.health = base_hp
	var blocked := Projectile.new()
	blocked.direction = Vector3(0, 0, 1)
	blocked.position = FAR + Vector3(0, 1.2, -12)
	main.add_child(blocked)
	await _frames(60)
	_check(not is_instance_valid(blocked) or blocked.is_queued_for_deletion(), "a wall stops a shot")
	await _frames(100)
	_check(player.health == base_hp, "and the player behind it is untouched")
	wall.free()
	brute.free()
	main.queue_free()
	await process_frame

	# --- a player up a tower cannot be reached ---
	main = await _raid()
	player = main._player
	_floor(main)
	await _frames(2)
	var hp0: int = player.health
	for height in [0.0, 5.0]:
		player.global_position = FAR + Vector3(0, height, 0)
		player.health = hp0
		var melee = _enemy(main, "grunt", FAR + Vector3(0, 0.1, -1.0), 30)
		melee.set_alert(true)
		melee.set_physics_process(true)
		await _frames(100)
		if height == 0.0:
			_check(player.health < hp0, "on the ground the grunt reaches the player")
		else:
			_check(player.health == hp0, "5 m up, out of its reach")
		melee.free()
	main.queue_free()
	await process_frame

	# --- map types ---
	var narrow_seeds: Array = []
	var open_seeds := 0
	var probe = load("res://scripts/main.gd").new()
	for sd in 60:
		var data: Dictionary = probe.preview(sd)
		if data["type"] == "narrow":
			narrow_seeds.append(sd)
			_check(data["d"] >= 96.0 and data["w"] <= 36.0, "narrow map %d is a long thin lane, %sx%s" % [sd, data["w"], data["d"]])
		else:
			open_seeds += 1
			_check(data["w"] >= 44.0 or data["d"] >= 44.0, "open maps keep their shape")
	probe.free()
	_check(narrow_seeds.size() >= 4 and narrow_seeds.size() <= 30 and open_seeds > narrow_seeds.size(), "narrow is one map type in four: %d of 60" % narrow_seeds.size())
	var weights: Dictionary = Tuning.MAP_TYPES
	_check(weights["narrow"]["weight"] < weights["open"]["weight"], "narrow maps are the rarer type")
	for sd in narrow_seeds.slice(0, 3):
		main = await _raid(sd)
		_check(main.map_type == "narrow" and main.half_d * 2.0 >= 96.0, "seed %d builds a narrow map" % sd)
		_check(main._player.global_position.z > main.half_d - 8.0 and main._player.global_position.is_equal_approx(main._start), "the player starts at one end, at z %s" % main._player.global_position.z)
		_check(main.extract_errors.is_empty(), "narrow map %d placed its extract zones: %s" % [sd, main.extract_errors])
		_check(main.extract_pos.z < 0.0, "the safe extract is in the far half of the lane, away from the start end (z %s)" % main.extract_pos.z)
		var gates: Array = main.blocks.filter(func(b): return b[0].y == 3.5 and b[0].z == 1.0)
		_check(gates.size() >= 2, "walls cross the lane, got %d" % gates.size())
		var grid: Dictionary = main._walk_grid()
		_check(main._walk_dist(grid, main.extract_pos) > main.half_d * 1.4, "the way to the extract is long (%d m)" % main._walk_dist(grid, main.extract_pos))
		main.queue_free()
		await process_frame
	main = await _raid(1)
	if main.map_type == "open":
		_check(main._start == Vector3.ZERO and main.blocks.filter(func(b): return b[0].y == 3.5 and b[0].z == 1.0).is_empty(), "open maps start in the middle with no gates")
	main.queue_free()
	await process_frame

	# --- towers and ladders ---
	var with_towers := 0
	var tower_seed := -1
	for sd in 8:
		main = await _raid(sd)
		if not main.towers.is_empty():
			with_towers += 1
			if tower_seed < 0:
				tower_seed = sd
		main.queue_free()
		await process_frame
	_check(with_towers >= 6, "most maps have a watch tower, %d of 8" % with_towers)
	if tower_seed >= 0:
		main = await _raid(tower_seed)
		player = main._player
		var t: Dictionary = main.towers[0]
		var ladder = t["ladder"]
		_check(ladder.is_in_group("ladder") and is_equal_approx(ladder.top_y, Scenery.TOWER_HEIGHT + 0.1), "the tower has a ladder up to its deck")
		var deck_hits: Array = main.blocks.filter(func(b): return b[0].is_equal_approx(Vector3(Scenery.TOWER_SIZE, 0.3, Scenery.TOWER_SIZE)) and b[1].is_equal_approx(t["pos"] + Vector3(0, Scenery.TOWER_HEIGHT - 0.15, 0)))
		_check(deck_hits.size() == 1, "a deck stands %s m up" % Scenery.TOWER_HEIGHT)
		var out: Vector3 = -ladder.facing
		var stand: Vector3 = ladder.global_position + out * 0.6
		player.global_position = Vector3(stand.x, 0.1, stand.z)
		player.rotation = Vector3(0, atan2(-ladder.facing.x, -ladder.facing.z), 0)
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
		await _frames(30)
		_check(player.ladder == ladder, "standing at the ladder's foot puts the player on it")
		var y0: float = player.global_position.y
		Input.parse_input_event(_key(KEY_W, true))
		await _frames(40)
		var mid_y: float = player.global_position.y
		_check(mid_y > y0 + 1.5, "holding W at the ladder climbs it (y %s)" % mid_y)
		Input.parse_input_event(_key(KEY_W, false))
		await _frames(30)
		_check(absf(player.global_position.y - mid_y) < 0.3, "letting go holds the player on the ladder, not falling (%s -> %s)" % [mid_y, player.global_position.y])
		Input.parse_input_event(_key(KEY_W, true))
		await _frames(150)
		Input.parse_input_event(_key(KEY_W, false))
		var on_deck: bool = absf(player.global_position.y - Scenery.TOWER_HEIGHT) < 0.4 and absf(player.global_position.x - t["pos"].x) < 1.8 and absf(player.global_position.z - t["pos"].z) < 1.8
		_check(on_deck, "the climb ends standing on the deck, at %s (deck at %s)" % [player.global_position, t["pos"]])
		# From the deck there is a view over the cover.
		_check(player.global_position.y + 1.6 > 6.0, "the eyes are above the tallest low cover")
		# Not looking at the ladder: walking past does not climb.
		player.global_position = Vector3(stand.x, 0.1, stand.z)
		player.rotation = Vector3(0, atan2(ladder.facing.x, ladder.facing.z), 0)
		player.velocity = Vector3.ZERO
		await _frames(20)
		Input.parse_input_event(_key(KEY_W, true))
		await _frames(30)
		Input.parse_input_event(_key(KEY_W, false))
		_check(player.global_position.y < 1.0, "walking away from the ladder does not climb it (y %s)" % player.global_position.y)
		player.set_physics_process(false)
		main.queue_free()
		await process_frame
	_clean()
