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

# 2. ATTRIBUTES are permanent and spent only at the base, on the character screen. Points come only from clearing a
#    round: kill every enemy (and destroy every enemy base) on round 5, 10, 15 ... and one point is earned, with a
#    message on screen. ATTR_LEVEL_MAX is the most one attribute can hold, ATTR_TOTAL_MAX the most points that can
#    ever be spent across all of them (so a character is a build: ATTR_TOTAL_MAX of the attributes below).
const ATTR_ROUNDS_PER_POINT := 5
const ATTR_LEVEL_MAX := 5
const ATTR_TOTAL_MAX := 15

# What each stat does, for the character screen: "text" is the line shown (the {v} is one level's worth), "mul" turns
# the stored number into the shown one (100 for a fraction shown as a percent), "dec" its decimals. Every stat is
# read by one hook somewhere in the game; profile.bonus(stat) is its total from the attributes.
const STATS := {
	"speed": {"text": "+{v}% move speed", "mul": 100, "dec": 0},
	"sprint_speed": {"text": "+{v}% sprint speed", "mul": 100, "dec": 0},
	"jump_height": {"text": "+{v}% jump speed (higher jumps)", "mul": 100, "dec": 0},
	"stealth": {"text": "{v}% slower to be spotted", "mul": 100, "dec": 0},
	"extract_speed": {"text": "{v}% shorter extract hold", "mul": 100, "dec": 0},
	"hp": {"text": "+{v} max health", "mul": 1, "dec": 0},
	"armor": {"text": "{v}% less damage taken", "mul": 100, "dec": 0},
	"regen": {"text": "+{v} health per second", "mul": 1, "dec": 1},
	"kill_heal": {"text": "+{v} health per kill", "mul": 1, "dec": 1},
	"heal_mult": {"text": "+{v}% healing from medkits", "mul": 100, "dec": 0},
	"dodge": {"text": "{v}% chance to shrug off a hit", "mul": 100, "dec": 0},
	"last_stand": {"text": "{v}% less damage taken below 30% health", "mul": 100, "dec": 0},
	"damage": {"text": "+{v}% damage", "mul": 100, "dec": 0},
	"firerate": {"text": "{v}% shorter wait between shots", "mul": 100, "dec": 0},
	"reload": {"text": "{v}% faster reloads", "mul": 100, "dec": 0},
	"spread": {"text": "{v}% tighter spread", "mul": 100, "dec": 0},
	"range": {"text": "+{v}% effective range", "mul": 100, "dec": 0},
	"zoom": {"text": "{v}% more zoom", "mul": 100, "dec": 0},
	"clip": {"text": "+{v}% magazine size", "mul": 100, "dec": 0},
	"ammo_save": {"text": "{v}% chance a shot costs no ammo", "mul": 100, "dec": 0},
	"crit": {"text": "{v}% chance of double damage", "mul": 100, "dec": 0},
	"dmg_pistol": {"text": "+{v}% pistol damage", "mul": 100, "dec": 0},
	"dmg_scattergun": {"text": "+{v}% scattergun damage", "mul": 100, "dec": 0},
	"dmg_sniper": {"text": "+{v}% sniper damage", "mul": 100, "dec": 0},
	"dmg_unaware": {"text": "+{v}% damage to enemies that have not noticed you", "mul": 100, "dec": 0},
	"ammo_drop": {"text": "+{v}% ammo drops", "mul": 100, "dec": 0},
	"scrap_find": {"text": "+{v}% scrap drops", "mul": 100, "dec": 0},
	"att_find": {"text": "+{v}% attachment drops", "mul": 100, "dec": 0},
	"powerup_find": {"text": "+{v}% powerup drops", "mul": 100, "dec": 0},
	"powerup_time": {"text": "+{v}% powerup duration", "mul": 100, "dec": 0},
	"start_ammo": {"text": "+{v} starting ammo", "mul": 1, "dec": 0},
	"att_wear": {"text": "{v}% chance a shot does not wear an attachment", "mul": 100, "dec": 0},
	"repair_cost": {"text": "{v} less scrap to repair an attachment", "mul": 1, "dec": 0},
	"xp_gain": {"text": "+{v}% experience", "mul": 100, "dec": 0},
	"combo_time": {"text": "+{v}% combo time", "mul": 100, "dec": 0},
	"combo_score": {"text": "+{v}% combo score", "mul": 100, "dec": 0},
}

# The 35 attributes, in the order the character screen shows them, by "group". "stats" maps a stat above to what one
# level adds.
const ATTR_GROUPS := ["OFFENSE", "DEFENSE", "MOBILITY", "SCAVENGING", "MASTERY"]
const ATTRS := {
	"marksman": {"group": "OFFENSE", "name": "Marksman", "stats": {"damage": 0.04}},
	"trigger": {"group": "OFFENSE", "name": "Trigger discipline", "stats": {"firerate": 0.04}},
	"handling": {"group": "OFFENSE", "name": "Weapon handling", "stats": {"reload": 0.1}},
	"steady": {"group": "OFFENSE", "name": "Steady hands", "stats": {"spread": 0.12}},
	"longshot": {"group": "OFFENSE", "name": "Long shot", "stats": {"range": 0.06}},
	"eagle": {"group": "OFFENSE", "name": "Eagle eye", "stats": {"zoom": 0.06}},
	"magazine": {"group": "OFFENSE", "name": "Extended mags", "stats": {"clip": 0.1}},
	"thrifty": {"group": "OFFENSE", "name": "Thrifty", "stats": {"ammo_save": 0.04}},
	"lethal": {"group": "OFFENSE", "name": "Lethal", "stats": {"crit": 0.04}},
	"sidearm": {"group": "OFFENSE", "name": "Sidearm training", "stats": {"dmg_pistol": 0.08}},
	"closequarters": {"group": "OFFENSE", "name": "Close quarters", "stats": {"dmg_scattergun": 0.08}},
	"longgun": {"group": "OFFENSE", "name": "Long gun training", "stats": {"dmg_sniper": 0.08}},
	"ambush": {"group": "OFFENSE", "name": "Ambusher", "stats": {"dmg_unaware": 0.1}},
	"constitution": {"group": "DEFENSE", "name": "Constitution", "stats": {"hp": 10, "armor": 0.04}},
	"regen": {"group": "DEFENSE", "name": "Regeneration", "stats": {"regen": 0.3}},
	"bloodlust": {"group": "DEFENSE", "name": "Bloodlust", "stats": {"kill_heal": 1.5}},
	"medic": {"group": "DEFENSE", "name": "Field medic", "stats": {"heal_mult": 0.1}},
	"dodge": {"group": "DEFENSE", "name": "Evasion", "stats": {"dodge": 0.02}},
	"laststand": {"group": "DEFENSE", "name": "Last stand", "stats": {"last_stand": 0.06}},
	"speed": {"group": "MOBILITY", "name": "Speed", "stats": {"speed": 0.06}},
	"sprint": {"group": "MOBILITY", "name": "Sprinter", "stats": {"sprint_speed": 0.06}},
	"jump": {"group": "MOBILITY", "name": "Spring legs", "stats": {"jump_height": 0.06}},
	"ghost": {"group": "MOBILITY", "name": "Ghost", "stats": {"stealth": 0.06}},
	"quickexit": {"group": "MOBILITY", "name": "Quick exit", "stats": {"extract_speed": 0.05}},
	"scavenger": {"group": "SCAVENGING", "name": "Scavenger", "stats": {"ammo_drop": 0.1}},
	"salvage": {"group": "SCAVENGING", "name": "Salvager", "stats": {"scrap_find": 0.1}},
	"prospector": {"group": "SCAVENGING", "name": "Prospector", "stats": {"att_find": 0.2}},
	"lucky": {"group": "SCAVENGING", "name": "Lucky", "stats": {"powerup_find": 0.08}},
	"lasting": {"group": "SCAVENGING", "name": "Lasting power", "stats": {"powerup_time": 0.1}},
	"quartermaster": {"group": "SCAVENGING", "name": "Quartermaster", "stats": {"start_ammo": 6}},
	"careful": {"group": "SCAVENGING", "name": "Careful hands", "stats": {"att_wear": 0.08}},
	"tinkerer": {"group": "SCAVENGING", "name": "Tinkerer", "stats": {"repair_cost": 1}},
	"study": {"group": "MASTERY", "name": "Quick study", "stats": {"xp_gain": 0.06}},
	"adrenaline": {"group": "MASTERY", "name": "Adrenaline", "stats": {"combo_time": 0.1}},
	"showboat": {"group": "MASTERY", "name": "Showboat", "stats": {"combo_score": 0.1}},
}

# One level's worth of an attribute as text: "+6% move speed", joined with ", " when it does several things.
static func attr_text(id: String) -> String:
	var parts: Array = []
	for stat in ATTRS[id]["stats"]:
		var s: Dictionary = STATS[stat]
		parts.append(str(s["text"]).format({"v": String.num(float(ATTRS[id]["stats"][stat]) * float(s["mul"]), int(s["dec"]))}))
	return ", ".join(parts)
