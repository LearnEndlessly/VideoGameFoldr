# Tunable numbers. Edit here; scripts read them from this file.

# Metres. Enemy group centres never spawn closer than this to the player's start.
const ENEMY_GROUP_MIN_ORIGIN := 20.0  # a fast grunt (7.2 m/s) needs over 2 s to cross the nearest member's 17 m
# Group members spawn within +/- this many metres of their group centre.
const GROUP_SPREAD := 2.0

# How many patrol groups spawn (3-4 enemies each). Set to 5 for the old, busier maps.
const ENEMY_GROUP_COUNT := 3

# Threat clock: THREAT_DELAY_SECONDS into a raid, every group stops patrolling and heads
# for the player's position, with a HUD warning. They still need to see you to attack, and
# they cannot see into shelters, so they will wait outside one.
#   THREAT_CONTINUOUS = true:  they keep tracking the player's live position until the raid ends.
#   THREAT_CONTINUOUS = false: one wave: they go to where the player was when it started and
#                              resume patrolling there after THREAT_WAVE_SECONDS.
const THREAT_DELAY_SECONDS := 120.0
const THREAT_CONTINUOUS := true
const THREAT_WAVE_SECONDS := 60.0
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

# Seconds a reload takes (the HUD refills the magazine slots over this time; no shooting meanwhile).
const RELOAD_SECONDS := 1.5

# Backpack size in slots (each slot holds one stack of one item).
const BACKPACK_SLOTS := 8

# Player movement, in m/s. JUMP_SPEED 7.2 with gravity 20 gives a 1.3 m jump (clears low barriers).
const PLAYER_WALK_SPEED := 6.0
const PLAYER_SPRINT_SPEED := 10.0
const PLAYER_JUMP_SPEED := 7.2

# How enemies notice the player. Sight needs both range and a clear line of sight (walls
# and tall cover block it). Sprinting is loud: it is heard through walls within
# SPRINT_NOISE_RANGE. Once alert, an enemy keeps chasing until the player is 30 m away.
const ENEMY_SIGHT_RANGE := 18.0
const SPRINT_NOISE_RANGE := 14.0

# One enemy group is placed GUARD_DISTANCE metres outside the door of this loot area
# ("" = no guard), so entering that area is a risk, not just a trip. Ids are in data/loot_zones.gd.
const GUARDED_ZONE := "armory"
const GUARD_DISTANCE := 8.0

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
