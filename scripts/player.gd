extends CharacterBody3D

const Inventory = preload("res://scripts/inventory.gd")
const Loot = preload("res://data/loot.gd")
const WeaponData = preload("res://data/weapons.gd")
const Sfx = preload("res://scripts/sfx.gd")

signal died
signal inventory_toggled(open: bool)

const MAX_HEALTH := 100
const SPEED := 6.0
const SPRINT := 10.0
const JUMP := 6.0
const SENS := 0.002

var health := MAX_HEALTH
var kills := 0
var safe := false  # true inside a shelter: enemies cannot see or hurt the player
var inventory_open := false
var inventory := Inventory.new()
var raid  # simulation that validates loot requests; set by main
var weapon: Dictionary = WeaponData.DATA["pistol"]
var _cooldown := 0.0
var _head: Node3D
var _cam: Camera3D
var _beam_near: MeshInstance3D
var _beam_far: MeshInstance3D
var _marker: MeshInstance3D

func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	add_child(shape)
	_head = Node3D.new()
	_head.position.y = 1.6
	add_child(_head)
	_cam = Camera3D.new()
	_head.add_child(_cam)
	var line := BoxMesh.new()
	line.size = Vector3(0.012, 0.012, 1)
	_beam_near = _make_mesh(line, Color(0.2, 1, 0.3))
	_beam_far = _make_mesh(line, Color(1, 0.6, 0.1))
	var dot := SphereMesh.new()
	dot.radius = 0.07
	dot.height = 0.14
	_marker = _make_mesh(dot, Color(0.2, 1, 0.3))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func use_slot(i: int) -> void:
	var s = inventory.slots[i]
	if s == null:
		return
	var heal: int = Loot.ITEMS[s["id"]].get("heal", 0)
	if heal > 0 and health < MAX_HEALTH:
		health = mini(health + heal, MAX_HEALTH)
		inventory.take_one(i)
		Sfx.play("heal")

func take_damage(amount: int) -> void:
	health -= amount
	Sfx.play("hurt")
	if health <= 0:
		died.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * SENS, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed and not inventory_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_TAB:
			inventory_open = not inventory_open
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_open else Input.MOUSE_MODE_CAPTURED
			inventory_toggled.emit(inventory_open)
		elif event.keycode == KEY_1:
			weapon = WeaponData.DATA["pistol"]
			Sfx.play("switch")
		elif event.keycode == KEY_2:
			weapon = WeaponData.DATA["scattergun"]
			Sfx.play("switch")
		elif event.keycode == KEY_E:
			var hit := _cast(3.0)
			if hit and raid != null and hit["collider"].is_in_group("lootable"):
				raid.request_loot(hit["collider"])

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir -= transform.basis.z
	if Input.is_physical_key_pressed(KEY_S): dir += transform.basis.z
	if Input.is_physical_key_pressed(KEY_A): dir -= transform.basis.x
	if Input.is_physical_key_pressed(KEY_D): dir += transform.basis.x
	var speed := SPRINT if Input.is_physical_key_pressed(KEY_SHIFT) else SPEED
	dir = dir.normalized() * speed
	velocity.x = dir.x
	velocity.z = dir.z
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE): velocity.y = JUMP
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()

	_cooldown -= delta
	if _cooldown <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cooldown = weapon["cooldown"]
		_shoot()
	_update_aim()

func weapon_text() -> String:
	return "%s  %dx%d dmg  full to %dm, falls off to %dm  [1/2 switch]" % [
		weapon["name"], weapon["damage"], weapon["pellets"], weapon["effective"], weapon["max"]]

func _cast(dist: float) -> Dictionary:
	return _cast_dir(-_cam.global_transform.basis.z, dist)

func _cast_dir(dir: Vector3, dist: float) -> Dictionary:
	var from := _cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * dist)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _shoot() -> void:
	Sfx.play(weapon["sound"])
	var from := _cam.global_position
	var cb := _cam.global_transform.basis
	var spread: float = weapon["spread"]
	for i in int(weapon["pellets"]):
		var dir := -cb.z
		if spread > 0.0:
			dir = (dir + cb.x * randf_range(-spread, spread) + cb.y * randf_range(-spread, spread)).normalized()
		var hit := _cast_dir(dir, weapon["max"])
		if hit and hit["collider"].has_method("take_damage"):
			var dmg := WeaponData.damage_at(weapon, from.distance_to(hit["position"]))
			if hit["collider"].take_damage(dmg):
				kills += 1

# Aim line: green out to the weapon's effective range, orange through the falloff
# zone, with a dot where the aim ray lands (green = full damage, orange = reduced).
func _update_aim() -> void:
	var on := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var from := _cam.global_position
	var dir := -_cam.global_transform.basis.z
	var eff: float = weapon["effective"]
	var hit := _cast_dir(dir, weapon["max"])
	var d: float = weapon["max"] if hit.is_empty() else from.distance_to(hit["position"])
	var muzzle := _cam.global_transform * Vector3(0.22, -0.18, -0.5)
	_set_beam(_beam_near, muzzle, from + dir * minf(d, eff), on)
	_set_beam(_beam_far, from + dir * eff, from + dir * d, on and d > eff)
	_marker.visible = on and not hit.is_empty()
	if _marker.visible:
		_marker.global_position = hit["position"]
		_marker.material_override.albedo_color = Color(0.2, 1, 0.3) if d <= eff else Color(1, 0.6, 0.1)

func _set_beam(beam: MeshInstance3D, a: Vector3, b: Vector3, show: bool) -> void:
	var length := a.distance_to(b)
	beam.visible = show and length > 0.05
	if not beam.visible:
		return
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	beam.look_at_from_position((a + b) / 2.0, b, up)
	beam.scale = Vector3(1, 1, length)

func _make_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.top_level = true
	m.visible = false
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m
