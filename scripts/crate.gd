extends StaticBody3D

const Loot = preload("res://data/loot.gd")

# Each crate rolls from its own seed, so contents don't depend on open order.
var seed_value := 0
var contents: Array = []  # [[id, qty], ...] still inside; rolled on first open
var _rolled := false
var _mat := StandardMaterial3D.new()

func _ready() -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	_mat.albedo_color = Color(0.9, 0.7, 0.1)
	mesh.material_override = _mat
	add_child(mesh)

# Takes what fits in the player's backpack; the rest stays here for a later visit.
func open(player) -> void:
	if not _rolled:
		_rolled = true
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in rng.randi_range(1, 3):
			contents.append(Loot.roll(rng))
	var left: Array = []
	for r in contents:
		var rem: int = player.inventory.add(r[0], r[1])
		if r[1] > rem:
			player.picked_up.emit(r[0], r[1] - rem)
		if rem > 0:
			left.append([r[0], rem])
	contents = left
	if left.is_empty():
		_mat.albedo_color = Color(0.3, 0.3, 0.3)
	elif _rolled:
		player.inventory_full.emit()
