# Run (headless): Godot --headless --path <project> -s tools/build_buildings.gd
# Assembles the Kenney Modular Buildings kit into walkable building scenes in scenes/buildings/, scaled to the game.
# Kit cell is 1 x 0.625 x 1 m. Scaled uniformly by 4 it is a 4 m wide, 2.5 m tall storey, and the kit door (0.25 x 0.5 m) is 1 x 2 m.
# Walls are the kit's wall pieces squashed to WALL_T deep (front faces out), floors and roofs are its flat roof tile.
# One straight stair flight per storey, with a LAND m landing before its first step (open in the floor above too, for head room): even flights climb +x along the back wall from
# the leftmost cell, odd ones climb -x along the front wall from the rightmost cell (so a tower's flights never stack), each cutting a hole in the floor above.
extends SceneTree

const KIT := "res://assets/buildings/kenney_modular_buildings/"
const CELL := 4.0
const STOREY := 2.5
const WALL_T := 0.5
const SLAB := 0.425  # roof-flat-center is 0.10625 m tall, x4
const LANE := 1.6  # stair width
const RUN := 0.35  # 10 steps of RUN x RISE = 3.5 m long, 2.5 m up
const RISE := 0.25
const LAND := 1.0  # flat floor in front of a flight, so a body can walk onto its first step from the open end
const DOOR_W := 1.2  # walkable gap in the door cell (the kit door is 1 m)

# name: [cells wide (x), cells deep (z), storeys, door column from the left, window piece]
const BUILDINGS := {
	"house_small": [3, 2, 1, 1, "building-window"],
	"depot": [3, 2, 2, 1, "building-windows"],
	"tower": [2, 2, 3, 0, "building-window-wide"],
	"row_shop": [4, 2, 2, 1, "building-window-large"],
}

var bld: Node3D
var body: StaticBody3D

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/buildings")
	for id in BUILDINGS:
		var s: Array = BUILDINGS[id]
		var scene := PackedScene.new()
		scene.pack(_build(id, s[0], s[1], s[2], s[3], s[4]))
		ResourceSaver.save(scene, "res://scenes/buildings/%s.tscn" % id)
		print("saved ", id)
		bld.free()
	quit()

func _own(n: Node, parent: Node) -> void:
	parent.add_child(n)
	n.owner = bld

func _piece(piece: String, nm: String, pos: Vector3, rot: float, scl: Vector3) -> void:
	var n: Node3D = (load(KIT + piece + ".glb") as PackedScene).instantiate()
	n.name = nm
	n.position = pos
	n.rotation_degrees.y = rot
	n.scale = scl
	_own(n, bld)

# A collision box with its centre at pos.
func _box(pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.position = pos
	c.rotation = rot
	_own(c, body)

# A flat slab tile over the x/z rectangle r (position, size), its top at height top.
func _slab(nm: String, r: Rect2, top: float) -> void:
	var c := r.get_center()
	_piece("roof-flat-center", nm, Vector3(c.x, top - SLAB, c.y), 0.0, Vector3(r.size.x / 1.0, CELL, r.size.y / 1.0))
	_box(Vector3(c.x, top - SLAB / 2.0, c.y), Vector3(r.size.x, SLAB, r.size.y))

# The cell rectangle `cell` as slabs around `hole` (a hole that touches or lies inside the cell).
func _slab_with_hole(nm: String, cell: Rect2, hole: Rect2, top: float) -> void:
	hole = hole.intersection(cell)  # a flight can run on into the next cell
	var strips := [
		Rect2(cell.position.x, cell.position.y, hole.position.x - cell.position.x, cell.size.y),
		Rect2(hole.end.x, cell.position.y, cell.end.x - hole.end.x, cell.size.y),
		Rect2(hole.position.x, cell.position.y, hole.size.x, hole.position.y - cell.position.y),
		Rect2(hole.position.x, hole.end.y, hole.size.x, cell.end.y - hole.end.y),
	]
	for i in strips.size():
		var r: Rect2 = strips[i]
		if r.size.x > 0.01 and r.size.y > 0.01:
			_slab("%s_%d" % [nm, i], r, top)

func _build(id: String, w: int, d: int, storeys: int, door_col: int, window: String) -> Node3D:
	bld = Node3D.new()
	bld.name = id
	body = StaticBody3D.new()
	body.name = "Collision"
	_own(body, bld)
	var left := -w * CELL / 2.0
	var right := w * CELL / 2.0
	var back := -d * CELL / 2.0
	var front := d * CELL / 2.0
	var half := CELL / 2.0 - WALL_T / 2.0  # wall centre, from the cell centre
	var wall_scale := Vector3(CELL, CELL, WALL_T / 1.0)
	var holes := {}  # storey -> hole rect in the floor at the top of that storey
	for k in range(storeys - 1):
		var length := 10 * RUN
		holes[k + 1] = (Rect2(left + WALL_T, back + WALL_T, LAND + length, LANE) if k % 2 == 0 else Rect2(right - WALL_T - LAND - length, front - WALL_T - LANE, LAND + length, LANE))
	for level in storeys:
		var y := level * STOREY
		for ix in w:
			for iz in d:
				var c := Vector3(left + (ix + 0.5) * CELL, y + STOREY / 2.0, back + (iz + 0.5) * CELL)
				# one wall per outer edge: [edge normal rotation, direction vector, runs along x?]
				for e in [[0.0, Vector3(0, 0, 1), iz == d - 1], [90.0, Vector3(1, 0, 0), ix == w - 1], [180.0, Vector3(0, 0, -1), iz == 0], [270.0, Vector3(-1, 0, 0), ix == 0]]:
					if not e[2]:
						continue
					var dir: Vector3 = e[1]
					var piece := window
					var is_door: bool = level == 0 and e[0] == 0.0 and ix == door_col
					if is_door:
						piece = "building-door"
					elif (ix == 0 or ix == w - 1) and (iz == 0 or iz == d - 1):  # corner cells: plain wall, no window
						piece = "building-block"
					var p := c + dir * half
					_piece(piece, "%s_%d_%d_%d" % [piece, level, ix, iz], Vector3(p.x, y, p.z), e[0], wall_scale)
					var along := Vector3(absf(dir.z), 0, absf(dir.x))
					var size := Vector3(CELL * along.x + WALL_T * absf(dir.x), STOREY, CELL * along.z + WALL_T * absf(dir.z))
					if is_door:
						var jamb := (CELL - DOOR_W) / 2.0
						_box(p + Vector3(-(DOOR_W + jamb) / 2.0, 0, 0), Vector3(jamb, STOREY, WALL_T))
						_box(p + Vector3((DOOR_W + jamb) / 2.0, 0, 0), Vector3(jamb, STOREY, WALL_T))
						_box(Vector3(p.x, y + 2.25, p.z), Vector3(DOOR_W, 0.5, WALL_T))
						_piece("door-brown", "Door", Vector3(p.x - DOOR_W / 2.0 + 0.1, y, p.z - WALL_T / 2.0 - 0.5), 90.0, Vector3(CELL, CELL, CELL))
					else:
						_box(p, size)
		# the floor at the top of this level: slab tiles, with the stair hole where this level's flight arrives
		if level >= 1:
			for ix in w:
				for iz in d:
					var cell := Rect2(left + ix * CELL, back + iz * CELL, CELL, CELL)
					var hole: Rect2 = holes.get(level, Rect2())
					if hole.size.x > 0.0 and cell.intersects(hole):
						_slab_with_hole("Floor%d_%d_%d" % [level, ix, iz], cell, hole, y)
					else:
						_slab("Floor%d_%d_%d" % [level, ix, iz], cell, y)
	for ix in w:
		for iz in d:
			_slab("Roof_%d_%d" % [ix, iz], Rect2(left + ix * CELL, back + iz * CELL, CELL, CELL), storeys * STOREY + SLAB)
	for k in range(storeys - 1):
		_stairs(k, holes[k + 1], k % 2 == 0)
	_crate_spots(w, d, storeys, left + (door_col + 0.5) * CELL, holes)
	return bld

# Candidate floor spots for loot crates (Marker3D at the crate's feet) against the inside walls, 2 m apart, kept clear of the
# door, the stair flights and the floor holes. The game picks a random few; see tools/preview_buildings.gd.
func _crate_spots(w: int, d: int, storeys: int, door_x: float, holes: Dictionary) -> void:
	var spots := Node3D.new()
	spots.name = "CrateSpots"
	_own(spots, bld)
	var x0 := -w * CELL / 2.0 + 1.0
	var x1 := w * CELL / 2.0 - 1.0
	var z0 := -d * CELL / 2.0 + 1.0
	var z1 := d * CELL / 2.0 - 1.0
	for level in storeys:
		var avoid: Array[Rect2] = []
		for lvl in [level, level + 1]:
			if holes.has(lvl):
				avoid.append((holes[lvl] as Rect2).grow(1.3))
		if level == 0:
			avoid.append(Rect2(door_x - 1.5, z1 - 2.0, 3.0, 3.0))
		for x in range(int(roundf((x1 - x0) / 2.0)) + 1):
			for z in range(int(roundf((z1 - z0) / 2.0)) + 1):
				var p := Vector2(x0 + x * 2.0, z0 + z * 2.0)
				if not (is_equal_approx(p.x, x0) or is_equal_approx(p.x, x1) or is_equal_approx(p.y, z0) or is_equal_approx(p.y, z1)):
					continue
				if avoid.any(func(r: Rect2): return r.has_point(p)):
					continue
				var m := Marker3D.new()
				m.name = "L%d_%d_%d" % [level, x, z]
				m.position = Vector3(p.x, level * STOREY, p.y)
				_own(m, spots)

# Ten solid steps rising from level k to k + 1 inside `lane`, plus one ramp collider through their middles.
func _stairs(k: int, lane: Rect2, plus_x: bool) -> void:
	var base := k * STOREY
	var dx := 1.0 if plus_x else -1.0
	var x0 := lane.position.x + LAND if plus_x else lane.end.x - LAND  # the lane rect includes the landing
	var zc := lane.get_center().y
	for i in 10:
		var h := (i + 1) * RISE
		_piece("roof-flat-center", "Step%d_%d" % [k, i], Vector3(x0 + dx * (i + 0.5) * RUN, base, zc), 0.0, Vector3(RUN, h / 0.10625, LANE))
	var length := Vector3(10 * RUN, STOREY, 0).length()
	var angle := atan2(STOREY, 10 * RUN)
	_box(Vector3(x0 + dx * 5 * RUN, base + STOREY / 2.0 + 0.0, zc), Vector3(length, 0.2, LANE), Vector3(0, 0, angle if plus_x else -angle))
