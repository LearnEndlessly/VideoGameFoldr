extends Node3D
# One bullet's flight, drawn: a glowing bullet travels from the muzzle to where the shot landed, dragging a trail
# behind it that fades after it arrives. On arrival it throws sparks; a shot that hit a wall also ricochets,
# a short bright streak off the surface. How all of it looks comes from the weapon's "tracer" row in
# data/weapons.gd, so the pistol, scattergun and sniper rifle each look different. Purely visual: the raid has
# already decided what the shot hit. Frees itself when done.

var from := Vector3.ZERO
var to := Vector3.ZERO
var normal := Vector3.ZERO  # surface normal at the end, ZERO for a miss
var kind := "none"  # "enemy", "wall" or "none"
var cfg: Dictionary = {}

var _dir := Vector3.FORWARD
var _len := 0.0
var _travelled := 0.0
var _age := 0.0  # seconds since arriving
var _arrived := false
var _bullet: MeshInstance3D
var _trail: MeshInstance3D
var _trail_mat: StandardMaterial3D
var _sparks: Array = []  # [mesh, velocity, life left]
var _streak: MeshInstance3D
var _streak_life := 0.0

func _ready() -> void:
	_len = from.distance_to(to)
	_dir = (to - from).normalized() if _len > 0.001 else Vector3.FORWARD
	var color: Color = cfg["color"]
	_bullet = _glow_mesh(SphereMesh.new(), color)
	(_bullet.mesh as SphereMesh).radius = float(cfg["size"])
	(_bullet.mesh as SphereMesh).height = float(cfg["size"]) * 2.0
	add_child(_bullet)
	var box := BoxMesh.new()
	box.size = Vector3(float(cfg["size"]) * 0.8, float(cfg["size"]) * 0.8, 1.0)
	_trail = _glow_mesh(box, color)
	_trail_mat = _trail.material_override
	add_child(_trail)
	_place()

func _glow_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

# Lays a thin box between two world points.
func _stretch(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	mesh.visible = length > 0.02
	if not mesh.visible:
		return
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	mesh.global_transform = Transform3D(Basis.looking_at(b - a, up) * Basis.from_scale(Vector3(1, 1, length)), (a + b) / 2.0)

func _place() -> void:
	var tip := from + _dir * _travelled
	_bullet.global_position = tip
	_bullet.visible = not _arrived
	_stretch(_trail, from + _dir * maxf(_travelled - float(cfg["trail"]), 0.0), tip)

func _process(delta: float) -> void:
	if not _arrived:
		_travelled = minf(_travelled + float(cfg["speed"]) * delta, _len)
		_place()
		if _travelled >= _len:
			_arrived = true
			_bullet.visible = false
			_impact()
	else:
		_age += delta
		var fade := clampf(1.0 - _age / float(cfg["fade"]), 0.0, 1.0)
		_trail_mat.albedo_color.a = fade
	_update_effects(delta)
	if _arrived and _age >= float(cfg["fade"]) and _sparks.is_empty() and _streak_life <= 0.0:
		queue_free()

# Sparks fly off the hit (red off an enemy, the weapon's colour off a wall); a wall hit also ricochets.
func _impact() -> void:
	if kind == "none":
		return
	var base_normal := normal if normal != Vector3.ZERO else -_dir
	var color: Color = Color(1.0, 0.25, 0.2) if kind == "enemy" else cfg["color"]
	for i in int(cfg["sparks"]):
		var s := _glow_mesh(BoxMesh.new(), color)
		(s.mesh as BoxMesh).size = Vector3.ONE * float(cfg["size"]) * 0.9
		add_child(s)
		s.global_position = to
		var v := (base_normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.2, 0.9), randf_range(-0.8, 0.8))).normalized() * randf_range(2.0, 5.0)
		_sparks.append([s, v, randf_range(0.25, 0.45)])
	if kind == "wall":
		var bounce := _dir.bounce(base_normal)
		_streak = _glow_mesh(BoxMesh.new(), cfg["color"])
		(_streak.mesh as BoxMesh).size = Vector3(float(cfg["size"]) * 0.7, float(cfg["size"]) * 0.7, 1.0)
		add_child(_streak)
		_streak.global_position = to
		_stretch(_streak, to, to + bounce * float(cfg["ricochet"]))
		_streak_life = 0.25

func _update_effects(delta: float) -> void:
	for s in _sparks.duplicate():
		s[2] -= delta
		if s[2] <= 0.0:
			s[0].queue_free()
			_sparks.erase(s)
			continue
		s[1].y -= 9.8 * delta
		s[0].global_position += s[1] * delta
		s[0].material_override.albedo_color.a = clampf(s[2] / 0.3, 0.0, 1.0)
	if _streak_life > 0.0:
		_streak_life -= delta
		_streak.material_override.albedo_color.a = clampf(_streak_life / 0.25, 0.0, 1.0)
		if _streak_life <= 0.0:
			_streak.queue_free()
