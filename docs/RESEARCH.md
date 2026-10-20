# Design research

Dated findings about how Arc Raiders, Path of Exile and Minecraft design their core systems, translated into this game's framework. Written by the `game-design-researcher` skill (`.claude/skills/game-design-researcher/SKILL.md`). Newest last. Read this before researching a question again.

Each entry uses this format: question, sources (with type and date), verified, folklore or inference, mechanism in one sentence, what it means for us (table or constant, intent, measure, smallest version), risks, experiment.

## Backlog of open questions (from the README and docs/DESIGN_METRICS.md)
- ~~What should scrap and repair kits do once durability exists?~~ Researched 2026-10-20 (entry below). Follow-ups: how gear persists between raids (loadout), a fallback weapon so a broken gun cannot end a save, and a prep step to spend banked scrap.
- What is the secondary weapon or ability, and what makes switching worth it?
- How should the three skill-tree stats differ in play, and how big is the first tree?
- Should enemies drop loot, and how does that interact with the zone-based loot design?
- What makes extraction tense: timer length, noise, a guaranteed way out, or what is lost on death?
- How large can a bounded procedural map be before world streaming is needed?

## 2026-10-20: what should scrap and repair kits do? How do Arc Raiders, Path of Exile and Minecraft handle crafting and durability?
Method: three background researchers (Arc Raiders: high-power model; Path of Exile: mid; Minecraft: low), one per game. I re-fetched two Arc Raiders sources myself to check the report (marked "checked"). The other findings are as the researchers reported them.

### Sources
- Gearing up FAQ | Embark Studios | 2025-10-27 | id.embark.games/arc-raiders/support/faq/140-gearing-up | dev. **Checked.**
- Update 1.26.0 patch notes (via VICE summary) | 2026-04-28 | vice.com article on 1.26.0 | patch notes via outlet. **Checked.**
- Patch 1.29.0 notes | arcraiders.com | 2026-05 | patch (seen only in search summaries). "Embark walks back durability changes" | Insider Gaming | 2026-05-19 | outlet.
- Design lead interview relayed by FRVR | 2026-01-15 | outlet relaying GamesRadar. Streamlined crafting option | GamingBolt | 2026-04-05 | outlet relaying dev.
- Arc Raiders recycling and crafting guides | community, 2025-11 (low trust; one is a gold-selling site).
- PoE 2 Crafting Overview | Maxroll | updated 2026-06 | guide. Rogers interview summary | Maxroll | 2024-02 | outlet summary of a dev stream. Harvest dev-blog coverage | MassivelyOP | about 2019 | outlet. Both PoE wikis were blocked; no GGG patch notes or talks were read.
- Minecraft Wiki pages (Durability, Anvil, Grindstone, Netherite Scrap, Ancient Debris, Smithing template, Crafting) | undated, current to 1.21.x | wiki. No Mojang article was read.

### Verified (developer or patch notes, or wiki read directly)
- Arc Raiders: weapons wear with use and can break if not repaired; repair costs materials that depend on the weapon. Wear is per shot fired, plus a lump when the player is knocked down (1.26.0 halved that lump).
- Arc Raiders 1.26.0: weapons found in the world start more worn (average durability 50 to 30; outskirts lower, locked rooms healthier); per-shot wear rose for cheap weapons and fell slightly for top tiers; upgrading a weapon also repairs 25% of max durability. Stated reasons: reduce hoarding, make wear a challenge for every playstyle, make upgrading less of a double cost. 1.29.0 partly walked back the fastest-wearing weapons.
- Arc Raiders design lead (Jan 2026, relayed): spending more should give an edge but not a decisive one; the cost-benefit of keeping top weapons was off.
- Minecraft (wiki): items lose a fixed amount of life per action type and vanish at zero; repair with the matching material restores 25% of max per unit (one wiki summary said 12%; the Anvil page says 25%, which is also my recollection); combining two worn copies adds their durability; the grindstone repairs at no cost but strips enchantments; anvil repair costs XP that escalates and caps. Netherite scrap comes only from smelting rare debris, is finite, and is used only to make top-tier ingots, which an upgrade needs along with a rare template from a separate location.
- Path of Exile (guide and outlet summaries): currency items are both money and crafting inputs; PoE 2 removed the reset-style orbs so bad items stay bad; junk can be broken down at a vendor into small, cheap crafting inputs (quality-improving scraps and whetstones in PoE 1); PoE 2 added a separate gold currency for convenience services; GGG admitted early PoE 2 loot and currency felt "not rewarding enough".

### Folklore or inference (not established by the sources)
- Why PoE has no equipment durability: not found in any source. (My background belief is that it has none; unverified.) Why Minecraft has durability and partial repair: not found from Mojang.
- Arc Raiders community: recycling at home returns more than salvaging mid-raid; repair restores about half; "recycle and rebuild beats repairing twice"; a safe pocket unlocked by paid gear; a free starter kit with nothing protected; a seasonal donation sink that players disliked and Embark paused. All from guides or outlets, not from a developer page I read.
- Orb economies drain themselves because spending the item forgoes using it elsewhere (analysis from a low-reliability outlet).

### Mechanisms (no game vocabulary)
1. Gear loses condition a little with every use, so good play with good gear still costs something, and a worn-out item disappears.
2. Restoring condition takes the same raw material that building and upgrading take, so every repair competes with progress.
3. Repair is partial (and in one game costs more the more often it is done), so no one keeps an item perfect forever and replacing becomes a real alternative.
4. Cheap, common drops can be broken into a few shared base materials, so no pickup is waste; the same material is both the money and the input.
5. Condition is part of loot quality: found gear arrives worn, and better-guarded places hold healthier gear.
6. A guaranteed free kit with nothing protected gives a broke player a way back in; a small protected slot caps how much a bad raid can cost.
7. If upkeep of the best gear costs more than the edge it gives, players hoard it and never use it (Arc Raiders retuned this twice in five months).
8. Wear that is too fast feels like a tax on fun; friction in finding what you need to craft is a separate, acknowledged complaint.

### For us
- Tables and constants: `data/weapons.gd` gains `durability` and `wear_per_shot`; `data/recipes.gd` gains `repair_kit: {scrap: N}` (scrap then has two competing uses: medkit or repair kit); `data/tuning.gd` gains `REPAIR_FRACTION` (the share of max durability one kit restores; both games land between a quarter and a half); `data/loot.gd` re-enables a small `repair_kit` drop weight.
- Intents (`scripts/raid.gd`): `request_fire` spends wear and refuses at zero; `request_repair(weapon_id)` spends a repair kit. A broken weapon is removed (your rule: broken items are lost for good).
- Prerequisite: nothing is brought into a raid today (the profile stores only totals). Permanent durability needs the profile to store gear with its condition, and a way to pick a loadout before a raid. That is the real first step.
- Measures: wear per kill; scrap spent on repair versus medkits per raid; share of raids that end with a broken or nearly broken weapon; share of raids where the equipped weapon is never fired (the hoarding signal); scrap banked at raid start (is there anything to spend it on).
- Smallest version: store the two weapons' durability in the profile; wear 1 per shot; a repair kit restores a fixed share; crafting from 6 scrap makes a repair kit; one prep action on the start screen spends banked scrap. No new currency.

### Risks
- Our game is single-player on a small map, so the PvP-driven wear variation Embark tuned for does not exist; wear will be steadier and easier to tune.
- Without a safe fallback, a broken only-weapon plus no scrap ends a save. Arc Raiders gives a free kit; we need an equivalent (for example an issue sidearm that cannot break and is weaker). This is a design decision for you.
- Upkeep must stay below the edge good gear gives (Embark's lesson), or players will hoard instead of fight. The 8-slot backpack helps: repair kits cost slots.
- Arc Raiders numbers change often; none are copied here.

### Experiment
Build the smallest version above and set wear so a pistol lasts about 8 to 10 average raids before repair. Judge it with the unused-gear share, the broken-weapon share and scrap spent per raid. Drop or retune it if more than a fifth of raids end with a broken weapon, or if banked scrap keeps rising unspent (the sink is too weak).
