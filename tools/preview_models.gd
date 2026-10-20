# Run (NOT headless, it needs to render):
#   Godot --path <project> -s tools/preview_models.gd -- <output.png> <res://model.glb> [<res://model2.glb> ...]
# Draws each model from the side in a row, left to right, with its file name above, and saves one PNG. For choosing
# art from assets/ without opening every file.
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var paths: Array = args.slice(1)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 420)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	vp.add_child(sun)
	var x := 0.0
	for p in paths:
		var scene: PackedScene = load(p)
		var node: Node3D = scene.instantiate()
		node.rotation_degrees.y = -90.0  # the weapon's long side (z) runs left to right
		node.position = Vector3(x, 0, 0)
		vp.add_child(node)
		var label := Label3D.new()
		label.text = str(p).get_file().replace(".glb", "")
		label.font_size = 48
		label.pixel_size = 0.004
		label.position = Vector3(x, 0.45, 0)
		vp.add_child(label)
		x += 1.9
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.9 * maxf(paths.size(), 1.0) * 0.26 + 0.2
	cam.position = Vector3(x / 2.0 - 0.95, 0, 5)
	vp.add_child(cam)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	quit()
