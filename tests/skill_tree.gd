# Run: Godot --headless --path <project> -s tests/skill_tree.gd   (exit code 1 on failure)
# The skill tree rules (scripts/skill_tree.gd), the stat resolver (scripts/skill_stats.gd), the node table and the
# profile's save version 3 with its migration from attributes. Uses scratch files only, never the real profile.
extends SceneTree

const Tuning = preload("res://data/tuning.gd")
const SkillNodes = preload("res://data/skill_nodes.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")
const SkillStats = preload("res://scripts/skill_stats.gd")
const Profile = preload("res://scripts/profile.gd")

const PATH := "user://test_skill_tree.json"
var failures: PackedStringArray = []

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _tree(points := 30) -> SkillTree:
	return SkillTree.new([], points)

# Takes ids in order; every one must be legal.
func _take(t: SkillTree, ids: Array) -> void:
	for id in ids:
		_check(t.allocate(id), "setup: could not allocate %s (%s)" % [id, t.can_allocate(id)["reason"]])

func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _init() -> void:
	var real_time := FileAccess.get_modified_time(Tuning.PROFILE_PATH) if FileAccess.file_exists(Tuning.PROFILE_PATH) else -1
	for p in [PATH, PATH + ".bad", PATH + ".tmp", PATH + ".v2.bak"]:
		DirAccess.remove_absolute(p)
	_table()
	_allocation()
	_refunds()
	_paths()
	_resolver()
	_profile()
	var real_after := FileAccess.get_modified_time(Tuning.PROFILE_PATH) if FileAccess.file_exists(Tuning.PROFILE_PATH) else -1
	_check(PATH != Tuning.PROFILE_PATH and real_time == real_after, "the real profile must not be touched")
	for p in [PATH, PATH + ".bad", PATH + ".tmp", PATH + ".v2.bak"]:
		DirAccess.remove_absolute(p)
	for f in failures:
		printerr(f)
	print("skill_tree: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

# The data is well formed: unique ids and positions, valid links, everything reachable, thresholds from tuning, stats limited.
func _table() -> void:
	var ids := {}
	var spots := {}
	var kinds := {}
	for r in SkillNodes.NODES:
		_check(not ids.has(r["id"]), "duplicate id %s" % r["id"])
		ids[r["id"]] = true
		_check(not spots.has(r["pos"]), "%s shares a position" % r["id"])
		spots[r["pos"]] = true
		kinds[r["kind"]] = int(kinds.get(r["kind"], 0)) + 1
	_check(ids.size() == 47, "47 nodes expected, got %d" % ids.size())
	_check(kinds.get("attribute") == 24 and kinds.get("trunk") == 2 and kinds.get("gateway") == 3 and kinds.get("notable") == 6 and kinds.get("minor") == 12, "kind counts: %s" % [kinds])
	for r in SkillNodes.NODES:
		for l in r["links"]:
			_check(ids.has(l), "%s links to unknown %s" % [r["id"], l])
		for a in r["requires"]:
			_check(SkillNodes.ATTRS.has(a), "%s requires unknown attribute %s" % [r["id"], a])
			var want: int = Tuning.SKILL_GATEWAY_REQ if r["kind"] == "gateway" else Tuning.SKILL_NOTABLE_REQ
			_check(r["kind"] in ["gateway", "notable"] and int(r["requires"][a]) == want, "%s threshold does not match tuning" % r["id"])
		_check((r["kind"] in ["gateway", "notable"]) == not r["requires"].is_empty(), "%s: only gateways and notables carry requirements" % r["id"])
		for e in r["effects"]:
			_check(Tuning.SKILL_STAT_LIMITS.has(e["stat"]) and e["mod"] in ["flat", "increased"], "%s has an unlimited or malformed effect" % r["id"])
	var all := ids.keys()
	var t := SkillTree.new(all.duplicate(), 0)  # a full tree is connected iff a refund-free walk from the hub sees every node
	_check(SkillTree._connected(all).size() == all.size(), "every node must be reachable from the hub")
	_check(t.attribute_totals() == {"str": 8, "dex": 8, "int": 8}, "8 attribute nodes per spoke")

func _allocation() -> void:
	var t := _tree()
	_check(not t.can_allocate("GB")["ok"] and t.can_allocate("GB")["reason"] != "", "a node with no link to the tree must be refused with a reason")
	_check(not t.can_allocate("S2")["ok"], "S2 is not linked to the hub or to an allocated node")
	_check(t.allocate("S1") and t.points == 29, "S1 touches the hub and costs a point")
	_check(t.can_allocate("S2")["ok"] and not t.can_allocate("S3")["ok"], "linkage follows allocated nodes only")
	_check(not t.allocate("S1"), "a node cannot be taken twice")
	var broke := _tree(0)
	_check(not broke.can_allocate("S1")["ok"] and "point" in broke.can_allocate("S1")["reason"], "no unspent point, no allocation")
	_check(not _tree().allocate("nonsense"), "an unknown id is refused")
	# gateway and notable thresholds come from attribute nodes only
	var g := _tree()
	_take(g, ["T1", "T2"])
	_check(not g.allocate("GB") and "STR 4" in g.can_allocate("GB")["reason"], "a gateway needs 4 of its attribute")
	_take(g, ["S1", "S2", "S3"])
	_check(not g.can_allocate("GB")["ok"], "3 STR is not enough")
	_check(not g.can_allocate("GM")["ok"], "STR does not open a DEX gateway")
	_take(g, ["S4", "GB", "B1", "B2"])
	_check(not g.can_allocate("BN1")["ok"] and "STR 6" in g.can_allocate("BN1")["reason"], "a notable needs 6")
	_take(g, ["S5", "S6"])
	_check(g.can_allocate("BN1")["ok"], "6 STR opens the notable")
	_check(g.attribute_totals() == {"str": 6, "dex": 0, "int": 0}, "only attribute nodes add attributes, got %s" % [g.attribute_totals()])

func _refunds() -> void:
	var t := _tree()
	_take(t, ["S1", "S2", "S3", "S4"])
	_check(not t.can_refund("S2")["ok"] and "cut" in t.can_refund("S2")["reason"], "a middle node holding up others cannot go")
	_check(t.can_refund("S4")["ok"] and t.refund("S4") and t.points == 27 and not t.allocated.has("S4"), "an end node refunds its point")
	_check(not t.refund("S4"), "refunding twice fails")
	_check(not t.can_refund("D1")["ok"], "a node that is not allocated cannot be refunded")
	# thresholds re-validated: GB stands on STR 4, so a STR node cannot go
	var g := _tree()
	_take(g, ["T1", "T2", "S1", "S2", "S3", "S4", "GB"])
	_check(not g.can_refund("S4")["ok"], "S4 is an end of the spoke but GB needs 4 STR")
	_take(g, ["S5"])
	_check(g.can_refund("S5")["ok"], "the fifth STR node is not holding anything up")
	g.refund("S5")
	_check("Brute Force" in g.can_refund("S4")["reason"], "the reason names the node that would break, got %s" % g.can_refund("S4")["reason"])
	_take(g, ["S5", "B1", "B2", "S6", "BN1"])
	_check(not g.can_refund("S5")["ok"], "BN1 needs 6 STR, so S5 now holds it up")
	g.refund("BN1")
	_check(g.can_refund("S6")["ok"], "once the notable goes, the sixth STR node can")
	# a tree with a loop: refunding one side keeps the other connected
	var l := _tree()
	_take(l, ["T1", "T2", "S1", "S2", "S3", "S4", "GB", "B1", "B2", "B3", "B4"])
	_check(l.can_refund("B2")["ok"], "B4 stays connected through B3 when B2 goes")
	_check(not l.can_refund("GB")["ok"], "the gateway holds its whole subtree")
	_check(not l.can_refund("T1")["ok"], "the trunk holds its gateway")

func _paths() -> void:
	var t := _tree()
	_check(t.shortest_path_cost("T2") == 2 and t.shortest_path("T2") == ["T1", "T2"], "from nothing, T2 costs T1 + T2")
	_check(t.shortest_path_cost("GB") == 3, "the gateway is 3 nodes away")
	_take(t, ["T1"])
	_check(t.shortest_path_cost("GB") == 2 and t.shortest_path("GB") == ["T2", "GB"], "the route starts from what you hold")
	_check(t.shortest_path_cost("T1") == 0, "an allocated node costs nothing to reach")
	_check(t.shortest_path_cost("S3") == 3 and t.shortest_path_cost("D2") == 2, "spokes are walked from the hub")
	_check(t.shortest_path_cost("nonsense") == 0, "an unknown id has no path")

func _resolver() -> void:
	_check(is_equal_approx(SkillStats.bonus("hp", ["S1", "S2"]), 8.0), "flat health adds up")
	_check(is_equal_approx(SkillStats.bonus("damage", ["T1", "T2", "GB"]), 0.10), "increased adds up")
	_check(SkillStats.bonus("hp", []) == 0.0 and SkillStats.bonus("crit", ["S1"]) == 0.0, "no node, no bonus; a stat the tree lacks is 0")
	_check(is_equal_approx(SkillStats.resolve("hp", 100.0, ["S1", "S2"]), 108.0), "flat then base: (100 + 8) x 1")
	_check(is_equal_approx(SkillStats.resolve("damage", 10.0, ["T1", "T2"]), 10.6), "(10 + 0) x (1 + 0.06)")
	var many := []
	for i in 12:
		many.append("BN1")
	_check(SkillStats.bonus("dmg_scattergun", many) == 2.0, "the cap holds (+200 percent), got %s" % SkillStats.bonus("dmg_scattergun", many))
	_check(SkillStats.bonus("range", many) == -0.5, "the floor holds, got %s" % SkillStats.bonus("range", many))
	var slow := []
	for i in 60:
		slow.append("I1")
	_check(SkillStats.bonus("extract_speed", slow) == 0.5, "extract hold never goes under 50% of base")
	_check(SkillStats.bonus("loot_reach", slow) == 2.0, "reach capped at 2 m")
	var fast := []
	for i in 30:
		fast.append("D1")
	_check(SkillStats.bonus("speed", fast) > 0.17 and SkillStats.bonus("speed", fast) < 0.19, "speed sums below its cap")
	_check(is_equal_approx(SkillStats.resolve("speed", 1.0, many + fast), 1.0 + SkillStats.bonus("speed", many + fast)) , "resolve respects the same limits")
	# a stat that has both kinds multiplies: flat first, then increased
	var prof := Profile.new(PATH)
	prof.allocated_nodes = ["S1", "T1"]
	_check(is_equal_approx(prof.node_bonus("hp"), 4.0) and is_equal_approx(prof.node_bonus("damage"), 0.03), "Profile.node_bonus reads the resolver")
	# a move speed cap of +40% is in tuning
	_check(Tuning.SKILL_STAT_LIMITS["speed"][1] == 0.4 and Tuning.SKILL_STAT_LIMITS["extract_speed"][1] == 0.5, "caps come from tuning")

func _profile() -> void:
	# round trip
	var a := Profile.new(PATH)
	a.load_from_disk()
	a.unspent_points = 10
	_check(a.allocate_node("S1") and a.allocate_node("S2") and a.allocate_node("T1") and not a.allocate_node("GB") and a.unspent_points == 7, "profile allocation keeps points in step")
	_check(a.save() and not FileAccess.file_exists(PATH + ".tmp"), "save is atomic: no temp file left behind")
	var b := Profile.new(PATH)
	b.load_from_disk()
	_check(b.allocated_nodes == ["S1", "S2", "T1"] and b.unspent_points == 7, "round trip, got %s / %d" % [b.allocated_nodes, b.unspent_points])
	var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_check(saved["version"] == 3 and not saved.has("attrs") and not saved.has("points"), "version 3 drops the old fields")
	_check(not FileAccess.file_exists(PATH + ".v2.bak"), "no backup for a file that is already version 3")
	# a refund needs ammo in the stash and spends it
	_check(not b.can_refund_node("T1")["ok"] and not b.refund_node("T1"), "a refund with no ammo in the stash is refused")
	b.add_items({"ammo": Tuning.SKILL_REFUND_AMMO + 3})
	_check(b.refund_node("T1") and b.unspent_points == 8 and b.owned("ammo") == 3, "a refund costs the tuned ammo and returns the point")
	_check(not b.refund_node("S1"), "S2 hangs off S1")
	# points: capped by unspent + allocated
	var c := Profile.new(PATH)
	c.unspent_points = Tuning.SKILL_POINT_CAP - 2
	c.allocated_nodes = ["S1", "S2"]
	_check(not c.grant_point() and c.unspent_points == Tuning.SKILL_POINT_CAP - 2, "no point past the cap of %d" % Tuning.SKILL_POINT_CAP)
	c.allocated_nodes = ["S1"]
	_check(c.grant_point() and c.unspent_points == Tuning.SKILL_POINT_CAP - 1, "a point below the cap is granted")
	# hand-edited v3 save: illegal and unknown nodes dropped, points clamped
	_write('{"version": 3, "totals": {"ammo": 2}, "allocated_nodes": ["GB", "S1", "nope", "S2"], "unspent_points": 999}')
	var d := Profile.new(PATH)
	d.load_from_disk()
	_check(d.allocated_nodes == ["S1", "S2"] and d.unspent_points == Tuning.SKILL_POINT_CAP - 2, "illegal nodes dropped and points clamped, got %s / %d" % [d.allocated_nodes, d.unspent_points])
	# migration from the old attribute save
	_write('{"version": 2, "totals": {"ammo": 5}, "attrs": {"marksman": 3, "speed": 2, "removed_one": 9}, "points": 4, "equipped": "scattergun"}')
	var old_text := FileAccess.get_file_as_string(PATH)
	var m := Profile.new(PATH)
	m.load_from_disk()
	_check(m.unspent_points == 9 and m.allocated_nodes.is_empty() and m.attrs.is_empty() and m.points == 0, "old purchases are refunded as 9 points (3 + 2 + 4), got %d" % m.unspent_points)
	_check(m.totals == {"ammo": 5} and m.equipped == "scattergun", "the rest of the profile is untouched")
	_check(FileAccess.file_exists(PATH + ".v2.bak") and FileAccess.get_file_as_string(PATH + ".v2.bak") == old_text, "a backup of the old save is kept")
	_check(m.save(), "migrated profile saves")
	var m2 := Profile.new(PATH)
	m2.load_from_disk()
	_check(m2.unspent_points == 9 and JSON.parse_string(FileAccess.get_file_as_string(PATH))["version"] == 3, "migration happens once")
	_check(FileAccess.get_file_as_string(PATH + ".v2.bak") == old_text, "the backup is not overwritten by later loads")
	# a version-1 file with no attrs and a huge old balance is capped
	_write('{"version": 1, "totals": {}, "attrs": {"marksman": 5, "trigger": 5, "handling": 5, "steady": 5, "longshot": 5}, "points": 50}')
	var e := Profile.new(PATH)
	e.load_from_disk()
	_check(e.unspent_points == Tuning.SKILL_POINT_CAP, "migrated points are held to the cap, got %d" % e.unspent_points)
