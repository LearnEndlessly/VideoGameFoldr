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
# Master volume for all sound effects, in dB (0 = full, -6 = about half, -80 = silent).
const SFX_VOLUME_DB := -6.0
# Footsteps: metres travelled per step (enemies scale this by their size), and how
# close an enemy must be to the player for its footsteps to play.
const PLAYER_STRIDE := 2.5
const ENEMY_STRIDE := 1.8
const ENEMY_STEP_HEAR_DISTANCE := 25.0
# Where the persisted loot totals are saved.
const PROFILE_PATH := "user://profile.json"
