# Run (NOT headless, it needs to render):
#   Godot --path <project> -s tools/capture.gd -- <output folder> [seed]
# Plays a scripted tour of one map and saves PNG screenshots: spawn, a top-down overview,
# the guarded armory from outside and inside, the guard group, a shelter, the backpack,
# a shot with the aim line, the extract countdown and the threat warning.
extends SceneTree

const Main = preload("res://scripts/main.gd")

const MAX_FILES := 24  # screenshots kept in the output folder; older ones are deleted

var out := ""

# Deletes the oldest PNGs in `dir` until at most `keep` remain.
func _prune(dir: String, keep: int) -> void:
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			files.append([FileAccess.get_modified_time(dir + "/" + f), f])
	files.sort()
	for i in maxi(files.size() - keep, 0):
		DirAccess.remove_absolute(dir + "/" + files[i][1])

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, label])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# Stand `dist` metres from `target`, in direction `dir` (horizontal), looking at it.
func _stand(player, target: Vector3, dir: Vector3, dist: float) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	player.global_position = Vector3(target.x, 0.05, target.z) + d * dist
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(d.x, d.z)  # the camera looks along -Z, so face away from `d`, toward the target
	player._head.rotation.x = -0.1

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var map_seed := int(args[1]) if args.size() > 1 else 3
	DirAccess.make_dir_recursive_absolute(out)
	_prune(out, 0)  # a run replaces the previous tour, so start from an empty folder
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = map_seed
	root.add_child(main)
	await process_frame
	await process_frame
	var player = main._player
	var enemies: Array = main.get_children().filter(func(c): return "stats" in c)
	for e in enemies:
		e.set_physics_process(false)  # hold still so the poses stay readable
	print("map %.0f x %.0f, %d enemies, seed %d" % [main.half_w * 2, main.half_d * 2, enemies.size(), map_seed])

	await _frames(5)
	await _shot("01_spawn")

	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = Vector3(0, 100, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.make_current()
	await _frames(3)
	await _shot("02_overview")
	player._cam.make_current()
	cam.queue_free()

	for st in main.structures:
		if st["id"] != "armory":
			continue
		var out_dir: Vector3 = (st["door"] - st["center"]).normalized()
		_stand(player, st["door"], out_dir, 10.0)
		await _frames(4)
		await _shot("03_armory_outside")
		_stand(player, st["center"], out_dir, 3.5)  # inside, looking back at the door
		player.rotation.y += PI
		await _frames(4)
		await _shot("04_armory_inside")
	var guard: Array = enemies.filter(func(e): return e.group_id == 0)
	if not guard.is_empty():
		var home: Vector3 = guard[0].home
		var side := Vector3(1, 0, 0) if absf(home.x) < 20.0 else Vector3(-sign(home.x), 0, 0)
		_stand(player, home, side, 12.0)
		await _frames(4)
		await _shot("05_guard_group")
	if not main.shelters.is_empty():
		_stand(player, main.shelters[0], Vector3(0.3, 0, 1), 9.0)
		await _frames(4)
		await _shot("06_shelter_from_9m")
		_stand(player, main.shelters[0], Vector3(0.3, 0, 1), 4.5)
		await _frames(4)
		await _shot("07_shelter_from_4m")

	# Backpack open with a few items.
	player.inventory.add("scrap", 12)
	player.inventory.add("medkit", 2)
	player.inventory_open = true
	player.inventory_toggled.emit(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(4)
	await _shot("08_backpack")
	player.inventory_open = false
	player.inventory_toggled.emit(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# A shot at the nearest enemy: aim line, health bar, ammo readout.
	var target = enemies[0]
	for e in enemies:
		if e.global_position.length() < target.global_position.length():
			target = e
	_stand(player, target.global_position, Vector3(0, 0, 1), 9.0)
	player.global_position = Vector3(target.global_position.x, 0.05, target.global_position.z + 9.0)
	player.rotation.y = 0.0  # looking down -Z toward the enemy
	await _frames(4)
	main.raid.request_fire(player.weapon_id, player._cam.global_transform)
	await _frames(3)
	await _shot("09_aim_and_healthbar")

	# Extract countdown, then the threat warning.
	player.global_position = main.extract_pos + Vector3(0, 0.05, 0)
	await _frames(100)
	await _shot("10_extracting")
	main.raid._start_threat()
	await _frames(6)
	await _shot("11_threat_banner")
	_prune(out, MAX_FILES)
	print("screenshots saved to ", out)
	quit()
