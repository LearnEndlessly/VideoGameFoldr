extends RefCounted
# Persisted player data, kept between raids: the stash (loot kept), the equipped weapon, skill tree nodes and unspent points, and lifetime stats. Separate from raid state; loot only
# gets in through add_items() after a successful extract. Every change is saved by the caller (save()).

const Tuning = preload("res://data/tuning.gd")
const Loot = preload("res://data/loot.gd")
const WeaponData = preload("res://data/weapons.gd")
const Difficulty = preload("res://data/difficulty.gd")
const Attachments = preload("res://data/attachments.gd")
const SkillTree = preload("res://scripts/skill_tree.gd")
const SkillStats = preload("res://scripts/skill_stats.gd")

var path: String
var totals := {}  # item id -> quantity in the stash
var attached := {}  # weapon id -> attachment id fitted to it (one per weapon); the attachments themselves are in `totals`
var wear := {}  # attachment id -> shots left (missing = full)
var equipped := "pistol"  # the weapon held at the start of a raid
var allocated_nodes: Array = []  # skill tree node ids taken (data/skill_nodes.gd), in the order they were taken
var unspent_points := 0  # points to spend in the skill tree
var stat_override := {}  # stat -> value that replaces the tree's bonus; tests use it to drive one stat without nodes
const SAVE_VERSION := 3
const OLD_ATTR_LEVEL_MAX := 5  # the most levels one old attribute could hold, for refunding old saves
var difficulty := {}  # raid difficulty option id -> level index (missing = Normal); see data/difficulty.gd
# Lifetime scoreboard numbers. "runs" counts runs (a descent is part of the run it came from), "deepest" is the deepest level reached
# (1 = the first), "hits" counts shots that hurt something, so hits / shots is the accuracy.
const STAT_DEFAULTS := {"runs": 0, "extracts": 0, "deaths": 0, "kills": 0, "shots": 0, "hits": 0, "deepest": 1}
var stats := STAT_DEFAULTS.duplicate()

func _init(file_path: String = Tuning.PROFILE_PATH) -> void:
	path = file_path

func load_from_disk() -> void:
	totals = {}
	equipped = "pistol"
	attached = {}
	wear = {}
	allocated_nodes = []
	unspent_points = 0
	difficulty = {}
	stats = STAT_DEFAULTS.duplicate()
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("totals")) != TYPE_DICTIONARY:
		# Keep the unreadable file so it can be recovered; start with an empty profile.
		push_warning("Profile at %s is unreadable; saved a copy as .bad and starting empty." % path)
		DirAccess.copy_absolute(path, path + ".bad")
		return
	for id in data["totals"]:
		if not Loot.ITEMS.has(str(id)):  # an item removed from the game (e.g. scrap) is dropped from old saves
			continue
		totals[str(id)] = int(data["totals"][id])
	# Everything below arrived in version 2; an older file simply lacks it (weapon upgrade levels in old files are ignored).
	if WeaponData.DATA.has(str(data.get("equipped", ""))):
		equipped = str(data["equipped"])
	var at = data.get("attached")
	if typeof(at) == TYPE_DICTIONARY:
		for w in at:
			if WeaponData.DATA.has(str(w)) and Attachments.DATA.has(str(at[w])):
				attached[str(w)] = str(at[w])
	var wr = data.get("wear")
	if typeof(wr) == TYPE_DICTIONARY:
		for id in wr:
			if Attachments.DATA.has(str(id)):
				wear[str(id)] = clampi(int(wr[id]), 0, int(Attachments.DATA[str(id)]["durability"]))
	_prune_attached()
	if int(data.get("version", 1)) < SAVE_VERSION:
		_migrate_old_attributes(data)
	else:
		var t := SkillTree.new([], 1 << 30)  # replay the saved order; a hand-edited illegal node is dropped
		var saved = data.get("allocated_nodes")
		if typeof(saved) == TYPE_ARRAY:
			for id in saved:
				if SkillTree.has_node(str(id)):
					t.allocate(str(id))
		allocated_nodes = t.allocated
		unspent_points = clampi(int(data.get("unspent_points", 0)), 0, maxi(Tuning.SKILL_POINT_CAP - allocated_nodes.size(), 0))
	var dd = data.get("difficulty")
	if typeof(dd) == TYPE_DICTIONARY:
		for id in dd:
			if Difficulty.OPTIONS.has(str(id)):
				difficulty[str(id)] = Difficulty.level_of(dd, str(id))
	var s = data.get("stats")
	if typeof(s) == TYPE_DICTIONARY:
		for k in STAT_DEFAULTS:
			stats[k] = maxi(int(s.get(k, STAT_DEFAULTS[k])), 0)

# Save versions before 3 held skill tree nodes and unspent points. Keep a copy of the file (once), refund every purchase as
# an unspent skill point (held to the point cap) and start with an empty tree. The old fields are not carried forward.
func _migrate_old_attributes(data: Dictionary) -> void:
	if not FileAccess.file_exists(path + ".v2.bak"):
		DirAccess.copy_absolute(path, path + ".v2.bak")
	var refunded := maxi(int(data.get("points", 0)), 0)
	var a = data.get("attrs")
	if typeof(a) == TYPE_DICTIONARY:
		for id in a:
			refunded += clampi(int(a[id]), 0, OLD_ATTR_LEVEL_MAX)
	unspent_points = mini(refunded, Tuning.SKILL_POINT_CAP)

func add_items(items: Dictionary) -> void:
	for id in items:
		totals[id] = totals.get(id, 0) + int(items[id])

# Takes loot back out of the stash (descending carries it into the next level).
func take_items(items: Dictionary) -> void:
	for id in items:
		totals[id] = int(totals.get(id, 0)) - int(items[id])
		if totals[id] <= 0:
			totals.erase(id)
	_prune_attached()

# --- weapon attachments ---

func owned(id: String) -> int:
	return int(totals.get(id, 0))

# An attachment can go on a weapon with a free slot if there is a copy not already fitted elsewhere.
func can_attach(weapon: String, att: String) -> bool:
	if not WeaponData.DATA.has(weapon) or not Attachments.DATA.has(att) or attached.has(weapon):
		return false
	return owned(att) > attached.values().count(att)

func attach(weapon: String, att: String) -> bool:
	if not can_attach(weapon, att):
		return false
	attached[weapon] = att
	return true

func detach(weapon: String) -> bool:
	return attached.erase(weapon)

func shots_left(att: String) -> int:
	return int(wear.get(att, Attachments.DATA[att]["durability"]))

func is_broken(att: String) -> bool:
	return shots_left(att) <= 0

func set_wear(att: String, left: int) -> void:
	var max_shots: int = Attachments.DATA[att]["durability"]
	if left >= max_shots:
		wear.erase(att)
	else:
		wear[att] = maxi(left, 0)

# Scrap a repair costs: Attachments.REPAIR_SCRAP, less one per level of Tinkerer, never under 1.
func repair_cost() -> int:
	return maxi(Attachments.REPAIR_SCRAP - int(bonus("repair_cost")), 1)

# Restores an attachment to full durability for repair_cost() scrap, and only scrap. False (nothing
# changes) if it is not worn or the stash is short.
func repair(att: String) -> bool:
	if not Attachments.DATA.has(att) or not wear.has(att) or owned("scrap") < repair_cost():
		return false
	totals["scrap"] = owned("scrap") - repair_cost()
	if totals["scrap"] <= 0:
		totals.erase("scrap")
	wear.erase(att)
	return true

# Drops fittings whose attachment is no longer in the stash (it was carried down a level, say).
func _prune_attached() -> void:
	var used := {}
	for w in attached.keys():
		var att: String = attached[w]
		used[att] = int(used.get(att, 0)) + 1
		if used[att] > owned(att):
			attached.erase(w)

# Every finished raid, win or lose, goes on the scoreboard. `level` is 1 for a raid started at the base.
func record_raid(extracted: bool, kills: int, shots: int, hits: int, level: int) -> void:
	if level <= 1:
		stats["runs"] += 1
	if not extracted:
		stats["deaths"] += 1
	stats["kills"] += kills
	stats["shots"] += shots
	stats["hits"] += hits
	stats["deepest"] = maxi(stats["deepest"], level)

# Percent of shots that hurt something, -1 before the first shot.
func accuracy() -> int:
	return -1 if stats["shots"] <= 0 else int(round(100.0 * stats["hits"] / stats["shots"]))

# A successful extract: count it on the scoreboard. (Skill points come from clearing rounds, see grant_point.)
func record_extract() -> void:
	stats["extracts"] += 1

# --- weapons ---

func equip(id: String) -> bool:
	if not WeaponData.DATA.has(id):
		return false
	equipped = id
	return true

# --- raid difficulty ---

func difficulty_level(id: String) -> int:
	return Difficulty.level_of(difficulty, id)

func set_difficulty(id: String, level: int) -> bool:
	if not Difficulty.OPTIONS.has(id) or level < 0 or level >= Difficulty.OPTIONS[id]["levels"].size():
		return false
	difficulty[id] = level
	return true

func reward_mult() -> float:
	return Difficulty.reward_mult(difficulty)

# --- skill points and stats ---

# A cleared round earns a skill point, unless the points held and allocated already reach Tuning.SKILL_POINT_CAP. True if one was added.
func grant_point() -> bool:
	if unspent_points + allocated_nodes.size() >= Tuning.SKILL_POINT_CAP:
		return false
	unspent_points += 1
	return true

# --- skill tree (scripts/skill_tree.gd holds the rules; these keep the profile's two fields in step) ---

func _tree() -> SkillTree:
	return SkillTree.new(allocated_nodes, unspent_points)

func allocate_node(id: String) -> bool:
	var t := _tree()
	if not t.allocate(id):
		return false
	unspent_points = t.points
	return true

# {ok, reason} for giving a node back: the tree must stay legal and the stash must hold Tuning.SKILL_REFUND_AMMO ammo.
func can_refund_node(id: String) -> Dictionary:
	var r := _tree().can_refund(id)
	if r["ok"] and owned("ammo") < Tuning.SKILL_REFUND_AMMO:
		return {"ok": false, "reason": "needs %d ammo in the stash" % Tuning.SKILL_REFUND_AMMO}
	return r

func refund_node(id: String) -> bool:
	if not can_refund_node(id)["ok"]:
		return false
	var t := _tree()
	t.refund(id)
	unspent_points = t.points
	take_items({"ammo": Tuning.SKILL_REFUND_AMMO})
	return true

# What the skill tree adds to `stat` (scripts/skill_stats.gd, floors and caps applied); 0 for a stat no node gives.
func bonus(stat: String) -> float:
	if stat_override.has(stat):
		return float(stat_override[stat])
	return SkillStats.bonus(stat, allocated_nodes)

func speed_mult() -> float:
	return 1.0 + bonus("speed")

func max_health(base: int) -> int:
	return base + int(bonus("hp"))

func armor() -> float:
	return bonus("armor")

func reload_mult() -> float:
	return maxf(1.0 - bonus("reload"), 0.25)  # a reload never gets under a quarter of its time

# Writes to a temp file first so a crash mid-save cannot corrupt the existing profile.
func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write profile to %s" % tmp)
		return false
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "totals": totals, "attached": attached, "wear": wear, "equipped": equipped,
		"allocated_nodes": allocated_nodes, "unspent_points": unspent_points, "difficulty": difficulty, "stats": stats}, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
