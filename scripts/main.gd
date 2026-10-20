extends Node3D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Crate = preload("res://scripts/crate.gd")
const Raid = preload("res://scripts/raid.gd")
const Profile = preload("res://scripts/profile.gd")
const ScreenUI = preload("res://scripts/screen_ui.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")

const COVER_COUNT := 25
const CRATE_COUNT := 10
const SHELTER_COUNT := 2
const GROUP_COUNT := 5  # enemy groups, 3-4 members each

# The first launch shows the start screen; "one more run" skips it. Survives scene reloads.
static var show_start := true

var rng := RandomNumberGenerator.new()
var seed_override := -1  # tests set these before add_child
var profile_path := Tuning.PROFILE_PATH
var profile: Profile
var raid: Raid
var extract_pos := Vector3.ZERO

var _seed := 0
var _last_tick := -1  # whole second of the extract timer last ticked
var _taken: Array = []  # [position, radius] of everything placed, to avoid overlaps
var _player: Player
var _zone_mat := StandardMaterial3D.new()
# HUD nodes are created in _build_raid so the start screen doesn't leave orphans.
var _hud: Label
var _feed: VBoxContainer  # recent pickups, each with its symbol
var _extract_box: VBoxContainer
var _extract_label: Label
var _extract_bar: ProgressBar

func _ready() -> void:
	profile = Profile.new(profile_path)
	profile.load_from_disk()
	if show_start:
		_show_start_screen()
	else:
		_build_raid()

func _show_start_screen() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := ScreenUI.new()
	layer.add_child(screen)
	var hold: float = Tuning.EXTRACT_HOLD_SECONDS
	screen.show_screen("EXTRACTION PROTOTYPE",
		"Loot crates, then reach the green zone and hold it for %.0f seconds to bring your loot home. If you die, everything you carried this raid is lost." % hold,
		"", {}, profile.totals, "Start raid", _next_raid)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_raid() -> void:
	get_tree().paused = false
	# Pass a seed after `--` on the command line to replay a map.
	var args := OS.get_cmdline_user_args()
	_seed = seed_override if seed_override >= 0 else (int(args[0]) if args.size() > 0 else randi())
	rng.seed = _seed

	_add_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color(0.3, 0.5, 0.3))
	for s in [-1, 1]:
		_add_box(Vector3(62, 4, 1), Vector3(0, 2, s * 30.5), Color(0.4, 0.4, 0.45))
		_add_box(Vector3(1, 4, 62), Vector3(s * 30.5, 2, 0), Color(0.4, 0.4, 0.45))

	var zone := _place_extract()
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
	raid = Raid.new()
	raid.profile = profile
	add_child(raid)
	raid.setup(_player)
	_player.raid = raid
	raid.picked_up.connect(_on_picked_up)
	raid.inventory_full.connect(func():
		Sfx.play("deny")
		_feed_row("", "Backpack full - Tab to make room"))
	raid.ended.connect(_on_raid_ended)
	zone.body_entered.connect(_on_zone_body.bind(true))
	zone.body_exited.connect(_on_zone_body.bind(false))

	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(16, 16)
	layer.add_child(_hud)
	_feed = VBoxContainer.new()
	_feed.position = Vector2(16, 110)
	layer.add_child(_feed)
	var ui := InventoryUI.new()
	layer.add_child(ui)
	ui.setup(_player)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(cross)
	_build_extract_hud(layer)
	add_child(layer)

func _build_extract_hud(layer: CanvasLayer) -> void:
	_extract_box = VBoxContainer.new()
	_extract_label = Label.new()
	_extract_bar = ProgressBar.new()
	_extract_label.add_theme_font_size_override("font_size", 26)
	_extract_label.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	_extract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_extract_bar.custom_minimum_size = Vector2(360, 22)
	_extract_bar.show_percentage = false
	_extract_box.add_child(_extract_label)
	_extract_box.add_child(_extract_bar)
	_extract_box.visible = false
	layer.add_child(_extract_box)
	_extract_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_extract_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_extract_box.offset_top = 24

func _process(_d: float) -> void:
	if raid == null:
		return
	var hold := raid.hold_seconds
	_hud.text = "Seed %d   HP %d   Kills %d   %s\nLoot: %s\n%s\nWASD move, Shift sprint, Space jump, LMB shoot, E open crate, Tab backpack, Esc free mouse. Blue shelter = safe. Hold the green zone for %.0f s to extract." \
		% [_seed, _player.health, _player.kills, "[SAFE]" if _player.safe else "", _loot_text(), _player.weapon_text(), hold]
	_zone_mat.albedo_color = Color(1, 0.9, 0.1, 0.45) if raid.extracting else Color(0, 1, 0.2, 0.25)
	_extract_box.visible = raid.extracting
	var second := int(raid.extract_elapsed) if raid.extracting else -1
	if second != _last_tick:
		_last_tick = second
		if second >= 0:
			Sfx.play("extract_tick")
	if raid.extracting:
		_extract_label.text = "EXTRACTING  %.1f s" % maxf(hold - raid.extract_elapsed, 0.0)
		_extract_bar.max_value = hold
		_extract_bar.value = raid.extract_elapsed

func _loot_text() -> String:
	return _player.inventory.summary()

func _on_picked_up(id: String, qty: int) -> void:
	Sfx.play("pickup")
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

func _on_zone_body(body: Node3D, inside: bool) -> void:
	if body != _player:
		return
	if inside:
		raid.request_extract()
	else:
		raid.cancel_extract()

func _on_raid_ended(result: Dictionary) -> void:
	get_tree().paused = true  # freeze the world behind the results screen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var extracted: bool = result["outcome"] == "extracted"
	Sfx.play("extract_done" if extracted else "death")
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var screen := ScreenUI.new()
	layer.add_child(screen)
	var subtitle := "Everything you carried this raid is lost."
	if extracted:
		subtitle = "Your loot is stored." if result["saved"] else "WARNING: your profile could not be saved."
	screen.show_screen("EXTRACTED" if extracted else "YOU DIED", subtitle,
		"Kept this raid" if extracted else "Lost this raid", result["items"],
		profile.totals, "One more run", _next_raid)

func _next_raid() -> void:
	show_start = false
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

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

# Builds the extract zone and returns its Area3D; the caller wires it to the raid.
func _place_extract() -> Area3D:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var pos := Vector3(side * 25.0, 0, rng.randf_range(-25, 25))
	extract_pos = pos
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
	_zone_mat.albedo_color = Color(0, 1, 0.2, 0.25)
	_zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = _zone_mat
	area.add_child(mesh)
	add_child(area)
	return area

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
