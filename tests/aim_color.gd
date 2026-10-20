# Run: Godot --headless --path <project> -s tests/aim_color.gd   (exit code 1 on failure)
# The aim laser's colour says the range: green inside "effective", orange in the falloff band,
# grey when nothing is hit. Checked for both weapons, using each weapon's own ranges.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const WeaponData = preload("res://data/weapons.gd")

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await _run()
	for f in failures:
		printerr(f)
	print("aim_color: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _run() -> void:
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 1
	root.add_child(main)
	await process_frame
	var player = main._player
	for id in WeaponData.DATA:
		player.select_weapon(id)
		var eff: float = WeaponData.DATA[id]["effective"]
		var mx: float = WeaponData.DATA[id]["max"]
		var green := Color(0.2, 1, 0.3)
		var orange := Color(1, 0.6, 0.1)
		_check(player.aim_color(false, eff - 1.0) == green, "%s: inside effective range should be green" % id)
		_check(player.aim_color(false, eff) == green, "%s: exactly at effective range should be green" % id)
		_check(player.aim_color(false, eff + 1.0) == orange, "%s: in the falloff band should be orange" % id)
		_check(player.aim_color(false, mx) == orange, "%s: at max range should be orange" % id)
		_check(player.aim_color(true, mx) not in [green, orange], "%s: no target should be neither green nor orange" % id)
	# The scattergun (effective 10 m) and pistol (25 m) must differ at 15 m.
	player.select_weapon("pistol")
	var pistol_15: Color = player.aim_color(false, 15.0)
	player.select_weapon("scattergun")
	_check(pistol_15 != player.aim_color(false, 15.0), "15 m is full damage for the pistol but falloff for the scattergun")
	main.queue_free()
	await process_frame
