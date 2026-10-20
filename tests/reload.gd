# Run: Godot --headless --path <project> -s tests/reload.gd   (exit code 1 on failure)
# Magazine and reload: shots drain the clip, an empty clip dry-fires, R refills it from the
# backpack over RELOAD_SECONDS, no shooting while reloading, switching weapons cancels.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Tuning = preload("res://data/tuning.gd")

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await _run()
	for f in failures:
		printerr(f)
	print("reload: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 1
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c:
			c.queue_free()
	await process_frame
	var raid = main.raid
	var player = main._player
	var aim: Transform3D = player._cam.global_transform
	var clip: int = player.weapon["clip"]

	_check(raid.loaded_rounds("pistol") == Tuning.STARTING_AMMO, "start: magazine held %d" % raid.loaded_rounds("pistol"))
	player.inventory.add("ammo", 30)  # 42 in the backpack, 12 loaded
	_check(raid.loaded_rounds("pistol") == Tuning.STARTING_AMMO, "pickup must not refill the magazine")

	raid.loaded["pistol"] = 4  # a part-empty magazine, so the fill can be seen part way
	_check(raid.request_reload(), "reload with spare ammo should start")
	_check(not raid.request_reload(), "a second reload while reloading must be refused")
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0 * 0.6))
	_check(not raid.request_fire("pistol", aim), "no firing while reloading")
	var mid: int = raid.shown_rounds("pistol")
	_check(mid > 4 and mid < clip, "mid-reload the HUD should show a partial fill, got %d" % mid)
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0) + 10)
	_check(raid.loaded_rounds("pistol") == clip, "after reload the magazine should be full, got %d" % raid.loaded_rounds("pistol"))
	_check(not raid.request_reload(), "reload with a full magazine must be refused")

	# Drain the magazine: the shot after the last round is a dry fire and costs nothing.
	for i in clip:
		await _frames(20)
		_check(raid.request_fire("pistol", aim), "shot %d should fire" % i)
	await _frames(20)
	var held: int = player.inventory.count("ammo")
	_check(raid.loaded_rounds("pistol") == 0 and held == 42 - clip, "empty magazine, backpack %d" % held)
	_check(not raid.request_fire("pistol", aim), "an empty magazine must not fire")
	_check(player.inventory.count("ammo") == held, "a dry fire must not cost ammo")

	# Switching weapon mid-reload cancels it.
	_check(raid.request_reload(), "reload from empty should start")
	player.select_weapon("scattergun")
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0) + 10)
	_check(raid.loaded_rounds("pistol") == 0, "a cancelled reload must not fill the magazine")
	player.select_weapon("pistol")
	_check(raid.request_reload(), "reload again after cancelling")
	await _frames(int(Tuning.RELOAD_SECONDS * 60.0) + 10)
	_check(raid.loaded_rounds("pistol") == mini(clip, held), "reload should load a full magazine, got %d" % raid.loaded_rounds("pistol"))

	main.queue_free()
	await process_frame
