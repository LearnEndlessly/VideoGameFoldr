# Run: Godot --headless --path <project> -s tests/scout_volley.gd   (exit code 1 on failure)
# The scout sees far and fires volleys of small parallel shots in a shape; a flyer's loot falls to the ground; the skill tree's
# bullets-per-shot, XP gain and XP pull range; the tree screen's wording of a node.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const SkillNodes = preload("res://data/skill_nodes.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const XpOrb = preload("res://scripts/xp_orb.gd")
const PATH := "user://test_scout_volley.json"
const FAR := Vector3(5000, 50, 5000)

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame
	await _run()
	for f in failures:
		printerr(f)
	print("scout_volley: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _raid() -> Node:
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 4
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c or "group_id" in c:
			c.free()
	await process_frame
	main._player.set_physics_process(false)
	return main

func _scout(main: Node, pos: Vector3) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["scout"].duplicate(true)
	stats["type"] = "scout"
	stats["modifier"] = ""
	e.stats = stats
	e.position = pos
	e.home = pos
	main.add_child(e)
	e.set_physics_process(false)
	return e

func _floor(main: Node) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	body.add_child(col)
	body.position = FAR + Vector3(0, -0.5, 0)
	main.add_child(body)

func _run() -> void:
	var main = await _raid()
	var player = main._player
	_floor(main)
	await _frames(2)
	player.global_position = FAR
	player.sprinting = false

	# Sight: a scout notices a standing player well beyond a grunt's 18 m.
	var s = _scout(main, FAR + Vector3(0, 0, -28))
	await _frames(2)
	_check(s._sees(player, 28.0), "a scout 7 m up sees a player 28 m away in the open")
	_check(not s._sees(player, 40.0), "but not past its sight range")
	_check(float(Enemies.TYPES["grunt"].get("sight", Tuning.ENEMY_SIGHT_RANGE)) < 20.0, "a grunt keeps the short sight range")

	# The volley: shapes fly parallel and in turn.
	s.set_alert(true)
	s._shot_cd = 0.0
	s._try_shoot(0.0, player, 28.0)
	var shots := get_nodes_in_group("projectile")
	_check(shots.size() == 5, "the first volley is the five-shot row, got %d" % shots.size())
	var ys := shots.map(func(p): return snappedf(p.position.y, 0.01))
	var dir0: Vector3 = shots[0].direction
	_check(shots.all(func(p): return p.direction.is_equal_approx(dir0)), "every shot in a volley flies parallel")
	_check(shots.all(func(p): return p.radius < 0.2 and p.damage > 0 and p.damage < 15), "the volley shots are small and light (%s dmg)" % [shots.map(func(p): return p.damage)])
	_check(ys.max() - ys.min() < 0.7, "a row spreads sideways, not up")
	for p in shots:
		p.queue_free()
	await _frames(2)
	s._shot_cd = 0.0
	s._try_shoot(0.0, player, 28.0)
	shots = get_nodes_in_group("projectile")
	_check(shots.size() == 4, "the next volley is the four-shot column, got %d" % shots.size())
	ys = shots.map(func(p): return p.position.y)
	_check(ys.max() - ys.min() > 1.5, "a column spreads upward")
	for p in shots:
		p.queue_free()
	await _frames(2)
	_check(float(Enemies.TYPES["scout"]["ranged"]["cooldown"]) > 0.0 and Enemies.SCOUT_PATTERNS.size() >= 3, "scouts cycle through several patterns")

	# A killed flyer's drops land on the ground (y 0), not up where the scout died.
	s.queue_free()
	await _frames(2)
	player.global_position = FAR
	player.rotation = Vector3.ZERO
	player._head.rotation = Vector3.ZERO
	var target = _scout(main, FAR + Vector3(0, -5.8, -10))  # hovers 7 m above this: 1.2 m over the player's feet
	await _frames(3)
	var raid = main.raid
	raid.loaded["pistol"] = 14
	raid._fire_cooldown = 0.0
	var died_at: Vector3 = target.global_position
	raid.request_fire("pistol", player._cam.global_transform)
	await _frames(3)
	_check(not is_instance_valid(target) or target.is_queued_for_deletion(), "the shot killed the scout")
	var orbs := get_nodes_in_group("xp")
	_check(orbs.size() > 0, "the kill left XP orbs")
	_check(orbs.all(func(o): return absf(o.global_position.y) < 0.01 and died_at.y > 40.0), "the orbs fell to the ground (y %s) from where the scout died (y %s)" % [orbs.map(func(o): return o.global_position.y), died_at.y])

	# Skill tree: bullets per shot, XP gain, XP pull radius.
	var prof = main.profile
	prof.stat_override = {"pellets": 1.0}
	raid.loaded["pistol"] = 14
	raid._fire_cooldown = 0.0
	var traced := [0]
	raid.bullet_traced.connect(func(_w, _e, _n, _k): traced[0] += 1)
	raid.request_fire("pistol", player._cam.global_transform)
	_check(traced[0] == 2, "+1 bullet makes the pistol fire two (traced %d)" % traced[0])
	prof.stat_override = {"xp_gain": 0.5}
	raid.xp = 0
	raid.add_xp(6)
	_check(raid.xp == 9, "+50%% XP turns 6 into 9 (got %d)" % raid.xp)
	prof.stat_override = {"xp_range": 3.0}
	_check(is_equal_approx(raid.xp_magnet_radius(), Tuning.XP_MAGNET_RADIUS + 3.0), "XP pull range adds to the base radius")
	var orb := XpOrb.new()
	orb.position = FAR + Vector3(Tuning.XP_MAGNET_RADIUS + 1.5, 0, 0)
	main.add_child(orb)
	var before := orb.global_position
	await _frames(3)
	_check(orb.global_position.distance_to(before) > 0.1, "an orb just past the base radius is pulled in with the bonus range")
	prof.stat_override = {}

	# The tree's new nodes exist and read well.
	for id in ["BN3", "OX1", "OX2", "ON3"]:
		_check(SkillNodes.NODES.any(func(r): return r["id"] == id), "node %s exists" % id)
	_check(SkillTreeView.effect_text({"stat": "pellets", "mod": "flat", "value": 1.0}) == "+1 bullets per shot", "pellets reads '%s'" % SkillTreeView.effect_text({"stat": "pellets", "mod": "flat", "value": 1.0}))
	_check(SkillTreeView.effect_text({"stat": "xp_gain", "mod": "increased", "value": 0.3}) == "+30% XP gained", "xp reads '%s'" % SkillTreeView.effect_text({"stat": "xp_gain", "mod": "increased", "value": 0.3}))
	_check(SkillTreeView.effect_text({"stat": "xp_range", "mod": "flat", "value": 1.5}) == "+1.5 m XP pull range", "range reads '%s'" % SkillTreeView.effect_text({"stat": "xp_range", "mod": "flat", "value": 1.5}))
	_check(SkillTreeView.effect_text({"stat": "damage", "mod": "increased", "value": -0.3}) == "-30% damage", "negative reads '%s'" % SkillTreeView.effect_text({"stat": "damage", "mod": "increased", "value": -0.3}))
	main.queue_free()
