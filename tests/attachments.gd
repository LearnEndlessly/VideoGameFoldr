# Run: Godot --headless --path <project> -s tests/attachments.gd   (exit code 1 on failure)
# Bullet flights (a different look per weapon, ricochets off walls) and weapon attachments: super rare drops,
# fitting them at the base, their effects and wear in a raid, breaking, and repair with scrap only.
extends SceneTree

const Main = preload("res://scripts/main.gd")
const Profile = preload("res://scripts/profile.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Enemies = preload("res://data/enemies.gd")
const Tracer = preload("res://scripts/tracer.gd")
const WeaponData = preload("res://data/weapons.gd")
const Attachments = preload("res://data/attachments.gd")
const Tuning = preload("res://data/tuning.gd")
const PATH := "user://test_attachments.json"

var failures: PackedStringArray = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	await process_frame  # the tree is not running yet inside _init
	await _run()
	for f in failures:
		printerr(f)
	print("attachments: %d failure(s)" % failures.size())
	quit(1 if failures.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _raid(profile: Profile) -> Node:
	profile.save()
	Main.show_start = false
	var main = load("res://main.tscn").instantiate()
	main.seed_override = 4
	main.profile_path = PATH
	root.add_child(main)
	await process_frame
	for c in main.get_children():
		if "stats" in c:
			c.queue_free()
	await process_frame
	main._player.set_physics_process(false)
	return main

func _grunt(main: Node, z := -6.0) -> Node:
	var e = Enemy.new()
	var stats: Dictionary = Enemies.TYPES["grunt"].duplicate()
	stats["type"] = "grunt"
	stats["modifier"] = ""
	e.stats = stats
	e.position = Vector3(0, 0, z)
	main.add_child(e)
	e.set_physics_process(false)
	return e

func _tracers(main: Node) -> Array:
	return main.get_children().filter(func(c): return c is Tracer)

func _run() -> void:
	DirAccess.remove_absolute(PATH)

	# Each weapon is drawn differently, and the sniper's trail is the longest.
	var looks := {}
	for id in WeaponData.DATA:
		var t: Dictionary = WeaponData.DATA[id]["tracer"]
		looks[var_to_str([t["color"], t["speed"], t["trail"], t["fade"]])] = true
	_check(looks.size() == WeaponData.DATA.size(), "every weapon should have its own bullet look")
	_check(WeaponData.DATA["sniper"]["tracer"]["trail"] > 4.0 * WeaponData.DATA["pistol"]["tracer"]["trail"], "the sniper's trail should be much longer")

	# A shot spawns a flying bullet; a scattergun blast spawns one per pellet.
	var prof := Profile.new(PATH)
	var main = await _raid(prof)
	var raid = main.raid
	var player = main._player
	var e = _grunt(main)
	await _frames(10)
	raid.request_fire("pistol", player._cam.global_transform)
	var flying := _tracers(main)
	_check(flying.size() == 1 and flying[0].kind == "enemy", "a pistol shot at an enemy should draw one bullet, got %d" % flying.size())
	_check(flying[0].from.distance_to(flying[0].to) > 1.0 and not is_equal_approx(flying[0].from.x, player._cam.global_position.x), "the bullet should fly from the muzzle, not the eye")
	await _frames(2)
	_check(flying[0]._travelled > 0.0 and flying[0]._travelled < flying[0]._len + 0.001, "the bullet should travel over time")
	await _frames(60)
	_check(not is_instance_valid(flying[0]), "a bullet and its trail should clean themselves up")
	raid.loaded["scattergun"] = 10
	player.select_weapon("scattergun")
	await _frames(70)
	var before := _tracers(main).size()
	raid.request_fire("scattergun", player._cam.global_transform)
	_check(_tracers(main).size() - before == int(WeaponData.DATA["scattergun"]["pellets"]), "a scattergun blast should draw %d pellets" % int(WeaponData.DATA["scattergun"]["pellets"]))
	# A shot into a wall ricochets: it arrives, throws sparks and a streak.
	player.select_weapon("pistol")
	player.rotation.y = PI / 2.0  # face along -x toward cover or the outer wall
	await _frames(70)
	raid.request_fire("pistol", player._cam.global_transform)
	var wall: Array = _tracers(main).filter(func(t): return t.kind == "wall")
	_check(wall.size() == 1, "a shot at the wall should be a wall hit")
	# On arrival: sparks, plus a ricochet streak off a wall (not off an enemy).
	var hit_wall := Tracer.new()
	hit_wall.from = Vector3(0, 1, 0)
	hit_wall.to = Vector3(0, 1, -9)
	hit_wall.normal = Vector3(0, 0, 1)
	hit_wall.kind = "wall"
	hit_wall.cfg = WeaponData.DATA["pistol"]["tracer"]
	main.add_child(hit_wall)
	var hit_enemy := Tracer.new()
	hit_enemy.from = hit_wall.from
	hit_enemy.to = hit_wall.to
	hit_enemy.normal = hit_wall.normal
	hit_enemy.kind = "enemy"
	hit_enemy.cfg = hit_wall.cfg
	main.add_child(hit_enemy)
	await _frames(12)
	_check(hit_wall._arrived and hit_wall._streak != null and hit_wall._sparks.size() > 0, "a wall hit should spark and ricochet")
	_check(hit_enemy._arrived and hit_enemy._streak == null and hit_enemy._sparks.size() > 0, "an enemy hit should spark but not ricochet")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)

	# Drops: scrap from enemies, attachments super rare.
	main = await _raid(Profile.new(PATH))
	raid = main.raid
	var before_p := get_nodes_in_group("nothing").size()
	var scrap := 0
	var atts := 0
	var counts := {}
	for i in 600:
		raid._on_kill(Vector3(55, 0, 55), Enemies.TYPES["grunt"])
	await _frames(2)
	for c in main.get_children():
		if "qty" in c and "id" in c:
			counts[c.id] = int(counts.get(c.id, 0)) + 1
	scrap = int(counts.get("scrap", 0))
	for id in Attachments.DATA:
		atts += int(counts.get(id, 0))
	_check(scrap > 120 and scrap < 300, "about 35%% of grunts should drop scrap, got %d of 600" % scrap)
	_check(atts >= 2 and atts <= 30, "attachments should be super rare (about %d%% of kills), got %d of 600" % [int(Tuning.ATTACHMENT_DROP_CHANCE * 100.0), atts])
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)

	# The profile: fitting, one per weapon, only what is owned, persistence, repair with scrap only.
	var p := Profile.new(PATH)
	_check(not p.attach("pistol", "att_heavy_barrel"), "cannot fit what you do not own")
	p.add_items({"att_heavy_barrel": 1, "att_compensator": 1})
	_check(p.attach("pistol", "att_heavy_barrel") and not p.attach("pistol", "att_compensator"), "one attachment per weapon")
	_check(not p.attach("sniper", "att_heavy_barrel"), "one copy fits one weapon")
	_check(p.attach("sniper", "att_compensator"), "a second attachment fits another weapon")
	p.set_wear("att_heavy_barrel", 0)
	_check(p.is_broken("att_heavy_barrel") and p.shots_left("att_compensator") == Attachments.DATA["att_compensator"]["durability"], "wear is tracked per attachment")
	_check(not p.repair("att_heavy_barrel"), "no scrap, no repair")
	p.add_items({"scrap": Attachments.REPAIR_SCRAP + 2})
	_check(p.repair("att_heavy_barrel") and not p.is_broken("att_heavy_barrel") and p.owned("scrap") == 2, "repair costs %d scrap and restores it" % Attachments.REPAIR_SCRAP)
	_check(not p.repair("att_compensator"), "an unworn attachment needs no repair")
	p.set_wear("att_compensator", 40)
	p.save()
	var q := Profile.new(PATH)
	q.load_from_disk()
	_check(q.attached == p.attached and q.shots_left("att_compensator") == 40 and q.owned("att_heavy_barrel") == 1, "attachments, fittings and wear should persist")
	q.take_items({"att_heavy_barrel": 1})
	_check(not q.attached.has("pistol"), "an attachment that left the stash is taken off the weapon")
	DirAccess.remove_absolute(PATH)

	# In a raid: the effect applies, each shot wears it, and at 0 it breaks and stops working.
	var kit := Profile.new(PATH)
	kit.add_items({"att_heavy_barrel": 1})
	kit.attach("pistol", "att_heavy_barrel")
	kit.set_wear("att_heavy_barrel", 2)
	main = await _raid(kit)
	raid = main.raid
	player = main._player
	var broke: Array = []
	raid.attachment_broke.connect(func(n): broke.append(n))
	e = _grunt(main)
	await _frames(10)
	raid.request_fire("pistol", player._cam.global_transform)
	_check(is_equal_approx(e.health, 50.0 - round(25 * 1.2)), "Heavy Barrel should add 20%% damage (30), grunt health %s" % e.health)
	_check(raid.att_left["att_heavy_barrel"] == 1 and broke.is_empty(), "one shot wears it by one")
	await _frames(20)
	raid.request_fire("pistol", player._cam.global_transform)
	_check(raid.att_left["att_heavy_barrel"] == 0 and broke == ["Heavy Barrel"], "the second shot should break it")
	_check(raid.attachment_text() == "HEAVY BARREL BROKEN", "the HUD should say it is broken, got %s" % raid.attachment_text())
	var e2 = _grunt(main, -8.0)
	e2.position.x = 3.0
	var hp_before: float = e.health
	await _frames(20)
	_check(raid._att("pistol").is_empty(), "a broken attachment does nothing")
	raid.request_fire("pistol", player._cam.global_transform)
	main.raid._player.take_damage(10000)  # end the raid: wear is saved
	var disk := Profile.new(PATH)
	disk.load_from_disk()
	_check(disk.is_broken("att_heavy_barrel") and disk.owned("att_heavy_barrel") == 1 and disk.attached.get("pistol") == "att_heavy_barrel", "a broken attachment is kept (not lost with the raid) and stays broken until repaired")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)

	# Loot kept from an extract: scrap and attachments are banked, and attachments are not multiplied by the reward.
	var bank := Profile.new(PATH)
	main = await _raid(bank)
	main.raid.reward_mult = 2.0
	main._player.inventory.add("scrap", 3)
	main._player.inventory.add("att_compensator", 1)
	main.raid.hold_seconds = 0.2
	main.raid.request_extract("A")
	await _frames(20)
	var banked := Profile.new(PATH)
	banked.load_from_disk()
	_check(banked.owned("scrap") == 6 and banked.owned("att_compensator") == 1, "scrap is scaled by the reward, an attachment is not, got %s" % [banked.totals])
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(PATH)

	# The ammo depot: fit, remove and repair buttons.
	var depot := Profile.new(PATH)
	depot.add_items({"att_speed_loader": 1, "scrap": 9})
	depot.save()
	Main.show_start = true
	var base = load("res://main.tscn").instantiate()
	base.profile_path = PATH
	root.add_child(base)
	await process_frame
	var hub = base.get_children().filter(func(c): return "open_station" in c)[0]
	hub._on_station_used(get_nodes_in_group("station").filter(func(n): return n.get_meta("station_id") == "armory")[0])
	var texts: Array = hub._content.find_children("*", "Button", true, false).map(func(b): return b.text)
	_check(texts.any(func(t): return t.begins_with("FIT")), "the depot should offer to fit the Speed Loader, buttons %s" % [texts])
	hub._attach("pistol", "att_speed_loader")
	hub.profile.set_wear("att_speed_loader", 50)
	hub._refresh()
	texts = hub._content.find_children("*", "Button", true, false).map(func(b): return b.text)
	_check(texts.any(func(t): return t.begins_with("REPAIR")) and texts.has("REMOVE"), "a fitted attachment offers remove and repair, buttons %s" % [texts])
	hub._repair("att_speed_loader")
	_check(hub.profile.shots_left("att_speed_loader") == Attachments.DATA["att_speed_loader"]["durability"] and hub.profile.owned("scrap") == 9 - Attachments.REPAIR_SCRAP, "repairing at the depot spends scrap")
	base.queue_free()
	await process_frame
	Main.show_start = false
	DirAccess.remove_absolute(PATH)
