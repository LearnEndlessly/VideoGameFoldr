# Loot only appears in these walled areas; the map has one of each.
#   size: outside width of the area (m)        crates: [min, max] crates inside
#   rolls: [min, max] item rolls per crate     qty_mult: scales every stack the zone drops
#   pool: item id -> relative chance (ids come from data/loot.gd)
const DATA := {
	"depot": {
		"name": "SUPPLY DEPOT", "size": 14.0, "crates": [4, 5], "rolls": [1, 2], "qty_mult": 1.5,
		"pool": {"scrap": 60, "ammo": 15, "medkit": 10, "repair_kit": 0},
		"wall_color": Color(0.45, 0.45, 0.5), "crate_color": Color(0.7, 0.7, 0.75),
	},
	"armory": {
		"name": "ARMORY", "size": 10.0, "crates": [2, 3], "rolls": [2, 3], "qty_mult": 1.0,
		"pool": {"ammo": 70, "scrap": 15, "repair_kit": 0},
		"wall_color": Color(0.55, 0.35, 0.25), "crate_color": Color(0.95, 0.75, 0.2),
	},
	"med_post": {
		"name": "MED POST", "size": 8.0, "crates": [2, 2], "rolls": [1, 2], "qty_mult": 1.0,
		"pool": {"medkit": 60, "repair_kit": 0, "scrap": 15},
		"wall_color": Color(0.35, 0.5, 0.4), "crate_color": Color(0.9, 0.3, 0.3),
	},
}
