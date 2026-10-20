extends Node3D
# The base of operations: a closed, enemy-free room the player returns to after every raid. A station in the middle of each wall and a map pit in the floor at the centre, each opened with E (or a click)
# while looking at it:
#   STASH       the loot kept from raids
#   ARMORY      choose the starting weapon and upgrade weapons with stash loot
#   CHARACTER   spend attribute points (speed, constitution, weapon handling)
#   MAP PIT     a miniature of the next raid's map seen from above through a glass cover; panels hovering
#               over it (shoot them) change the map number
#   RAID TERMINAL  the button that starts a raid on the map in the pit
# Everything it changes goes through the profile (scripts/profile.gd) and is saved at once.
# main.gd builds this instead of a raid when Main.show_start is true.

const Player = preload("res://scripts/player.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
const Loot = preload("res://data/loot.gd")
const Upgrades = preload("res://data/upgrades.gd")
const Difficulty = preload("res://data/difficulty.gd")
const WeaponData = preload("res://data/weapons.gd")
const Tuning = preload("res://data/tuning.gd")
const Sfx = preload("res://scripts/sfx.gd")
const UIKit = preload("res://scripts/ui_kit.gd")

const HALF_W := 9.0
const HALF_D := 7.0
# The map pit is a funnel: the walls slope down at 45 degrees from the opening in the floor to a smaller
# viewing area at the bottom, so the whole map can be seen from above. A glass cover (the map station)
# walks like floor.
const PIT_DEPTH := 1.5
const PIT_BOTTOM := Vector2(2.4, 1.8)  # the bottom (x, z in m)
const PIT := PIT_BOTTOM + Vector2(2.0, 2.0) * PIT_DEPTH  # the opening in the floor: 45 degrees means 1 m out per 1 m down
const PIT_MAP := Vector2(2.2, 1.6)  # the part of the pit floor the miniature may cover (m)
const STATIONS := {
	"raid": {"name": "RAID TERMINAL", "pos": Vector3(0, 0, -HALF_D + 1.0), "size": Vector3(3.0, 1.6, 0.8), "color": Color(0.2, 0.8, 0.3)},
	"stash": {"name": "STASH", "pos": Vector3(0, 0, HALF_D - 1.0), "size": Vector3(2.6, 1.2, 1.0), "color": Color(0.35, 0.45, 0.75)},
	"armory": {"name": "ARMORY", "pos": Vector3(-HALF_W + 1.0, 0, 0), "size": Vector3(1.0, 1.2, 2.6), "color": Color(0.85, 0.55, 0.2)},
	"character": {"name": "CHARACTER", "pos": Vector3(HALF_W - 1.0, 0, 0), "size": Vector3(1.0, 1.2, 2.6), "color": Color(0.75, 0.35, 0.7)},
	"map": {"name": "MAP PIT", "pos": Vector3(0, 0, 0), "size": Vector3(PIT.x, 0.06, PIT.y), "y": -0.03, "color": Color(0.7, 0.85, 1.0, 0.05)},
}
const STATION_TAGLINES := {
	"raid": "pick your risk and deploy", "stash": "what you brought home", "armory": "choose and sharpen your weapon",
	"character": "train your operator", "map": "choose the next battlefield",
}
# Panels hovering over the map pit, in view while looking at the map: shoot them (or press E close up) to change the map.
const MAP_BUTTONS := {
	"prev": {"label": "<", "name": "Previous map", "x": -0.6, "color": Color(0.8, 0.3, 0.25)},
	"random": {"label": "?", "name": "Random map", "x": 0.0, "color": Color(0.85, 0.75, 0.2)},
	"next": {"label": ">", "name": "Next map", "x": 0.6, "color": Color(0.3, 0.75, 0.35)},
}

var profile  # scripts/profile.gd instance, set by main before add_child
var start_raid := Callable()  # called with the map seed when the player presses START RAID; set by main
var preview_fn := Callable()  # seed -> the map as data (see Main.preview); set by main
var selected_seed := 0  # the map the next raid will be played on
var preview_data := {}  # what the pit currently shows
var player
var open_station := ""  # which station panel is showing, "" if none

var _prompt: Label
var _preview: Node3D  # the miniature in the map pit
var _table_label: Label3D
var _panel: PanelContainer
var _head: VBoxContainer  # the open panel's header
var _content: VBoxContainer
var _status: Label

func _ready() -> void:
	_build_room()
	for id in STATIONS:
		_add_station(id)
	_add_map_buttons()
	player = Player.new()
	player.position = Vector3(0, 0.1, 4.2)
	add_child(player)
	player.station_used.connect(_on_station_used)
	player.ui_closed.connect(_hide_panel)
	_add_scoreboard()
	_build_ui()
	set_seed(randi() % 1000000)

func _process(_d: float) -> void:
	var hit: Dictionary = player._cast(3.0)
	var what := ""
	if not hit.is_empty() and open_station == "":
		var body: Node = hit["collider"]
		if body.is_in_group("station"):
			what = STATIONS[body.get_meta("station_id")]["name"]
		elif body.is_in_group("shootable"):
			what = MAP_BUTTONS[body.get_meta("action")]["name"]
	_prompt.text = "[E]  %s" % what if what != "" else ""

# --- the room ---

func _build_room() -> void:
	var floor_color := Color(0.32, 0.32, 0.36)
	var wall_color := Color(0.5, 0.5, 0.55)
	# The floor is four slabs around the map pit, and the pit has its own floor PIT_DEPTH down.
	var strip := (HALF_D - PIT.y / 2.0)
	var side := (HALF_W - PIT.x / 2.0)
	var slab := PIT_DEPTH + 0.2  # thick enough that the pit's walls are solid all the way down
	for s in [-1, 1]:
		_box(Vector3(HALF_W * 2.0, slab, strip), Vector3(0, -slab / 2.0, s * (PIT.y / 2.0 + strip / 2.0)), floor_color)
		_box(Vector3(side, slab, PIT.y), Vector3(s * (PIT.x / 2.0 + side / 2.0), -slab / 2.0, 0), floor_color)
	_box(Vector3(PIT_BOTTOM.x, 1, PIT_BOTTOM.y), Vector3(0, -PIT_DEPTH - 0.5, 0), Color(0.28, 0.3, 0.28))
	_add_pit_slopes()
	var pit_light := OmniLight3D.new()  # lights the miniature below the floor
	pit_light.position = Vector3(0, -0.6, 0)
	pit_light.omni_range = 7.0
	pit_light.light_energy = 1.2
	add_child(pit_light)
	_box(Vector3(HALF_W * 2.0, 0.5, HALF_D * 2.0), Vector3(0, 4.25, 0), wall_color)  # ceiling
	for s in [-1, 1]:
		_box(Vector3(HALF_W * 2.0 + 1.0, 4, 0.5), Vector3(0, 2, s * (HALF_D + 0.25)), wall_color)
		_box(Vector3(0.5, 4, HALF_D * 2.0), Vector3(s * (HALF_W + 0.25), 2, 0), wall_color)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.6, 0)
	light.omni_range = 24.0
	light.light_energy = 1.6
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.08, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)

# Four 45 degree slabs from the rim of the opening down to the edge of the pit floor. Each is a thin box
# whose long side runs down the slope: tilted about X for the north and south walls, about Z for west and east.
func _add_pit_slopes() -> void:
	var slope_color := Color(0.5, 0.52, 0.58)
	var length := PIT_DEPTH * sqrt(2.0)
	var mid := (PIT.y + PIT_BOTTOM.y) / 4.0  # halfway between rim and bottom edge, from the centre
	var mid_x := (PIT.x + PIT_BOTTOM.x) / 4.0
	var north := _box(Vector3(PIT.x, 0.1, length), Vector3(0, -PIT_DEPTH / 2.0, -mid), slope_color)
	north.rotation_degrees.x = 45.0
	var south := _box(Vector3(PIT.x, 0.1, length), Vector3(0, -PIT_DEPTH / 2.0, mid), slope_color)
	south.rotation_degrees.x = 135.0
	var west := _box(Vector3(length, 0.1, PIT.y), Vector3(-mid_x, -PIT_DEPTH / 2.0, 0), slope_color)
	west.rotation_degrees.z = -45.0
	var east := _box(Vector3(length, 0.1, PIT.y), Vector3(mid_x, -PIT_DEPTH / 2.0, 0), slope_color)
	east.rotation_degrees.z = -135.0

func _box(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
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
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body

func _add_station(id: String) -> void:
	var d: Dictionary = STATIONS[id]
	var size: Vector3 = d["size"]
	var pos: Vector3 = d["pos"]
	var body := _box(size, Vector3(pos.x, float(d.get("y", size.y / 2.0)), pos.z), d["color"])
	body.add_to_group("station")
	body.set_meta("station_id", id)
	var label := Label3D.new()
	label.text = d["name"]
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.9, -0.6) if id == "map" else Vector3(0, size.y / 2.0 + 0.7, 0)  # the map's label floats over the pit, above the buttons
	body.add_child(label)
	if id == "map":
		_table_label = label

func _add_map_buttons() -> void:
	for id in MAP_BUTTONS:
		var d: Dictionary = MAP_BUTTONS[id]
		var body := _box(Vector3(0.45, 0.45, 0.06), Vector3(d["x"], 0.3, -0.6), d["color"])
		body.rotation_degrees.x = -35.0  # leans back so its face points up toward a player looking down at the map
		body.collision_layer = 2  # shots and E reach it, but the player walks through it
		body.collision_mask = 0
		body.add_to_group("shootable")
		body.set_meta("action", id)
		var label := Label3D.new()
		label.text = d["label"]
		label.font_size = 90
		label.outline_size = 8
		label.position = Vector3(0, 0, 0.04)
		body.add_child(label)

# --- the map pit ---

func _map_button(action: String) -> void:
	match action:
		"prev": set_seed(selected_seed - 1)
		"next": set_seed(selected_seed + 1)
		"random": set_seed(randi() % 1000000)
	Sfx.play("switch")
	if open_station == "map":
		_refresh()

# Picks the map for the next raid and redraws the miniature in the pit.
func set_seed(map_seed: int) -> void:
	selected_seed = maxi(map_seed, 0)
	if _table_label != null:
		_table_label.text = "MAP PIT\nmap %d" % selected_seed
	if _preview != null:
		_preview.queue_free()
		_preview = null
	if not preview_fn.is_valid():
		return
	preview_data = preview_fn.call(selected_seed)
	_preview = _build_miniature(preview_data)
	add_child(_preview)

# The map as a scaled-down model: every wall and cover box, the green extract beam, the red enemy-base
# beams and an orange dot at each patrol. The model is in map units, scaled to fit the pit floor.
func _build_miniature(data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * minf(PIT_MAP.x / float(data["w"]), PIT_MAP.y / float(data["d"]))
	root.position = Vector3(0, -PIT_DEPTH, 0)  # on the pit floor, seen from above through the glass
	for b in data["blocks"]:
		_mini_mesh(root, BoxMesh.new(), b[0], b[1], b[2])
	for z in data["extracts"]:  # A (safe route) green, B (fast route) amber, like the beams in the raid
		_mini_marker(root, z["pos"], 3.0, 9.0, Color(0.2, 1, 0.3, 0.7) if z["id"] == "A" else Color(1, 0.6, 0.1, 0.7))
	for sp in data["spawners"]:
		_mini_marker(root, sp, 1.6, 9.0, Color(1, 0.15, 0.1, 0.7))
	for g in data["groups"]:
		var s := SphereMesh.new()
		s.radius = 1.3
		s.height = 2.6
		_mini_mesh(root, s, Vector3.ONE, g + Vector3(0, 1.5, 0), Color(1, 0.6, 0.1))
	return root

func _mini_mesh(parent: Node3D, mesh: Mesh, size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	if mesh is BoxMesh:
		mesh.size = size
	m.mesh = mesh
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func _mini_marker(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	_mini_mesh(parent, c, Vector3.ONE, pos + Vector3(0, height / 2.0, 0), color)

# --- the wall scoreboard ---

# What the board shows, as [caption, value] pairs, from the profile's lifetime stats.
func scoreboard_rows() -> Array:
	var s: Dictionary = profile.stats
	var acc: int = profile.accuracy()
	var runs: int = s["runs"]
	return [["RUNS", str(runs)], ["EXTRACTED", str(s["extracts"])], ["KILLED IN ACTION", str(s["deaths"])],
		["SURVIVAL", "-" if runs == 0 else "%d%%" % int(round(100.0 * s["extracts"] / runs))],
		["KILLS", str(s["kills"])], ["SHOTS FIRED", str(s["shots"])],
		["ACCURACY", "-" if acc < 0 else "%d%%" % acc], ["DEEPEST LEVEL", str(s["deepest"])]]

# A board on the north wall beside the raid terminal: two rows of four big numbers.
func _add_scoreboard() -> void:
	var cx := 5.5
	var z := -HALF_D + 0.05
	_box(Vector3(6.4, 2.9, 0.04), Vector3(cx, 2.1, z), UIKit.AMBER)  # the frame
	_box(Vector3(6.2, 2.7, 0.06), Vector3(cx, 2.1, z + 0.02), Color(0.04, 0.045, 0.06))
	var title := Label3D.new()
	title.text = "RAID LEDGER"
	title.font = UIKit.bold()
	title.font_size = 96
	title.pixel_size = 0.004
	title.modulate = UIKit.AMBER
	title.position = Vector3(cx, 3.12, z + 0.07)
	add_child(title)
	var rows := scoreboard_rows()
	for i in rows.size():
		var x := cx - 2.3 + (i % 4) * 1.53
		var y := 2.45 - (i / 4) * 1.15
		var value := Label3D.new()
		value.text = rows[i][1]
		value.font = UIKit.bold()
		value.font_size = 120
		value.pixel_size = 0.004
		value.position = Vector3(x, y, z + 0.07)
		add_child(value)
		var caption := Label3D.new()
		caption.text = rows[i][0]
		caption.font_size = 36
		caption.pixel_size = 0.004
		caption.modulate = UIKit.DIM
		caption.position = Vector3(x, y - 0.38, z + 0.07)
		add_child(caption)

# --- panels ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := UIKit.label("WASD MOVE    E / CLICK USE A STATION    SHOOT THE  < ? >  PANELS TO CHANGE MAP    ESC CLOSE", 13, UIKit.DIM)
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_prompt = UIKit.label("", 24, UIKit.AMBER, true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = 50
	var cross := UIKit.label("+", 16, UIKit.AMBER)
	layer.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.visible = false
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_head = VBoxContainer.new()
	box.add_child(_head)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	box.add_child(_content)
	_status = UIKit.label("", 14, UIKit.AMBER)
	box.add_child(_status)
	var close := Button.new()
	close.text = "CLOSE  [ESC]"
	close.pressed.connect(_close)
	box.add_child(close)

func _on_station_used(station: Node) -> void:
	if station.has_meta("action"):  # a pad by the map pit, not a panel
		_map_button(station.get_meta("action"))
		return
	open_station = station.get_meta("station_id")
	_status.text = ""
	var accent: Color = STATIONS[open_station]["color"]
	accent.a = 1.0
	_panel.theme = UIKit.theme(accent)
	_panel.add_theme_stylebox_override("panel", UIKit.slab(UIKit.BG, accent, 10, 20))
	for c in _head.get_children():
		_head.remove_child(c)
		c.queue_free()
	_head.add_child(UIKit.header(STATIONS[open_station]["name"], STATION_TAGLINES[open_station], accent))
	_panel.visible = true
	_refresh()
	player.inventory_open = true  # in the base this flag means "a panel has the mouse"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	player.inventory_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hide_panel()

func _hide_panel() -> void:
	open_station = ""
	_panel.visible = false

func _refresh() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	match open_station:
		"stash": _fill_stash()
		"armory": _fill_armory()
		"character": _fill_character()
		"map": _fill_map()
		"raid": _fill_raid()

# Saves after any change; tells the player if it failed.
func _commit() -> void:
	_status.text = "" if profile.save() else "WARNING: could not save your profile."
	_refresh()

func _accent() -> Color:
	var c: Color = STATIONS[open_station]["color"]
	c.a = 1.0
	return c

func _label(text: String, font_size := 16, color := UIKit.TEXT) -> Label:
	var l := UIKit.label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)
	return l

func _row(parent: Node = null, gap := 8) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", gap)
	(parent if parent != null else _content).add_child(r)
	return r

func _button(parent: Node, text: String, on_press: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b

func _start() -> void:
	if start_raid.is_valid():
		start_raid.call(selected_seed)

func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for id in cost:
		parts.append("%d %s" % [cost[id], str(id).replace("_", " ")])
	return ", ".join(parts)

func _equip(id: String) -> void:
	if profile.equip(id):
		_commit()

func _spend(id: String) -> void:
	if profile.spend_point(id):
		_commit()

func _fill_stash() -> void:
	var a := _accent()
	var row := _row()
	row.add_child(UIKit.tile("extractions", str(profile.stats["extracts"]), a))
	row.add_child(UIKit.tile("frags", str(profile.stats["kills"]), a))
	var count := 0
	for id in profile.totals:
		count += int(profile.totals[id])
	row.add_child(UIKit.tile("items stored", str(count), a))
	if profile.totals.is_empty():
		_label("Nothing stored yet. Extract loot from a raid and it lands here.", 16, UIKit.DIM)
		return
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	var ids: Array = profile.totals.keys()
	ids.sort()
	for id in ids:
		grid.add_child(UIKit.item_tile(id, profile.totals[id], a))

func _fill_armory() -> void:
	var a := _accent()
	_label("Pick the weapon you start raids with. Weapon and character upgrades are won during a raid and are lost when it ends.", 13, UIKit.DIM)
	var most := {"damage": 1.0, "clip": 1.0, "range": 1.0}  # the best of each stat, so the meters compare weapons
	for id in WeaponData.DATA:
		var w: Dictionary = WeaponData.DATA[id]
		most["damage"] = maxf(most["damage"], w["damage"] * w["pellets"])
		most["clip"] = maxf(most["clip"], w["clip"])
		most["range"] = maxf(most["range"], w["effective"])
	var cards := _row(null, 12)
	for id in WeaponData.DATA:
		var w: Dictionary = WeaponData.DATA[id]
		var equipped: bool = profile.equipped == id
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UIKit.slab(UIKit.CARD, a if equipped else Color(1, 1, 1, 0.15), 6, 14))
		cards.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		card.add_child(v)
		v.add_child(UIKit.label(str(w["name"]).to_upper(), 26, UIKit.TEXT, true))
		for stat in [["DAMAGE", w["damage"] * w["pellets"] / most["damage"], "%d x %d" % [w["damage"], w["pellets"]]],
				["CLIP", w["clip"] / most["clip"], str(w["clip"])], ["RANGE", w["effective"] / most["range"], "%d m" % w["effective"]]]:
			var line := _row(v)
			var cap := UIKit.label(stat[0], 12, UIKit.DIM)
			cap.custom_minimum_size = Vector2(62, 0)
			line.add_child(cap)
			line.add_child(UIKit.meter(stat[1], a, 90))
			line.add_child(UIKit.label(stat[2], 13))
		var equip := _button(v, "STARTING WEAPON" if equipped else "TAKE INTO RAIDS", _equip.bind(id), equipped)
		if equipped:
			UIKit.mark_chosen(equip, a)

func _fill_character() -> void:
	var a := _accent()
	var top := _row(null, 14)
	top.add_child(UIKit.label(str(profile.points), 56, UIKit.AMBER, true))
	var cap := VBoxContainer.new()
	cap.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(cap)
	cap.add_child(UIKit.label("ATTRIBUTE POINTS", 18, UIKit.TEXT, true))
	cap.add_child(UIKit.label("%d per extract, +1 for every %d frags in it, at most %d per raid" % [Upgrades.POINTS_PER_EXTRACT, Upgrades.KILLS_PER_POINT, Upgrades.POINTS_PER_RAID_MAX], 12, UIKit.DIM))
	for id in Upgrades.ATTRS:
		var at: Dictionary = Upgrades.ATTRS[id]
		var level: int = profile.attr_level(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.slab(UIKit.CARD, a, 5, 12))
		_content.add_child(card)
		var line := _row(card, 14)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(names)
		names.add_child(UIKit.label(str(at["name"]).to_upper(), 20, UIKit.TEXT, true))
		names.add_child(UIKit.label(at["desc"], 12, UIKit.DIM))
		line.add_child(UIKit.pips(level, int(at["max"]), a))
		var plus := _button(line, "+", _spend.bind(id), profile.points <= 0 or level >= int(at["max"]))
		plus.custom_minimum_size = Vector2(48, 40)
	var sums := _row()
	sums.add_child(UIKit.tile("health", str(profile.max_health(Player.MAX_HEALTH)), a))
	sums.add_child(UIKit.tile("armor", "%.0f%%" % (profile.armor() * 100.0), a))
	sums.add_child(UIKit.tile("speed", "x%.2f" % profile.speed_mult(), a))
	sums.add_child(UIKit.tile("reload", "x%.2f" % profile.reload_mult(), a))

func _fill_map() -> void:
	var a := _accent()
	var d := preview_data
	_row().add_child(UIKit.label("MAP %d" % selected_seed, 44, UIKit.AMBER, true))
	var tiles := _row()
	tiles.add_child(UIKit.tile("size", "%.0fx%.0f" % [d["w"], d["d"]], a))
	tiles.add_child(UIKit.tile("loot rooms", str(d["rooms"]), a))
	tiles.add_child(UIKit.tile("enemy bases", str(d["spawners"].size()), UIKit.BAD))
	tiles.add_child(UIKit.tile("patrols", str(d["groups"].size()), a))
	tiles.add_child(UIKit.tile("cover", str(d["cover"]), a))
	var legend := _row(null, 18)
	for entry in [["SAFE EXTRACT", Color(0.2, 1, 0.3)], ["FAST EXTRACT", Color(1, 0.6, 0.1)], ["ENEMY BASE", Color(1, 0.15, 0.1)], ["PATROL", Color(1, 0.6, 0.1)]]:
		var key := _row(legend, 6)
		var swatch := ColorRect.new()
		swatch.color = entry[1]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.add_child(swatch)
		key.add_child(UIKit.label(entry[0], 12, UIKit.DIM))
	var row := _row()
	_button(row, "< PREVIOUS", _step_seed.bind(-1), selected_seed <= 0)
	_button(row, "NEXT >", _step_seed.bind(1))
	_button(row, "RANDOM MAP", _random_seed)
	var entry := _row()
	entry.add_child(UIKit.label("MAP NUMBER", 12, UIKit.DIM))
	var field := LineEdit.new()
	field.text = str(selected_seed)
	field.custom_minimum_size = Vector2(120, 0)
	field.text_submitted.connect(_enter_seed)
	entry.add_child(field)
	_button(entry, "GO", func(): _enter_seed(field.text))

func _step_seed(delta: int) -> void:
	set_seed(selected_seed + delta)
	_refresh()

func _random_seed() -> void:
	set_seed(randi() % 1000000)
	_refresh()

func _enter_seed(text: String) -> void:
	if text.is_valid_int():
		set_seed(text.to_int())
	_refresh()

func _fill_raid() -> void:
	var a := _accent()
	var mult: float = profile.reward_mult()
	var tiles := _row()
	tiles.add_child(UIKit.tile("map (change at the pit)", str(selected_seed), a))
	tiles.add_child(UIKit.tile("starting weapon", str(WeaponData.DATA[profile.equipped]["name"]).to_upper(), a))
	tiles.add_child(UIKit.tile("reward", "x%.2f" % mult, UIKit.GOOD if mult > 1.0 else (UIKit.BAD if mult < 1.0 else UIKit.TEXT)))
	_label("RISK DIAL  -  harder options pay more loot and more attribute points; easier ones pay less", 12, UIKit.DIM)
	for id in Difficulty.OPTIONS:
		var opt: Dictionary = Difficulty.OPTIONS[id]
		var line := _row(null, 12)
		var names := VBoxContainer.new()
		names.custom_minimum_size = Vector2(250, 0)
		line.add_child(names)
		names.add_child(UIKit.label(str(opt["name"]).to_upper(), 16, UIKit.TEXT, true))
		var desc := UIKit.label(opt["desc"], 11, UIKit.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.add_child(desc)
		for i in opt["levels"].size():
			var level: Dictionary = opt["levels"][i]
			var reward := float(level["reward"])
			var text: String = level["label"] if reward == 0.0 else "%s (%+d%%)" % [level["label"], int(round(reward * 100.0))]
			var chip := _button(line, text, _set_difficulty.bind(id, i), profile.difficulty_level(id) == i)
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if profile.difficulty_level(id) == i:
				UIKit.mark_chosen(chip, a)
	var b := UIKit.big_button("START RAID", a, 72)
	b.pressed.connect(_start)
	_content.add_child(b)
	b.grab_focus()  # Enter / Space also start the raid

func _set_difficulty(id: String, level: int) -> void:
	if profile.set_difficulty(id, level):
		_commit()
