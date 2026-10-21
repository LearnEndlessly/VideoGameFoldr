const Rng = preload("res://data/rng.gd")
const Tuning = preload("res://data/tuning.gd")

# Ammo drops: when the player kills one, it leaves a pickup of "drop" [min, max] ammo with "drop_chance", and
# scrap ("scrap" [min, max] with "scrap_chance"), which repairs weapon attachments at the base.
# Hit zones: every enemy has armor in front and weak points on the head and the back (the exception is "zones": false,
# for the scout). Where a shot lands decides ZONE_MULT times its damage: "head" (the top of the body, from any side),
# "back" (the shooter is behind it), "front" (the shooter is in front of it, where the armor is), "side" in between.
# A type can change them with "zone_mult": {...}. WEAK_COLOR and STRONG_COLOR paint the weak points and the armor.
# Extra fields: "flying": true floats the enemy "hover" metres up and lets it fly over everything (the scout);
# "scout": true makes it raise the alarm in every group within SCOUT_ALERT_RADIUS and faster (SCOUT_DETECT_MULT of the
# usual time); "ranged": {...} lets it fire slow projectiles (scripts/projectile.gd): "cooldown" s between shots,
# "speed" m/s, "damage_mult" of its damage stat, "range" and "min" distances (m), "radius" of the shot.
# Art: "model" is an optional path to a .glb/.gltf/.tscn (e.g. "res://assets/enemies/grunt.glb")
# that replaces the placeholder capsule; "" keeps the capsule. Add "model_scale" (default 1.0)
# to correct a model's size; it is multiplied by "size". Models should have their origin at their feet.
const TYPES := {
	"grunt": {"weight": 75, "health": 50, "speed": 3.0, "damage": 15, "size": 1.0, "color": Color.RED, "model": "", "drop_chance": 0.5, "drop": [3, 6], "scrap_chance": 0.35, "scrap": [1, 2]},
	"scout": {"weight": 14, "health": 15, "speed": 5.0, "damage": 0, "size": 0.45, "color": Color(0.3, 0.9, 1.0), "model": "", "drop_chance": 0.1, "drop": [1, 2], "scrap_chance": 0.1, "scrap": [1, 1],
		"flying": true, "hover": 7.0, "scout": true, "zones": false},
	"super_brute": {"weight": 7, "health": 300, "speed": 1.8, "damage": 45, "size": 1.7, "color": Color(0.55, 0.08, 0.08), "model": "", "drop_chance": 1.0, "drop": [10, 18], "scrap_chance": 1.0, "scrap": [3, 5],
		"zone_mult": {"front": 0.4}, "ranged": {"cooldown": 4.0, "speed": 7.0, "damage_mult": 0.7, "range": 30.0, "min": 5.0, "radius": 0.4}},
	"brute": {"weight": 25, "health": 150, "speed": 2.0, "damage": 38, "size": 1.4, "color": Color.PURPLE, "model": "", "drop_chance": 0.8, "drop": [6, 12], "scrap_chance": 0.7, "scrap": [2, 4]},
}

# Tests that need exact damage numbers switch the zones off here.
static var zones_enabled := true
const ZONE_MULT := {"head": 2.0, "back": 1.5, "side": 1.0, "front": 0.6}
const WEAK_COLOR := Color(1.0, 0.5, 0.0)
const STRONG_COLOR := Color(0.28, 0.4, 0.62)
const HEAD_HEIGHT := 0.78  # a shot above this fraction of the body's height is a head shot
const SCOUT_ALERT_RADIUS := 60.0
const SCOUT_DETECT_MULT := 0.25
const SCOUT_PING_SECONDS := 2.0  # while it sees you it keeps re-alerting the groups near it this often

const MODIFIER_CHANCE := 0.25
const MODIFIERS := {
	"armored": {"weight": 1, "health_mult": 2.0},
	"fast": {"weight": 1, "speed_mult": 2.4},  # a fast grunt (7.2 m/s) outruns a walking player
}

# Returns a stats dictionary: the type's stats plus a "type" and "modifier" name.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var type := Rng.pick(TYPES, rng)
	var e: Dictionary = TYPES[type].duplicate()
	e["type"] = type
	e["modifier"] = ""
	if rng.randf() < MODIFIER_CHANCE:
		var m := Rng.pick(MODIFIERS, rng)
		e["modifier"] = m
		e["health"] = int(e["health"] * MODIFIERS[m].get("health_mult", 1.0))
		e["speed"] = e["speed"] * MODIFIERS[m].get("speed_mult", 1.0)
	return e

# How much tougher enemies are in `round` (0 = the first level): {"damage", "health", "speed"} multipliers on the
# base stats, each capped at Tuning.ENEMY_SCALE_CAP.
static func round_scale(round: int) -> Dictionary:
	var cap: float = Tuning.ENEMY_SCALE_CAP
	return {
		"damage": minf(1.0 + Tuning.ENEMY_ROUND_DAMAGE * round, cap),
		"health": minf(1.0 + Tuning.ENEMY_ROUND_HEALTH * round, cap),
		"speed": minf(1.0 + Tuning.ENEMY_ROUND_SPEED * (round / Tuning.ENEMY_ROUND_SPEED_EVERY), cap),
	}

# What an enemy is worth in XP: its health, speed and damage each against a plain grunt (50 health, 3 m/s, 15
# damage), added up and rounded, at least 1. A plain grunt is worth 3; armored, fast, brute and deeper-level
# enemies are worth more.
static func xp_value(stats: Dictionary) -> int:
	var score: float = float(stats["health"]) / 50.0 + float(stats["speed"]) / 3.0 + float(stats["damage"]) / 15.0
	return maxi(1, int(round(score)))
