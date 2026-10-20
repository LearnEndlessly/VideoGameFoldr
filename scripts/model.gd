extends RefCounted
# Optional art: loads the 3D model (a .glb/.gltf or .tscn under assets/) that a data table row
# names in its "model" field. Returns null when no path is set or the file is missing, so the
# caller keeps its built-in placeholder shape and the game never breaks over missing art.

static var _warned := {}

static func load_scene(path: String) -> Node3D:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("model not found: %s (using the placeholder shape)" % path)
		return null
	var res = load(path)
	if res is PackedScene:
		var inst = res.instantiate()
		if inst is Node3D:
			return inst
		inst.free()
	return null

# Loads a model and stretches it to fill `size` (metres, x y z), centred on the node's origin, tinted by `tint`
# (multiplied into its colours; white leaves it alone). Kenney's pieces are plain shapes, so stretching them keeps
# their look. Returns null when the model is missing, so the caller keeps its placeholder box.
static func load_fitted(path: String, size: Vector3, tint := Color.WHITE) -> Node3D:
	var m := load_scene(path)
	if m == null:
		return null
	var box := _bounds(m, Transform3D.IDENTITY)
	if box.size.x <= 0.0001 or box.size.y <= 0.0001 or box.size.z <= 0.0001:
		m.free()
		return null
	var holder := Node3D.new()
	holder.add_child(m)
	m.scale = Vector3(size.x / box.size.x, size.y / box.size.y, size.z / box.size.z)
	m.position = -(box.position + box.size / 2.0) * m.scale
	tint_all(holder, tint)
	return holder

# The combined bounding box of every mesh under `node`, in the space of `xform`.
static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var has := false
	var t := xform
	if node is Node3D:
		t = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = t * (node as MeshInstance3D).get_aabb()
		has = true
	for c in node.get_children():
		var sub := _bounds(c, t)
		if sub.size != Vector3.ZERO:
			box = sub if not has else box.merge(sub)
			has = true
	return box

# Multiplies `color` into every material under `node` (each mesh gets its own copy, so the shared model is untouched).
static func tint_all(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count() if mi.mesh != null else 0:
			var base = mi.get_active_material(i)
			if base is StandardMaterial3D:
				var copy: StandardMaterial3D = base.duplicate()
				copy.albedo_color = color
				mi.set_surface_override_material(i, copy)
	for c in node.get_children():
		tint_all(c, color)
