# What the player can grow. Edit numbers here. Two separate systems:
#
# 1. RAID UPGRADES (weapon and character) are earned and picked during a raid and lost when it ends, by
#    extracting or dying. XP orbs from kills fill a level: the first needs RAID_XP_BASE xp and each later one
#    RAID_XP_GROWTH more (a grunt is worth 3, see data/enemies.gd). A level earns a pick: the game pauses and offers
#    RAID_PICK_CHOICES random upgrades that are not yet at their max. Descending to the next level keeps them.
#      per_level: the effect of each level (a fraction, except "hp": max health and healing per level)
const RAID_XP_BASE := 12
const RAID_XP_GROWTH := 4
const RAID_PICK_CHOICES := 3
const RAID_UPGRADES := {
	"damage": {"group": "weapon", "name": "Heavy rounds", "max": 5, "per_level": 0.15, "desc": "+15% damage with every weapon"},
	"firerate": {"group": "weapon", "name": "Rapid fire", "max": 3, "per_level": 0.1, "desc": "10% shorter wait between shots"},
	"vitality": {"group": "character", "name": "Vitality", "max": 5, "hp": 20, "desc": "+20 max health and heal 20 now"},
	"sprint": {"group": "character", "name": "Fleet foot", "max": 5, "per_level": 0.08, "desc": "+8% move speed"},
	"hands": {"group": "character", "name": "Quick hands", "max": 3, "per_level": 0.15, "desc": "15% faster reloads"},
	"plating": {"group": "character", "name": "Plating", "max": 5, "per_level": 0.04, "desc": "4% less damage taken"},
}

# 2. ATTRIBUTES are permanent and spent only at the base. Points come from an extract: POINTS_PER_EXTRACT, plus
#    one for every KILLS_PER_POINT kills in that raid, but never more than POINTS_PER_RAID_MAX come home from one
#    raid. Each point buys one level of one attribute (up to "max").
const POINTS_PER_EXTRACT := 1
const KILLS_PER_POINT := 5
const POINTS_PER_RAID_MAX := 3

# "speed": walk and sprint speed, +per_level each level (a fraction).
# "constitution": +hp max health and armor (a fraction of every hit absorbed) per level.
# "handling": reload time is cut by per_level (a fraction) per level.
const ATTRS := {
	"speed": {"name": "Speed", "max": 5, "per_level": 0.06, "desc": "+6% move speed per level"},
	"constitution": {"name": "Constitution", "max": 5, "hp": 10, "armor": 0.04, "desc": "+10 max health and 4% less damage taken per level"},
	"handling": {"name": "Weapon handling", "max": 5, "per_level": 0.1, "desc": "10% faster reloads per level"},
}
