# Loot only appears in these small walled rooms (crates stand against the inside walls); the map has one of each.
#   size: outside width of the area (m)        door: doorway width (m); every area has two doorways, on opposite walls
#   height: wall height (m)   style: how the building is dressed (see Main._dress_building)   trim_color, roof_color: its trim and roof
#   crates: [min, max] crates inside
#   rolls: [min, max] item rolls per crate     qty_mult: scales every stack the zone drops
#   pool: item id -> relative chance (ids come from data/loot.gd)
const DATA := {
	"armory": {
		"name": "ARMORY", "style": "armory", "height": 4.6, "size": 5.0, "door": 2.0, "crates": [2, 3], "rolls": [2, 3], "qty_mult": 1.0,
		"pool": {"ammo": 70, "repair_kit": 0},
		"wall_color": Color(0.34, 0.38, 0.27), "crate_color": Color(0.95, 0.75, 0.2),
		"trim_color": Color(0.95, 0.75, 0.1), "roof_color": Color(0.2, 0.22, 0.18),
	},
	"med_post": {
		"name": "MED POST", "style": "medical", "height": 4.2, "size": 4.6, "door": 2.0, "crates": [2, 2], "rolls": [1, 2], "qty_mult": 1.0,
		"pool": {"medkit": 60, "repair_kit": 0},
		"wall_color": Color(0.86, 0.9, 0.9), "crate_color": Color(0.9, 0.3, 0.3),
		"trim_color": Color(0.2, 0.7, 0.45), "roof_color": Color(0.7, 0.75, 0.78),
	},
}
