# Tunable numbers. Edit here; scripts read them from this file.

# Metres. Enemy group centres never spawn closer than this to the player's start.
const ENEMY_GROUP_MIN_ORIGIN := 15.0
# Group members spawn within +/- this many metres of their group centre.
const GROUP_SPREAD := 2.0
# Placement attempts per object before overlapping other objects is accepted.
const SPAWN_TRIES := 50

# Map shape: the floor area is MAP_AREA m2, split into a width and depth by a random
# aspect ratio between MAP_ASPECT_MIN and MAP_ASPECT_MAX (below 1 = taller than wide),
# each side then clamped to [MAP_MIN_SIDE, MAP_MAX_SIDE].
const MAP_AREA := 3600.0
const MAP_ASPECT_MIN := 0.5
const MAP_ASPECT_MAX := 2.0
const MAP_MIN_SIDE := 44.0
const MAP_MAX_SIDE := 100.0
# Minimum clear walking space (m) kept between placed objects and between objects and the outer wall.
const PATH_GAP := 3.0

# Ammo the player starts every raid with. Deliberately tight: the pistol uses 1 per
# shot, so 12 is twelve shots. Spent before any ammo found in crates, and never counts
# as loot: only ammo beyond this amount can be kept on extract.
const STARTING_AMMO := 12

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
const ENEMY_STEP_HEAR_DISTANCE := 40.0
# 3D sound falloff: full volume within this many metres of a sound, then it fades
# with distance (inverse distance), so nearer enemies are louder. Smaller = steeper.
const SOUND_UNIT_SIZE := 3.0
# Where the persisted loot totals are saved.
const PROFILE_PATH := "user://profile.json"
