# Run: Godot --headless --path <project> -s tests/profile_unit.gd   (exit code 1 on failure)
# Profile save/load round trip, repeated saves, and recovery from a corrupt file.
extends SceneTree

const Profile = preload("res://scripts/profile.gd")
const PATH := "user://test_profile_unit.json"

func _init() -> void:
	var failures: PackedStringArray = []
	for p in [PATH, PATH + ".bad", PATH + ".tmp"]:
		DirAccess.remove_absolute(p)

	var a := Profile.new(PATH)
	a.load_from_disk()
	if not a.totals.is_empty():
		failures.append("missing file must give an empty profile")
	a.add_items({"scrap": 3, "medkit": 1})
	if not a.save():
		failures.append("first save failed")
	a.add_items({"scrap": 2})
	if not a.save():
		failures.append("second save (overwrite) failed")

	var b := Profile.new(PATH)
	b.load_from_disk()
	if b.totals != {"scrap": 5, "medkit": 1}:
		failures.append("reload gave %s" % [b.totals])

	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var c := Profile.new(PATH)
	c.load_from_disk()
	if not c.totals.is_empty() or not FileAccess.file_exists(PATH + ".bad"):
		failures.append("corrupt file must load empty and be kept as .bad")

	for fail in failures:
		printerr(fail)
	print("profile_unit: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)
