extends Node3D

const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Crate = preload("res://scripts/crate.gd")
const Raid = preload("res://scripts/raid.gd")
const Profile = preload("res://scripts/profile.gd")
const ScreenUI = preload("res://scripts/screen_ui.gd")
const Sfx = preload("res://scripts/sfx.gd")
const WeaponData = preload("res://data/weapons.gd")
const Enemies = preload("res://data/enemies.gd")
const Tuning = preload("res://data/tuning.gd")
const Scenery = preload("res://data/scenery.gd")
const LootZones = preload("res://data/loot_zones.gd")
const Buildings = preload("res://data/buildings.gd")
const Rng = preload("res://data/rng.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const AmmoBar = preload("res://scripts/ammo_bar.gd")
const Crosshair = preload("res://scripts/crosshair.gd")
const Spawner = preload("res://scripts/spawner.gd")
const DirectionTick = preload("res://scripts/direction_tick.gd")
const Hub = preload("res://scripts/hub.gd")
const UpgradePick = preload("res://scripts/upgrade_pick.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Scope = preload("res://scripts/scope.gd")
const ComboMeter = preload("res://scripts/combo_meter.gd")
const ReadyRing = preload("res://scripts/ready_ring.gd")
const Tracer = preload("res://scripts/tracer.gd")
const Model = preload("res://scripts/model.gd")
const Difficulty = preload("res://data/difficulty.gd")
const Ladder = preload("res://scripts/ladder.gd")

# Kenney Prototype Kit pieces (assets/) the map is built from. Collision stays the plain box; these are the looks.
const WALL_MODEL := "res://assets/buildings/kenney_prototype_kit/wall.glb"
const FLOOR_MODEL := "res://assets/buildings/kenney_prototype_kit/floor-thick.glb"

const EXTRACT_ZONES := {
	"A": {"name": "Safe route", "color": Color(0, 1, 0.2, 0.25)},
	"B": {"name": "Fast route", "color": Color(1, 0.6, 0.1, 0.25)},
}
const SHELTER_COUNT := 2

# True: build the base (scripts/hub.gd) instead of a raid. The game opens there, and extracting or dying
# returns to it; the raid terminal clears it. Survives scene reloads.
static var show_start := true
# The map seed picked at the base's map table for the next raid; -1 = none picked.
static var chosen_seed := -1
# How many levels this run has descended (0 = a raid started at the base) and the loot carried down, still unbanked.
static var depth := 0
static var carry := {}
static var run_upgrades := {}  # raid upgrades kept while descending; cleared when the run ends
static var _launched := false  # the first Main of a real launch starts from an empty profile (Tuning.RESET_ON_LAUNCH)

var rng := RandomNumberGenerator.new()
var seed_override := -1  # tests set these before add_child
# The VG_PROFILE environment variable moves the default save (the test runner uses it so tests never touch the real one).
var profile_path: String = OS.get_environment("VG_PROFILE") if OS.has_environment("VG_PROFILE") else Tuning.PROFILE_PATH
var profile: Profile
var raid: Raid
var extract_pos := Vector3.ZERO  # zone A's position (the "safe route"); see extract_zones
var extract_zones: Array = []  # [{"id": "A"|"B", "name", "pos", "color", "area", "beam", "label", "mat", "hold"}]
var extract_errors: Array = []  # placement failures (should stay empty): a clear message each
# Extract placement settings. They default to data/tuning.gd; a test changes entries before add_child to prove
# that the extract tuning moves only the zones.
var extract_cfg := {"a_min_path": Tuning.EXTRACT_A_MIN_PATH, "b_min_path": Tuning.EXTRACT_B_MIN_PATH,
	"b_max_path": Tuning.EXTRACT_B_MAX_PATH, "min_separation": Tuning.EXTRACT_MIN_SEPARATION,
	"min_base_distance": Tuning.EXTRACT_MIN_BASE_DISTANCE, "b_hold": Tuning.EXTRACT_B_HOLD_SECONDS,
	"b_noise_radius": Tuning.EXTRACT_B_NOISE_RADIUS, "beam_reveal_radius": Tuning.EXTRACT_BEAM_REVEAL_RADIUS,
	"beam_always_visible": Tuning.EXTRACT_BEAM_ALWAYS_VISIBLE, "threat_tick": Tuning.THREAT_EXTRACT_TICK}
var map_type := "open"  # "open" or "narrow" (Tuning.MAP_TYPES)
var half_w := 30.0  # half the map width (x) and depth (z), set per raid
var half_d := 30.0
var towers: Array = []  # {"pos", "ladder", "top"} of each watch tower
var structures: Array = []  # loot areas: {"id", "center", "rect": Rect2 on the XZ plane}
var shelters: Array = []  # Vector3 centres of the safe nooks
var buildings: Array = []  # walkable buildings: {"id", "pos", "rect": Rect2 on the XZ plane}
var blocks: Array = []  # [size, centre, colour] of every box added, for the base's map table
var solids: Array = []  # Rect2 (x, z) of every solid box, for the layout test

var _seed := 0
var _start := Vector3.ZERO  # where the player starts: the centre, or near one end of a narrow map
var _zone_label: Label  # "HEADSHOT" / "ARMORED" under the crosshair after a hit
var _zone_time := 0.0
var _last_tick := -1  # whole second of the extract timer last ticked
var _gap := 3.0  # this map's minimum walkable gap between objects, rolled per map (Tuning.PATH_GAP_RANGE)
var _taken: Array = []  # [centre, half_x, half_z] of everything placed, to keep walkable gaps
var _cover: Array = []  # centres of placed cover boxes
var _guard_pos = null  # Vector3 home of the group guarding Tuning.GUARDED_ZONE, or null
var _player: Player
var _spawners: Array = []  # the enemy bases (Spawner); each is freed when destroyed
var _legacy_pad := Vector3.ZERO  # where the old single extract zone used to go; still kept clear (see _reserve_legacy_extract_pad)
# HUD nodes are created in _build_raid so the start screen doesn't leave orphans.
var _hud: Label
var _feed: VBoxContainer  # recent pickups, each with its symbol
var _extract_box: VBoxContainer
var _extract_label: Label
var _extract_bar: ProgressBar
var _banner: Label
var _threat_label: Label  # top right: the threat clock countdown, then "converging"
var _tick: Control  # arrow toward the nearest extract zone, after the threat clock fires
var _banner_time := 0.0
var _pick_layer: CanvasLayer  # the level-up screen while it is open
var _pause_layer: CanvasLayer  # the pause menu while it is open
var _xp_bar: ProgressBar
var _scope: Control  # the sniper scope overlay
var _hp_bar: ProgressBar
var _stats_label: Label
var _ammo_bar: Control
var _ammo_label: Label
var _cross: Control
var _ring: Control  # the ready indicator around the crosshair (slow weapons)
var _combo: Control  # the kill combo counter
var _reload_tip: Label  # "R to reload" under the crosshair

func _ready() -> void:
	profile = Profile.new(profile_path)
	var fresh := resets_profile(profile_path, _launched)
	_launched = true
	if fresh:
		profile.save()  # overwrite last session's file now, or the next scene reload would read it back
	else:
		profile.load_from_disk()
	if show_start:
		_build_hub()
	else:
		_build_raid()

# True for the first Main of a real launch: only the real save file is wiped, never a test or tool profile.
static func resets_profile(path: String, launched: bool) -> bool:
	return Tuning.RESET_ON_LAUNCH and not launched and path == Tuning.PROFILE_PATH

func _build_hub() -> void:
	var hub := Hub.new()
	hub.profile = profile
	hub.start_raid = _next_raid
	hub.preview_fn = Callable(self, "preview")
	add_child(hub)

# Generates the whole map from rng (already seeded): floor, walls, extract zone, loot rooms, enemy groups,
# enemy bases, shelters and cover. Needs no scene tree, so preview() can run it.
func _build_map() -> void:
	_roll_map_size()
	_roll_map_type()
	_gap = rng.randf_range(Tuning.PATH_GAP_RANGE[0], Tuning.PATH_GAP_RANGE[1])
	var wall_color := Color(0.4, 0.4, 0.45)
	_add_box(Vector3(half_w * 2.0, 1, half_d * 2.0), Vector3(0, -0.5, 0), Color(0.3, 0.5, 0.3), FLOOR_MODEL)
	for s in [-1, 1]:
		_add_box(Vector3(half_w * 2.0 + 2.0, 4, 1), Vector3(0, 2, s * (half_d + 0.5)), wall_color, WALL_MODEL)
		_add_box(Vector3(1, 4, half_d * 2.0 + 2.0), Vector3(s * (half_w + 0.5), 2, 0), wall_color, WALL_MODEL)

	# Order matters: the big fixed things go in first (they may overlap if the map is too
	# small), then shelters with their screening cover, then general cover fills whatever
	# space is left, skipping what doesn't fit with a walkable gap.
	_taken.append([_start, 2.5, 2.5])  # player start
	_reserve_legacy_extract_pad()
	_place_gates()  # first on a narrow map, so everything else is placed around the walls
	for id in LootZones.DATA:
		_add_structure(id, LootZones.DATA[id])
	for g in Tuning.ENEMY_GROUP_COUNT:
		var guard = _guard_pos if g == 0 else null
		var center: Vector3 = guard if guard != null else _free_spot(3.5, 3.5, Tuning.ENEMY_GROUP_MIN_ORIGIN)
		for i in rng.randi_range(Tuning.ENEMY_GROUP_SIZE_MIN, Tuning.ENEMY_GROUP_SIZE_MAX):
			var e := Enemy.new()
			e.stats = Enemies.roll(rng)
			e.home = center
			e.group_id = g
			var spread: float = Tuning.GROUP_SPREAD
			e.position = center + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
			add_child(e)
	for i in Tuning.SPAWNER_COUNT:
		_place_spawner(i)
		_garrison(_spawners.back())
	_place_shelters()
	_place_towers()
	_place_buildings()  # before the cover, which fills what is left; drawn from its own RNG stream
	var mix := {}  # this map's own cover mix: each type's weight scaled by a random factor
	for k in Scenery.COVER_TYPES:
		mix[k] = maxi(1, int(round(float(Scenery.COVER_TYPES[k]["weight"]) * 10.0 * rng.randf_range(Tuning.COVER_MIX_RANGE[0], Tuning.COVER_MIX_RANGE[1]))))
	for i in rng.randi_range(Tuning.COVER_ATTEMPTS_MIN, Tuning.COVER_ATTEMPTS_MAX):  # boxes that don't fit with a walkable gap are skipped
		_place_cover(null, mix)
	_place_extracts()  # last, and from its own RNG stream: nothing above depends on it

func _build_raid() -> void:
	get_tree().paused = false
	# Pass a seed after `--` on the command line to replay a map.
	var args := OS.get_cmdline_user_args()
	if seed_override >= 0:
		_seed = seed_override
	elif chosen_seed >= 0:  # picked at the base's map table
		_seed = chosen_seed
		chosen_seed = -1
	else:
		_seed = int(args[0]) if args.size() > 0 else randi()
	rng.seed = _seed
	_build_map()
	_add_depth_bases()
	_apply_difficulty(Difficulty.values(profile.difficulty))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.7, 0.9)
	add_child(env)

	_player = Player.new()
	_player.position = _start
	add_child(_player)
	_player.pause_requested.connect(_open_pause)
	_player.apply_profile(profile)  # the base's upgrades: attributes and the starting weapon
	raid = Raid.new()
	raid.profile = profile
	raid.reload_seconds = Tuning.RELOAD_SECONDS * profile.reload_mult()
	raid.start_ammo = Difficulty.values(profile.difficulty)["ammo"] + Tuning.DEPTH_AMMO_BONUS * depth + int(profile.bonus("start_ammo"))
	raid.reward_mult = profile.reward_mult() + Tuning.DEPTH_REWARD_BONUS * depth
	raid.drop_mult = 1.0 + Tuning.DEPTH_DROP_BONUS * depth
	raid.depth = depth
	raid.upgrades = run_upgrades.duplicate()
	raid.carry = carry
	carry = {}
	raid.b_hold_seconds = float(extract_cfg["b_hold"])
	raid.b_noise_radius = float(extract_cfg["b_noise_radius"])
	for z in extract_zones:
		raid.extract_points[z["id"]] = z["pos"]
	raid.seed_value = _seed
	raid.map_info = _map_info()
	add_child(raid)
	raid.setup(_player)
	_player.raid = raid
	raid.picked_up.connect(_on_picked_up)
	raid.inventory_full.connect(func():
		Sfx.play("deny")
		_feed_row("", "Backpack full - Tab to make room"))
	raid.ended.connect(_on_raid_ended)
	raid.shot_fired.connect(func(weapon_id: String): Sfx.play(WeaponData.DATA[weapon_id]["sound"]))
	raid.dry_fire.connect(func(): Sfx.play("empty"))
	raid.threat_started.connect(_on_threat_started)
	raid.bullet_traced.connect(_on_bullet)
	raid.zone_hit.connect(_on_zone_hit)
	raid.combo_kill.connect(func(_count: int): _combo.bump())
	raid.combo_ended.connect(func(count: int, bonus: int):
		if count >= 2:
			_combo.show_paid("COMBO x%d  +%d" % [count, bonus]))
	raid.point_earned.connect(func():
		_banner.text = "NEW SKILL POINT AT THE CHARACTER STATION\nRound %d cleared" % raid.round_number()
		_banner_time = 7.0
		Sfx.play("pickup"))
	raid.attachment_broke.connect(func(attachment_name: String):
		_banner.text = "%s BROKE\nRepair it with scrap at the gunsmith" % attachment_name.to_upper()
		_banner_time = 5.0
		Sfx.play("deny"))
	for z in extract_zones:
		z["area"].body_entered.connect(_on_zone_body.bind(true, z["id"]))
		z["area"].body_exited.connect(_on_zone_body.bind(false, z["id"]))

	var layer := CanvasLayer.new()
	_scope = Scope.new()
	_scope.visible = false
	layer.add_child(_scope)
	_scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud = Label.new()
	_hud.position = Vector2(16, 16)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a narrow left column, clear of the extract bar in the middle
	_hud.custom_minimum_size = Vector2(420, 0)
	layer.add_child(_hud)
	_feed = VBoxContainer.new()
	_feed.position = Vector2(16, 110)
	layer.add_child(_feed)
	var ui := InventoryUI.new()
	layer.add_child(ui)
	ui.setup(_player)
	_cross = Crosshair.new()
	_cross.fov = _player._cam.fov
	layer.add_child(_cross)
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ring = ReadyRing.new()
	layer.add_child(_ring)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_zone_label = Label.new()
	_zone_label.add_theme_font_size_override("font_size", 22)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.visible = false
	layer.add_child(_zone_label)
	_zone_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_zone_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_zone_label.offset_top = 90
	_combo = ComboMeter.new()
	_combo.visible = false
	layer.add_child(_combo)
	_combo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_combo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_combo.offset_left = -210
	_combo.offset_right = -16
	_combo.offset_top = 56
	_combo.offset_bottom = 152
	_build_extract_hud(layer)
	_build_status_hud(layer)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	layer.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 140  # below the extract countdown, clear of the HUD text
	_threat_label = Label.new()
	_threat_label.add_theme_font_size_override("font_size", 22)
	_threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_threat_label)
	_threat_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_threat_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_threat_label.offset_top = 14
	_threat_label.offset_right = -16
	_tick = DirectionTick.new()
	_tick.radius = Tuning.THREAT_TICK_RADIUS
	layer.add_child(_tick)
	_tick.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.move_child(ui, -1)  # the backpack draws over every other HUD piece
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

# Top-left: health bar, kills and shots. Small ammo slots and the reload tip sit just under the crosshair.
func _build_status_hud(layer: CanvasLayer) -> void:
	var top := VBoxContainer.new()
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 18)
	_hp_bar.max_value = Player.MAX_HEALTH
	_hp_bar.show_percentage = false  # the stats line already prints HP
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.15, 0.15)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 14)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(260, 10)
	_xp_bar.max_value = 1.0
	_xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.3, 0.7, 1.0)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	top.add_child(_stats_label)
	top.add_child(_hp_bar)
	top.add_child(_xp_bar)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)  # bottom left corner
	top.grow_vertical = Control.GROW_DIRECTION_BEGIN
	top.offset_left = 16
	top.offset_bottom = -16

	var ammo := VBoxContainer.new()
	ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_bar = AmmoBar.new()
	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size", 14)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo.add_child(_ammo_bar)
	ammo.add_child(_ammo_label)
	_reload_tip = Label.new()
	_reload_tip.text = "R to reload"
	_reload_tip.add_theme_font_size_override("font_size", 16)
	_reload_tip.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	_reload_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_tip.visible = false
	ammo.add_child(_reload_tip)
	layer.add_child(ammo)
	ammo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ammo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ammo.offset_top = 40  # clear of the weapon's crosshair circle

# "Enemies left" counts the living enemies on the map; the respawn countdown is the soonest of the bases
# that are still spawning (a base holds its timer while its group is full).
func _enemy_status() -> String:
	var alive := get_tree().get_nodes_in_group("enemy").filter(func(e): return not e.is_queued_for_deletion()).size()
	var bases := _spawners.filter(is_instance_valid)
	if bases.is_empty():
		return "Enemies left: %d   ALL ENEMY BASES DESTROYED" % alive
	var soonest := INF
	for b in bases:
		if get_tree().get_nodes_in_group("pack_%d" % b.group_id).size() < b.max_alive:
			soonest = minf(soonest, b.time_left())
	var timer := "%.0f s" % ceilf(soonest) if soonest < INF else "-"
	return "Enemies left: %d\nEnemy bases: %d   Next respawn: %s" % [alive, bases.size(), timer]

func _update_status_hud() -> void:
	var id: String = _player.weapon_id
	var w: Dictionary = _player.weapon
	var shown: int = raid.shown_rounds(id)
	var held: int = _player.inventory.count(w["ammo_item"])
	_hp_bar.max_value = _player.max_health
	_hp_bar.value = _player.health
	_xp_bar.value = raid.xp_fraction()
	_stats_label.text = "DEPTH %d   LV %d   HP %d   FRAGS %d   SHOTS %d   SCORE %d" % [depth + 1, raid.raid_level(), _player.health, _player.kills, raid.shots, raid.score]
	_ammo_bar.total = raid.clip_size(id)
	_ammo_bar.filled = shown
	_cross.spread = w["spread"]
	_cross.fov = _player._cam.fov
	_cross.visible = not _player.scoped
	_scope.shown = _player.scoped
	_update_ready_ring(id, w, shown, held)
	_combo.count = raid.combo
	_combo.fraction = raid.combo_left / maxf(raid.combo_total, 0.01)
	_combo.pending = "+%d  x%.2f" % [raid.combo_payout(), raid.combo_mult(raid.combo)]
	_reload_tip.visible = shown * 5 <= raid.clip_size(id) and held > shown and raid.reload_weapon != id
	var note := ""
	if raid.reload_weapon == id:
		note = "  RELOADING..."
	elif held < w["ammo_per_shot"]:
		note = "  NO AMMO"
	_ammo_label.text = "%d / %d%s" % [shown, maxi(held - shown, 0), note]

# The ring around the crosshair for slow weapons ("ready" in data/weapons.gd): orange and filling while the next shot is
# not ready, green when it is; around the scope's centre while scoped in.
func _update_ready_ring(id: String, w: Dictionary, shown: int, held: int) -> void:
	_ring.shown = bool(w.get("ready", false))
	if not _ring.shown:
		return
	var reloading: bool = raid.reload_weapon == id
	_ring.empty = held < int(w["ammo_per_shot"]) and not reloading
	_ring.is_ready = raid.shot_ready(id)
	if reloading:
		_ring.fraction = _player.reload_progress()
	else:
		_ring.fraction = raid.shot_progress() if shown >= int(w["ammo_per_shot"]) else 0.0  # an empty magazine waits for R
	var cone := tan(float(w["spread"])) / tan(deg_to_rad(_player._cam.fov) / 2.0) * get_viewport().get_visible_rect().size.y / 2.0
	_ring.radius = 44.0 if _player.scoped else maxf(cone, 12.0) + 12.0

func _process(_d: float) -> void:
	if raid == null:
		return
	if raid.picks_pending > 0 and _pick_layer == null and raid.state == raid.State.ACTIVE:
		if raid.pick_choices().is_empty():  # nothing left to offer: never show an empty level-up screen
			raid.picks_pending = 0
		else:
			_open_pick()
	_banner_time = maxf(_banner_time - _d, 0.0)
	_zone_time = maxf(_zone_time - _d, 0.0)
	_zone_label.visible = _zone_time > 0.0
	_banner.visible = _banner_time > 0.0
	var hold := raid.hold_seconds_for(raid.extract_zone) if raid.extracting else raid.hold_seconds
	_update_status_hud()
	_hud.text = "%s %s\n%s%s" % ["[SAFE]" if _player.safe else "", raid.powerup_text(), _enemy_status(), ("\n" + raid.attachment_text()) if raid.attachment_text() != "" else ""]
	_update_threat_hud()
	for z in extract_zones:
		var shown := beam_shown(z)
		z["beam"].visible = shown
		z["label"].visible = shown
		z["mat"].albedo_color = Color(1, 0.9, 0.1, 0.45) if raid.extracting and raid.extract_zone == z["id"] else z["color"]
	_extract_box.visible = raid.extracting
	var second := int(raid.extract_elapsed) if raid.extracting else -1
	if second != _last_tick:
		_last_tick = second
		if second >= 0:
			Sfx.play("extract_tick")
	if raid.extracting:
		_extract_label.text = "EXTRACTING (%s)  %.1f s" % [EXTRACT_ZONES[raid.extract_zone]["name"], maxf(hold - raid.extract_elapsed, 0.0)]
		_extract_bar.max_value = hold
		_extract_bar.value = raid.extract_elapsed

func _on_picked_up(id: String, qty: int) -> void:
	Sfx.play("pickup")
	_feed_row(id, "+%d %s" % [qty, id.replace("_", " ")])

# What the threat clock HUD shows now: {"mode": "countdown" | "converging" | "none", "seconds", "tone": "normal" |
# "amber" | "red"}. A countdown from the start of the raid; amber and red as it runs low; once it has fired,
# "converging" for as long as patrols are converging.
func threat_hud_state() -> Dictionary:
	var left: float = raid.threat_countdown()
	if left >= 0.0:
		var tone := "red" if left <= Tuning.THREAT_COUNTDOWN_RED_SECONDS else ("amber" if left <= Tuning.THREAT_COUNTDOWN_AMBER_SECONDS else "normal")
		return {"mode": "countdown", "seconds": left, "tone": tone}
	if raid.threat_active:
		return {"mode": "converging", "seconds": 0.0, "tone": "red"}
	return {"mode": "none", "seconds": 0.0, "tone": "normal"}

# The extract zone nearest the player (straight line) and the arrow's angle to it: 0 = straight ahead.
func nearest_extract_bearing() -> Dictionary:
	var best: Dictionary = extract_zones[0]
	var p := _player.global_position
	for z in extract_zones:
		if Vector2(p.x - z["pos"].x, p.z - z["pos"].z).length() < Vector2(p.x - best["pos"].x, p.z - best["pos"].z).length():
			best = z
	var to := Vector3(best["pos"].x - p.x, 0, best["pos"].z - p.z)
	var local := _player.global_transform.basis.inverse() * to
	return {"zone": best, "angle": atan2(local.x, -local.z), "distance": to.length()}

# True when the arrow toward the nearest extract zone is up: only after the clock has fired, and only if
# the setting is on.
func tick_shown() -> bool:
	return bool(extract_cfg["threat_tick"]) and raid.threat_fired() and raid.state == raid.State.ACTIVE

func _update_threat_hud() -> void:
	var st := threat_hud_state()
	var colors := {"normal": Color(1, 1, 1, 0.9), "amber": Color(1, 0.75, 0.1), "red": Color(1, 0.2, 0.2)}
	_threat_label.add_theme_color_override("font_color", colors[st["tone"]])
	match st["mode"]:
		"countdown":
			var secs := int(ceil(st["seconds"]))
			_threat_label.text = "THREAT CLOCK  %d:%02d" % [secs / 60, secs % 60]
		"converging":
			_threat_label.text = "PATROLS CONVERGING"
		_:
			_threat_label.text = ""
	_tick.shown = tick_shown()
	if _tick.shown:
		var b := nearest_extract_bearing()
		_tick.angle = b["angle"]
		_tick.text = "%s %.0f m" % ["SAFE" if b["zone"]["id"] == "A" else "FAST", b["distance"]]

# A shot landed on an enemy: say so when it hit a weak point or the armor.
func _on_zone_hit(zone: String) -> void:
	match zone:
		"head": _zone_label.text = "HEADSHOT"
		"back": _zone_label.text = "WEAK POINT"
		"front": _zone_label.text = "ARMORED"
		_: return
	_zone_label.add_theme_color_override("font_color", Enemies.STRONG_COLOR.lightened(0.3) if zone == "front" else Enemies.WEAK_COLOR)
	_zone_time = 0.5

# One pellet's flight, from the muzzle to where it landed.
func _on_bullet(weapon_id: String, end: Vector3, normal: Vector3, kind: String) -> void:
	var t := Tracer.new()
	t.from = _player.muzzle_position()
	t.to = end
	t.normal = normal
	t.kind = kind
	t.cfg = WeaponData.DATA[weapon_id]["tracer"]
	add_child(t)

# Esc during a raid: pause and show the controls; Esc again or the button resumes.
func _open_pause() -> void:
	if get_tree().paused or raid.state != raid.State.ACTIVE:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 11
	add_child(_pause_layer)
	var menu := PauseMenu.new()
	_pause_layer.add_child(menu)
	menu.show_menu(_resume)

func _resume() -> void:
	_pause_layer.queue_free()
	_pause_layer = null
	get_tree().paused = false
	if not _player.inventory_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# A level-up: pause and offer upgrades; taking one resumes (and offers the next, if several were earned).
func _open_pick() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pick_layer = CanvasLayer.new()
	_pick_layer.layer = 9
	add_child(_pick_layer)
	var screen := UpgradePick.new()
	_pick_layer.add_child(screen)
	screen.show_choices(raid.pick_choices(), raid.upgrades, _picked)

func _picked(id: String) -> void:
	raid.choose_upgrade(id)
	Sfx.play("switch")
	_pick_layer.queue_free()
	_pick_layer = null
	get_tree().paused = false
	if not _player.inventory_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_threat_started() -> void:
	_banner.text = "THEY KNOW WHERE YOU ARE\nPatrols are closing in and will keep coming" if raid.threat_continuous \
		else "THEY KNOW WHERE YOU ARE\nA patrol wave is heading for your position"
	_banner_time = 7.0
	Sfx.play("threat")

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

func _on_zone_body(body: Node3D, inside: bool, zone_id: String) -> void:
	if body != _player:
		return
	if inside:
		raid.request_extract(zone_id)
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
	screen.show_result(result, depth + 1, _return_to_base, _descend.bind(result["items"]))

func _return_to_base() -> void:
	depth = 0
	carry = {}
	run_upgrades = {}
	show_start = true
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

# Applies the raid difficulty (data/difficulty.gd) to the map just built. It changes how many enemies there
# are and how they behave, never the terrain, so a map number is the same map on every difficulty.
func _apply_difficulty(d: Dictionary) -> void:
	var scale := Enemies.round_scale(depth)  # each level down makes enemies tougher, up to the cap
	var diff_rng := RandomNumberGenerator.new()  # its own stream, so the map's rng is untouched
	diff_rng.seed = _seed + 1
	var groups := {}
	for c in get_children():
		if "stats" in c:
			groups[c.group_id] = groups.get(c.group_id, []) + [c]
	for g in groups:
		var members: Array = groups[g]
		var want := maxi(1, int(round(members.size() * float(d["patrols"]))))
		for i in range(want, members.size()):  # fewer: drop the extras
			members[i].queue_free()
		for i in range(members.size(), want):  # more: add newcomers at the patrol's home
			var e := Enemy.new()
			e.stats = Enemies.roll(diff_rng)
			e.home = members[0].home
			e.group_id = g
			var spread: float = Tuning.GROUP_SPREAD
			e.position = e.home + Vector3(diff_rng.randf_range(-spread, spread), 0, diff_rng.randf_range(-spread, spread))
			add_child(e)
			members.append(e)
	for c in get_children():
		if "stats" in c and not c.is_queued_for_deletion():
			c.apply_difficulty(float(d["damage"]), float(d["awareness"]))
			c.apply_depth(scale["health"], scale["speed"], scale["damage"])
	for sp in _spawners:
		sp.round_scale = scale
		sp.interval = maxf(float(d["bases"]["interval"]) * pow(Tuning.DEPTH_INTERVAL_MULT, depth), minf(Tuning.DEPTH_MIN_INTERVAL, float(d["bases"]["interval"])))
		sp.max_alive = int(d["bases"]["max_alive"]) + depth / Tuning.DEPTH_MAX_ALIVE_EVERY
		sp.damage_mult = float(d["damage"])
		sp.detect_seconds = float(d["awareness"])

# Deeper levels have more enemy bases. They come from their own RNG stream (swapped in for the map's while they
# are placed), so the map underneath is the one its seed makes; a base too near an extract zone is moved.
func _add_depth_bases() -> void:
	var extra := mini(depth * Tuning.DEPTH_EXTRA_SPAWNERS, Tuning.DEPTH_MAX_EXTRA_SPAWNERS)
	if extra <= 0:
		return
	var map_rng := rng
	rng = RandomNumberGenerator.new()
	rng.seed = _seed + 2
	for i in extra:
		for attempt in 6:
			_place_spawner(_spawners.size())
			var sp: Node3D = _spawners.back()
			if extract_zones.all(func(z): return Vector2(z["pos"].x - sp.position.x, z["pos"].z - sp.position.z).length() >= Tuning.EXTRACT_MIN_BASE_DISTANCE):
				_garrison(sp)
				break
			_spawners.pop_back()
			sp.free()
	rng = map_rng

# The map a seed makes, as data for the base's map table: builds the map's nodes off the scene tree,
# reads them back, and frees them. The same seed gives the same map in the raid.
func preview(map_seed: int) -> Dictionary:
	var m = load("res://scripts/main.gd").new()
	m.rng.seed = map_seed
	m._build_map()
	var groups := {}
	for c in m.get_children():
		if "stats" in c:
			groups[c.home] = true
	var data := {"w": m.half_w * 2.0, "d": m.half_d * 2.0, "blocks": m.blocks, "extract": m.extract_pos, "extracts": m.extract_zones.map(func(z): return {"id": z["id"], "pos": z["pos"]}),
		"spawners": m._spawners.map(func(sp): return sp.position), "groups": groups.keys(),
		"rooms": m.structures.size(), "cover": m._cover.size(), "type": m.map_type}
	m.free()
	return data

# Stay in the raid: the loot just extracted comes back out of the stash into the next level's backpack (at risk
# again) and the next map is a fresh one derived from this map's number.
func _descend(items: Dictionary) -> void:
	profile.take_items(items)
	profile.save()
	carry = items
	run_upgrades = raid.upgrades.duplicate()
	depth += 1
	chosen_seed = absi(("descend:%d" % _seed).hash()) % 1000000
	show_start = false
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func _next_raid(map_seed := -1) -> void:
	depth = 0
	carry = {}
	run_upgrades = {}
	chosen_seed = map_seed
	show_start = false
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func _set_safe(body: Node3D, value: bool) -> void:
	if body == _player:
		_player.safe = value

# The starting map as data, written to the first line of each raid's log (scripts/telemetry.gd).
# Add anything new about the map here.
func _map_info() -> Dictionary:
	var zones: Array = []
	for st in structures:
		zones.append({"id": st["id"], "center": st["center"], "size": st["size"], "door": st["door"]})
	var enemies: Array = []
	var crates: Array = []
	for c in get_children():
		if "stats" in c:
			enemies.append({"id": c.stats["type"], "mod": c.stats["modifier"], "group": c.group_id, "pos": c.position})
		elif c.is_in_group("lootable"):
			crates.append({"zone": c.zone_id, "pos": c.position})
	return {"type": map_type, "w": half_w * 2.0, "d": half_d * 2.0, "extract": extract_pos, "extracts": extract_zones.map(func(z): return z["pos"]), "shelters": shelters,
		"zones": zones, "buildings": buildings.map(func(b): return {"id": b["id"], "pos": b["pos"]}), "spawners": _spawners.map(func(sp): return sp.position), "enemies": enemies, "crates": crates}

# An enemy base: a small footprint reserved like a group, far from the start and (when the map has room)
# SPAWNER_MIN_SEPARATION m from every other base. See scripts/spawner.gd.
func _place_spawner(index: int) -> void:
	var apart: float = Tuning.SPAWNER_NARROW_SEPARATION if map_type == "narrow" else Tuning.SPAWNER_MIN_SEPARATION
	var pos := _base_spot()
	for attempt in 30:
		if _spawners.all(func(o): return Vector2(o.position.x - pos.x, o.position.z - pos.z).length() >= apart):
			break
		_taken.pop_back()  # _base_spot reserved this spot; give it back and draw another
		pos = _base_spot()
	var sp := Spawner.new()
	sp.position = pos
	sp.group_id = Tuning.ENEMY_GROUP_COUNT + index
	sp.rng_seed = rng.randi()
	add_child(sp)
	_spawners.append(sp)
	solids.append(Rect2(Vector2(pos.x - 1.0, pos.z - 1.0), Vector2(2, 2)))

# A spot for a base with the ground around it for its garrison kept clear of cover; a crowded map falls back to the bare
# 2x2 footprint.
func _base_spot() -> Vector3:
	var half := Tuning.SPAWNER_CLUSTER_MAX + 1.0
	var p = _free_spot(half, half, Tuning.SPAWNER_MIN_ORIGIN, false)
	return p if p != null else _free_spot(2.0, 2.0, Tuning.SPAWNER_MIN_ORIGIN)

# The base's starting defenders: a cluster standing SPAWNER_CLUSTER_MIN..MAX m around it, in the base's own group so
# the base counts them toward its cap. Drawn from a stream of its own (the base's seed), never the map's.
func _garrison(sp: Node3D) -> void:
	var grng := RandomNumberGenerator.new()
	grng.seed = sp.rng_seed + 1
	for i in grng.randi_range(Tuning.SPAWNER_GARRISON_MIN, Tuning.SPAWNER_GARRISON_MAX):
		var e := Enemy.new()
		e.stats = Enemies.roll(grng)
		e.home = sp.position
		e.group_id = sp.group_id
		e.patrol_radius = Tuning.SPAWNER_PATROL_RADIUS
		for attempt in 8:  # not inside a wall or box: take the first of a few draws that is clear
			var a := grng.randf() * TAU
			e.position = sp.position + Vector3(cos(a), 0, sin(a)) * grng.randf_range(Tuning.SPAWNER_CLUSTER_MIN, Tuning.SPAWNER_CLUSTER_MAX)
			if not solids.any(func(r): return r.grow(0.6).has_point(Vector2(e.position.x, e.position.z))):
				break
		add_child(e)

# --- map generation -------------------------------------------------------------

# Picks the map's width and depth: a floor area that grows with the number of enemy bases, split by a random aspect ratio,
# so some maps are long and narrow, some wide, some near square.
func _roll_map_size() -> void:
	var aspect := exp(rng.randf_range(log(Tuning.MAP_ASPECT_MIN), log(Tuning.MAP_ASPECT_MAX)))
	var area := maxf(Tuning.MAP_AREA, Tuning.MAP_AREA_PER_BASE * (Tuning.SPAWNER_COUNT + mini(depth * Tuning.DEPTH_EXTRA_SPAWNERS, Tuning.DEPTH_MAX_EXTRA_SPAWNERS)))  # more bases, bigger map
	var w := clampf(sqrt(area * aspect), Tuning.MAP_MIN_SIDE, Tuning.MAP_MAX_SIDE)
	var d := clampf(area / w, Tuning.MAP_MIN_SIDE, Tuning.MAP_MAX_SIDE)
	half_w = roundf(w) / 2.0
	half_d = roundf(d) / 2.0

# Rolls the map's type from a stream of its own, so an open map is the map its seed always made. A narrow map is a
# long thin lane: the player starts near one end and the safe extract is far down the other.
func _roll_map_type() -> void:
	var trng := RandomNumberGenerator.new()
	trng.seed = ("maptype:%d" % rng.seed).hash()
	map_type = Rng.pick(Tuning.MAP_TYPES, trng)
	if map_type != "narrow":
		return
	var t: Dictionary = Tuning.MAP_TYPES["narrow"]
	half_w = roundf(trng.randf_range(t["width"][0], t["width"][1])) / 2.0
	half_d = roundf(trng.randf_range(t["length"][0], t["length"][1])) / 2.0
	_start = Vector3(0, 0, half_d - float(t["start_inset"]))
	extract_cfg["a_min_path"] = maxf(float(extract_cfg["a_min_path"]), half_d * 1.4)

# Narrow maps: a wall across the lane every gate_every m with a gap, the gap on alternating sides. A gate that does
# not fit among what is already placed (the start, the old extract pad) is skipped.
func _place_gates() -> void:
	if map_type != "narrow":
		return
	var t: Dictionary = Tuning.MAP_TYPES["narrow"]
	var gap: float = t["gap"]
	var left := rng.randi_range(0, 1) == 0
	var z: float = _start.z - float(t["gate_first"])
	while z > -half_d + float(t["gate_first"]) * 0.5:
		var gap_x := half_w * 0.45 * (-1.0 if left else 1.0)
		var pieces := [[-half_w, gap_x - gap / 2.0], [gap_x + gap / 2.0, half_w]]
		var fits := _is_clear(Vector3(gap_x, 0, z), gap / 2.0, 0.5)
		for pc in pieces:
			fits = fits and _is_clear(Vector3((pc[0] + pc[1]) / 2.0, 0, z), (pc[1] - pc[0]) / 2.0, 0.5)
		if fits:
			_taken.append([Vector3(gap_x, 0, z), gap / 2.0, 0.5])
			for pc in pieces:
				var wlen: float = pc[1] - pc[0]
				var c := Vector3((pc[0] + pc[1]) / 2.0, 0, z)
				_taken.append([c, wlen / 2.0, 0.5])
				_add_box(Vector3(wlen, 3.5, 1.0), c + Vector3(0, 1.75, 0), Color(0.45, 0.43, 0.42), WALL_MODEL)
		left = not left
		z -= float(t["gate_every"])

# Watch towers, from a stream of their own (so the cover is the cover the seed always made, minus the room they take).
func _place_towers() -> void:
	var trng := RandomNumberGenerator.new()
	trng.seed = ("towers:%d" % rng.seed).hash()
	var map_rng := rng
	rng = trng
	for i in Tuning.TOWER_COUNT:
		var p = _free_spot(2.7, 2.7, 10.0, false)
		if p != null:
			_add_tower(p, rng.randi_range(0, 3))
	rng = map_rng

# Walkable buildings (data/buildings.gd): Buildings.COUNT of them, each a scene from scenes/buildings/. Drawn from a stream of
# the map seed's own, like the towers, and a building with no clear spot is skipped. They go in before the cover so there is room.
func _place_buildings() -> void:
	var brng := RandomNumberGenerator.new()
	brng.seed = ("buildings:%d" % rng.seed).hash()
	var map_rng := rng
	rng = brng
	var ids: Array = Buildings.DATA.keys()
	var total := 0
	for id in ids:
		total += int(Buildings.DATA[id]["weight"])
	for i in rng.randi_range(Buildings.COUNT[0], Buildings.COUNT[1]):
		var roll := rng.randi_range(1, total)
		for id in ids:
			roll -= int(Buildings.DATA[id]["weight"])
			if roll <= 0:
				_add_building(id, Buildings.DATA[id])
				break
	rng = map_rng

# One building at a clear spot, turned a random quarter turn, then turned round if its door (local +z) would face the outer wall.
# Its CrateSpots markers (tools/build_buildings.gd) give the floor spots; a random few get loot crates.
func _add_building(id: String, def: Dictionary) -> void:
	var turn := rng.randi_range(0, 3)
	var size := Vector2(def["size"][0], def["size"][1])
	if turn % 2 == 1:
		size = Vector2(size.y, size.x)
	var p = _free_spot(size.x / 2.0, size.y / 2.0, 10.0, false)
	if p == null:
		return
	if Vector3(0, 0, 1).rotated(Vector3.UP, turn * PI / 2.0).dot(p) > 0.0:
		turn = (turn + 2) % 4
	var node: Node3D = (load(def["scene"]) as PackedScene).instantiate()
	node.position = p
	node.rotation.y = turn * PI / 2.0
	add_child(node)
	var rect := Rect2(Vector2(p.x - size.x / 2.0, p.z - size.y / 2.0), size)
	solids.append(rect)
	buildings.append({"id": id, "pos": p, "rect": rect})
	var spots: Array = node.get_node("CrateSpots").get_children()
	for i in range(spots.size() - 1, 0, -1):  # shuffled from the map's stream, not Array.shuffle's global one
		var j := rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	var crates: Array = def["crates"]
	for m in spots.slice(0, mini(rng.randi_range(crates[0], crates[1]), spots.size())):
		var c := Crate.new()
		c.seed_value = rng.randi()
		c.zone_id = Buildings.CRATE_ZONE_ID
		c.color = Buildings.CRATE_COLOR
		c.position = node.transform * (m.position + Vector3(0, 0.5, 0))
		add_child(c)

# A deck on four legs with a rail on three sides and a ladder up the fourth (`ladder_side`, see _side_normal).
func _add_tower(pos: Vector3, ladder_side: int) -> void:
	var size: float = Scenery.TOWER_SIZE
	var h: float = Scenery.TOWER_HEIGHT
	var half := size / 2.0
	var color: Color = Scenery.TOWER_COLOR
	_add_box(Vector3(size, 0.3, size), pos + Vector3(0, h - 0.15, 0), color, FLOOR_MODEL)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_add_box(Vector3(0.3, h - 0.3, 0.3), pos + Vector3(cx * (half - 0.15), (h - 0.3) / 2.0, cz * (half - 0.15)), color)
	for s in 4:
		if s == ladder_side:
			continue
		var sn := _side_normal(s)
		var rail := Vector3(size, 1.0, 0.15) if absf(sn.z) > 0.5 else Vector3(0.15, 1.0, size)
		_add_box(rail, pos + sn * (half - 0.075) + Vector3(0, h + 0.5, 0), color)
	var n := _side_normal(ladder_side)
	var ladder := Ladder.new()
	ladder.top_y = h + 0.1
	ladder.height = h + 0.2
	ladder.facing = -n
	ladder.position = pos + n * (half + 0.05)
	ladder.rotation.y = atan2(n.x, n.z)  # local +Z is outward
	add_child(ladder)
	towers.append({"pos": pos, "ladder": ladder, "top": h})

# A random point where a footprint of half-size (hx, hz) stays PATH_GAP away from the outer wall.
func _random_point(hx: float, hz: float) -> Vector3:
	var rx := maxf(half_w - hx - _gap, 0.0)
	var rz := maxf(half_d - hz - _gap, 0.0)
	return Vector3(rng.randf_range(-rx, rx), 0, rng.randf_range(-rz, rz))

# True if a footprint centred at p keeps PATH_GAP of walkable space from everything placed.
func _is_clear(p: Vector3, hx: float, hz: float) -> bool:
	for t in _taken:
		if absf(p.x - t[0].x) < t[1] + hx + _gap and absf(p.z - t[0].z) < t[2] + hz + _gap:
			return false
	return true

# Picks and reserves a spot for a footprint of half-size (hx, hz), at least min_origin
# from the player's start. With overlap_ok == false it returns null if no clear spot
# is found; otherwise, after SPAWN_TRIES valid samples it accepts overlap, but min_origin
# is never relaxed.
# shortcut: gives up after 1000 samples, so a min_origin near the map size could
# still return a spot inside it; upgrade if min_origin is ever tuned that high.
func _free_spot(hx: float, hz: float, min_origin: float, overlap_ok := true):
	var p := Vector3.ZERO
	var tries := 0
	for i in 1000:
		p = _random_point(hx, hz)
		if (p - _start).length() < min_origin:
			continue
		tries += 1
		if _is_clear(p, hx, hz):
			_taken.append([p, hx, hz])
			return p
		if tries >= Tuning.SPAWN_TRIES:
			break
	if not overlap_ok:
		return null
	_taken.append([p, hx, hz])
	return p

func _inside_map(p: Vector3, half: float) -> bool:
	return absf(p.x) <= half_w - half - _gap and absf(p.z) <= half_d - half - _gap

# Every spot GUARD_DISTANCE to GUARD_DISTANCE + 4 m from the door on `side` of the loot area
# at `center`, within 70 degrees of straight out from the door, that is clear, inside the map
# and at least ENEMY_GROUP_MIN_ORIGIN from the player's start. A grid, not random samples:
# the valid region is often a thin sliver that 40 random tries missed.
func _guard_spots(center: Vector3, size: float, side: int) -> Array:
	var n := _side_normal(side)
	var door := center + n * (size / 2.0)
	var spots: Array = []
	for a in 25:
		for d in 5:
			var p := door + n.rotated(Vector3.UP, -1.2 + a * 0.1) * (Tuning.GUARD_DISTANCE + d)
			if (p - _start).length() >= Tuning.ENEMY_GROUP_MIN_ORIGIN and _inside_map(p, 3.5) and _is_clear(p, 3.5, 3.5):
				spots.append(p)
	return spots

# Rolls a cover box and places it: at a random clear spot, or exactly at `at` if given
# and clear. Skipped (nothing placed) when it doesn't fit with a walkable gap.
func _place_cover(at = null, mix := {}) -> void:
	var type := Rng.pick(mix if not mix.is_empty() else Scenery.COVER_TYPES, rng)
	var t: Dictionary = Scenery.COVER_TYPES[type]
	var xr: Array = t["x"]
	var yr: Array = t["y"]
	var zr: Array = t["z"]
	var size := Vector3(rng.randf_range(xr[0], xr[1]), rng.randf_range(yr[0], yr[1]), rng.randf_range(zr[0], zr[1]))
	if rng.randf() < 0.5:
		size = Vector3(size.z, size.y, size.x)
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	var p = null
	if at == null:
		p = _free_spot(hx, hz, 6.0, false)
	elif absf(at.x) <= half_w - hx - _gap and absf(at.z) <= half_d - hz - _gap \
			and (at - _start).length() >= 6.0 and _is_clear(at, hx, hz):
		p = at
		_taken.append([p, hx, hz])
	if p == null:
		return
	_cover.append(p)
	_add_box(size, p + Vector3(0, size.y / 2.0, 0), t["color"], t.get("model", ""))

# Safe nooks: small, coloured like the cover, door facing a random way, with cover pieces
# placed in front of the door so they are hard to spot from the open. They are placed
# before the general cover so there is still room for them.
func _place_shelters() -> void:
	var half := Scenery.SHELTER_OUTER / 2.0 + 0.2
	for i in SHELTER_COUNT:
		var p: Vector3 = _free_spot(half, half, 8.0)
		var door_side := rng.randi_range(0, 3)
		_add_shelter(p, door_side)
		var dist_range: Array = Scenery.SHELTER_SCREEN_DIST
		for k in Scenery.SHELTER_SCREENS:
			var dir := _side_normal(door_side).rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
			_place_cover(p + dir * rng.randf_range(dist_range[0], dist_range[1]))

func _add_shelter(pos: Vector3, door_side: int) -> void:
	shelters.append(pos)
	_add_room(pos, Scenery.SHELTER_OUTER, door_side, Scenery.SHELTER_DOOR_WIDTH,
		Scenery.SHELTER_HEIGHT, Scenery.SHELTER_WALL, Scenery.SHELTER_COLOR)
	var inner := Scenery.SHELTER_OUTER - Scenery.SHELTER_WALL * 2.0
	var area := Area3D.new()
	area.position = pos + Vector3(0, 1.3, 0)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(inner - 0.2, 2.6, inner - 0.2)
	shape.shape = bs
	area.add_child(shape)
	area.body_entered.connect(_set_safe.bind(true))
	area.body_exited.connect(_set_safe.bind(false))
	add_child(area)

# One of the loot areas: a walled compound with a door and crates inside that roll
# from the area's own loot pool and quantity (data/loot_zones.gd).
func _add_structure(id: String, zone: Dictionary) -> void:
	var size: float = zone["size"]
	var half := size / 2.0 + 0.3
	var center: Vector3 = _free_spot(half, half, 10.0)
	# The guarded area's door goes on a side that has room for the guard group outside it,
	# and the guard spot is reserved now, before later areas, shelters and cover take it.
	var door_side := -1
	if id == Tuning.GUARDED_ZONE:
		var first := rng.randi_range(0, 3)
		for k in 4:
			var spots := _guard_spots(center, size, (first + k) % 4)
			if not spots.is_empty():
				door_side = (first + k) % 4
				_guard_pos = spots[rng.randi_range(0, spots.size() - 1)]
				_taken.append([_guard_pos, 3.5, 3.5])
				break
	# Otherwise the door faces toward the middle of the map, never at a nearby outer wall.
	if door_side < 0:
		var door_sides: Array = []
		for s in 4:
			if _side_normal(s).dot(center.normalized()) < 0.0:
				door_sides.append(s)
		door_side = door_sides[rng.randi_range(0, door_sides.size() - 1)] if not door_sides.is_empty() else rng.randi_range(0, 3)
	var door2_side := door_side ^ 1  # sides 0/1 and 2/3 are opposite walls: a second doorway straight across
	var height: float = zone["height"]
	_add_room(center, size, door_side, float(zone["door"]), height, 0.5, zone["wall_color"], door2_side)
	_dress_building(center, size, height, zone, [door_side, door2_side])
	var floor_mark := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(size - 1.0, 0.02, size - 1.0)
	floor_mark.mesh = fm
	floor_mark.position = center + Vector3(0, 0.011, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = (zone["wall_color"] as Color).lerp(Color(0.3, 0.5, 0.3), 0.5)
	floor_mark.material_override = mat
	add_child(floor_mark)
	var label := Label3D.new()
	label.text = zone["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.position = center + Vector3(0, height + 3.0, 0)
	add_child(label)

	# Crates: against the inside walls (never the door's wall) and apart from each other, so the middle
	# and the doorway stay clear. A crate is 1 m wide and the walls are 0.5 m thick.
	var door_point := center + _side_normal(door_side) * (size / 2.0)
	var edge := size / 2.0 - 1.05
	var entry := center + _side_normal(door_side) * (size / 2.0 - 1.0) + Vector3(0, 0.5, 0)  # 1 m inside the doorway
	var entry2 := center + _side_normal(door2_side) * (size / 2.0 - 1.0) + Vector3(0, 0.5, 0)
	var spots: Array = []
	var crate_range: Array = zone["crates"]
	for round in 10:  # a first crate can leave no room for the next one in a small room: start over
		spots = []
		for i in rng.randi_range(crate_range[0], crate_range[1]):
			for attempt in 40:
				var side := rng.randi_range(0, 3)
				if side == door_side or side == door2_side:
					continue
				var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
				var p := center + _side_normal(side) * edge + along * rng.randf_range(-edge, edge) + Vector3(0, 0.5, 0)
				if p.distance_to(entry) < 1.3 or p.distance_to(entry2) < 1.3:  # keep the ways in clear
					continue
				if spots.all(func(s): return p.distance_to(s) >= 1.2):
					spots.append(p)
					break
		if spots.size() >= int(crate_range[0]):
			break
	for p in spots:
		var c := Crate.new()
		c.seed_value = rng.randi()
		c.zone_id = id
		c.pool = zone["pool"]
		c.qty_mult = zone["qty_mult"]
		c.rolls = zone["rolls"]
		c.color = zone["crate_color"]
		c.position = p
		add_child(c)
	structures.append({"id": id, "center": center, "size": size, "door": door_point, "door2": center + _side_normal(door2_side) * (size / 2.0),
		"rect": Rect2(Vector2(center.x - size / 2.0, center.z - size / 2.0), Vector2(size, size))})

# Sides: 0 = +z, 1 = -z, 2 = +x, 3 = -x.
func _side_normal(side: int) -> Vector3:
	return [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]

# Four walls around a square with a doorway cut into one side (door_side -1 = no door).
func _add_room(center: Vector3, outer: float, door_side: int, door_w: float,
		height: float, thick: float, color: Color, door2_side := -1) -> void:
	for side in 4:
		var n := _side_normal(side)
		var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
		var segments := [[-outer / 2.0, outer / 2.0]]
		if side == door_side or side == door2_side:
			segments = [[-outer / 2.0, -door_w / 2.0], [door_w / 2.0, outer / 2.0]]
		for seg in segments:
			var length: float = seg[1] - seg[0]
			var mid: float = (seg[0] + seg[1]) / 2.0
			var size := Vector3(length, height, thick) if side < 2 else Vector3(thick, height, length)
			var pos := center + n * (outer / 2.0 - thick / 2.0) + along * mid + Vector3(0, height / 2.0, 0)
			_add_box(size, pos, color, WALL_MODEL)

# Looks only, no collision and not in `blocks` or `solids` (so the walk grid and the base map ignore them): a
# roof, a band of trim under it (a lintel over each doorway), and what says what the building is. The armory
# is olive with yellow trim, corner merlons on the roof and rows of rounds painted on its walls; the med post
# is white with green trim, a red cross on its walls and a big red cross standing on the roof.
func _dress_building(center: Vector3, size: float, height: float, zone: Dictionary, doors: Array) -> void:
	var roof_y := height + 0.175
	_deco(Vector3(size + 0.8, 0.35, size + 0.8), center + Vector3(0, roof_y, 0), zone["roof_color"], FLOOR_MODEL)
	for side in 4:
		var n := _side_normal(side)
		var wall_pos := center + n * (size / 2.0 + 0.04)
		_deco(Vector3(size + 0.1, 0.45, 0.1) if side < 2 else Vector3(0.1, 0.45, size + 0.1), wall_pos + Vector3(0, height - 0.5, 0), zone["trim_color"])
		if side in doors:
			continue  # the doorway is in the middle of this wall
		var face := wall_pos + n * 0.02 + Vector3(0, height * 0.5, 0)
		var thin := 0.08
		if zone["style"] == "medical":
			var red := Color(0.85, 0.12, 0.12)
			_deco(Vector3(0.5, 1.6, thin) if side < 2 else Vector3(thin, 1.6, 0.5), face, red)
			_deco(Vector3(1.6, 0.5, thin) if side < 2 else Vector3(thin, 0.5, 1.6), face, red)
		else:
			for k in [-0.7, 0.0, 0.7]:  # three rounds: brass body, copper tip
				var off := Vector3(k, 0, 0) if side < 2 else Vector3(0, 0, k)
				_deco(Vector3(0.4, 1.3, thin) if side < 2 else Vector3(thin, 1.3, 0.4), face + off - Vector3(0, 0.2, 0), zone["trim_color"])
				_deco(Vector3(0.4, 0.35, thin) if side < 2 else Vector3(thin, 0.35, 0.4), face + off + Vector3(0, 0.62, 0), Color(0.75, 0.4, 0.15))
	if zone["style"] == "medical":
		var up := Vector3(0, height + 0.35 + 1.1, 0)
		for dims in [Vector3(0.6, 2.2, 0.6), Vector3(2.2, 0.6, 0.6), Vector3(0.6, 0.6, 2.2)]:
			_deco(dims, center + up, Color(0.85, 0.12, 0.12))
	else:
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_deco(Vector3(0.9, 0.6, 0.9), center + Vector3(sx, 0, sz) * (size / 2.0 + 0.2) + Vector3(0, height + 0.35 + 0.3, 0), zone["roof_color"])

func _deco(size: Vector3, pos: Vector3, color: Color, model := "") -> void:
	if model != "":
		var fitted := Model.load_fitted(model, size, color)
		if fitted != null:
			fitted.position = pos
			add_child(fitted)
			return
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)

# The old single extract zone sat at one end of the map's long axis. The zones are now placed by
# _place_extracts, but this still makes the same two draws from the map's rng and keeps the same footprint
# clear, so that every seed's terrain, crates and enemies stay exactly as they were before the extract work
# (tests/layout_isolation.gd checks this). The cost is an empty 9 m patch at the old spot. Regenerating the
# layout fixtures would let this go.
func _reserve_legacy_extract_pad() -> void:
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var pos: Vector3
	if half_w >= half_d:
		pos = Vector3(side * (half_w - 5.0), 0, rng.randf_range(-(half_d - 6.0), half_d - 6.0))
	else:
		pos = Vector3(rng.randf_range(-(half_w - 6.0), half_w - 6.0), 0, side * (half_d - 5.0))
	_legacy_pad = pos
	_taken.append([pos, 4.5, 4.5])

# --- extract zones ---

# True if the player can see this zone's beam and label: within the reveal radius, or always when the
# always-visible setting is on. (The zone's trigger works either way.)
func beam_shown(z: Dictionary) -> bool:
	if bool(extract_cfg["beam_always_visible"]):
		return true
	var d := Vector2(_player.global_position.x - z["pos"].x, _player.global_position.z - z["pos"].z).length()
	return d <= float(extract_cfg["beam_reveal_radius"])

# Walking distance (m) from the player's start to every 1 m cell of the map, around walls, rooms, cover,
# crates and bases (an obstacle is grown by half a body width). 4-connected, so a little longer than a
# straight line on diagonals; cells that cannot be reached hold -1.
func _walk_grid() -> Dictionary:
	var cols := int(ceil(half_w * 2.0))
	var rows := int(ceil(half_d * 2.0))
	var blocked := PackedByteArray()
	blocked.resize(cols * rows)
	var obstacles: Array = solids.duplicate()
	for c in get_children():
		if "zone_id" in c:  # a crate; not in its group yet when the map is built off the scene tree
			obstacles.append(Rect2(Vector2(c.position.x - 0.5, c.position.z - 0.5), Vector2(1, 1)))
	for r in obstacles:
		var g: Rect2 = r.grow(0.5)
		var x0 := maxi(int(floor(g.position.x + half_w)), 0)
		var x1 := mini(int(floor(g.end.x + half_w - 0.001)), cols - 1)
		var z0 := maxi(int(floor(g.position.y + half_d)), 0)
		var z1 := mini(int(floor(g.end.y + half_d - 0.001)), rows - 1)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				blocked[z * cols + x] = 1
	var dist := PackedInt32Array()
	dist.resize(cols * rows)
	dist.fill(-1)
	var start := clampi(int(floor(half_w + _start.x)), 0, cols - 1) + clampi(int(floor(half_d + _start.z)), 0, rows - 1) * cols
	dist[start] = 0
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var cx := cur % cols
		var cz := cur / cols
		for step in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + step[0]
			var nz: int = cz + step[1]
			if nx < 0 or nz < 0 or nx >= cols or nz >= rows:
				continue
			var ni := nz * cols + nx
			if dist[ni] < 0 and blocked[ni] == 0:
				dist[ni] = dist[cur] + 1
				queue.append(ni)
	return {"dist": dist, "cols": cols, "rows": rows}

func _walk_dist(grid: Dictionary, p: Vector3) -> int:
	var x := int(floor(p.x + half_w))
	var z := int(floor(p.z + half_d))
	if x < 0 or z < 0 or x >= grid["cols"] or z >= grid["rows"]:
		return -1
	return grid["dist"][z * grid["cols"] + x]

# True if `p` satisfies every placement constraint for zone `which` ("A" or "B"); a_pos is where A went.
func _extract_ok(p: Vector3, which: String, a_pos: Vector3, grid: Dictionary) -> bool:
	var d := _walk_dist(grid, p)
	if d < 0:
		return false
	if which == "A":
		if d < float(extract_cfg["a_min_path"]):
			return false
	else:
		if d < float(extract_cfg["b_min_path"]) or d > float(extract_cfg["b_max_path"]):
			return false
		if Vector2(p.x - a_pos.x, p.z - a_pos.z).length() < float(extract_cfg["min_separation"]):
			return false
	for sp in _spawners:
		if Vector2(p.x - sp.position.x, p.z - sp.position.z).length() < float(extract_cfg["min_base_distance"]):
			return false
	var reach: float = Tuning.EXTRACT_ZONE_SIZE / 2.0  # the whole zone stays inside the walls
	if absf(p.x) > half_w - reach or absf(p.z) > half_d - reach:
		return false
	return _extract_open(p, grid)

# True if every cell within EXTRACT_OPEN_RADIUS of p is walkable and reachable: room to stand in the zone.
# (Cover may overlap the edges of the 6 m trigger box; the old extract spot kept 9 m clear, which left no
# room for a zone close to the start.)
func _extract_open(p: Vector3, grid: Dictionary) -> bool:
	var r: int = Tuning.EXTRACT_OPEN_RADIUS
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if _walk_dist(grid, p + Vector3(dx, 0, dz)) < 0:
				return false
	return true

# The cells (indices into the walk grid) a zone could be in by walking distance alone. Drawing from these
# instead of from the whole map keeps the retries few: far fewer draws are wasted on unreachable or wrong-distance spots.
func _extract_cells(grid: Dictionary, which: String) -> Array:
	var cells: Array = []
	var dist: PackedInt32Array = grid["dist"]
	for i in dist.size():
		var d := dist[i]
		if d < 0:
			continue
		if which == "A":
			if d >= float(extract_cfg["a_min_path"]):
				cells.append(i)
		elif d >= float(extract_cfg["b_min_path"]) and d <= float(extract_cfg["b_max_path"]):
			cells.append(i)
	return cells

# The next point from the extract stream that fits zone `which`, or null after EXTRACT_PLACE_TRIES draws.
# Each draw picks a cell from `cells` and a spot inside it.
func _draw_extract(ext: RandomNumberGenerator, which: String, a_pos: Vector3, grid: Dictionary, cells: Array):
	if cells.is_empty():
		return null
	for i in Tuning.EXTRACT_PLACE_TRIES:
		var idx: int = cells[ext.randi_range(0, cells.size() - 1)]
		var p := Vector3((idx % int(grid["cols"])) + ext.randf() - half_w, 0, (idx / int(grid["cols"])) + ext.randf() - half_d)
		if _extract_ok(p, which, a_pos, grid):
			return p
	return null

# Places both zones from a stream of their own, derived from the map seed, so no other part of the map is
# affected by how they are placed. If no pair satisfies the constraints after the bounded retries, it logs a
# clear error and falls back: A at the old single-zone spot, B at the reachable cell whose path distance is
# nearest the middle of B's window.
func _place_extracts() -> void:
	var ext := RandomNumberGenerator.new()
	ext.seed = ("extract:%d" % rng.seed).hash()
	var grid := _walk_grid()
	var cells_a := _extract_cells(grid, "A")
	var cells_b := _extract_cells(grid, "B")
	var a = null
	var b = null
	for attempt in Tuning.EXTRACT_PAIR_RETRIES:
		a = _draw_extract(ext, "A", Vector3.ZERO, grid, cells_a)
		if a == null:
			continue
		b = _draw_extract(ext, "B", a, grid, cells_b)
		if b != null:
			break
	if a == null or b == null:
		var msg := "Extract placement failed for map %d: no %s satisfied the constraints after %d pairs of %d draws; using a fallback." % [
			rng.seed, "zone A" if a == null else "zone B", Tuning.EXTRACT_PAIR_RETRIES, Tuning.EXTRACT_PLACE_TRIES]
		push_error(msg)
		extract_errors.append(msg)
		if a == null:
			a = _legacy_pad
		if b == null:
			b = _extract_fallback_b(grid)
	extract_pos = a
	_make_extract_zone("A", a)
	_make_extract_zone("B", b)

func _extract_fallback_b(grid: Dictionary) -> Vector3:
	var mid := (float(extract_cfg["b_min_path"]) + float(extract_cfg["b_max_path"])) / 2.0
	var best := Vector3.ZERO
	var best_err := INF
	var dist: PackedInt32Array = grid["dist"]
	for i in dist.size():
		if dist[i] >= 0 and absf(dist[i] - mid) < best_err:
			best_err = absf(dist[i] - mid)
			best = Vector3((i % int(grid["cols"])) + 0.5 - half_w, 0, (i / int(grid["cols"])) + 0.5 - half_d)
	return best

# One extract zone: a trigger box, a beam into the sky (the amber one for the noisy fast route) and a label
# with what the player needs to know to choose it: the route and how long the hold is.
func _make_extract_zone(id: String, pos: Vector3) -> void:
	var def: Dictionary = EXTRACT_ZONES[id]
	var size: float = Tuning.EXTRACT_ZONE_SIZE
	var hold: float = Tuning.EXTRACT_HOLD_SECONDS if id == "A" else float(extract_cfg["b_hold"])
	var area := Area3D.new()
	area.position = pos + Vector3(0, 1.5, 0)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, 3, size)
	shape.shape = bs
	area.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := CylinderMesh.new()  # a beam into the sky
	bm.top_radius = size / 3.0
	bm.bottom_radius = size / 2.0
	bm.height = 300.0
	mesh.mesh = bm
	mesh.position.y = bm.height / 2.0 - 1.5  # base on the floor (area sits 1.5 up)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def["color"]
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	area.add_child(mesh)
	var label := Label3D.new()
	label.text = "%s\n%.0f s%s" % [str(def["name"]).to_upper(), hold, "" if id == "A" else " - noisy"]
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.0, 0)
	area.add_child(label)
	add_child(area)
	extract_zones.append({"id": id, "name": def["name"], "pos": pos, "color": def["color"], "area": area,
		"beam": mesh, "label": label, "mat": mat, "hold": hold})

func _add_box(size: Vector3, pos: Vector3, color: Color, model_path := "") -> void:
	blocks.append([size, pos, color])
	if pos.y > 0.0:  # everything above the floor blocks walking
		solids.append(Rect2(Vector2(pos.x - size.x / 2.0, pos.z - size.z / 2.0), Vector2(size.x, size.z)))
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var fitted := Model.load_fitted(model_path, size, color) if model_path != "" else null
	if fitted != null:  # the art; collision above is still the plain box
		body.add_child(fitted)
	else:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material_override = mat
		body.add_child(mesh)
	add_child(body)
