# Run (NOT headless): Godot --path <project> -s tools/preview_buildings.gd -- <output.png> <scene.tscn> [...]
# Add --crates to put four crates on random CrateSpots (seed it with the Godot `seed()` call for repeatable shots). Add --open for a dollhouse row. Add --cut for a roofless view from above of the first scene. Lays building scenes in a row beside a 1.8 m capsule "player" for scale, seen from the front and above, and saves one PNG.
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 800)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	vp.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 60)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(25, -0.01, 0)
	vp.add_child(floor_mesh)
	var x := 0.0
	seed(7)
	var open := "--open" in args  # roofs and front walls removed: a dollhouse view into a row of buildings
	var cut := "--cut" in args or "--floors" in args  # roofs removed, camera over a single building
	for p in Array(args.slice(1)).filter(func(a): return not a.begins_with("--")):
		var node: Node3D = (load(p) as PackedScene).instantiate()
		node.position = Vector3(x, 0, 0)
		vp.add_child(node)
		if "--crates" in args:  # four random crate spots per building
			var spots := node.get_node("CrateSpots").get_children()
			spots.shuffle()
			for m in spots.slice(0, 4):
				var crate: Node3D = load("res://scripts/crate.gd").new()
				crate.position = m.position + Vector3(0, 0.5, 0)
				node.add_child(crate)
		if open:
			for r in node.get_children().filter(func(c): return c.name.begins_with("Roof") or (c is Node3D and not c is StaticBody3D and absf(c.rotation_degrees.y) < 1.0 and c.name != "Collision" and c.name != "CrateSpots" and not c.name.begins_with("Floor") and not c.name.begins_with("Step"))):
				r.free()
		if cut:
			for r in node.get_children().filter(func(c): return c.name.begins_with("Roof") or ("--floors" in args and c.name.begins_with("Floor"))):
				r.free()
		x += 22.0
	var player := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.height = 1.8
	cap.radius = 0.35
	player.mesh = cap
	player.position = Vector3(-8.0, 0.9, 7.0)
	vp.add_child(player)
	var cam := Camera3D.new()
	cam.position = Vector3(x / 2.0 - 11.0, 20, 52)
	cam.rotation_degrees = Vector3(-24, 0, 0)
	cam.fov = 50
	if open:
		cam.position = Vector3(x / 2.0 - 11.0, 30, 52)
		cam.rotation_degrees = Vector3(-33, 0, 0)
	if cut:
		cam.position = Vector3(0, 24, 12)
		cam.rotation_degrees = Vector3(-62, 0, 0)
	vp.add_child(cam)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(args[0])
	quit()
