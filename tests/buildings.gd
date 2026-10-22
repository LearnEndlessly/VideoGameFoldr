# Run: Godot --headless --path <project> -s tests/buildings.gd   (exit code 1 on failure)
# Buildings (data/buildings.gd, scenes/buildings/): a body can walk in through the door and up every flight to the top floor,
# and on a real map the buildings keep clear of each other and every building crate stands on one of its floors.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Buildings = preload("res://data/buildings.gd")

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + msg)

func _init() -> void:
	Main.show_start = false
	await process_frame
	await _walk("depot", [Vector3(0, 0, 6), Vector3(0, 0, 1), Vector3(-5.0, 0, -1.0), Vector3(-5.0, 0, -2.7), Vector3(-0.5, 0, -2.7)], 2.5)
	await _walk("tower", [Vector3(-2, 0, 6), Vector3(-2, 0, 1), Vector3(-3.0, 0, -1.0), Vector3(-3.0, 0, -2.7), Vector3(1.6, 0, -2.7), Vector3(3.0, 0, 0.5), Vector3(3.0, 0, 2.7), Vector3(-1.6, 0, 2.7)], 5.0)
	for s in 12:
		var main = load("res://main.tscn").instantiate()
		main.seed_override = s
		root.add_child(main)
		for i in main.buildings.size():
			for j in range(i + 1, main.buildings.size()):
				_check(not main.buildings[i]["rect"].intersects(main.buildings[j]["rect"]), "seed %d: buildings %d and %d overlap" % [s, i, j])
		for c in main.get_children().filter(func(n): return "zone_id" in n and n.zone_id == Buildings.CRATE_ZONE_ID):
			var inside: bool = main.buildings.any(func(b): return b["rect"].has_point(Vector2(c.position.x, c.position.z)))
			var level: float = (c.position.y - 0.5) / 2.5
			_check(inside and absf(level - roundf(level)) < 0.01, "seed %d: a building crate at %s is not on a floor inside a building" % [s, c.position])
		main.queue_free()
		await process_frame
	print("buildings: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

# Drops a capsule outside the building's door and steers it through the waypoints (x, z); it must end `top` m up.
func _walk(id: String, waypoints: Array, top: float) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	gs.shape = box
	ground.add_child(gs)
	ground.position.y = -0.5
	holder.add_child(ground)
	holder.add_child((load(Buildings.DATA[id]["scene"]) as PackedScene).instantiate())
	var body := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5  # the player's own default capsule (scripts/player.gd)
	cap.height = 2.0
	cs.shape = cap
	cs.position.y = 1.0
	body.add_child(cs)
	body.position = waypoints[0] + Vector3(0, 0.05, 0)
	holder.add_child(body)
	var step := 1
	var frames := 0
	while step < waypoints.size() and frames < 1800:
		frames += 1
		var to: Vector3 = waypoints[step] - body.position
		to.y = 0
		if to.length() < 0.25:
			step += 1
			continue
		body.velocity.x = to.normalized().x * 4.0
		body.velocity.z = to.normalized().z * 4.0
		body.velocity.y -= 20.0 / 60.0
		body.move_and_slide()
		await physics_frame
	_check(step >= waypoints.size(), "%s: stuck before waypoint %d at %s" % [id, step, body.position])
	_check(absf(body.position.y - top) < 0.35, "%s: ended %.2f m up, expected %.1f" % [id, body.position.y, top])
	holder.queue_free()
	await process_frame
