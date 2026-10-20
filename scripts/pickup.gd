extends Area3D
# An item lying on the ground (an enemy's ammo drop). Walking into it asks the raid to move it into the
# backpack; what does not fit stays here.

const Loot = preload("res://data/loot.gd")
const Attachments = preload("res://data/attachments.gd")
const Model = preload("res://scripts/model.gd")

var id := "ammo"
var qty := 1

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	shape.shape = sphere
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.35, 0.35)
	mesh.mesh = bm
	mesh.position.y = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Loot.ITEMS[id]["color"] if Loot.ITEMS.has(id) else Color(1.0, 0.8, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)
	if Attachments.DATA.has(id):  # super rare: bigger, and named so it is not missed
		bm.size = Vector3(0.5, 0.5, 0.5)
		var art := Model.load_scene(Attachments.DATA[id].get("model", ""))
		if art != null:  # the real part (a scope, a silencer, a magazine) instead of the cube
			mesh.visible = false
			art.scale = Vector3.ONE * 2.5
			art.position.y = 0.5
			add_child(art)
		var label := Label3D.new()
		label.text = Attachments.DATA[id]["name"].to_upper()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.modulate = Loot.ITEMS[id]["color"]
		label.position.y = 1.0
		add_child(label)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.raid != null:
		body.raid.request_pickup(self)
