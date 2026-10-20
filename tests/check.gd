# Run: Godot --headless --path <project> -s tests/check.gd
extends SceneTree

const Loot = preload("res://data/loot.gd")
const Enemies = preload("res://data/enemies.gd")
const Inventory = preload("res://scripts/inventory.gd")
const WeaponData = preload("res://data/weapons.gd")

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
	assert(counts["scrap"] > counts["repair_kit"], "common items must outnumber rare ones")
	var inv := Inventory.new()
	assert(inv.add("medkit", 100) == 100 - 3 * Inventory.SLOTS, "overflow must be returned")
	assert(inv.add("scrap", 1) == 1, "full backpack must reject new item types")
	inv.take_one(0)
	assert(inv.add("medkit", 1) == 0, "freed space must be reusable")
	var w: Dictionary = WeaponData.DATA["scattergun"]
	assert(WeaponData.damage_at(w, 5.0) == 12, "full damage inside effective range")
	assert(WeaponData.damage_at(w, 15.0) < 12 and WeaponData.damage_at(w, 15.0) > 0, "falloff between effective and max")
	assert(WeaponData.damage_at(w, 30.0) == 0, "no damage beyond max range")
	print("checks passed: ", counts)
	quit()
