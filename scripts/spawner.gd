extends StaticBody3D
# An enemy base. A red beam into the sky marks it and is as wide as the time left until its next spawn
# (a point at the moment an enemy appears, then wide again). Adds a new enemy to its own group every
# Tuning.SPAWNER_INTERVAL seconds, up to
# Tuning.SPAWNER_MAX_ALIVE alive at once, until the player shoots it down. Shots reach it through
# take_damage(), like an enemy. It rolls enemies from its own RNG so spawning never disturbs the map's.

const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const Sfx = preload("res://scripts/sfx.gd")

var group_id := 0
var rng_seed := 0  # set by main before add_child
var health: int = Tuning.SPAWNER_HEALTH

var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _label := Label3D.new()
var _beam: MeshInstance3D

const BEAM_RADIUS := 2.0

# Same as enemy.gd: an off-tree base (the map preview) never parented its label.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_label) and _label.get_parent() == null:
		_label.free()

func _ready() -> void:
	_rng.seed = rng_seed
	_clock = _rng.randf() * Tuning.SPAWNER_INTERVAL * 0.5  # bases do not all pulse in step
	add_to_group("spawner")
	var size := Vector3(2, 1.5, 2)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position.y = size.y / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.12, 0.14)
	mesh.material_override = mat
	add_child(mesh)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 300.0
	_beam.mesh = cyl
	_beam.position.y = cyl.height / 2.0
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1, 0.1, 0.1, 0.3)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_update_beam()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = size.y + 0.8
	_label.visible = false  # only shown once it has been shot
	add_child(_label)
	_update_label()

func _update_label() -> void:
	_label.text = "ENEMY BASE %d/%d" % [health, Tuning.SPAWNER_HEALTH]

# Returns true if this hit destroyed the base. Shooting it wakes its defenders.
func take_damage(amount: int) -> bool:
	if health <= 0:
		return false
	health -= amount
	get_tree().call_group("pack_%d" % group_id, "set_alert", true)
	if health <= 0:
		Sfx.play("kill", global_position)
		queue_free()
		return true
	Sfx.play("hit", global_position)
	_label.visible = true
	_update_label()
	return false

# Seconds until this base spawns its next enemy. Stands still while its group is full.
func time_left() -> float:
	return Tuning.SPAWNER_INTERVAL - _clock

func _update_beam() -> void:
	var f := clampf(time_left() / Tuning.SPAWNER_INTERVAL, 0.02, 1.0)
	_beam.scale = Vector3(BEAM_RADIUS * f, 1.0, BEAM_RADIUS * f)

func _physics_process(delta: float) -> void:
	var pack := get_tree().get_nodes_in_group("pack_%d" % group_id)
	if pack.size() >= Tuning.SPAWNER_MAX_ALIVE:
		return  # full: the countdown holds until a defender dies
	_clock += delta
	_update_beam()
	if _clock < Tuning.SPAWNER_INTERVAL:
		return
	_clock = 0.0
	_update_beam()
	var e := Enemy.new()
	e.stats = Enemies.roll(_rng)
	e.home = global_position
	e.group_id = group_id
	var a := _rng.randf() * TAU
	e.position = global_position + Vector3(cos(a), 0, sin(a)) * 3.5
	get_parent().add_child(e)
	if pack.any(func(m): return m.alert):  # the group is already fighting: the newcomer joins in
		e.set_alert(true)
