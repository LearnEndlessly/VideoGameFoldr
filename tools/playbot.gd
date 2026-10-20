# A simple bot that plays one raid on the real game code and prints a RESULT line (JSON).
#   Godot --headless --fixed-fps 60 --path <project> -s tools/playbot.gd -- <seed> [max game seconds]
# --fixed-fps 60 makes simulated time run as fast as the machine allows instead of real time.
#
# The bot: visits the loot zones nearest-first (through each door), opens every crate, shoots the
# nearest alert enemy it can see (scattergun up close, pistol otherwise), uses a medkit below half
# health, runs to a shelter once if badly hurt, heads straight for extraction when the threat
# clock starts, and holds the extract zone. It never sprints and has no pathfinding beyond the
# door waypoints and a sidestep when stuck, so it plays a cautious, slightly clumsy raid.
# It drives movement itself (the player's own physics process is off), so it measures game
# rules and balance, not input handling.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Tuning = preload("res://data/tuning.gd")

var main
var player
var raid
var done := false
var result := {}
var first_alert := -1.0
var crates_opened := 0
var used_shelter := false

var _waypoints: Array = []  # {"pos": Vector3, "crate": node (optional), "extract": true (optional)}
var _stuck_pos := Vector3.ZERO
var _stuck_timer := 0.0
var _detour_left := 0.0
var _detour_dir := Vector3.ZERO
var _shelter_wait := 0.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 1
	var max_seconds := float(args[1]) if args.size() > 1 else 240.0
	Main.show_start = false
	main = load("res://main.tscn").instantiate()
	main.profile_path = "user://playbot_profile.json"  # never the real save: a bot raid would bank loot and points into it
	main.seed_override = map_seed
	root.add_child(main)
	await process_frame
	player = main._player
	raid = main.raid
	player.set_physics_process(false)  # the bot moves the player itself
	raid.ended.connect(func(r): result = r; done = true)
	raid.picked_up.connect(func(_id, _qty): crates_opened += 1)
	_plan()
	while not done and raid.elapsed < max_seconds:
		await physics_frame
		_step(1.0 / 60.0)
	var outcome: String = result.get("outcome", "timeout")
	var loot: Dictionary = result.get("items", raid._loot())
	print("RESULT " + JSON.stringify({
		"seed": map_seed, "outcome": outcome, "t": snappedf(raid.elapsed, 0.1), "hp": player.health,
		"kills": player.kills, "shots": raid.shots, "ammo_spent": raid.ammo_spent, "loot": loot,
		"pickups": crates_opened, "first_alert": snappedf(first_alert, 0.1), "threat": raid._threat_reached,
		"map": [main.half_w * 2.0, main.half_d * 2.0],
		# where the bot ended up: a timeout with a big distance and waypoints left means it got stuck
		"to_extract": snappedf(Vector2(player.global_position.x - main.extract_pos.x, player.global_position.z - main.extract_pos.z).length(), 0.1),
		"waypoints_left": _waypoints.size(), "safe": player.safe}))
	quit()

# Waypoints: for each loot zone (nearest first) the door, its crates, and back out; then the extract zone.
func _plan() -> void:
	var zones: Array = main.structures.duplicate()
	zones.sort_custom(func(a, b): return a["center"].length() < b["center"].length())
	for st in zones:
		var out: Vector3 = (st["door"] - st["center"]).normalized()
		_waypoints.append({"pos": st["door"] + out * 3.0})
		_waypoints.append({"pos": st["door"] - out * 1.5})
		for c in main.get_children():
			if c.is_in_group("lootable") and c.zone_id == st["id"]:
				_waypoints.append({"pos": c.global_position, "crate": c})
		_waypoints.append({"pos": st["door"] - out * 1.5})
		_waypoints.append({"pos": st["door"] + out * 3.0})
	_waypoints.append({"pos": main.extract_pos, "extract": true})

func _step(delta: float) -> void:
	var enemies: Array = get_nodes_in_group("enemy").filter(func(e): return not e.is_queued_for_deletion())
	if first_alert < 0.0 and enemies.any(func(e): return e.alert):
		first_alert = raid.elapsed
	if raid.threat_active and not (not _waypoints.is_empty() and _waypoints[0].has("extract")):
		_waypoints = [{"pos": main.extract_pos, "extract": true}]  # the clock started: just leave
	if player.health <= 50:
		_use_medkit()

	# Badly hurt: hide in the nearest shelter once, and wait there a few seconds.
	if player.health < 35 and not used_shelter and not main.shelters.is_empty():
		if player.safe:
			_shelter_wait += delta
			if _shelter_wait > 6.0:
				used_shelter = true
			return
		_move_toward(_nearest(main.shelters), Tuning.PLAYER_WALK_SPEED, delta)
		return

	var target = _visible_alert_enemy(enemies)
	if target != null:
		_fight(target)
		return
	_follow_waypoints(delta)

func _nearest(points: Array) -> Vector3:
	var best: Vector3 = points[0]
	for p in points:
		if player.global_position.distance_to(p) < player.global_position.distance_to(best):
			best = p
	return best

# The nearest alert enemy within 22 m that has a clear line to the player, or null.
func _visible_alert_enemy(enemies: Array):
	var best = null
	var best_d := 22.0
	for e in enemies:
		if not e.alert:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best_d and e._has_line_of_sight(player):
			best = e
			best_d = d
	return best

func _fight(target) -> void:
	var d: float = target.global_position.distance_to(player.global_position)
	var want := "scattergun" if (d < 9.0 and player.inventory.count("ammo") >= 2) else "pistol"
	if player.weapon_id != want:
		player.select_weapon(want)
	var aim: Vector3 = target.global_position + Vector3(0, 1.1 * float(target.stats["size"]), 0) - player._cam.global_position
	player.rotation.y = atan2(-aim.x, -aim.z)  # the camera looks along the body's -Z
	player._head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	if raid.loaded_rounds(want) < player.weapon["ammo_per_shot"]:
		raid.request_reload()
	raid.request_fire(player.weapon_id, player._cam.global_transform)

func _use_medkit() -> void:
	for i in player.inventory.slots.size():
		var s = player.inventory.slots[i]
		if s != null and s["id"] == "medkit":
			player.use_slot(i)
			return

func _follow_waypoints(delta: float) -> void:
	if _waypoints.is_empty():
		return
	var wp: Dictionary = _waypoints[0]
	var flat := Vector3(wp["pos"].x - player.global_position.x, 0, wp["pos"].z - player.global_position.z)
	if wp.has("crate"):
		if flat.length() < 2.5:
			raid.request_loot(wp["crate"])
			_waypoints.pop_front()
			return
	elif wp.has("extract"):
		if flat.length() < 1.0:
			return  # stand in the zone; the raid does the rest
	elif flat.length() < 1.5:
		_waypoints.pop_front()
		return
	_move_toward(wp["pos"], Tuning.PLAYER_WALK_SPEED, delta)

func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := Vector3(target.x - player.global_position.x, 0, target.z - player.global_position.z)
	if to.length() < 0.2:
		return
	var dir := to.normalized()
	if _detour_left > 0.0:
		dir = (dir * 0.3 + _detour_dir).normalized()
		_detour_left -= delta
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.velocity = Vector3(dir.x * speed, -2.0, dir.z * speed)
	player.move_and_slide()
	_stuck_timer += delta
	if _stuck_timer >= 1.0:  # barely moved in a second: sidestep for a moment
		if player.global_position.distance_to(_stuck_pos) < 0.6:
			var side := Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
			_detour_dir = side
			_detour_left = 1.5
		_stuck_pos = player.global_position
		_stuck_timer = 0.0
