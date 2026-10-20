extends Node3D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Crate = preload("res://scripts/crate.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")

const COVER_COUNT := 25
const CRATE_COUNT := 10
const SHELTER_COUNT := 2
const GROUP_COUNT := 5  # enemy groups, 3-4 members each

# Shown on the next run's HUD; survives the scene reload.
static var last_result := ""

var rng := RandomNumberGenerator.new()
var seed_override := -1  # tests set this before add_child to pick a map
var _seed := 0
var _taken: Array = []  # [position, radius] of everything placed, to avoid overlaps
var _player: Player
var _hud := Label.new()
var _feed := VBoxContainer.new()  # recent pickups, each with its symbol
var _ended := false

func _ready() -> void:
	# Pass a seed after `--` on the command line to replay a map.
	var args := OS.get_cmdline_user_args()
	_seed = seed_override if seed_override >= 0 else (int(args[0]) if args.size() > 0 else randi())
	rng.seed = _seed

	_add_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color(0.3, 0.5, 0.3))
	for s in [-1, 1]:
		_add_box(Vector3(62, 4, 1), Vector3(0, 2, s * 30.5), Color(0.4, 0.4, 0.45))
		_add_box(Vector3(1, 4, 62), Vector3(s * 30.5, 2, 0), Color(0.4, 0.4, 0.45))

	_place_extract()
	for i in SHELTER_COUNT:
		_add_shelter(_free_spot(6.0, 8.0))
	for i in COVER_COUNT:
		var size := Vector3(rng.randf_range(2, 6), rng.randf_range(2, 3.5), rng.randf_range(2, 6))
		var p := _free_spot(maxf(size.x, size.z) / 2.0 + 1.0, 6.0)
		_add_box(size, p + Vector3(0, size.y / 2.0, 0), Color(0.5, 0.4, 0.3))
	for i in CRATE_COUNT:
		var c := Crate.new()
		c.seed_value = rng.randi()
		c.position = _free_spot(1.5, 3.0) + Vector3(0, 0.5, 0)
		add_child(c)
	for g in GROUP_COUNT:
		var center := _free_spot(4.0, Tuning.ENEMY_GROUP_MIN_ORIGIN)
		for i in rng.randi_range(3, 4):
			var e := Enemy.new()
			e.stats = Enemies.roll(rng)
			e.home = center
			e.group_id = g
			var spread: float = Tuning.GROUP_SPREAD
			e.position = center + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
			add_child(e)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.7, 0.9)
	add_child(env)

	_player = Player.new()
	add_child(_player)
	_player.died.connect(func(): _end("DIED - run loot lost"))
	_player.picked_up.connect(_on_picked_up)
	_player.inventory_full.connect(func(): _feed_row("", "Backpack full - Tab to make room"))

	var layer := CanvasLayer.new()
	_hud.position = Vector2(16, 16)
	layer.add_child(_hud)
	_feed.position = Vector2(16, 110)
	layer.add_child(_feed)
	var ui := InventoryUI.new()
	layer.add_child(ui)
	ui.setup(_player)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(cross)
	add_child(layer)

func _process(_d: float) -> void:
	_hud.text = "Seed %d   HP %d   Kills %d   %s\nLoot: %s\n%s\n%s\nWASD move, Shift sprint, Space jump, LMB shoot, E open crate, Tab backpack, Esc free mouse. Blue shelter = safe. Green zone = extract." \
		% [_seed, _player.health, _player.kills, "[SAFE]" if _player.safe else "", _loot_text(), _player.weapon_text(), last_result]

func _loot_text() -> String:
	return _player.inventory.summary()

func _on_picked_up(id: String, qty: int) -> void:
	_feed_row(id, "+%d %s" % [qty, id.replace("_", " ")])

func _feed_row(id: String, text: String) -> void:
	var row := HBoxContainer.new()
	var icon := ItemIcon.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.item_id = id
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	row.add_child(label)
	_feed.add_child(row)
	get_tree().create_timer(3.0).timeout.connect(row.queue_free)

func _set_safe(body: Node3D, value: bool) -> void:
	if body == _player:
		_player.safe = value

# Open-fronted hut (door toward +z). Standing inside makes the player invisible to enemies.
func _add_shelter(pos: Vector3) -> void:
	var wall := Color(0.35, 0.45, 0.7)
	_add_box(Vector3(8, 2.5, 0.5), pos + Vector3(0, 1.25, -3.75), wall)
	_add_box(Vector3(0.5, 2.5, 8), pos + Vector3(-3.75, 1.25, 0), wall)
	_add_box(Vector3(0.5, 2.5, 8), pos + Vector3(3.75, 1.25, 0), wall)
	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(7, 0.02, 7)
	pad.mesh = pm
	pad.position = pos + Vector3(0, 0.011, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 1.0)
	pad.material_override = mat
	add_child(pad)
	var label := Label3D.new()
	label.text = "SHELTER"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos + Vector3(0, 3.2, 0)
	add_child(label)
	var area := Area3D.new()
	area.position = pos + Vector3(0, 1.5, 0)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7, 3, 7)
	shape.shape = bs
	area.add_child(shape)
	area.body_entered.connect(_set_safe.bind(true))
	area.body_exited.connect(_set_safe.bind(false))
	add_child(area)

func _end(msg: String) -> void:
	if _ended:
		return
	_ended = true
	last_result = "Last run: %s (loot: %s)" % [msg, _loot_text()]
	get_tree().reload_current_scene.call_deferred()

func _on_extract(body: Node3D) -> void:
	if body == _player:
		_end("EXTRACTED")

# Picks a spot clear of everything placed so far. The map is crowded by the time
# enemies are placed, so after SPAWN_TRIES valid samples overlap is accepted, but
# min_origin (distance from the player's start) is never relaxed.
# shortcut: gives up after 1000 samples, so a min_origin near the map size could
# still return a spot inside it; upgrade if min_origin is ever tuned that high.
func _free_spot(radius: float, min_origin: float) -> Vector3:
	var p := Vector3.ZERO
	var tries := 0
	for i in 1000:
		p = Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-26, 26))
		if p.length() < min_origin:
			continue
		tries += 1
		if tries >= Tuning.SPAWN_TRIES or _is_clear(p, radius):
			break
	_taken.append([p, radius])
	return p

func _is_clear(p: Vector3, radius: float) -> bool:
	for t in _taken:
		if p.distance_to(t[0]) < t[1] + radius:
			return false
	return true

func _place_extract() -> void:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var pos := Vector3(side * 25.0, 0, rng.randf_range(-25, 25))
	_taken.append([pos, 5.0])
	var area := Area3D.new()
	area.position = pos + Vector3(0, 1.5, 0)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6, 3, 6)
	shape.shape = bs
	area.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 1, 0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	area.add_child(mesh)
	area.body_entered.connect(_on_extract)
	add_child(area)

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
