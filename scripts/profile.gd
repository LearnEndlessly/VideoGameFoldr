extends RefCounted
# Persisted player data, kept between raids: the stash (loot kept), weapon upgrades and the equipped
# weapon, attribute levels and unspent points, and lifetime stats. Separate from raid state; loot only
# gets in through add_items() after a successful extract. Every change is saved by the caller (save()).

const Tuning = preload("res://data/tuning.gd")
const Loot = preload("res://data/loot.gd")
const Upgrades = preload("res://data/upgrades.gd")
const WeaponData = preload("res://data/weapons.gd")

var path: String
var totals := {}  # item id -> quantity in the stash
var weapons := {}  # weapon id -> upgrade level (missing = 0)
var equipped := "pistol"  # the weapon held at the start of a raid
var attrs := {}  # attribute id -> level (missing = 0)
var points := 0  # unspent attribute points
var stats := {"extracts": 0, "kills": 0}  # lifetime, successful raids only

func _init(file_path: String = Tuning.PROFILE_PATH) -> void:
	path = file_path

func load_from_disk() -> void:
	totals = {}
	weapons = {}
	equipped = "pistol"
	attrs = {}
	points = 0
	stats = {"extracts": 0, "kills": 0}
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
	# Everything below arrived in version 2; an older file simply lacks it.
	var w = data.get("weapons")
	if typeof(w) == TYPE_DICTIONARY:
		for id in w:
			if WeaponData.DATA.has(str(id)):
				weapons[str(id)] = clampi(int(w[id]), 0, Upgrades.WEAPON_MAX_LEVEL)
	if WeaponData.DATA.has(str(data.get("equipped", ""))):
		equipped = str(data["equipped"])
	var a = data.get("attrs")
	if typeof(a) == TYPE_DICTIONARY:
		for id in a:
			if Upgrades.ATTRS.has(str(id)):
				attrs[str(id)] = clampi(int(a[id]), 0, int(Upgrades.ATTRS[str(id)]["max"]))
	points = maxi(int(data.get("points", 0)), 0)
	var s = data.get("stats")
	if typeof(s) == TYPE_DICTIONARY:
		stats = {"extracts": int(s.get("extracts", 0)), "kills": int(s.get("kills", 0))}

func add_items(items: Dictionary) -> void:
	for id in items:
		totals[id] = totals.get(id, 0) + int(items[id])

# A successful extract: bank the points it earned (see data/upgrades.gd) and the lifetime stats.
# Returns the points gained.
func record_extract(kills: int) -> int:
	var gained: int = Upgrades.POINTS_PER_EXTRACT + kills / Upgrades.KILLS_PER_POINT
	points += gained
	stats["extracts"] += 1
	stats["kills"] += kills
	return gained

# --- weapons ---

func weapon_level(id: String) -> int:
	return int(weapons.get(id, 0))

func damage_mult(id: String) -> float:
	return 1.0 + Upgrades.WEAPON_DAMAGE_PER_LEVEL * weapon_level(id)

# What the next level costs, {} if the weapon is at its top level.
func upgrade_cost(id: String) -> Dictionary:
	var level := weapon_level(id)
	return {} if level >= Upgrades.WEAPON_MAX_LEVEL else Upgrades.WEAPON_COSTS[level]

func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if int(totals.get(id, 0)) < int(cost[id]):
			return false
	return true

# Pays the cost from the stash and raises the weapon one level. False (nothing changes) if it is at
# its top level or the stash is short.
func upgrade_weapon(id: String) -> bool:
	var cost := upgrade_cost(id)
	if not WeaponData.DATA.has(id) or cost.is_empty() or not can_afford(cost):
		return false
	for item in cost:
		totals[item] = int(totals[item]) - int(cost[item])
		if totals[item] <= 0:
			totals.erase(item)
	weapons[id] = weapon_level(id) + 1
	return true

func equip(id: String) -> bool:
	if not WeaponData.DATA.has(id):
		return false
	equipped = id
	return true

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
	f.store_string(JSON.stringify({"version": 2, "totals": totals, "weapons": weapons, "equipped": equipped,
		"attrs": attrs, "points": points, "stats": stats}, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
