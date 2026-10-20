extends RefCounted
# Persisted player data: total count kept per item type. Separate from raid state;
# the only way loot gets in is add_items() after a successful extract.

const Tuning = preload("res://data/tuning.gd")
const Loot = preload("res://data/loot.gd")

var path: String
var totals := {}  # item id -> quantity kept across all raids

func _init(file_path: String = Tuning.PROFILE_PATH) -> void:
	path = file_path

func load_from_disk() -> void:
	totals = {}
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

func add_items(items: Dictionary) -> void:
	for id in items:
		totals[id] = totals.get(id, 0) + int(items[id])

# Writes to a temp file first so a crash mid-save cannot corrupt the existing profile.
func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write profile to %s" % tmp)
		return false
	f.store_string(JSON.stringify({"version": 1, "totals": totals}, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
