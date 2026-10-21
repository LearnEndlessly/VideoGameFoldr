extends RefCounted
# The stat resolver. UI-free: given the allocated node ids it sums each stat's "flat" and "increased" effects.
# final = clamp((base + sum_flat) * (1 + sum_increased), floor, cap); increased stacks additively.

const Tuning = preload("res://data/tuning.gd")
const SkillNodes = preload("res://data/skill_nodes.gd")

static var _rows := {}

# {stat: {"flat": f, "increased": i}} over the allocated ids; unknown ids (a node removed from the table) are skipped.
static func sums(ids: Array) -> Dictionary:
	if _rows.is_empty():
		for r in SkillNodes.NODES:
			_rows[r["id"]] = r
	var out := {}
	for id in ids:
		if not _rows.has(id):
			continue
		for e in _rows[id]["effects"]:
			var s: Dictionary = out.get(e["stat"], {"flat": 0.0, "increased": 0.0})
			s[e["mod"]] += float(e["value"])
			out[e["stat"]] = s
	return out

# The tree's limits for a stat as [floor, cap]; an unlisted stat is unlimited.
static func limits(stat: String) -> Array:
	return Tuning.SKILL_STAT_LIMITS.get(stat, [-INF, INF])

# A stat with a real base (health 100, speed 1.0): (base + flat) * (1 + increased), where what the tree added is held to
# the stat's floor and cap, so a cap of +0.4 on speed 1.0 gives at most 1.4.
static func resolve(stat: String, base: float, ids: Array) -> float:
	var s: Dictionary = sums(ids).get(stat, {"flat": 0.0, "increased": 0.0})
	var raw: float = (base + s["flat"]) * (1.0 + s["increased"])
	var lim := limits(stat)
	return base + clampf(raw - base, lim[0], lim[1])

# What the tree adds to a stat the game reads as a bonus on top of nothing (0.12 = +12%, 30 = +30 health): the flat and
# increased sums added, held to the limits. This is what Profile.bonus returns.
static func bonus(stat: String, ids: Array) -> float:
	var s: Dictionary = sums(ids).get(stat, {"flat": 0.0, "increased": 0.0})
	var lim := limits(stat)
	return clampf(s["flat"] + s["increased"], lim[0], lim[1])
