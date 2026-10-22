# What the player can grow. Edit numbers here. Two separate systems:
#
# 1. RAID UPGRADES (weapon and character) are earned and picked during a raid and lost when it ends, by
#    extracting or dying. XP orbs from kills fill a level: the first needs RAID_XP_BASE xp and each later one
#    RAID_XP_GROWTH more (a grunt is worth 3, see data/enemies.gd). A level earns a pick: the game pauses and offers
#    RAID_PICK_CHOICES random upgrades that are not yet at their max. Descending to the next level keeps them.
#    There is no top level: every upgrade can be taken again and again, but the amount each level adds
#    shrinks as you stack it: every 3 levels of the same upgrade, each further level adds RAID_DIMINISH times
#    what the previous 3 added (levels 1-3 full, 4-6 x0.8, 7-9 x0.64 ...).
#      per_level: what a full level adds (a fraction, except "hp": max health and healing per level)
const RAID_XP_BASE := 12
const RAID_XP_GROWTH := 4
const RAID_PICK_CHOICES := 3
const RAID_DIMINISH := 0.8
const RAID_UPGRADES := {
	"damage": {"group": "weapon", "name": "Heavy rounds", "per_level": 0.15, "unit": "%", "desc": "more damage with every weapon"},
	"firerate": {"group": "weapon", "name": "Rapid fire", "per_level": 0.1, "unit": "%", "desc": "shorter wait between shots"},
	"vitality": {"group": "character", "name": "Vitality", "hp": 20, "unit": " max health", "desc": "more max health, and heals the same now"},
	"sprint": {"group": "character", "name": "Fleet foot", "per_level": 0.08, "unit": "%", "desc": "more move speed"},
	"hands": {"group": "character", "name": "Quick hands", "per_level": 0.15, "unit": "%", "desc": "faster reloads"},
	"plating": {"group": "character", "name": "Plating", "per_level": 0.04, "unit": "%", "desc": "less damage taken"},
	"jump": {"group": "character", "name": "Moon boots", "per_level": 0.12, "unit": "%", "desc": "lower gravity: you jump higher and float longer"},
}

# What the level about to be gained adds, as a share of a full level (index 0 is the first level).
static func step_factor(index: int) -> float:
	return pow(RAID_DIMINISH, index / 3)

# `level` levels of one upgrade, counted in full levels (3 levels = 3.0, 4 levels = 3.8 ...).
static func total(level: int) -> float:
	var t := 0.0
	for i in level:
		t += step_factor(i)
	return t

# "+13%" or "+16 max health": what taking the next level of upgrade `id` (now at `level`) adds.
static func next_text(id: String, level: int) -> String:
	var u: Dictionary = RAID_UPGRADES[id]
	var f := step_factor(level)
	if u.has("hp"):
		return "+%d%s" % [int(round(float(u["hp"]) * f)), u["unit"]]
	return "+%d%s" % [int(round(float(u["per_level"]) * f * 100.0)), u["unit"]]

# 2. SKILL POINTS are earned by clearing a round (kill every enemy and destroy every enemy base on every round), one
#    point each, held to Tuning.SKILL_POINT_CAP, and spent in the skill tree (data/skill_nodes.gd). The tree's stats are
#    resolved by scripts/skill_stats.gd; Profile.bonus(stat) is what the game reads.
const ATTR_ROUNDS_PER_POINT := 1
