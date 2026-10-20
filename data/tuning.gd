# Tunable numbers. Edit here; scripts read them from this file.

# Metres. Enemy group centres never spawn closer than this to the player's start.
const ENEMY_GROUP_MIN_ORIGIN := 15.0
# Group members spawn within +/- this many metres of their group centre.
const GROUP_SPREAD := 2.0
# Placement attempts per object before overlapping other objects is accepted.
const SPAWN_TRIES := 50

# Seconds the player must stand inside the extract zone. Leaving resets the timer.
const EXTRACT_HOLD_SECONDS := 8.0
# Metres from the player to a crate for a loot request to be accepted.
const LOOT_REACH := 4.0
# Where the persisted loot totals are saved.
const PROFILE_PATH := "user://profile.json"
