# Run: Godot --headless --path <project> -s tests/spawn_safety.gd   (exit code 1 on failure)
# Regression for "player lost HP in the first 2 seconds": enemy groups must not spawn
# near the player's start, and a player standing still must be untouched for 2 seconds.
extends SceneTree

const Tuning = preload("res://data/tuning.gd")
const Main = preload("res://scripts/main.gd")
const SEEDS := 60      # maps checked for spawn distance
const SIM_SEEDS := 20  # of those, maps also simulated
const SIM_FRAMES := 120  # 2 seconds of physics

func _init() -> void:
	Main.show_start = false
	var failures: PackedStringArray = []
	var min_ok: float = Tuning.ENEMY_GROUP_MIN_ORIGIN - Tuning.GROUP_SPREAD * sqrt(2.0)
	for s in SEEDS:
		var main = load("res://main.tscn").instantiate()
		main.seed_override = s
		root.add_child(main)
		await process_frame  # _ready only runs once the tree is processing
		var player = main._player
		var enemies: Array = main.get_children().filter(func(c): return "stats" in c)
		if enemies.is_empty():
			failures.append("seed %d: no enemies found, the test is not measuring anything" % s)
		for e in enemies:
			var d: float = e.global_position.distance_to(player.global_position)
			if d < min_ok:
				failures.append("seed %d: enemy spawned %.1f m from the player (min %.1f)" % [s, d, min_ok])
				break
		if s < SIM_SEEDS:
			for f in SIM_FRAMES:
				await physics_frame
			if player.health < player.MAX_HEALTH:
				failures.append("seed %d: player at %d HP after 2 s of standing still" % [s, player.health])
		main.queue_free()
		await process_frame
	for f in failures:
		printerr(f)
	print("spawn_safety: %d failure(s) over %d seeds" % [failures.size(), SEEDS])
	quit(1 if failures.size() > 0 else 0)
