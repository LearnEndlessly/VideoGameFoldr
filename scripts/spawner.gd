extends StaticBody3D
# An enemy base (small and unmarked: the player has to find it). Adds a new enemy to its own group every Tuning.SPAWNER_INTERVAL seconds, up to
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

func _ready() -> void:
	_rng.seed = rng_seed
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

func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock < Tuning.SPAWNER_INTERVAL:
		return
	_clock = 0.0
	var pack := get_tree().get_nodes_in_group("pack_%d" % group_id)
	if pack.size() >= Tuning.SPAWNER_MAX_ALIVE:
		return
	var e := Enemy.new()
	e.stats = Enemies.roll(_rng)
	e.home = global_position
	e.group_id = group_id
	var a := _rng.randf() * TAU
	e.position = global_position + Vector3(cos(a), 0, sin(a)) * 3.5
	get_parent().add_child(e)
	if pack.any(func(m): return m.alert):  # the group is already fighting: the newcomer joins in
		e.set_alert(true)
