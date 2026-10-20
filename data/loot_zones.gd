# Loot only appears in these small walled rooms (crates stand against the inside walls); the map has one of each.
#   size: outside width of the area (m)        door: doorway width (m)
#   crates: [min, max] crates inside
#   rolls: [min, max] item rolls per crate     qty_mult: scales every stack the zone drops
#   pool: item id -> relative chance (ids come from data/loot.gd)
const DATA := {
	"armory": {
		"name": "ARMORY", "size": 5.0, "door": 2.0, "crates": [2, 3], "rolls": [2, 3], "qty_mult": 1.0,
		"pool": {"ammo": 70, "repair_kit": 0},
		"wall_color": Color(0.55, 0.35, 0.25), "crate_color": Color(0.95, 0.75, 0.2),
	},
	"med_post": {
		"name": "MED POST", "size": 4.0, "door": 2.0, "crates": [2, 2], "rolls": [1, 2], "qty_mult": 1.0,
		"pool": {"medkit": 60, "repair_kit": 0},
		"wall_color": Color(0.35, 0.5, 0.4), "crate_color": Color(0.9, 0.3, 0.3),
	},
}
