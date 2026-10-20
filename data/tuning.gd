# Tunable numbers. Edit here; scripts read them from this file.

# Metres. Enemy group centres never spawn closer than this to the player's start.
const ENEMY_GROUP_MIN_ORIGIN := 20.0  # a fast grunt (7.2 m/s) needs over 2 s to cross the nearest member's 17 m
# Group members spawn within +/- this many metres of their group centre.
const GROUP_SPREAD := 2.0

# How many patrol groups spawn, and how many enemies each (the old maps had 3-4 per group).
const ENEMY_GROUP_COUNT := 3
const ENEMY_GROUP_SIZE_MIN := 1
const ENEMY_GROUP_SIZE_MAX := 2

# Enemy bases: SPAWNER_COUNT small, unmarked, destroyable spawners, each at least SPAWNER_MIN_ORIGIN m from
# the player's start. Every SPAWNER_INTERVAL seconds a base adds one enemy to its own group (home: the
# base), while fewer than SPAWNER_MAX_ALIVE of that group are alive. Destroy a base and it stops for good.
# The HUD only says how many are left; finding them is the player's job.
const SPAWNER_COUNT := 4
const SPAWNER_HEALTH := 100
const SPAWNER_INTERVAL := 12.0
const SPAWNER_MAX_ALIVE := 3
const SPAWNER_MIN_ORIGIN := 25.0

# Threat clock: THREAT_DELAY_SECONDS into a raid, every group stops patrolling and heads
# for the player's position, with a HUD warning. They still need to see you to attack, and
# they cannot see into shelters, so they will wait outside one.
#   THREAT_CONTINUOUS = true:  they keep tracking the player's live position until the raid ends.
#   THREAT_CONTINUOUS = false: one wave: they go to where the player was when it started and
#                              resume patrolling there after THREAT_WAVE_SECONDS.
const THREAT_DELAY_SECONDS := 120.0
const THREAT_CONTINUOUS := true
const THREAT_WAVE_SECONDS := 60.0
# HUD for the threat clock: a countdown from the start of the raid that turns amber at
# THREAT_COUNTDOWN_AMBER_SECONDS left and red at THREAT_COUNTDOWN_RED_SECONDS. Once the clock has fired it is
# replaced by a "converging" indicator, and (if THREAT_EXTRACT_TICK) a small arrow on a ring of
# THREAT_TICK_RADIUS px around the crosshair points toward the nearest extract zone.
const THREAT_COUNTDOWN_AMBER_SECONDS := 30.0
const THREAT_COUNTDOWN_RED_SECONDS := 10.0
const THREAT_EXTRACT_TICK := true
const THREAT_TICK_RADIUS := 110.0
# Placement attempts per object before overlapping other objects is accepted.
const SPAWN_TRIES := 200

# Map shape: the floor area is MAP_AREA m2, split into a width and depth by a random
# aspect ratio between MAP_ASPECT_MIN and MAP_ASPECT_MAX (below 1 = taller than wide),
# each side then clamped to [MAP_MIN_SIDE, MAP_MAX_SIDE].
const MAP_AREA := 3600.0
const MAP_ASPECT_MIN := 0.5
const MAP_ASPECT_MAX := 2.0
const MAP_MIN_SIDE := 44.0
const MAP_MAX_SIDE := 100.0
# Minimum clear walking space (m) kept between placed objects and between objects and the outer wall.
# Cover per map varies: each map tries a random number of cover boxes between these (cover that does not fit
# is skipped), and each cover type's chance is scaled by a random factor in COVER_MIX_RANGE, so some maps
# are sparse and open, some cramped, some mostly pillars, some mostly long walls.
const COVER_ATTEMPTS_MIN := 8
const COVER_ATTEMPTS_MAX := 80
const COVER_MIX_RANGE := [0.2, 2.0]
const PATH_GAP_RANGE := [2.7, 4.0]  # this map's minimum walkable gap between objects (m): tight maps pack more cover

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
# Sight is a view cone in front of the enemy (ENEMY_FOV_DEGREES wide, ENEMY_SIGHT_RANGE long), plus
# a small all-round ENEMY_NEAR_SENSE circle. Being seen fills a suspicion meter over
# ENEMY_DETECT_SECONDS; out of sight it drains over ENEMY_DETECT_DECAY_SECONDS. Full = the group is alerted.
# Sprint noise fills the meter twice as fast. A shot alerts the group at once.
const ENEMY_SIGHT_RANGE := 18.0
const ENEMY_FOV_DEGREES := 100.0
const ENEMY_NEAR_SENSE := 3.0
const ENEMY_DETECT_SECONDS := 5.0
const ENEMY_DETECT_DECAY_SECONDS := 3.0
# While suspicious (meter above 0) an enemy stops patrolling: it faces the spot it last saw or heard
# the player and creeps toward it at this fraction of its speed, stopping ENEMY_INVESTIGATE_STOP m short.
const ENEMY_INVESTIGATE_SPEED := 0.3
const ENEMY_INVESTIGATE_STOP := 6.0
const SPRINT_NOISE_RANGE := 14.0

# One enemy group is placed GUARD_DISTANCE metres outside the door of this loot area
# ("" = no guard), so entering that area is a risk, not just a trip. Ids are in data/loot_zones.gd.
const GUARDED_ZONE := "armory"
const GUARD_DISTANCE := 8.0

# Extraction. Every map has two zones (placed by their own RNG stream, so they never move anything else):
#   A "Safe route": far from the start, EXTRACT_HOLD_SECONDS to hold.
#   B "Fast route": close to the start, EXTRACT_B_HOLD_SECONDS to hold, and noisy: when a player starts
#     holding in it, every enemy group with a member within EXTRACT_B_NOISE_RADIUS m of the zone is alerted.
# Leaving a zone resets its timer. Distances along the ground ("path") are walking distance from the
# player's start around walls and cover, measured on a 1 m grid (4-connected, so slightly more than a
# straight line on diagonals). Separations are straight-line metres.
const EXTRACT_HOLD_SECONDS := 8.0
const EXTRACT_B_HOLD_SECONDS := 12.0
const EXTRACT_B_NOISE_RADIUS := 30.0
const EXTRACT_A_MIN_PATH := 32.0  # A is at least this far (path) from the start
const EXTRACT_B_MIN_PATH := 8.0  # B is between these two path distances from the start
const EXTRACT_B_MAX_PATH := 18.0
const EXTRACT_MIN_SEPARATION := 35.0  # A and B are at least this far apart
const EXTRACT_MIN_BASE_DISTANCE := 10.0  # both zones are at least this far from every enemy base
const EXTRACT_ZONE_SIZE := 6.0  # width and depth of a zone (m)
const EXTRACT_OPEN_RADIUS := 2  # a zone needs this many metres of walkable space around its centre (no wall, cover or crate), so a player can stand in it
# Extract beams (and their labels) only show when the player is within EXTRACT_BEAM_REVEAL_RADIUS m of the
# zone, so they stop working as a compass; set EXTRACT_BEAM_ALWAYS_VISIBLE to true for the old see-it-from-
# anywhere behaviour. The map pit in the base always shows both zones. Enemy base beams are unaffected.
const EXTRACT_BEAM_REVEAL_RADIUS := 25.0
const EXTRACT_BEAM_ALWAYS_VISIBLE := false
# Placement draws from the extract stream: up to EXTRACT_PLACE_TRIES points per zone, and if no pair
# works the whole pair is redrawn up to EXTRACT_PAIR_RETRIES times. Then it logs an error and falls back.
const EXTRACT_PLACE_TRIES := 300
const EXTRACT_PAIR_RETRIES := 25
# Going deeper: after an extract the player may descend instead of going home. The loot just extracted
# comes along, at risk again, on a fresh map (new crates, so loot is reset). Each level below the first adds:
#   DEPTH_EXTRA_SPAWNERS more enemy bases (at most DEPTH_MAX_EXTRA_SPAWNERS extra), placed from their own stream
#   bases spawning faster: the interval times DEPTH_INTERVAL_MULT per level (never under DEPTH_MIN_INTERVAL s),
#     and one more defender per base every DEPTH_MAX_ALIVE_EVERY levels
#   DEPTH_AMMO_BONUS more starting ammo, and enemy ammo drops DEPTH_DROP_BONUS (a fraction) likelier
#   DEPTH_REWARD_BONUS added to the reward multiplier (loot kept and points earned)
const DEPTH_EXTRA_SPAWNERS := 1
const DEPTH_MAX_EXTRA_SPAWNERS := 4
const DEPTH_INTERVAL_MULT := 0.85
const DEPTH_MIN_INTERVAL := 4.0
const DEPTH_MAX_ALIVE_EVERY := 2
const DEPTH_AMMO_BONUS := 6
const DEPTH_DROP_BONUS := 0.25
const DEPTH_REWARD_BONUS := 0.25
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
