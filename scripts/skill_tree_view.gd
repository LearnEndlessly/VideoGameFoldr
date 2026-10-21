extends Control
# The skill tree screen: the node graph of data/skill_nodes.gd drawn around the hub. Drag to pan, wheel to zoom, left-click an
# available node to take it, right-click a taken one to give it back. Hovering a node shows what it does, what it needs and
# the route to it. UI only: it asks the hub to change anything (allocate_requested / refund_requested) and the rules live in
# scripts/skill_tree.gd. `cam` ({"center": Vector2, "scale": float}) is owned by the hub so a redraw keeps the view.

const Tuning = preload("res://data/tuning.gd")
const SkillNodes = preload("res://data/skill_nodes.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")
const UIKit = preload("res://scripts/ui_kit.gd")

signal allocate_requested(id: String)
signal refund_requested(id: String)

const MIN_SCALE := 16.0
const MAX_SCALE := 90.0
const DRAG_PX := 6.0
const ATTR_COLORS := {"str": Color(0.95, 0.38, 0.32), "dex": Color(0.4, 0.9, 0.45), "int": Color(0.36, 0.62, 1.0)}
const TREE_COLORS := {"offense": Color(1.0, 0.8, 0.3), "brutality": Color(0.95, 0.38, 0.32), "marksmanship": Color(0.4, 0.9, 0.45), "ordnance": Color(0.36, 0.62, 1.0)}
const TREE_NAMES := {"offense": "OFFENSE", "brutality": "BRUTALITY", "marksmanship": "MARKSMANSHIP", "ordnance": "ORDNANCE"}
const KIND_NAMES := {"attribute": "ATTRIBUTE", "trunk": "TRUNK", "minor": "MINOR", "notable": "NOTABLE", "gateway": "GATEWAY"}
const RADIUS := {"attribute": 0.26, "trunk": 0.32, "minor": 0.3, "notable": 0.5, "gateway": 0.42}  # tree units

var profile
var cam := {"center": Vector2(0, -4), "scale": 36.0}
var hover := ""

var _tree: SkillTree
var _pressing := false
var _press_pos := Vector2.ZERO
var _dragged := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func():
		hover = ""
		queue_redraw())

# --- text ---

# "+8% pistol damage", "+4 max health", "+0.25 m loot reach" for one effect row of a node.
static func effect_text(e: Dictionary) -> String:
	var info: Dictionary = SkillNodes.STAT_NAMES.get(e["stat"], {"name": e["stat"]})
	var v := float(e["value"])
	if e["mod"] == "increased":
		return "%s%s%% %s" % ["+" if v >= 0.0 else "-", _num(absf(v) * 100.0, 1), info["name"]]
	return "%s%s%s %s" % ["+" if v >= 0.0 else "-", _num(absf(v), 2), info.get("unit", ""), info["name"]]

static func _num(v: float, decimals: int) -> String:
	var r := snappedf(v, pow(10.0, -decimals))
	return str(int(r)) if is_equal_approx(r, roundf(r)) else str(r)

# The lines of a node's tooltip: name, kind, effects, then why it can't be taken or what the click does.
func info_lines(id: String) -> Array:
	var r := SkillTree.row(id)
	var lines: Array = [r["name"].to_upper(), "%s  -  %s" % [KIND_NAMES[r["kind"]], _tree_name(r)]]
	for e in r["effects"]:
		lines.append(effect_text(e))
	if not r["requires"].is_empty():
		var parts: Array = []
		for a in r["requires"]:
			parts.append("%d %s" % [int(r["requires"][a]), str(a).to_upper()])
		lines.append("Needs %s allocated" % ", ".join(parts))
	if _tree.allocated.has(id):
		var why: Dictionary = profile.can_refund_node(id)
		lines.append("TAKEN.  Right-click to give back (%d ammo)" % Tuning.SKILL_REFUND_AMMO if why["ok"] else "TAKEN.  Can't give back: " + why["reason"])
	else:
		var can := _tree.can_allocate(id)
		if can["ok"]:
			lines.append("Click to take (1 point)")
		else:
			lines.append("Locked: " + can["reason"])
			var path := _tree.shortest_path(id)
			if path.size() > 1:
				lines.append("%d points to reach along the route" % (path.size() * Tuning.SKILL_NODE_COST))
	return lines

func _tree_name(r: Dictionary) -> String:
	return str(r["attr"]).to_upper() if r["kind"] == "attribute" else TREE_NAMES.get(r["tree"], str(r["tree"]).to_upper())

# --- geometry ---

func _to_screen(p: Vector2) -> Vector2:
	return size / 2.0 + (p - cam["center"]) * float(cam["scale"])

func _to_world(p: Vector2) -> Vector2:
	return cam["center"] + (p - size / 2.0) / float(cam["scale"])

func _radius_px(id: String) -> float:
	return float(RADIUS[SkillTree.row(id)["kind"]]) * float(cam["scale"])

func _color_of(r: Dictionary) -> Color:
	return ATTR_COLORS[r["attr"]] if r["kind"] == "attribute" else TREE_COLORS.get(r["tree"], UIKit.AMBER)

func _node_at(screen: Vector2) -> String:
	var best := ""
	var best_d := INF
	for r in SkillNodes.NODES:
		var d := _to_screen(r["pos"]).distance_to(screen)
		if d <= _radius_px(r["id"]) + 5.0 and d < best_d:
			best = r["id"]
			best_d = d
	return best

# --- drawing ---

func _draw() -> void:
	if profile == null:
		return
	_tree = SkillTree.new(profile.allocated_nodes, profile.unspent_points)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.05))
	var s := float(cam["scale"])
	var route: Array = _tree.shortest_path(hover) if hover != "" else []
	for r in SkillNodes.NODES:  # links first, under the nodes
		for other in r["links"]:
			if other > r["id"] or not SkillTree.has_node(other) or not SkillTree.row(other)["links"].has(r["id"]):
				_draw_link(r["id"], other, route)
	for id in SkillNodes.HUB_LINKS:
		_draw_link(SkillNodes.HUB, id, route)
	_draw_hub()
	for tree in TREE_NAMES:
		_draw_wedge_title(tree)
	for a in SkillNodes.ATTRS:
		var first := _first_attribute_node(a)
		var at := _to_screen(SkillTree.row(first)["pos"]) + Vector2(0, -0.55 * s)
		_text(at, "%s  %d" % [a.to_upper(), _tree.attribute_totals()[a]], 14, ATTR_COLORS[a])
	for r in SkillNodes.NODES:
		_draw_node(r, route)
	if hover != "":
		_draw_info()

func _first_attribute_node(attr: String) -> String:
	for id in SkillNodes.HUB_LINKS:
		var r := SkillTree.row(id)
		if r["kind"] == "attribute" and r["attr"] == attr:
			return id
	return SkillNodes.HUB_LINKS[0]

func _pos_of(id: String) -> Vector2:
	return SkillNodes.HUB_POS if id == SkillNodes.HUB else SkillTree.row(id)["pos"]

func _taken(id: String) -> bool:
	return id == SkillNodes.HUB or _tree.allocated.has(id)

func _draw_link(a: String, b: String, route: Array) -> void:
	var lit := _taken(a) and _taken(b)
	var on_route := (route.has(a) or _taken(a)) and (route.has(b) or _taken(b)) and not lit
	var col := Color(0.35, 0.36, 0.42, 0.7)
	var w := 2.0
	if lit:
		col = Color(1.0, 0.82, 0.35)
		w = 4.0
	elif on_route:
		col = Color(1.0, 0.72, 0.12, 0.55)
		w = 3.0
	draw_line(_to_screen(_pos_of(a)), _to_screen(_pos_of(b)), col, w, true)

func _draw_hub() -> void:
	var c := _to_screen(SkillNodes.HUB_POS)
	var rad := 0.45 * float(cam["scale"])
	draw_circle(c, rad, Color(1.0, 0.82, 0.35))
	draw_arc(c, rad + 4.0, 0.0, TAU, 32, Color(1.0, 0.82, 0.35, 0.5), 2.0, true)
	_text(c + Vector2(0, 5), "YOU", 12, UIKit.INK)

func _draw_wedge_title(tree: String) -> void:
	var sum := Vector2.ZERO
	var n := 0
	var top := INF
	var top_pos := Vector2.ZERO
	for r in SkillNodes.NODES:
		if r["tree"] == tree and r["kind"] != "attribute":
			sum += r["pos"]
			if r["pos"].y < top:
				top = r["pos"].y
				top_pos = r["pos"]
			n += 1
	if n == 0:
		return
	var at := _to_screen(Vector2(sum.x / n, top - 1.1))
	var col: Color = TREE_COLORS[tree]
	col.a = 0.9
	if tree == "offense":  # the central trunk is crowded above; put the title beside it, right-aligned
		var w := ThemeDB.fallback_font.get_string_size(TREE_NAMES[tree], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		at = _to_screen(top_pos) + Vector2(-0.5 * float(cam["scale"]) - w / 2.0, 6.0)
	_text(at, TREE_NAMES[tree], 16, col)

func _draw_node(r: Dictionary, route: Array) -> void:
	var id: String = r["id"]
	var c := _to_screen(r["pos"])
	var rad := _radius_px(id)
	var col := _color_of(r)
	var taken := _tree.allocated.has(id)
	var can: bool = _tree.can_allocate(id)["ok"]
	var fill := Color(0.07, 0.075, 0.1)
	var ring := col
	ring.a = 0.35
	if taken:
		fill = col
		ring = Color.WHITE
	elif can:
		ring = col.lightened(0.2)
	elif route.has(id):
		ring = Color(1.0, 0.72, 0.12)
	var width := 3.0 if can or taken else 2.0
	if r["kind"] == "gateway":
		var pts := PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0)])
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, ring, width, true)
	else:
		draw_circle(c, rad, fill)
		draw_arc(c, rad, 0.0, TAU, 28, ring, width, true)
		if r["kind"] == "notable":
			draw_arc(c, rad + 4.0, 0.0, TAU, 32, ring, 1.5, true)
	if can and not taken:  # available: a soft halo so the next picks stand out
		var halo := col
		halo.a = 0.18
		draw_circle(c, rad + 7.0, halo)
	if (r["kind"] in ["notable", "gateway"] and float(cam["scale"]) >= 26.0) or id == hover:
		_text(c + Vector2(0, rad + 15.0), r["name"], 12, Color(0.93, 0.94, 0.96) if (taken or can or id == hover) else UIKit.DIM)

func _draw_info() -> void:
	var lines := info_lines(hover)
	var font := ThemeDB.fallback_font
	var w := 300.0
	var h := 14.0
	for i in lines.size():
		h += 22.0 if i == 0 else 18.0
	var box := Rect2(Vector2(10, size.y - h - 10), Vector2(w, h))
	draw_rect(box, Color(0.045, 0.05, 0.065, 0.97))
	draw_rect(box, Color(0.35, 0.37, 0.45), false, 1.0)
	var accent := _color_of(SkillTree.row(hover))
	draw_rect(Rect2(box.position, Vector2(4, h)), accent)
	var y := box.position.y + 20.0
	for i in lines.size():
		var col := UIKit.TEXT
		var fs := 13
		if i == 0:
			col = accent
			fs = 16
		elif i == 1:
			col = UIKit.DIM
			fs = 11
		elif i == lines.size() - 1 or lines[i].begins_with("Needs") or lines[i].begins_with("Locked") or lines[i].begins_with("TAKEN"):
			col = UIKit.AMBER if lines[i].begins_with("Click") or lines[i].begins_with("TAKEN.  Right") else UIKit.DIM
		draw_string(font, Vector2(box.position.x + 14, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w - 22.0, fs, col)
		y += 22.0 if i == 0 else 18.0

func _text(center: Vector2, text: String, size_px: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(font, center + Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_button(event)
	elif event is InputEventMouseMotion:
		if _pressing:
			if not _dragged and (event.position - _press_pos).length() > DRAG_PX:
				_dragged = true
			if _dragged:
				cam["center"] -= event.relative / float(cam["scale"])
		var now := _node_at(event.position)
		if now != hover or _dragged:
			hover = now
			queue_redraw()

func _on_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			var before := _to_world(event.position)
			cam["scale"] = clampf(float(cam["scale"]) * (1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), MIN_SCALE, MAX_SCALE)
			cam["center"] += before - _to_world(event.position)  # the point under the cursor stays put
			queue_redraw()
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_pressing = true
				_dragged = false
				_press_pos = event.position
			else:
				var click := _pressing and not _dragged and event.button_index == MOUSE_BUTTON_LEFT
				_pressing = false
				if click and hover != "" and not profile.allocated_nodes.has(hover):
					allocate_requested.emit(hover)
		MOUSE_BUTTON_RIGHT:
			if event.pressed and hover != "" and profile.allocated_nodes.has(hover):
				refund_requested.emit(hover)
