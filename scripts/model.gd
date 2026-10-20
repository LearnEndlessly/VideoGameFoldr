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
