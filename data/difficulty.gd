# Raid difficulty options, chosen at the base's raid terminal. Each option has three levels (Easy, Normal,
# Hard); "value" is what the raid uses and "reward" is added to the reward multiplier. The multiplier is
# 1 + the sum of the chosen levels' rewards, and scales the loot kept on a successful extract and the
# attribute points it earns. None of these change the map's layout, so a map number looks the same on
# every difficulty. Edit the numbers here.
#
#   patrols    enemies in each starting patrol, as a fraction of the map's (at least 1 per patrol)
#   damage     multiplier on every hit enemies deal
#   awareness  seconds in an enemy's view before it raises the alarm
#   bases      how fast the enemy bases respawn defenders: seconds between spawns, defenders alive per base
#   ammo       ammo the player starts the raid with
const OPTIONS := {
	"patrols": {"name": "Patrol size", "desc": "Enemies in each starting patrol", "levels": [
		{"label": "Fewer", "value": 0.5, "reward": -0.1},
		{"label": "Normal", "value": 1.0, "reward": 0.0},
		{"label": "More", "value": 1.5, "reward": 0.2},
	]},
	"damage": {"name": "Enemy damage", "desc": "How hard enemies hit", "levels": [
		{"label": "x0.75", "value": 0.75, "reward": -0.1},
		{"label": "x1", "value": 1.0, "reward": 0.0},
		{"label": "x1.5", "value": 1.5, "reward": 0.2},
	]},
	"awareness": {"name": "Enemy awareness", "desc": "Seconds in view before an enemy raises the alarm", "levels": [
		{"label": "8 s", "value": 8.0, "reward": -0.05},
		{"label": "5 s", "value": 5.0, "reward": 0.0},
		{"label": "3 s", "value": 3.0, "reward": 0.15},
	]},
	"bases": {"name": "Enemy bases", "desc": "Respawn speed and defenders per base", "levels": [
		{"label": "Slow", "value": {"interval": 18.0, "max_alive": 2}, "reward": -0.1},
		{"label": "Normal", "value": {"interval": 12.0, "max_alive": 3}, "reward": 0.0},
		{"label": "Fast", "value": {"interval": 8.0, "max_alive": 4}, "reward": 0.2},
	]},
	"ammo": {"name": "Starting ammo", "desc": "Ammo you carry in", "levels": [
		{"label": "24", "value": 24, "reward": -0.05},
		{"label": "12", "value": 12, "reward": 0.0},
		{"label": "6", "value": 6, "reward": 0.15},
	]},
}
const DEFAULT_LEVEL := 1

static func level_of(chosen: Dictionary, id: String) -> int:
	return clampi(int(chosen.get(id, DEFAULT_LEVEL)), 0, OPTIONS[id]["levels"].size() - 1)

# option id -> the value the raid uses, for the levels in `chosen` (option id -> level index).
static func values(chosen: Dictionary) -> Dictionary:
	var out := {}
	for id in OPTIONS:
		out[id] = OPTIONS[id]["levels"][level_of(chosen, id)]["value"]
	return out

# 1 + the rewards of the chosen levels: 1.0 on all Normal.
static func reward_mult(chosen: Dictionary) -> float:
	var m := 1.0
	for id in OPTIONS:
		m += float(OPTIONS[id]["levels"][level_of(chosen, id)]["reward"])
	return m

# What a reward is worth at `mult`: never rounds a real reward down to nothing.
static func scale(qty: int, mult: float) -> int:
	return maxi(1, int(round(qty * mult))) if qty > 0 else 0
