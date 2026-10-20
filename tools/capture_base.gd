# Run (NOT headless, it needs to render):
#   Godot --path <project> -s tools/capture_base.gd -- <output folder>
# Saves screenshots of the base: the room from the spawn point, then each station's panel, using a
# scratch profile with some stash, points and a weapon upgrade (the real profile is not touched).
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Telemetry = preload("res://scripts/telemetry.gd")
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
	p.weapons = {"pistol": 1}
	p.stats = {"extracts": 3, "kills": 17}
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
	DirAccess.remove_absolute(PATH)
	quit()
