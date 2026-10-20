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
var _title: Label
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
	_prompt.text = "E / shoot: %s" % what if what != "" else ""

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
	_mini_marker(root, data["extract"], 3.0, 9.0, Color(0.2, 1, 0.3, 0.7))
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

# --- panels ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "BASE - WASD move, E or shoot (click) a station to use it, shoot the < ? > panels hovering over the map pit to change the map, Esc closes a panel. Ammo is free here."
	hint.position = Vector2(16, 12)
	layer.add_child(hint)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = 50
	var cross := Label.new()
	cross.text = "+"
	layer.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.13, 0.97)
	bg.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", bg)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	box.add_child(_title)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	box.add_child(_content)
	_status = Label.new()
	_status.modulate = Color(1, 0.8, 0.3)
	box.add_child(_status)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(_close)
	box.add_child(close)

func _on_station_used(station: Node) -> void:
	if station.has_meta("action"):  # a pad by the map pit, not a panel
		_map_button(station.get_meta("action"))
		return
	open_station = station.get_meta("station_id")
	_status.text = ""
	_title.text = STATIONS[open_station]["name"]
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

func _label(text: String, font_size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	_content.add_child(l)
	return l

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

func _upgrade(id: String) -> void:
	if profile.upgrade_weapon(id):
		_commit()

func _spend(id: String) -> void:
	if profile.spend_point(id):
		_commit()

func _fill_stash() -> void:
	_label("Extractions: %d    Frags: %d" % [profile.stats["extracts"], profile.stats["kills"]])
	if profile.totals.is_empty():
		_label("The stash is empty. Extract loot from a raid to fill it.")
		return
	var ids: Array = profile.totals.keys()
	ids.sort()
	for id in ids:
		var row := HBoxContainer.new()
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.item_id = id
		row.add_child(icon)
		var l := Label.new()
		l.text = "%s x%d" % [str(id).replace("_", " "), profile.totals[id]]
		row.add_child(l)
		_content.add_child(row)

func _fill_armory() -> void:
	_label("Stash: %s" % (_cost_text(profile.totals) if not profile.totals.is_empty() else "empty"))
	for id in WeaponData.DATA:
		var w: Dictionary = WeaponData.DATA[id]
		var level: int = profile.weapon_level(id)
		_label("%s   level %d/%d%s" % [w["name"], level, Upgrades.WEAPON_MAX_LEVEL, "   (starting weapon)" if profile.equipped == id else ""], 20)
		var dmg := int(round(w["damage"] * profile.damage_mult(id)))
		_label("%d x %d damage, %d-round clip, full damage to %d m" % [dmg, w["pellets"], w["clip"], w["effective"]])
		var row := HBoxContainer.new()
		_content.add_child(row)
		_button(row, "Take into raids" if profile.equipped != id else "Equipped", _equip.bind(id), profile.equipped == id)
		var cost: Dictionary = profile.upgrade_cost(id)
		_button(row, "Upgrade (%s)" % _cost_text(cost) if not cost.is_empty() else "Max level", _upgrade.bind(id),
			cost.is_empty() or not profile.can_afford(cost))

func _fill_character() -> void:
	_label("Attribute points: %d" % profile.points, 20)
	_label("Earn points by extracting: %d per raid, and 1 more for every %d frags in it." % [Upgrades.POINTS_PER_EXTRACT, Upgrades.KILLS_PER_POINT])
	for id in Upgrades.ATTRS:
		var a: Dictionary = Upgrades.ATTRS[id]
		var level: int = profile.attr_level(id)
		var row := HBoxContainer.new()
		_content.add_child(row)
		var l := Label.new()
		l.text = "%s  %d/%d   (%s)" % [a["name"], level, a["max"], a["desc"]]
		l.custom_minimum_size = Vector2(400, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		_button(row, "+", _spend.bind(id), profile.points <= 0 or level >= int(a["max"]))
	_label("Max health %d   armor %.0f%%   speed x%.2f   reload x%.2f" % [
		profile.max_health(Player.MAX_HEALTH), profile.armor() * 100.0, profile.speed_mult(), profile.reload_mult()])

func _fill_map() -> void:
	_label("Next raid: map %d" % selected_seed, 20)
	var d := preview_data
	_label("%.0f x %.0f m   |   %d loot rooms   |   %d enemy bases   |   %d patrols   |   %d cover pieces" % [
		d["w"], d["d"], d["rooms"], d["spawners"].size(), d["groups"].size(), d["cover"]])
	_label("In the pit: green beam = extraction, red beams = enemy bases, orange dots = patrols. Every map number is a different layout.")
	var row := HBoxContainer.new()
	_content.add_child(row)
	_button(row, "< Previous", _step_seed.bind(-1), selected_seed <= 0)
	_button(row, "Next >", _step_seed.bind(1))
	_button(row, "Random map", _random_seed)
	var entry := HBoxContainer.new()
	_content.add_child(entry)
	var l := Label.new()
	l.text = "Map number:"
	entry.add_child(l)
	var field := LineEdit.new()
	field.text = str(selected_seed)
	field.custom_minimum_size = Vector2(120, 0)
	field.text_submitted.connect(_enter_seed)
	entry.add_child(field)
	_button(entry, "Go", func(): _enter_seed(field.text))

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
	_label("Map: %d (change it at the map pit)    Starting weapon: %s" % [selected_seed, WeaponData.DATA[profile.equipped]["name"]])
	_label("RAID DIFFICULTY   reward x%.2f" % profile.reward_mult(), 20)
	_label("Harder options scale the loot you keep and the attribute points an extract earns. Easier ones shrink them.")
	for id in Difficulty.OPTIONS:
		var opt: Dictionary = Difficulty.OPTIONS[id]
		_label("%s - %s" % [opt["name"], opt["desc"]])
		var row := HBoxContainer.new()
		_content.add_child(row)
		for i in opt["levels"].size():
			var level: Dictionary = opt["levels"][i]
			var reward := float(level["reward"])
			var text: String = level["label"] if reward == 0.0 else "%s (%+d%%)" % [level["label"], int(round(reward * 100.0))]
			_button(row, text, _set_difficulty.bind(id, i), profile.difficulty_level(id) == i)
	var b := _button(_content, "START RAID", _start)
	b.custom_minimum_size = Vector2(0, 60)
	b.grab_focus()  # Enter / Space also start the raid

func _set_difficulty(id: String, level: int) -> void:
	if profile.set_difficulty(id, level):
		_commit()
