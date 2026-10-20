extends StaticBody3D

const Loot = preload("res://data/loot.gd")
const Model = preload("res://scripts/model.gd")

const MODEL := "res://assets/props/kenney_blaster_kit/crate-medium.glb"  # Kenney Blaster Kit

# Each crate rolls from its own seed, so contents don't depend on open order.
var seed_value := 0
var zone_id := ""  # which loot area this crate is in (logged with every open)
var pool: Dictionary = Loot.ITEMS  # which items can drop; the loot zone sets this
var qty_mult := 1.0
var rolls := [1, 3]  # [min, max] item rolls
var color := Color(0.9, 0.7, 0.1)
var contents: Array = []  # [[id, qty], ...] still inside; rolled on first take
var _rolled := false
var _mat := StandardMaterial3D.new()
var _art: Node3D  # the crate model, if it loaded

func _ready() -> void:
	add_to_group("lootable")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	add_child(shape)
	_art = Model.load_fitted(MODEL, Vector3.ONE, color)
	if _art != null:
		add_child(_art)
		return
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	_mat.albedo_color = color
	mesh.material_override = _mat
	add_child(mesh)

# Moves as much as fits into the inventory; the rest stays here for a later visit.
# Called by the raid simulation after it has validated a loot request.
# Returns what was taken: {id: qty}.
func take_into(inventory) -> Dictionary:
	if not _rolled:
		_rolled = true
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in rng.randi_range(rolls[0], rolls[1]):
			contents.append(Loot.roll(rng, pool, qty_mult))
	var taken := {}
	var left: Array = []
	for r in contents:
		var rem: int = inventory.add(r[0], r[1])
		if r[1] > rem:
			taken[r[0]] = taken.get(r[0], 0) + r[1] - rem
		if rem > 0:
			left.append([r[0], rem])
	contents = left
	if left.is_empty():
		_mat.albedo_color = Color(0.3, 0.3, 0.3)
		if _art != null:
			Model.tint_all(_art, Color(0.3, 0.3, 0.3))
	return taken
