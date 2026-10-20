# Run: Godot --headless --path <project> -s tests/models.gd   (exit code 1 on failure)
# Optional art: a "model" path in a data row replaces the placeholder shape, a missing or empty
# path keeps it, a model takes the alert tint, and a weapon model shows in the view.
extends SceneTree

const Model = preload("res://scripts/model.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const WeaponData = preload("res://data/weapons.gd")
const Player = preload("res://scripts/player.gd")
const FIXTURE := "res://tests/fixtures/test_model.tscn"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _enemy(model_path: String) -> Node:
	var e = Enemy.new()
	e.stats = Enemies.TYPES["grunt"].duplicate()
	e.stats["type"] = "grunt"
	e.stats["modifier"] = ""
	e.stats["model"] = model_path
	root.add_child(e)
	e.set_physics_process(false)
	return e

func _capsule_visible(e: Node) -> bool:
	for c in e.get_children():
		if c is MeshInstance3D and c.mesh is CapsuleMesh:
			return c.visible
	return false

func _init() -> void:
	await process_frame
	# The loader.
	_check(Model.load_scene("") == null, "an empty path must give no model")
	_check(Model.load_scene("res://assets/does_not_exist.glb") == null, "a missing file must give no model, not an error")
	var m := Model.load_scene(FIXTURE)
	_check(m != null and m is Node3D, "the fixture scene should load")
	if m != null:
		m.free()

	# Enemy without a model: the capsule shows.
	var plain := _enemy("")
	await process_frame
	_check(plain.get_node_or_null("Model") == null, "no model path: there should be no Model node")
	_check(_capsule_visible(plain), "no model path: the capsule should be visible")
	var missing := _enemy("res://assets/does_not_exist.glb")
	await process_frame
	_check(missing.get_node_or_null("Model") == null and _capsule_visible(missing), "a missing model file should fall back to the capsule")

	# Enemy with a model: it replaces the capsule, is scaled, and takes the alert tint.
	var art := _enemy(FIXTURE)
	await process_frame
	var model = art.get_node_or_null("Model")
	_check(model != null, "model path: the Model node should exist")
	_check(not _capsule_visible(art), "model path: the capsule should be hidden")
	if model != null:
		_check(model.scale.is_equal_approx(Vector3.ONE * float(art.stats["size"])), "model should be scaled by the enemy's size")
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
		_check(mesh.material_override == null, "a model keeps its own look when calm")
		art.set_alert(true)
		_check(mesh.material_override != null, "an alert model should take the alert colour")
		art.set_alert(false)
		_check(mesh.material_override == null, "a calm model should go back to its own look")

	# Weapon model shows in the view; with no model nothing is added.
	var player = Player.new()
	root.add_child(player)
	await process_frame
	_check(player._cam.get_node_or_null("Viewmodel") == null, "no weapon model: nothing should be held")
	var w: Dictionary = WeaponData.DATA["pistol"].duplicate()
	w["model"] = FIXTURE
	w["model_scale"] = 0.5
	player.weapon = w
	player._show_viewmodel()
	var held = player._cam.get_node_or_null("Viewmodel")
	_check(held != null, "weapon model path: a Viewmodel should be held")
	if held != null:
		_check(held.scale.is_equal_approx(Vector3.ONE * 0.5), "model_scale should apply to the weapon model")

	for f in failures:
		printerr(f)
	print("models: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)
