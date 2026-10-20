# Run: Godot --headless --path <project> -s tests/map_layout.gd   (exit code 1 on failure)
# Generates 40 maps and checks: sizes vary (long and square maps both occur), the three loot
# areas exist, crates only appear inside them, and the map is walkable: from the player's
# start, a body about 0.9 m wide can reach the extract zone, every loot area, every shelter
# and every enemy group, and nearly all open floor.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Tuning = preload("res://data/tuning.gd")
const LootZones = preload("res://data/loot_zones.gd")
const SEEDS := 40
const CELL := 0.4
const AGENT_RADIUS := 0.45  # the player capsule is 0.5; the shelter door is 1.8 wide
const MIN_REACHED := 0.98   # share of open floor that must be connected to the start

var failures: PackedStringArray = []

func _init() -> void:
	Main.show_start = false
	var wide := 0
	var tall := 0
	var covers: Array = []
	for s in SEEDS:
		var main = load("res://main.tscn").instantiate()
		main.seed_override = s
		root.add_child(main)
		await process_frame  # _ready only runs once the tree is processing
		var w: float = main.half_w * 2.0
		var d: float = main.half_d * 2.0
		if w < Tuning.MAP_MIN_SIDE - 1.0 or d < Tuning.MAP_MIN_SIDE - 1.0 or w > Tuning.MAP_MAX_SIDE + 1.0 or d > Tuning.MAP_MAX_SIDE + 1.0:
			_fail(s, "map size %.0fx%.0f is outside the allowed range" % [w, d])
		if w > d * 1.3:
			wide += 1
		if d > w * 1.3:
			tall += 1
		covers.append(main._cover.size())
		_check_structures(s, main)
		_check_walkable(s, main)
		main.queue_free()
		await process_frame
	if wide < 5 or tall < 5:
		failures.append("map shapes lack variety: %d wide and %d tall out of %d" % [wide, tall, SEEDS])
	covers.sort()
	if covers[-1] - covers[0] < 12:
		failures.append("cover count lacks variety: %d to %d pieces over %d maps" % [covers[0], covers[-1], SEEDS])
	for f in failures:
		printerr(f)
	print("map_layout: %d failure(s) over %d maps (%d wide, %d tall)" % [failures.size(), SEEDS, wide, tall])
	quit(1 if failures.size() > 0 else 0)

# Every loot building has a second doorway straight across from the first.
func _check_two_doors(s: int, st: Dictionary) -> void:
	if not st["door2"].is_equal_approx(st["center"] * 2.0 - st["door"]):
		_fail(s, "%s's second door is not opposite the first" % st["id"])

func _fail(map_seed: int, message: String) -> void:
	if failures.size() < 25:
		failures.append("seed %d: %s" % [map_seed, message])

func _check_structures(s: int, main) -> void:
	var ids: Array = main.structures.map(func(x): return x["id"])
	for st in main.structures:
		_check_two_doors(s, st)
	ids.sort()
	var expected: Array = LootZones.DATA.keys()
	expected.sort()
	if ids != expected:
		_fail(s, "loot areas were %s, expected %s" % [ids, expected])
	var per_area := {}
	for c in main.get_children().filter(func(n): return n.is_in_group("lootable")):
		var at := Vector2(c.position.x, c.position.z)
		var found := false
		for st in main.structures:
			if st["rect"].has_point(at):
				found = true
				per_area[st["id"]] = per_area.get(st["id"], 0) + 1
		if not found:
			_fail(s, "a crate at %s is outside every loot area" % [c.position])
	for st in main.structures:
		if per_area.get(st["id"], 0) < 2:
			_fail(s, "%s has only %d crate(s)" % [st["id"], per_area.get(st["id"], 0)])
	if main.shelters.size() != main.SHELTER_COUNT:
		_fail(s, "expected %d shelters, found %d" % [main.SHELTER_COUNT, main.shelters.size()])

func _check_walkable(s: int, main) -> void:
	var hw: float = main.half_w
	var hd: float = main.half_d
	var cols := int((hw * 2.0 + 4.0) / CELL)
	var rows := int((hd * 2.0 + 4.0) / CELL)
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	var obstacles: Array = main.solids.duplicate()
	for c in main.get_children().filter(func(n): return n.is_in_group("lootable")):
		obstacles.append(Rect2(Vector2(c.position.x - 0.5, c.position.z - 0.5), Vector2(1, 1)))
	for r in obstacles:
		var g: Rect2 = r.grow(AGENT_RADIUS)
		var c0 := maxi(int((g.position.x + hw + 2.0) / CELL), 0)
		var c1 := mini(int((g.end.x + hw + 2.0) / CELL) + 1, cols - 1)
		var r0 := maxi(int((g.position.y + hd + 2.0) / CELL), 0)
		var r1 := mini(int((g.end.y + hd + 2.0) / CELL) + 1, rows - 1)
		for cy in range(r0, r1 + 1):
			for cx in range(c0, c1 + 1):
				if g.has_point(_cell_centre(cx, cy, hw, hd)):
					blocked[cy * cols + cx] = 1

	var start := _cell_of(Vector2.ZERO, hw, hd, cols)
	if blocked[start] == 1:
		_fail(s, "the player's start is blocked")
		return
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	var queue: Array = [start]
	seen[start] = 1
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var cx := cur % cols
		var cy := cur / cols
		for step in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + step[0]
			var ny: int = cy + step[1]
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var ni := ny * cols + nx
			if seen[ni] == 0 and blocked[ni] == 0:
				seen[ni] = 1
				queue.append(ni)

	var targets := {}
	for z in main.extract_zones:
		targets["extract zone %s" % z["id"]] = z["pos"]
	for st in main.structures:
		var inward: Vector3 = (st["center"] - st["door"]).normalized()  # a crate can sit at the centre, so aim just inside the door
		targets["%s door" % st["id"]] = st["door"]
		targets["%s just inside" % st["id"]] = st["door"] + inward * 1.0
		targets["%s second door" % st["id"]] = st["door2"]
		targets["%s just inside the second door" % st["id"]] = st["door2"] - inward * 1.0
	for i in main.shelters.size():
		targets["shelter %d" % i] = main.shelters[i]
	var homes := {}
	for e in main.get_children().filter(func(n): return "stats" in n):
		homes[e.home] = true
	var gi := 0
	for h in homes:
		targets["enemy group %d" % gi] = h
		gi += 1
	for name in targets:
		var t: Vector3 = targets[name]
		var idx := _cell_of(Vector2(t.x, t.z), hw, hd, cols)
		if blocked[idx] == 1:
			_fail(s, "%s at (%.1f, %.1f) is inside a solid" % [name, t.x, t.z])
		elif seen[idx] == 0:
			_fail(s, "%s at (%.1f, %.1f) cannot be reached from the start" % [name, t.x, t.z])

	var open := 0
	var reached := 0
	for cy in rows:
		for cx in cols:
			var c := _cell_centre(cx, cy, hw, hd)
			if absf(c.x) > hw or absf(c.y) > hd:
				continue
			var i := cy * cols + cx
			if blocked[i] == 0:
				open += 1
				if seen[i] == 1:
					reached += 1
	if float(reached) / open < MIN_REACHED:
		_fail(s, "only %.0f%% of open floor is connected to the start" % (100.0 * reached / open))

func _cell_centre(cx: int, cy: int, hw: float, hd: float) -> Vector2:
	return Vector2((cx + 0.5) * CELL - hw - 2.0, (cy + 0.5) * CELL - hd - 2.0)

func _cell_of(p: Vector2, hw: float, hd: float, cols: int) -> int:
	return int((p.y + hd + 2.0) / CELL) * cols + int((p.x + hw + 2.0) / CELL)
