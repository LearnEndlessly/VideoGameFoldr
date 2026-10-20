# Design review: systems, level design, HUD

Written from the code and the screenshots, not from play sessions. Ratings are my judgment (A strong, B good, C works but weak, D problem). Nothing here has been measured: the 40-seed playbot baseline predates the halved patrols, damage +50%, enemy bases, ammo drops, smaller rooms and difficulty options, so every balance statement below is a hypothesis to test.

## The loop

Base (pick map, set difficulty, upgrade) -> raid (loot rooms, fight, extract) -> back to base with loot and points. All the pieces exist and connect. The weak point is the back half: what you bring home has little to spend on and no way to come back out into a raid.

## Systems

| System | Grade | What works | What does not |
|---|---|---|---|
| Raid loop and extraction | B+ | Clear goal; 8 s hold in a green beam seen from anywhere; threat clock at 120 s forces the exit | One fixed extract point per map, so routes are predictable; the beam doubles as a compass, which removes navigation tension |
| Weapons (pistol, scattergun) | B | Two clearly different tools; per-weapon crosshair; laser colour shows falloff; 30-round clips with a reload animation | Only two weapons; the 30-round clip is larger than the 12-round starting ammo, so reload rarely matters early; damage upgrade is the only weapon progression |
| Ammo economy | B- | Enemy drops (grunt 50% for 3-6, brute 80% for 6-12) fix the run-dry problem; start ammo is a difficulty option | Loot ammo is only in the armory now that the depot is gone; ammo kept in the stash cannot be brought back into a raid |
| Enemy AI | B | Visible view cone clipped by walls; 5 s suspicion meter; suspicious enemies face and creep toward you; readable and fair | Melee only (reach 1.8 m), so no pressure at range; only two types (grunt, brute); patrols just wander near home; a still enemy never sweeps its gaze |
| Enemy bases | B+ | Red beam narrows to a point at each spawn, which is an excellent readable timer; defenders guard the base; difficulty tunes speed and cap | Destroying a base pays nothing, so there is no reason to do it beyond relief; 100 hp is only 4 pistol shots |
| Difficulty and reward multiplier | A- | Five independent options, multiplier shown live, scales kept loot and points, never changes the terrain | No presets; the multiplier is not shown on the map pit; effects of each option are unverified in play |
| Progression (weapons, attributes) | C | Upgrades and attributes persist; points earned only by extracting gives risk/reward | About 21 purchasable steps in total, then nothing; `repair_kit` can never drop and has no use; stash holds only ammo and medkits |
| Base of operations | B | Walkable, safe, diegetic stations; shootable map controls; funnel pit shows the map from above; free ammo in the base | Empty room with little to do; panels use the default Godot theme; no tutorial or tooltips; stash is a list with no item descriptions |
| Save and profile | A- | Versioned file, atomic writes, old saves load, tests never touch the real profile | None found |
| Tests | A | 16 headless suites cover most rules, map layout and the base; mutation checks done | Balance is not tested at all; no automated look at the HUD |

## Level design

| Aspect | Grade | Notes |
|---|---|---|
| Generation | B+ | Seeded and deterministic; fixed area with varied aspect ratio; walkability test over 40 maps; the map pit previews exactly what the raid will build |
| Loot rooms | C | Halved to 5 m (armory) and 4 m (med post): inner space is 4 x 4 and 3 x 3 m with a 2 m door, which leaves no room to fight or manoeuvre; only two rooms and about 4-5 crates per map, so loot is thin |
| Cover and sightlines | C | 25 random boxes on one flat floor, one wall colour, no landmarks, no height. Cones and line of sight work, but the map has few interesting places to hide, flank or hold |
| Shelters | B- | Two safe nooks give real tension and a place to wait out a patrol; the threat clock stops them being a permanent exploit |
| Enemy placement | B | Guard group outside the armory door makes the best loot a real risk; bases are at least 25 m from the start. Bases can land near the extract zone, which would make the finish trivial or brutal |
| Readability | B | Beams make objectives visible from anywhere; the flip side is that exploration has no surprise |

## HUD and UI

| Element | Grade | Notes |
|---|---|---|
| Crosshair | A- | Small cross vs spread circle sized to the cone: tells you the weapon and its spread at a glance |
| Aim laser | A- | One beam coloured by range; fixed the lag by updating every frame |
| Ammo slots and reload | B | Slot animation looks good; the `12 / 0` text does not say which number is loaded and which is reserve; 30 slots at 5 px are hard to read |
| Health | B- | Bar plus a text line; no hurt flash or damage direction |
| Objective info | B- | Frags, enemies left, bases left, next respawn are all shown; the threat clock (120 s) has no countdown, only a banner after it fires |
| Detection feedback | C+ | Cone colour is subtle; no on-screen cue when something is noticing you, so an alert can feel sudden |
| Combat feedback | C | No hit marker, no kill confirmation beyond sound; enemy labels and health bars are small in world space |
| Help text | C | Two permanent lines at the bottom edge that most players will stop reading and that crowd the view |
| Base panels | C+ | Functional and consistent; dense (the raid terminal has 15 option buttons plus START); default theme looks unfinished |
| Results screen | B | Clear; shows kept loot, points and the reward multiplier |

## Biggest problems, in order

1. **Nothing is measured.** Rerun the playbot across Easy, Normal and Hard and run a balance pass before changing more numbers.
2. **The stash has no use in a raid.** Let the player bring ammo and medkits in (a loadout slot at the base), and add sinks beyond the 21 upgrade steps, such as a third weapon.
3. **Loot is too thin.** After the depot was removed and rooms were halved there are 2 small rooms. Add a third room or scatter small caches among the cover.
4. **Fights lack variety.** Add a ranged or fast enemy type; give bases a reward (bonus loot or points) so destroying one is a choice, not a chore.
5. **HUD feedback.** Add a hit marker and damage direction, a threat-clock countdown, a "being noticed" indicator, clearer ammo text (`12 loaded / 18 reserve`), and shrink the permanent help text to a key hint that fades.
6. **Level identity.** Colour-code regions, add a few landmarks and some height so maps stop reading as scattered boxes.
7. **Base polish.** Show the reward multiplier at the map pit, add difficulty presets (Easy / Normal / Hard / Nightmare), a styled theme, and a short first-visit hint.

## Not checked

I did not play full raids, so enemy pressure, ammo feel and how crowded four beams make the map are untested. The threat of bases spawning close to the extract zone is from reading the placement rule (`_free_spot` with a 25 m minimum from the start only), not from a measured map. `docs/STATE.md` has not been updated for the base, bases, drops or difficulty work.
