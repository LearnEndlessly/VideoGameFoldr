# Run: Godot --headless --path <project> -s tests/enemy_base.gd   (exit code 1 on failure)
# Enemy awareness and the enemy base: the view cone and suspicion meter (seen over
# ENEMY_DETECT_SECONDS, never from behind, decays out of sight), group size, and the spawner
# (spawns on a timer up to a cap, can be shot down by the player, then stops for good).
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Inventory = preload("res://scripts/inventory.gd")

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await _run()
	for f in failures:
		printerr(f)
	print("enemy_base: %d failure(s)" % failures.size())
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

# A grunt high above the map (nothing to fall on or hit), its own physics off so the test drives it.
func _enemy_at(main: Node, pos: Vector3, yaw: float) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.group_id = 9
	e.position = pos
	main.add_child(e)
	e.set_physics_process(false)
	e.rotation.y = yaw
	return e

func _run() -> void:
	Main.show_start = false

	# Detection meter. The player stands at the origin (y 50); an enemy 12 m away at -Z facing +Z (yaw PI) looks at them.
	var main = await _new_raid(2, false)
	var player = main._player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 50, 0)
	var seer = _enemy_at(main, Vector3(0, 50, -12), PI)
	await _frames(2)
	for i in 4:
		seer._update_suspicion(player, 12.0, 1.0)
	_check(not seer.alert, "seen for 4 s of a 5 s meter must not alert yet")
	_check(absf(seer.suspicion - 0.8) < 0.01, "after 4 s suspicion was %.2f, expected 0.8" % seer.suspicion)
	seer._update_suspicion(player, 12.0, 1.0)
	_check(seer.alert, "seen for the full %.0f s must alert" % Tuning.ENEMY_DETECT_SECONDS)

	# Facing away: the same 12 m, but the enemy looks the other way.
	var blind = _enemy_at(main, Vector3(0, 50, -12), 0.0)
	for i in 20:
		blind._update_suspicion(player, 12.0, 1.0)
	_check(not blind.alert and blind.suspicion == 0.0, "an enemy facing away must never see the player")

	# Right behind the enemy but inside the near-sense circle.
	var close = _enemy_at(main, Vector3(0, 50, -2), 0.0)
	for i in 6:
		close._update_suspicion(player, 2.0, 1.0)
	_check(close.alert, "inside the near-sense circle the enemy notices even from behind")

	# Decay and shelter.
	var drain = _enemy_at(main, Vector3(0, 50, -12), PI)
	drain._update_suspicion(player, 12.0, 2.0)
	_check(drain.suspicion > 0.3, "suspicion should have filled")
	drain._update_suspicion(player, INF, Tuning.ENEMY_DETECT_DECAY_SECONDS)  # player out of sight (sheltered)
	_check(drain.suspicion == 0.0 and not drain.alert, "suspicion should drain to 0 when the player is out of sight")

	# Walls cut the view cone short; the same cast that blocks sight shapes the drawn wedge.
	var look = _enemy_at(main, Vector3(0, 50, -12), PI)  # faces +Z, toward the player
	_check(is_equal_approx(look._ray_reach(Vector3.FORWARD), Tuning.ENEMY_SIGHT_RANGE), "an open cone should reach the full sight range")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.global_position = Vector3(0, 51.5, -6)
	await _frames(2)
	_check(absf(look._ray_reach(Vector3.FORWARD) - 5.75) < 0.1, "a wall 6 m ahead should cut the cone to about 5.75 m, got %.2f" % look._ray_reach(Vector3.FORWARD))
	_check(look._ray_reach(Vector3.FORWARD.rotated(Vector3.UP, 1.2)) > 10.0, "rays that miss the wall should stay long")

	# A suspicious enemy turns toward where it last saw the player, and creeps there while far away.
	var watcher = _enemy_at(main, Vector3(30, 50, -12), 0.0)  # faces -Z, the player is behind it
	watcher.suspicion = 0.5
	watcher.last_seen = player.global_position
	for i in 40:
		watcher._investigate(0.1)
	var want: Vector3 = (player.global_position - watcher.global_position) * Vector3(1, 0, 1)
	var facing: Vector3 = -watcher.global_transform.basis.z
	_check(facing.dot(want.normalized()) > 0.98, "a suspicious enemy should face the last-seen spot, dot %.2f" % facing.dot(want.normalized()))
	_check(watcher.velocity.length() > 0.1, "a suspicious enemy far from the spot should creep toward it")
	var near = _enemy_at(main, Vector3(0, 50, -3), 0.0)
	near.suspicion = 0.5
	near.last_seen = player.global_position
	near._investigate(0.1)
	_check(near.velocity.length() == 0.0, "within ENEMY_INVESTIGATE_STOP the enemy stands and watches")
	main.queue_free()
	await process_frame

	# Group size: 3 groups of ENEMY_GROUP_SIZE_MIN..MAX at the start.
	main = await _new_raid(5, true)
	var count := main.get_children().filter(func(c): return "stats" in c).size()
	_check(count >= 3 * Tuning.ENEMY_GROUP_SIZE_MIN and count <= 3 * Tuning.ENEMY_GROUP_SIZE_MAX, "%d enemies at the start" % count)

	# Spawner: one enemy per interval, capped, in its own group.
	_check(main._spawners.size() == Tuning.SPAWNER_COUNT, "the map should have %d enemy bases" % Tuning.SPAWNER_COUNT)
	var sp = main._spawners[0]
	_check(sp.group_id == Tuning.ENEMY_GROUP_COUNT and main._spawners[1].group_id == Tuning.ENEMY_GROUP_COUNT + 1, "each base gets its own group")
	_check(not sp._label.visible, "a base is unmarked until it is shot")
	for i in 8:
		sp._physics_process(Tuning.SPAWNER_INTERVAL)
	var pack := get_nodes_in_group("pack_%d" % sp.group_id)
	_check(pack.size() == Tuning.SPAWNER_MAX_ALIVE, "base group was %d, expected the cap of %d" % [pack.size(), Tuning.SPAWNER_MAX_ALIVE])
	_check(pack.all(func(e): return e.home == sp.global_position), "spawned enemies should defend the base")

	# Destroying it: no kill is counted, the spawning stops, defenders are woken.
	_check(not sp.take_damage(Tuning.SPAWNER_HEALTH - 1), "a non-lethal hit must not destroy the base")
	_check(pack.all(func(e): return e.alert), "shooting the base should alert its defenders")
	_check(sp.take_damage(1), "the lethal hit should destroy the base")
	await process_frame
	_check(not is_instance_valid(sp), "a destroyed base should be gone")
	_check(main._spawners.filter(is_instance_valid).size() == Tuning.SPAWNER_COUNT - 1, "the other bases should be unaffected")
	main.queue_free()
	await process_frame

	# A real shot at the base through the raid: it dies, and that is not counted as a kill.
	main = await _new_raid(5, false)
	player = main._player
	sp = main._spawners[0]
	player.set_physics_process(false)
	# Stand 5 m from the base on whichever side has a clear line to it, aiming down at its middle (it is
	# low: eye height is 1.6 m).
	for dir in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		player.global_position = sp.global_position + dir * 5.0
		player.rotation.y = atan2(dir.x, dir.z)
		player._head.rotation.x = -atan2(0.85, 5.0)
		await _frames(2)
		if player._cast_dir(-player._cam.global_transform.basis.z, 12.0).get("collider") == sp:
			break
	var aim: Transform3D = player._cam.global_transform
	var guard := 0
	while is_instance_valid(sp) and guard < Tuning.SPAWNER_HEALTH:
		main.raid.loaded[player.weapon_id] = 30
		player.inventory.add("ammo", 1)
		main.raid.request_fire(player.weapon_id, aim)
		await _frames(20)
		guard += 1
	_check(not is_instance_valid(sp), "shots from the player should be able to destroy the base")
	_check(player.kills == 0, "destroying the base must not count as a kill")
	main.queue_free()
	await process_frame

	# Ammo drops: a roll that succeeds leaves a pickup with the enemy's drop amount, walking into it
	# fills the backpack, and what does not fit stays on the ground.
	main = await _new_raid(5, false)
	var raid = main.raid
	player = main._player
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0, 0)
	var grunt: Dictionary = Enemies.TYPES["grunt"].duplicate()
	var dropped := 0
	var kinds := 400
	for i in kinds:
		if raid._drop_ammo(Vector3(30, 0, 30), grunt):
			dropped += 1
	var rate := float(dropped) / kinds
	_check(absf(rate - float(grunt["drop_chance"])) < 0.1, "drop rate was %.2f, expected about %.2f" % [rate, grunt["drop_chance"]])
	await process_frame
	var pickups := main.get_children().filter(func(n): return "qty" in n and n.id == "ammo")
	_check(pickups.size() == dropped, "every successful drop should leave a pickup, got %d of %d" % [pickups.size(), dropped])
	_check(pickups.all(func(p): return p.qty >= grunt["drop"][0] and p.qty <= grunt["drop"][1]), "drop amounts should stay in the enemy's range")
	for p in pickups:
		p.queue_free()
	await process_frame

	var loot := Pickup.new()
	loot.id = "ammo"
	loot.qty = 40
	loot.position = Vector3(1, 0, 0)
	main.add_child(loot)
	player.inventory.clear()
	player.inventory.add("medkit", 3 * (Inventory.SLOTS - 1))  # one free slot: a stack of 30 ammo fits
	_check(raid.request_pickup(loot), "walking into a drop should pick it up")
	_check(player.inventory.count("ammo") == 30 and loot.qty == 10, "only 30 of 40 fit, the rest stays: backpack %d, ground %d" % [player.inventory.count("ammo"), loot.qty])
	_check(not raid.request_pickup(loot), "a full backpack must leave the pickup alone")
	player.inventory.clear()
	_check(raid.request_pickup(loot), "after making room the rest can be picked up")
	await process_frame
	_check(not is_instance_valid(loot), "an emptied pickup should disappear")
	player.global_position = Vector3(40, 0, 40)
	var far := Pickup.new()
	far.position = Vector3(1, 0, 0)
	main.add_child(far)
	_check(not raid.request_pickup(far), "a pickup out of reach must be refused")
	main.queue_free()
	await process_frame
