extends Area3D
# A powerup lying on the ground (data/powerups.gd). It bobs, shows its name and the seconds it has left,
# blinks for the last 2 s and is gone after Tuning.POWERUP_PICKUP_SECONDS. Walking into it asks the raid.

const Powerups = preload("res://data/powerups.gd")
const Tuning = preload("res://data/tuning.gd")

var id := "damage"
var left: float = Tuning.POWERUP_PICKUP_SECONDS

var _orb: MeshInstance3D
var _label := Label3D.new()
var _age := 0.0

func _ready() -> void:
	add_to_group("powerup")
	var data: Dictionary = Powerups.DATA[id]
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	add_child(shape)
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	_orb.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb.material_override = mat
	add_child(_orb)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.modulate = data["color"]
	_label.position.y = 1.0
	add_child(_label)
	body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.raid != null:
			body.raid.collect_powerup(self))

func _physics_process(delta: float) -> void:
	left -= delta
	_age += delta
	if left <= 0.0:
		queue_free()
		return
	_orb.position.y = 0.9 + sin(_age * 4.0) * 0.15
	_orb.visible = left > 2.0 or int(_age * 8.0) % 2 == 0  # blinks as it runs out
	_label.text = "%s  %d" % [Powerups.DATA[id]["name"], ceili(left)]
