# Run (NOT headless, it needs to render):
#   Godot --path <project> -s tools/capture_base.gd -- <output folder>
# Saves screenshots of the base: the room from the spawn point, then each station's panel, using a
# scratch profile with some stash, points and a weapon upgrade (the real profile is not touched).
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
const ScreenUI = preload("res://scripts/screen_ui.gd")
const UpgradePick = preload("res://scripts/upgrade_pick.gd")
const PATH := "user://capture_base_profile.json"

var out := ""

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, label])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	Telemetry.enabled = false
	var p := Profile.new(PATH)
	p.add_items({"ammo": 64, "medkit": 5})
	p.points = 2
	p.stats = {"runs": 6, "extracts": 4, "deaths": 2, "kills": 37, "shots": 212, "hits": 96, "deepest": 3}
	p.save()
	Main.show_start = true
	var main = load("res://main.tscn").instantiate()
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	await _frames(5)
	var hub = main.get_children().filter(func(c): return "open_station" in c)[0]
	hub.player.position = Vector3(0, 0.1, 4.0)
	hub.player._head.rotation.x = -0.5
	hub.set_seed(5)
	await _shot("b1_base")
	for id in ["map", "stash", "armory", "character", "raid"]:
		var station = get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == id)[0]
		hub._on_station_used(station)
		await _frames(3)
		await _shot("b_%s" % id)
		hub._close()
	hub.player.position = Vector3(3.5, 0.1, -2.0)
	hub.player._head.rotation.x = 0.25
	await _frames(3)
	await _shot("b_board")
	for outcome in ["extracted", "dead"]:
		var layer := CanvasLayer.new()
		root.add_child(layer)
		var screen := ScreenUI.new()
		layer.add_child(screen)
		screen.show_result({"outcome": outcome, "items": {"ammo": 14, "medkit": 3}, "saved": true, "kills": 7, "points": 3,
			"reward_mult": 1.35, "shots": 41, "hits": 19, "duration": 148.0, "depth": 0}, 1, func(): pass, func(): pass)
		await _frames(3)
		await _shot("b_result_%s" % outcome)
		layer.queue_free()
	var pick_layer := CanvasLayer.new()
	root.add_child(pick_layer)
	var pick := UpgradePick.new()
	pick_layer.add_child(pick)
	pick.show_choices(["damage", "vitality", "hands"], {"damage": 1}, func(_id): pass)
	await _frames(3)
	await _shot("b_level_up")
	DirAccess.remove_absolute(PATH)
	quit()
