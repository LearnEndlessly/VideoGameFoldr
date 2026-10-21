# Run: Godot --headless --path <project> -s tests/combo.gd   (exit code 1 on failure)
# The kill combo (a window that shrinks, a score multiplier that grows, paid when it runs out), its skull counter,
# the ready ring for the slow weapons, and the gunsmith bench with the stats its attachments add.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const WeaponData = preload("res://data/weapons.gd")
const Attachments = preload("res://data/attachments.gd")
const ComboMeter = preload("res://scripts/combo_meter.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_combo.json"
const FAR := Vector3(5000, 50, 5000)

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("combo: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _clean() -> void:
	for p in [PATH, PATH + ".tmp", PATH + ".bad"]:
		DirAccess.remove_absolute(p)

func _raid(attrs := {}) -> Node:
	_clean()
	var prof := Profile.new(PATH)
	prof.attrs = attrs
	prof.save()
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 4
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c or "group_id" in c:
			c.free()
	await process_frame
	main._player.set_physics_process(false)
	main._player.global_position = FAR
	main._player.rotation = Vector3.ZERO
	main._player._head.rotation = Vector3.ZERO
	return main

# Shoots dead a grunt 10 m ahead with the pistol.
func _kill(main: Node) -> void:
	var player = main._player
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = FAR + Vector3(0, 0, -10)
	main.add_child(e)
	e.set_physics_process(false)
	e.health = 25
	await _frames(3)
	player.select_weapon("pistol")
	main.raid.loaded["pistol"] = 14
	main.raid._fire_cooldown = 0.0
	main.raid.request_fire("pistol", player._cam.global_transform)

func _run() -> void:
	# --- the numbers ---
	var main = await _raid()
	var raid = main.raid
	_check(is_equal_approx(raid.combo_window(1), Tuning.COMBO_WINDOW) and raid.combo_window(2) < raid.combo_window(1) and raid.combo_window(10) < raid.combo_window(5), "the more kills, the shorter the window")
	_check(is_equal_approx(raid.combo_window(2), Tuning.COMBO_WINDOW - Tuning.COMBO_WINDOW_SHRINK) and is_equal_approx(raid.combo_window(500), Tuning.COMBO_WINDOW_MIN), "the window shrinks by a step per kill, down to the minimum")
	_check(is_equal_approx(raid.combo_mult(1), 1.0) and raid.combo_mult(5) > raid.combo_mult(2) and is_equal_approx(raid.combo_mult(5), 1.0 + 4.0 * Tuning.COMBO_MULT_STEP), "the more kills, the bigger the multiplier")

	# --- a chain of kills ---
	var counts := []
	var ended := []
	raid.combo_kill.connect(func(n: int): counts.append(n))
	raid.combo_ended.connect(func(n: int, bonus: int): ended.append([n, bonus]))
	await _kill(main)
	_check(raid.combo == 1 and is_equal_approx(raid.combo_left, raid.combo_window(1)), "the first kill starts a combo")
	_check(main._combo._pulse == 1.0, "a kill makes the counter bump")
	await _kill(main)
	await _kill(main)
	var worth: int = Enemies.xp_value(Enemies.TYPES["grunt"]) * Tuning.COMBO_KILL_SCORE
	_check(counts == [1, 2, 3] and raid.combo == 3 and raid.combo_points == 3 * worth, "three kills in a row: %s, points %d" % [counts, raid.combo_points])
	_check(is_equal_approx(raid.combo_left, raid.combo_window(3)) and is_equal_approx(raid.combo_total, raid.combo_window(3)), "every kill refills the timer, to a shorter window")
	_check(raid.combo_payout() == int(round(3 * worth * raid.combo_mult(3))), "the payout is the banked score times the multiplier, got %d" % raid.combo_payout())
	_check(raid.score == 0, "nothing is paid while the combo runs")
	await process_frame
	await process_frame
	_check(main._combo.count == 3 and main._combo.visible and main._combo.pending.begins_with("+%d" % raid.combo_payout()), "the counter shows 3 and what it pays, got '%s'" % main._combo.pending)
	raid.combo_left = 0.05
	await _frames(5)
	var paid: int = int(round(3 * worth * raid.combo_mult(3)))
	_check(raid.combo == 0 and raid.score == paid and ended == [[3, paid]], "the combo runs out and pays %d, got score %d %s" % [paid, raid.score, ended])
	_check(raid.combo_points == 0 and raid.best_combo == 3, "then it starts over")
	await _kill(main)
	_check(raid.combo == 1, "after the reset a kill starts a new combo of 1")

	# Adrenaline lengthens it, Showboat pays more.
	main.profile.attrs = {"adrenaline": 5, "showboat": 5}
	_check(is_equal_approx(raid.combo_window(3), (Tuning.COMBO_WINDOW - 2.0 * Tuning.COMBO_WINDOW_SHRINK) * 1.5), "Adrenaline 5: 50%% longer combos, got %s" % raid.combo_window(3))
	raid.combo = 3
	raid.combo_points = 900
	_check(raid.combo_payout() == int(round(900 * 1.5 * 1.5)), "Showboat 5: 50%% more combo score, got %d" % raid.combo_payout())
	main.profile.attrs = {}

	# The raid ending pays the running combo and reports it.
	raid.combo = 2
	raid.combo_points = 600
	var before: int = raid.score
	var result := []
	raid.ended.connect(func(r): result.append(r))
	raid._finish("dead")
	_check(raid.score == before + int(round(600 * raid.combo_mult(2))) and result.size() == 1 and result[0]["score"] == raid.score and result[0]["best_combo"] == 3, "the end of the raid pays the combo (600 x 1.25), result %s" % [result])
	main.queue_free()
	await process_frame

	# --- the skull counter ---
	var meter := ComboMeter.new()
	root.add_child(meter)
	meter.count = 4
	_check(ComboMeter.SKULL_COLOR.r > 0.8 and ComboMeter.SKULL_COLOR.g < 0.2 and ComboMeter.SKULL_COLOR.b < 0.2, "the skull is red")
	_check(is_equal_approx(meter.scale_now(), 1.0), "at rest the counter is its normal size")
	meter.bump()
	_check(is_equal_approx(meter.scale_now(), 1.0 + ComboMeter.PEAK_SCALE), "a kill makes it much bigger at once")
	meter._process(ComboMeter.PULSE_SECONDS / 2.0)
	var mid: float = meter.scale_now()
	_check(mid > 1.0 and mid < 1.0 + ComboMeter.PEAK_SCALE and meter._shake.length() <= ComboMeter.SHAKE * 1.5, "it shrinks back and the shake dies down, got %s" % mid)
	meter._process(ComboMeter.PULSE_SECONDS)
	_check(is_equal_approx(meter.scale_now(), 1.0) and meter._shake == Vector2.ZERO, "and settles at normal size without shaking")
	meter.bump()
	meter._process(0.01)
	meter.bump()
	_check(is_equal_approx(meter.scale_now(), 1.0 + ComboMeter.PEAK_SCALE), "each kill repeats the effect")
	meter.count = 0
	meter._process(3.0)
	_check(not meter.visible, "no combo, no counter")
	meter.free()

	# --- the ready ring ---
	_check(not WeaponData.DATA["pistol"].has("ready") and WeaponData.DATA["scattergun"]["ready"] and WeaponData.DATA["sniper"]["ready"], "the slow weapons have the ready indicator")
	main = await _raid()
	raid = main.raid
	var player = main._player
	player.select_weapon("pistol")
	await process_frame
	await process_frame
	_check(not main._ring.shown, "the pistol has no ready ring")
	player.select_weapon("sniper")
	await process_frame
	await process_frame
	_check(main._ring.shown and main._ring.is_ready and raid.shot_ready("sniper") and not main._ring.empty, "a loaded sniper is ready: green ring")
	raid.request_fire("sniper", player._cam.global_transform)
	await process_frame
	await process_frame
	_check(not raid.shot_ready("sniper") and raid.shot_progress() < 1.0 and not main._ring.is_ready and main._ring.fraction < 1.0, "right after a shot the ring is not ready and fills up")
	var early: float = main._ring.fraction
	raid._fire_cooldown *= 0.5
	await process_frame
	await process_frame
	_check(main._ring.fraction > early, "the arc fills as the wait runs down (%s -> %s)" % [early, main._ring.fraction])
	raid._fire_cooldown = 0.0
	await process_frame
	await process_frame
	_check(raid.shot_ready("sniper") and main._ring.is_ready, "when the wait is over the ring is ready")
	raid.request_reload()
	await process_frame
	await process_frame
	_check(raid.reload_weapon == "" or not main._ring.is_ready, "a reload is not ready")
	raid.reload_weapon = "sniper"
	raid.reload_left = raid.reload_seconds * 0.5
	await process_frame
	await process_frame
	_check(not raid.shot_ready("sniper") and not main._ring.is_ready and absf(main._ring.fraction - player.reload_progress()) < 0.15, "while reloading the ring shows the reload")
	raid.cancel_reload()
	player.zoom_input_test = true
	player._update_zoom(10.0)
	await process_frame
	await process_frame
	_check(player.scoped and is_equal_approx(main._ring.radius, 44.0), "scoped in, the ring sits inside the scope")
	player.zoom_input_test = false
	player._update_zoom(10.0)
	player.inventory.clear()
	await process_frame
	await process_frame
	_check(main._ring.empty and not raid.shot_ready("sniper"), "with no ammo the ring shows empty")
	player.select_weapon("scattergun")
	player.inventory.add("ammo", 20)
	raid.loaded["scattergun"] = 30
	await process_frame
	await process_frame
	_check(main._ring.shown and main._ring.is_ready, "the scattergun has the ring too")
	main.queue_free()
	await process_frame

	# --- the gunsmith ---
	_clean()
	var depot := Profile.new(PATH)
	depot.add_items({"att_heavy_barrel": 1, "att_compensator": 1, "att_speed_loader": 1, "att_scope": 1, "scrap": 9})
	depot.save()
	Main.show_start = true
	var base = load("res://main.tscn").instantiate()
	base.profile_path = PATH
	root.add_child(base)
	await process_frame
	var hub = base.get_children().filter(func(c): return "open_station" in c)[0]
	var bench = get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "gunsmith")
	_check(bench.size() == 1 and hub.STATIONS["gunsmith"]["name"] == "GUNSMITH", "the base has a gunsmith bench")
	_check(bench[0].find_children("*", "MeshInstance3D", true, false).size() > 2, "the bench has attachment models lying on it")
	var armory = get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "armory")[0]
	hub._on_station_used(armory)
	var armory_buttons: Array = hub._content.find_children("*", "Button", true, false).map(func(b): return b.text)
	_check(not armory_buttons.any(func(t): return t.begins_with("FIT")), "attachments are no longer fitted at the ammo depot")
	hub._close()
	hub._on_station_used(bench[0])
	_check(hub.open_station == "gunsmith" and hub._panel.visible, "using the bench opens its panel")
	var fit: Array = hub._content.find_children("*", "Button", true, false).map(func(b): return b.text).filter(func(t): return t.begins_with("FIT"))
	_check(fit.size() >= 4, "every weapon offers the attachments in the stash, got %s" % [fit])
	var bare: Dictionary = hub.weapon_stats("pistol")
	_check(is_equal_approx(bare["damage"][0], bare["damage"][1]) and is_equal_approx(bare["rate"][0], bare["rate"][1]) and is_equal_approx(bare["reload"][0], bare["reload"][1]) and is_equal_approx(bare["zoom"][0], bare["zoom"][1]), "a bare weapon shows no change")
	hub._attach("pistol", "att_heavy_barrel")
	hub._attach("scattergun", "att_compensator")
	hub._attach("sniper", "att_speed_loader")
	var s_pistol: Dictionary = hub.weapon_stats("pistol")
	var s_scatter: Dictionary = hub.weapon_stats("scattergun")
	var s_sniper: Dictionary = hub.weapon_stats("sniper")
	_check(is_equal_approx(s_pistol["damage"][1], 30.0) and is_equal_approx(s_pistol["rate"][0], s_pistol["rate"][1]), "Heavy Barrel: pistol damage 25 -> 30 and nothing else, got %s" % [s_pistol])
	_check(is_equal_approx(s_scatter["rate"][1], s_scatter["rate"][0] / 0.85) and is_equal_approx(s_scatter["damage"][0], s_scatter["damage"][1]), "Compensator: faster fire rate only, got %s" % [s_scatter])
	_check(is_equal_approx(s_sniper["reload"][1], s_sniper["reload"][0] * 0.75) and is_equal_approx(s_sniper["zoom"][0], s_sniper["zoom"][1]), "Speed Loader: faster reload only, got %s" % [s_sniper])
	hub._detach("sniper")
	hub._attach("sniper", "att_scope")
	var s_scope: Dictionary = hub.weapon_stats("sniper")
	_check(s_scope["zoom"][1] > s_scope["zoom"][0] * 1.5 and is_equal_approx(s_scope["reload"][0], s_scope["reload"][1]), "Scope: more zoom only, got %s" % [s_scope])
	var rows: Array = hub._content.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(rows.has("> 30") and rows.any(func(t): return t.begins_with("> x")), "the panel shows the new numbers beside the old, got %s" % [rows])
	depot.load_from_disk()
	_check(depot.attached == {"pistol": "att_heavy_barrel", "scattergun": "att_compensator", "sniper": "att_scope"}, "fittings are saved, got %s" % [depot.attached])
	hub.profile.set_wear("att_heavy_barrel", 0)
	var broken: Dictionary = hub.weapon_stats("pistol")
	_check(is_equal_approx(broken["damage"][0], broken["damage"][1]), "a broken attachment adds nothing")
	base.queue_free()
	await process_frame
	Main.show_start = false
	_clean()
