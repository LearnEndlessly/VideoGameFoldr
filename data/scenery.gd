# Cover shapes and shelter dimensions. Sizes are [min, max] in metres; each cover box
# is rolled from one type and turned 90 degrees half the time.
#   fat = big block, tall = pillar, thin = wall slab, long = low barrier, block = small crate-like cover
const COVER_TYPES := {
	"fat": {"weight": 3, "x": [5.0, 8.0], "y": [1.5, 3.0], "z": [5.0, 8.0], "color": Color(0.5, 0.4, 0.3)},
	"tall": {"weight": 2, "x": [1.5, 2.5], "y": [5.0, 8.0], "z": [1.5, 2.5], "color": Color(0.4, 0.35, 0.3)},
	"thin": {"weight": 3, "x": [0.5, 1.0], "y": [2.0, 3.5], "z": [4.0, 8.0], "color": Color(0.55, 0.5, 0.45)},
	"long": {"weight": 2, "x": [10.0, 16.0], "y": [1.0, 1.8], "z": [1.2, 2.0], "color": Color(0.45, 0.42, 0.4)},
	"block": {"weight": 3, "x": [2.0, 4.0], "y": [1.5, 3.0], "z": [2.0, 4.0], "color": Color(0.5, 0.4, 0.3)},
}

# Shelters (safe zones): small nooks coloured like the cover so they blend in.
const SHELTER_OUTER := 3.6       # outside width of the nook
const SHELTER_WALL := 0.4
const SHELTER_HEIGHT := 2.2
const SHELTER_DOOR_WIDTH := 1.8
const SHELTER_COLOR := Color(0.5, 0.4, 0.3)
# After each shelter is placed, up to SHELTER_SCREENS cover pieces are tried in front of its
# door (within about 50 degrees of straight ahead, SHELTER_SCREEN_DIST metres out) to hide it.
const SHELTER_SCREENS := 3
const SHELTER_SCREEN_DIST := [7.0, 10.0]
