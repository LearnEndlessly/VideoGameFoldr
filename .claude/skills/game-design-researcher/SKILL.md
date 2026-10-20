---
name: game-design-researcher
description: Researches how Arc Raiders, Path of Exile (1 and 2) and Minecraft design their core systems, and turns it into concrete ideas for this game. Use when the user asks how those games do something, wants design inspiration, is deciding a skill tree, loot, extraction risk, progression, crafting, durability, base building or world generation question in VideoGameFoldr, says research, "what would Arc Raiders do", "how does PoE handle", or when an open design question in the README needs outside evidence. Run it in the background with subagents for broad topics.
---

# game-design-researcher

This project is a setting-agnostic framework built from three inspirations: **Arc Raiders** (extraction loop, seeded RNG loot and enemies), **Path of Exile** (a skill tree on three attribute types, itemization), and **Minecraft** (exploration, building, customizing your approach to the surroundings). The research job is to understand why those games' systems work at the level of mechanism, then ask what the smallest version of that mechanism would be here and how we would measure whether it works. It is not to copy their content, names or numbers; the user wants a structure that any narrative can sit on.

## 1. Start from a question, not a game

Good questions come from the project's own gaps. Check `README.md` ("Known gaps", "open design questions"), `docs/DESIGN_METRICS.md` (what the data says is dead or dominant) and `docs/BALANCE_LOG.md`/`docs/RESEARCH.md` (what is already known). Typical ones: what should scrap and repair kits do; what is the secondary ability; how should the skill tree's three stats differ in play; should enemies drop loot; how should loot rarity scale; what makes an extraction decision tense; how large can a bounded map be before streaming matters.

Read `docs/RESEARCH.md` first. If the question is already answered there, build on it instead of repeating the work.

## 2. Gather sources

Use WebSearch and WebFetch (load them with ToolSearch if they are deferred) or the built-in browser. Prefer, in this order: developer posts, patch notes, GDC or conference talks and their transcripts, official wikis, then reputable analysis, then community discussion. Games change, so note the date and version of everything and prefer recent material; say when a source is old or when you could only find community lore. Keep what is verified (a developer said it, a patch note shows it) separate from what is folklore or your inference.

Seed topics:

| Game | Mechanisms worth understanding |
|---|---|
| Arc Raiders | extraction risk and reward, how loot value and rarity are spread across the map, enemy awareness and noise, safe spots and their cost, gear loss and what is protected, repair and crafting economy, progression between raids |
| Path of Exile | passive tree shape (starting points, small nodes versus notables versus keystones, how the three attributes steer builds), item rarity and affixes, currency as crafting, defence layering, how power curves and death penalties are paced |
| Minecraft | what pulls players to explore, resource tiers and tool durability, how building is constrained and rewarded, survival pressure (mob spawning, light, hunger), seeded world generation and biomes, emergent play from simple rules |

## 3. Extract mechanisms, then translate

For each finding, write down the mechanism in one sentence without the game's vocabulary, and then the translation into this framework:

- Which data table or tuning constant would express it (`data/loot_zones.gd`, `data/enemies.gd`, `data/tuning.gd`, a new table)?
- Which raid-simulation intent would it need (`request_*` in `scripts/raid.gd`)?
- Which measure in `docs/DESIGN_METRICS.md` or the telemetry would show whether it works?
- What is the smallest version that could be built and tested in one step?
- What could go wrong here that did not for the original (a single-player game with a small bounded map has different constraints than a live-service one)?

## 4. Write it down

Append a dated entry to `docs/RESEARCH.md` (create it with a short header if missing):

```
## <date>: <question>
Sources: <title, publisher, date, link> (mark each: dev / patch notes / talk / wiki / community)
Verified: <facts the sources support>
Folklore or inference: <what is not established>
Mechanism: <one sentence, no game vocabulary>
For us: <table or constant, intent, measure, smallest version>
Risks: <why it might not transfer>
Experiment: <the change to try, the measure that would judge it, and what result would mean we drop it>
```

Summarise sources in your own words. Do not paste passages from articles or wikis; if a short quotation is truly needed, keep it under fifteen words and attribute it. Never reproduce game text, lore, item names or numbers wholesale: describe the principle and invent our own values.

## 5. Scale with subagents when the topic is broad

For a topic across all three games, run one researcher per game in parallel in the background, matched to the work: a cheaper model (haiku) to collect and list candidate sources for a game, a mid model (sonnet) to read them and write the findings, and the strongest model only for the synthesis across games and for the "for us" translation, which needs the project's context. Give each a disjoint game, tell them not to edit project files except to return text, and tell them to separate verified from inferred. Check the findings before they go into `docs/RESEARCH.md`: a subagent's report is a claim to verify, not a source.

## 6. Hand off

End with: the three most useful ideas ranked, the single experiment you would run first, and which measure will tell us if it worked. If an idea changes a number, route it through the balance-pass skill so it is tied to data; if it needs a new mechanic, say so and keep the first version small and logged (see the header of `scripts/telemetry.gd` for how to record it).
