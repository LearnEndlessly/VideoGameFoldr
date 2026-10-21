extends Area3D
# A climbable ladder. The area is a strip beside a tower's edge; while the player stands in it, looking at the tower
# and holding W (or Space), they climb at CLIMB_SPEED; S climbs down; letting go holds them where they are. Above
# `top_y` the ladder lets go, so walking on lands them on the platform. Set top_y, height and facing (the direction
# a climber looks, toward the tower) before add_child; the node's local +Z is the way the ladder faces outward.

const CLIMB_SPEED := 4.5
const WIDTH := 1.0
const DEPTH := 1.0

var top_y := 5.2
var height := 5.2
var facing := Vector3.FORWARD

func _ready() -> void:
	add_to_group("ladder")
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH + 0.4, top_y, DEPTH)
	shape.shape = box
	shape.position = Vector3(0, top_y / 2.0, DEPTH / 2.0)
	add_child(shape)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.25)
	for s in [-1.0, 1.0]:  # the two rails
		_bar(Vector3(0.08, height, 0.08), Vector3(s * WIDTH / 2.0, height / 2.0, 0.05), mat)
	var rungs := int(height / 0.4)
	for i in rungs:  # the rungs
		_bar(Vector3(WIDTH, 0.06, 0.06), Vector3(0, 0.3 + i * 0.4, 0.05), mat)
	body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			body.ladder = self)
	body_exited.connect(func(body: Node3D):
		if body.is_in_group("player") and body.ladder == self:
			body.ladder = null)

func _bar(size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = pos
	m.material_override = mat
	add_child(m)
