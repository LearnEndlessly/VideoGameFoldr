# Walkable buildings dropped on the map (scenes/buildings/, built by tools/build_buildings.gd from the Kenney Modular Buildings kit).
# Placed before the cover (so there is room for them) from a stream of their own; the cover then fills around them, so a seed
# differs from before the buildings existed, but tuning these never moves the enemies, loot rooms, shelters or towers.
# A building that finds no clear spot is skipped, so crowded maps get fewer.
# "size" is the footprint [x, z] in metres with the door on the +z side; "crates" is [min, max] loot crates put on random
# floor spots (the scene's CrateSpots markers); the crates roll from the default loot pool.
const COUNT := [2, 4]  # buildings attempted per map
const CRATE_ZONE_ID := "building"
const CRATE_COLOR := Color(0.9, 0.7, 0.1)
const DATA := {
	"house_small": {"scene": "res://scenes/buildings/house_small.tscn", "weight": 4, "size": [12.0, 8.0], "crates": [1, 2]},
	"depot": {"scene": "res://scenes/buildings/depot.tscn", "weight": 3, "size": [12.0, 8.0], "crates": [2, 4]},
	"tower": {"scene": "res://scenes/buildings/tower.tscn", "weight": 2, "size": [8.0, 8.0], "crates": [2, 4]},
	"row_shop": {"scene": "res://scenes/buildings/row_shop.tscn", "weight": 2, "size": [16.0, 8.0], "crates": [3, 5]},
}
