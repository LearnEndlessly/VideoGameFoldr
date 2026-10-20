# What the base lets the player buy and train. Edit numbers here.
#
# Weapon upgrades are paid from the stash (loot kept from raids). A weapon at level n costs
# WEAPON_COSTS[n] to take to level n + 1; each level adds WEAPON_DAMAGE_PER_LEVEL to its damage.
const WEAPON_MAX_LEVEL := 3
const WEAPON_DAMAGE_PER_LEVEL := 0.2
const WEAPON_COSTS := [
	{"ammo": 10},
	{"ammo": 20, "medkit": 2},
	{"ammo": 30, "medkit": 4},
]

# Attribute points are earned on a successful extract only: POINTS_PER_EXTRACT, plus one for every
# KILLS_PER_POINT kills in that raid. Each point buys one level of one attribute (up to "max").
const POINTS_PER_EXTRACT := 1
const KILLS_PER_POINT := 5

# "speed": walk and sprint speed, +per_level each level (a fraction).
# "constitution": +hp max health and armor (a fraction of every hit absorbed) per level.
# "handling": reload time is cut by per_level (a fraction) per level.
const ATTRS := {
	"speed": {"name": "Speed", "max": 5, "per_level": 0.06, "desc": "+6% move speed per level"},
	"constitution": {"name": "Constitution", "max": 5, "hp": 10, "armor": 0.04, "desc": "+10 max health and 4% less damage taken per level"},
	"handling": {"name": "Weapon handling", "max": 5, "per_level": 0.1, "desc": "10% faster reloads per level"},
}
