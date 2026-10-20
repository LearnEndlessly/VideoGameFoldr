# Run: Godot --headless --path <project> -s tests/check.gd
extends SceneTree

const Loot = preload("res://data/loot.gd")
const Enemies = preload("res://data/enemies.gd")
const Inventory = preload("res://scripts/inventory.gd")
const WeaponData = preload("res://data/weapons.gd")
const LootZones = preload("res://data/loot_zones.gd")
const Sounds = preload("res://data/sounds.gd")
const Sfx = preload("res://scripts/sfx.gd")

func _init() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	for i in 200:
		assert(Loot.roll(a) == Loot.roll(b), "same seed must give same loot")
		assert(Enemies.roll(a) == Enemies.roll(b), "same seed must give same enemy")
	var counts := {}
	for i in 5000:
		var id: String = Loot.roll(a)[0]
		counts[id] = counts.get(id, 0) + 1
	assert(counts["ammo"] > counts["medkit"], "common items must outnumber rare ones")
	assert(not counts.has("repair_kit"), "repair_kit has weight 0 and must never drop")
	var inv := Inventory.new()
	assert(inv.add("medkit", 100) == 100 - 3 * Inventory.SLOTS, "overflow must be returned")
	assert(inv.add("ammo", 1) == 1, "full backpack must reject new item types")
	inv.take_one(0)
	assert(inv.add("medkit", 1) == 0, "freed space must be reusable")
	var w: Dictionary = WeaponData.DATA["scattergun"]
	assert(WeaponData.damage_at(w, 5.0) == w["damage"], "full damage inside effective range")
	assert(WeaponData.damage_at(w, 17.0) < w["damage"] and WeaponData.damage_at(w, 17.0) > 0, "falloff between effective and max")
	assert(WeaponData.damage_at(w, 30.0) == 0, "no damage beyond max range")
	for name in Sounds.DATA:
		var s := Sfx.stream_for(name)
		var want: int = int(float(Sounds.DATA[name]["duration"]) * Sfx.RATE) * 2
		assert(s.data.size() == want, "%s: wrong length" % name)
		var peak := 0
		for i in range(0, s.data.size(), 2):
			peak = maxi(peak, absi(s.data.decode_s16(i)))
		assert(peak > 1000, "%s: sound is silent" % name)
	for zone_id in LootZones.DATA:
		var zone: Dictionary = LootZones.DATA[zone_id]
		for item in zone["pool"]:
			assert(Loot.ITEMS.has(item), "%s drops unknown item %s" % [zone_id, item])
		for i in 200:
			assert(zone["pool"].has(Loot.roll(a, zone["pool"], zone["qty_mult"])[0]), "%s rolled outside its pool" % zone_id)
	assert(Loot.roll(a, {"medkit": 1}, 3.0) == ["medkit", 3], "pool and quantity multiplier must apply")
	for weapon_id in WeaponData.DATA:
		assert(Sounds.DATA.has(WeaponData.DATA[weapon_id]["sound"]), "weapon %s has no sound" % weapon_id)
	# Every art path named in a data table must exist (after the first Godot import on a fresh clone).
	for table in [WeaponData.DATA, Enemies.TYPES]:
		for row_id in table:
			var model_path: String = table[row_id].get("model", "")
			assert(model_path == "" or ResourceLoader.exists(model_path), "%s names a model that does not exist: %s" % [row_id, model_path])
	print("checks passed: ", counts)
	quit()
