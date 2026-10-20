extends RefCounted
# Persisted player data, kept between raids: the stash (loot kept), the equipped weapon, attribute levels and unspent points, and lifetime stats. Separate from raid state; loot only
# gets in through add_items() after a successful extract. Every change is saved by the caller (save()).

const Tuning = preload("res://data/tuning.gd")
const Loot = preload("res://data/loot.gd")
const Upgrades = preload("res://data/upgrades.gd")
const WeaponData = preload("res://data/weapons.gd")
const Difficulty = preload("res://data/difficulty.gd")
const Attachments = preload("res://data/attachments.gd")

var path: String
var totals := {}  # item id -> quantity in the stash
var attached := {}  # weapon id -> attachment id fitted to it (one per weapon); the attachments themselves are in `totals`
var wear := {}  # attachment id -> shots left (missing = full)
var equipped := "pistol"  # the weapon held at the start of a raid
var attrs := {}  # attribute id -> level (missing = 0)
var points := 0  # unspent attribute points
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
	attrs = {}
	points = 0
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
	var a = data.get("attrs")
	if typeof(a) == TYPE_DICTIONARY:
		for id in a:
			if Upgrades.ATTRS.has(str(id)):
				attrs[str(id)] = clampi(int(a[id]), 0, int(Upgrades.ATTRS[str(id)]["max"]))
	points = maxi(int(data.get("points", 0)), 0)
	var dd = data.get("difficulty")
	if typeof(dd) == TYPE_DICTIONARY:
		for id in dd:
			if Difficulty.OPTIONS.has(str(id)):
				difficulty[str(id)] = Difficulty.level_of(dd, str(id))
	var s = data.get("stats")
	if typeof(s) == TYPE_DICTIONARY:
		for k in STAT_DEFAULTS:
			stats[k] = maxi(int(s.get(k, STAT_DEFAULTS[k])), 0)

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

# Restores an attachment to full durability for Attachments.REPAIR_SCRAP scrap, and only scrap. False (nothing
# changes) if it is not worn or the stash is short.
func repair(att: String) -> bool:
	if not Attachments.DATA.has(att) or not wear.has(att) or owned("scrap") < Attachments.REPAIR_SCRAP:
		return false
	totals["scrap"] = owned("scrap") - Attachments.REPAIR_SCRAP
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

# A successful extract: bank the points it earned (see data/upgrades.gd, scaled by the raid's reward
# multiplier) and the lifetime stats. Returns the points gained.
func record_extract(kills: int, reward_mult := 1.0) -> int:
	var gained := mini(Difficulty.scale(Upgrades.POINTS_PER_EXTRACT + kills / Upgrades.KILLS_PER_POINT, reward_mult), Upgrades.POINTS_PER_RAID_MAX)
	points += gained
	stats["extracts"] += 1
	return gained

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

# --- attributes ---

func attr_level(id: String) -> int:
	return int(attrs.get(id, 0))

# Spends one point on an attribute. False if there is no point to spend or it is at its maximum.
func spend_point(id: String) -> bool:
	if not Upgrades.ATTRS.has(id) or points <= 0 or attr_level(id) >= int(Upgrades.ATTRS[id]["max"]):
		return false
	points -= 1
	attrs[id] = attr_level(id) + 1
	return true

func speed_mult() -> float:
	return 1.0 + float(Upgrades.ATTRS["speed"]["per_level"]) * attr_level("speed")

func max_health(base: int) -> int:
	return base + int(Upgrades.ATTRS["constitution"]["hp"]) * attr_level("constitution")

func armor() -> float:
	return float(Upgrades.ATTRS["constitution"]["armor"]) * attr_level("constitution")

func reload_mult() -> float:
	return 1.0 - float(Upgrades.ATTRS["handling"]["per_level"]) * attr_level("handling")

# Writes to a temp file first so a crash mid-save cannot corrupt the existing profile.
func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write profile to %s" % tmp)
		return false
	f.store_string(JSON.stringify({"version": 2, "totals": totals, "attached": attached, "wear": wear, "equipped": equipped,
		"attrs": attrs, "points": points, "difficulty": difficulty, "stats": stats}, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
