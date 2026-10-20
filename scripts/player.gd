extends CharacterBody3D

const Inventory = preload("res://scripts/inventory.gd")
const Loot = preload("res://data/loot.gd")
const WeaponData = preload("res://data/weapons.gd")
const Recipes = preload("res://data/recipes.gd")
const Model = preload("res://scripts/model.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Tuning = preload("res://data/tuning.gd")
const Telemetry = preload("res://scripts/telemetry.gd")

signal died
signal inventory_toggled(open: bool)
signal station_used(station: Node)  # base only: E or a click on a station
signal ui_closed  # base only: Esc while a station panel is open

const MAX_HEALTH := 100
const SENS := 0.002

var health := MAX_HEALTH
var max_health := MAX_HEALTH  # raised by the Constitution attribute (apply_profile)
var armor := 0.0  # fraction of every hit absorbed
var speed_mult := 1.0
var kills := 0
var safe := false  # true inside a shelter: enemies cannot see or hurt the player
var sprinting := false  # moving with Shift held: loud, enemies hear it through walls
var inventory_open := false
var inventory := Inventory.new()
var raid  # simulation that validates loot requests; set by main
var weapon_id := "pistol"
var weapon: Dictionary = WeaponData.DATA["pistol"]
var _viewmodel: Node3D  # the current weapon's art model, if it has one
var _step_dist := 0.0  # metres walked since the last footstep sound
var _head: Node3D
var _cam: Camera3D
var _beam: MeshInstance3D
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
	_show_viewmodel()
	var line := BoxMesh.new()
	line.size = Vector3(0.012, 0.012, 1)
	_beam = _make_mesh(line, Color(0.2, 1, 0.3))
	var dot := SphereMesh.new()
	dot.radius = 0.07
	dot.height = 0.14
	_marker = _make_mesh(dot, Color(0.2, 1, 0.3))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func use_slot(i: int) -> void:
	var s = inventory.slots[i]
	if s == null:
		return
	var id: String = s["id"]
	if _try_craft(id):
		return
	var heal: int = Loot.ITEMS[id].get("heal", 0)
	if heal > 0 and health < max_health:
		health = mini(health + heal, max_health)
		inventory.take_one(i)
		Sfx.play("heal")
		Telemetry.emit("player.use.item", {"id": id, "outcome": "ok"})

# If `id` is an ingredient in a recipe, ask the raid to craft it. True if a recipe applies.
func _try_craft(id: String) -> bool:
	for output in Recipes.DATA:
		if Recipes.DATA[output].has(id):
			if raid != null:
				var ok: bool = raid.request_craft(output)
				Telemetry.emit("player.use.item", {"id": id, "outcome": "ok" if ok else "none"})
			return true
	return false

func take_damage(amount: int) -> void:
	health -= maxi(1, int(round(amount * (1.0 - armor))))
	Sfx.play("hurt")
	if health <= 0:
		died.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * SENS, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed and not inventory_open:
		var was_captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED  # the click that grabs the mouse is not a shot
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if raid == null and was_captured and event.button_index == MOUSE_BUTTON_LEFT:
			_hub_shoot()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if raid == null and inventory_open:  # in the base: close the open station panel
				inventory_open = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				ui_closed.emit()
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_TAB and raid != null:
			inventory_open = not inventory_open
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory_open else Input.MOUSE_MODE_CAPTURED
			inventory_toggled.emit(inventory_open)
		elif event.keycode == KEY_1:
			select_weapon("pistol")
			Sfx.play("switch")
		elif event.keycode == KEY_2:
			select_weapon("scattergun")
			Sfx.play("switch")
		elif event.keycode == KEY_R and raid != null:
			if raid.request_reload():
				Sfx.play("switch")
		elif event.keycode == KEY_E:
			var hit := _cast(3.0)
			if hit and raid != null and hit["collider"].is_in_group("lootable"):
				raid.request_loot(hit["collider"])
			elif raid == null:
				_use_station()

# In the base: use the station or button (bodies in group "station" or "shootable") the player is
# looking at, within `dist` metres. E reaches 3 m; a shot reaches the weapon's range.
func _use_station(dist := 3.0) -> void:
	var hit := _cast(dist)
	if hit and (hit["collider"].is_in_group("station") or hit["collider"].is_in_group("shootable")):
		station_used.emit(hit["collider"])

# In the base a click fires the weapon: it makes the sound, uses no ammo (the stash and backpack are
# untouched), and whatever it hits that can be used is used, so buttons can be shot from across the room.
func _hub_shoot() -> void:
	Sfx.play(weapon["sound"])
	_use_station(float(weapon["max"]))

# Carry the profile's upgrades into a raid: attributes, and the weapon held at the start.
func apply_profile(profile) -> void:
	max_health = profile.max_health(MAX_HEALTH)
	health = max_health
	armor = profile.armor()
	speed_mult = profile.speed_mult()
	select_weapon(profile.equipped)

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir -= transform.basis.z
	if Input.is_physical_key_pressed(KEY_S): dir += transform.basis.z
	if Input.is_physical_key_pressed(KEY_A): dir -= transform.basis.x
	if Input.is_physical_key_pressed(KEY_D): dir += transform.basis.x
	var run := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed: float = (Tuning.PLAYER_SPRINT_SPEED if run else Tuning.PLAYER_WALK_SPEED) * speed_mult
	dir = dir.normalized() * speed
	sprinting = run and dir.length() > 0.1  # enemies can hear this (see enemy.gd)
	velocity.x = dir.x
	velocity.z = dir.z
	if is_on_floor():
		if Input.is_physical_key_pressed(KEY_SPACE): velocity.y = Tuning.PLAYER_JUMP_SPEED
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	if is_on_floor():
		_step_dist += Vector2(velocity.x, velocity.z).length() * delta
		if _step_dist >= Tuning.PLAYER_STRIDE:
			_step_dist = 0.0
			Sfx.play("step_player")

	if raid != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		raid.request_fire(weapon_id, _cam.global_transform)  # the raid checks cooldown and ammo

# The aim line follows the camera, so it updates every rendered frame (physics ticks lag the mouse).
func _process(_delta: float) -> void:
	_update_aim()

func select_weapon(id: String) -> void:
	weapon_id = id
	weapon = WeaponData.DATA[id]
	if raid != null:
		raid.cancel_reload()  # switching weapons interrupts a reload
	_show_viewmodel()

# The weapon's optional art model (its "model" field in data/weapons.gd), held at the lower
# right of the view. Without one nothing is shown, as before.
func _show_viewmodel() -> void:
	if _viewmodel != null:
		_viewmodel.queue_free()
		_viewmodel = null
	var model := Model.load_scene(weapon.get("model", ""))
	if model == null:
		return
	model.name = "Viewmodel"
	model.position = Vector3(0.22, -0.2, -0.5)
	model.scale = Vector3.ONE * float(weapon.get("model_scale", 1.0))
	_cam.add_child(model)
	_viewmodel = model

func ammo_count() -> int:
	return inventory.count(weapon["ammo_item"])

func _cast(dist: float) -> Dictionary:
	return _cast_dir(-_cam.global_transform.basis.z, dist)

func _cast_dir(dir: Vector3, dist: float) -> Dictionary:
	var from := _cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * dist)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

# Aim line, one colour by where it lands: green = full damage, orange = in the falloff band,
# grey = nothing within the weapon's max range. The dot at the hit point matches.
func _update_aim() -> void:
	var on := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and raid != null  # no laser in the base
	var from := _cam.global_position
	var dir := -_cam.global_transform.basis.z
	var hit := _cast_dir(dir, weapon["max"])
	var d: float = weapon["max"] if hit.is_empty() else from.distance_to(hit["position"])
	var color := aim_color(hit.is_empty(), d)
	var muzzle := _cam.global_transform * Vector3(0.22, -0.18, -0.5)
	_beam.material_override.albedo_color = color
	_set_beam(_beam, muzzle, from + dir * d, on)
	_marker.visible = on and not hit.is_empty()
	if _marker.visible:
		_marker.global_position = hit["position"]
		_marker.material_override.albedo_color = color

func aim_color(no_hit: bool, dist: float) -> Color:
	if no_hit:
		return Color(0.6, 0.6, 0.6)
	return Color(0.2, 1, 0.3) if dist <= weapon["effective"] else Color(1, 0.6, 0.1)

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
