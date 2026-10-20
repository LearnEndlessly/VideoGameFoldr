extends Area3D
# One point of experience: a small glowing sphere an enemy leaves when it dies (one per point, so a tougher
# enemy leaves more). It waits where it fell, drifts toward the player once they are near, and is collected on
# touch (Raid.collect_xp). It does not expire.

const Tuning = preload("res://data/tuning.gd")

var amount := 1  # xp this orb is worth: always 1, one sphere per point
var _age := randf() * TAU
var _orb: MeshInstance3D

func _ready() -> void:
	add_to_group("xp")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	add_child(shape)
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	_orb.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.85, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb.material_override = mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.raid != null:
			body.raid.collect_xp(self))

func _physics_process(delta: float) -> void:
	_age += delta
	_orb.position.y = 0.5 + sin(_age * 3.0) * 0.08
	for p in get_tree().get_nodes_in_group("player"):
		var to: Vector3 = p.global_position + Vector3(0, 0.8, 0) - global_position
		if to.length() < Tuning.XP_MAGNET_RADIUS:
			global_position += to.normalized() * minf(Tuning.XP_MAGNET_SPEED * delta, to.length())
