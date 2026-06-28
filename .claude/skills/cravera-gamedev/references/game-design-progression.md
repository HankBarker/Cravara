# Cravera — Survival/Crafting Game Design & Progression Reference

A practical design reference for **Cravera**: a 2D top-down pixel-art dinosaur survival/crafting
game in Godot 4.6. North stars: **Core Keeper** (excavate-and-escalate loop), **Terraria**
(boss-gated tiers), **Stardew/Forager** (cozy compulsion, "just one more day"), **ARK**
(taming/breeding/base-building/tech progression) reimagined in 2D.

All numbers below are **starting points to playtest**, not gospel. Cravera's current values are
called out so you can see the delta. Tune against the telemetry in the last section.

---

## 1. The Core Gameplay Loop

The universal survival-craft loop is: **gather → craft → build → explore → fight → progress →
(repeat one tier up)**. Every successful entry in the genre is the same sentence: *acquire
materials, then make a thing that lets you harvest better materials.* (See the Core Keeper/Terraria
comparison — [TheGamer](https://www.thegamer.com/core-keeper-terraria-similarities/).)

How the north stars structure it:

- **Core Keeper** — "excavation and escalation." You start with almost nothing next to the Core,
  mine outward for stone/ore/crystal, build workbenches, craft better tools that let you mine
  *harder* walls and reach the next biome. Bosses are gates that unlock new tech and biomes.
  ([Wikipedia](https://en.wikipedia.org/wiki/Core_Keeper))
- **Terraria** — bosses *physically change the world*: defeating one spawns new ore, lets NPCs move
  in, opens the next tier. Progression is legible because the world visibly mutates.
  ([Terraria Wiki](https://terraria.wiki.gg/wiki/Bosses))
- **Stardew/Forager** — the loop is *cozy compulsion*. Short day cycles + many overlapping
  micro-goals (a crop ready tomorrow, a skill one XP from leveling, a structure half-built) create
  the "just one more day" hook. Stardew's foraging shows the failure mode too: a skill that levels
  *too* slowly with nothing to do alongside it becomes a chore.
  ([Stardew forums](https://forums.stardewvalley.net/threads/level-up-foraging-fast.11079/))

**Session pacing target for Cravera:** with `TimeCycle.cycle_seconds = 180` (3-min day), one
"session beat" is ~2-4 day/night cycles (6-12 min): gather by day, retreat/defend at night, craft
the upgrade at dawn. Always leave the player mid-progress on *something* when they'd naturally stop
— a half-stocked chest, a recipe one ingredient away, an armor set 1 piece short. That unfinished
thread is the "just one more thing" hook.

**The hook checklist** — at any moment the player should have at least **3 active pulls**:
1. A short-term goal (finish this node / kill this dino).
2. A craftable upgrade they can *see* but not yet afford.
3. A "frontier" — somewhere darker/harder they're not ready for yet.

---

## 2. Progression & Tech-Tree Pacing

**Principles**

- **Gate by station, biome, and boss — not by raw grind.** A new recipe should require a new
  *station* (Workbench → Forge → ...) or a *boss drop*, so unlocks feel earned, not farmed.
  Terraria-style world-mutation gates read as progress; Stardew-style slow XP grinds read as chores.
- **The gather→craft ladder:** each tier's tool must be the key to the next tier's material.
  Pickaxe(stone) mines copper → copper tools mine iron → iron tools mine the boss-zone ore. If any
  rung is skippable or any rung is a wall, the ladder breaks.
- **Unlock cadence:** front-load unlocks. The first 20 minutes should drip a new recipe/station
  every few minutes; later tiers can space out to 20-40 min as each carries more content. Avoid
  the Stardew foraging trap — never make a tier a pure time-sink with no parallel goals.
- **Avoid grind walls:** cap any single "collect N" requirement at what one focused day-cycle
  yields at the *current* tool tier. If it takes more than ~2 cycles of pure farming, either lower
  the cost or add a tool/station that multiplies yield.

**Concrete Cravera tier ladder (dino theme).** Cravera today has Tier 0-1 only (wood/stone/plank,
basic axe/pickaxe, leather from T-Rex). Proposed ladder:

| Tier | Theme / Biome | Key Station | Tools (tool_type, damage) | Armor (defense) | Gate to next |
|------|---------------|-------------|---------------------------|-----------------|--------------|
| 0 Wood | Starting plains | (hands/Workbench) | Basic Axe (axe, 3), Basic Pickaxe (pickaxe, 2) | Leather set (2/5/3) | Craft Workbench |
| 1 Stone | Plains/rocky | **Stone Anvil** | Stone Axe (5), Stone Pickaxe (4), Stone Spear (melee 6) | Hide+Bone set (3/7/4) | Mine copper (needs stone pick) |
| 2 Bone/Copper | Bonelands | **Bone Forge** | Copper Tools (7-8), Bow (ranged 5) | Bone Carapace (5/11/6) | Kill **Raptor Pack Alpha** (mini-boss) |
| 3 Iron | Caverns | **Smelter** | Iron Tools (10-12), Iron Sword (14) | Plated set (8/16/9) | Kill **Bonewalker** (boss) → drops Cryst-key |
| 4 Crystal/Amber | Tar pits / glow caves | **Amber Catalyst** | Amber tools (15+), Tranq Dart Gun (taming) | Amber-plate (12/22/13) | Kill **Apex Tyrannosaur** (apex boss) |
| 5 Apex | Endgame | **Apex Bench** | Apex gear, saddle/war-beast crafting | Apex set (16+) | — (taming/breeding endgame) |

Each station is itself a recipe (like Cravera's `workbench` = log×5). Each tier's pickaxe is
required to harvest the next tier's ore node (mirror `DestructibleObject.harvest_tool_required`).

---

## 3. Survival Stat Design & Tuning

**Design philosophy:** survival stats are *gentle pressure*, not a chore. Good rules
([Game Design Skills — Survival](https://gamedesignskills.com/game-design/survival/)):
stats deplete slowly enough that players aren't *constantly* managing them; every stat has a clear
replenish path; low stats hurt but don't hard-lock; different activities drain different stats.

**Soft vs hard fail:** hunger should be a *soft* fail (drains HP slowly at zero — recoverable),
HP-at-zero is the only *hard* fail. Cravera already does this correctly.

**Cravera's current stats (good baseline):**

| Stat | Max | Drain | Replenish | Fail |
|------|-----|-------|-----------|------|
| Health | 100 | only from damage/starvation | (food/regen — see below) | hard: death |
| Hunger | 100 | `100/600` ≈ 0.167/s (empties in 10 min ≈ 3.3 days) | T-Rex Meat = +25 | soft: 0.5 HP/s starvation |
| Stamina | 100 | sprint 18/s, attack 12/swing | regen 20/s (0.5s lockout) | none (drops to walk) |

These are well-tuned. Two suggested additions:

- **Passive HP regen** when hunger > 50%: **+1 HP/s**, paused for 3s after taking damage. Makes
  food meaningful (the buffer that *enables* regen) without making the player immortal.
- **Optional later stats — add only with content to justify them:**
  - **Temperature** (cold at night / in caves): ticks down at night unless near a Torch/fire or
    wearing armor. Directly motivates base lighting (ties to existing Torch). Drain ~ −2/s exposed
    at night, +5/s near a light source. Hard cap so it's pressure, not instakill.
  - **Sanity / Fear** (ARK/Don't-Starve flavor): rises in the dark, drops near campfire/tamed
    dinos. A great *night-tension* multiplier without adding a third resource to babysit.
  - **Skip thirst** unless you build a water biome — three meters is the ceiling before it's a
    chore.

**Day-length tuning:** 180s is good for a fast arcade feel. If night becomes the core threat (it
should), consider **240s with night ~30% of the cycle (~72s)** so the player has a real "defend the
base" beat rather than a blink. Make day-length an exported var and playtest 120/180/240.

---

## 4. Combat Design

**Damage formula.** Pure subtraction (`damage − defense`) breaks at the extremes: high defense →
0 damage, and it forces a numbers arms race
([RPG Fandom — Damage Formula](https://rpg.fandom.com/wiki/Damage_Formula)). Cravera currently uses
`actual = max(1, damage − defense)`, which is fine *at low numbers* but will wall out as armor
climbs (Tier-4 armor 22 def vs a 14 sword = chip damage). Recommended **hybrid**:

```
mitigated = damage * (100.0 / (100.0 + defense))   # percentage, scales cleanly
actual    = max(1, round(mitigated))                # always at least 1
# then: crit, knockback, i-frames
```

At defense 22 vs damage 14 this yields ~11 (not 1) — armor *matters* but never trivializes hits.
Keep the `max(1, …)` floor so nothing is fully immune. (Percentage reduction also makes healing
and "tank" builds meaningful — [rpgcodex discussion](https://rpgcodex.net/forums/threads/percentage-based-damage-reduction-is-awful.140780/).)

**Weapon archetypes** (map onto `Item.tool_type` / `damage`):
- **Melee** — axe/sword/spear. Spear = longer reach (bigger AttackArea), slower. Current swing:
  0.3s anim, 12 stamina.
- **Tool-as-weapon** — axe/pickaxe already deal damage (3/2). Keep them *weak* as weapons so
  dedicated weapons stay relevant.
- **Ranged** — Bow/Dart Gun. Lower DPS, but no melee i-frame trades; key for kiting apex dinos and
  for **taming** (tranq darts, §7). Add an `ammo`/`projectile_scene` field to `Item`.

**Combat feel knobs:**
- **i-frames:** player already has `invulnerability_duration = 0.6`. Good. Give creatures a short
  hurt-flash + 0.1s hit-pause on landing a blow.
- **Knockback:** Cravera has `knockback_friction = 800`. Apply knockback to creatures too (scaled
  by weapon) — it's the cheapest "this hit landed" feedback.
- **Crit:** add `crit_chance` (e.g. 10%) and `crit_mult` (1.5×) to weapons. Floating yellow number
  via the existing `FloaterLabel`.
- **Attack speed / stamina:** stamina cost (12) already prevents spam — good. Faster weapons should
  cost proportionally less per swing so DPS≈parity but feel differs.
- **Aggro:** T-Rex uses `AGGRO_RANGE = 100` (150 at night). Keep ranged aggro telegraphs (a "!"
  via FloaterLabel) so ambushes feel fair.

**TTK balancing (the most important combat number).** Target **time-to-kill**, then derive HP/DPS.

- *Player kills creature:* trash mobs **1.5-3s**, mini-boss **15-30s**, boss **60-120s**.
- *Creature kills player:* player should survive **8-15s** of focused aggression at the matching
  armor tier (room to react/retreat).

Reality check on current values: player HP 100, T-Rex damage **20**, attack every **1.8s** →
≈11 DPS → kills an *unarmored* player in ~9s. Good. But T-Rex HP is **8**; a stone sword (~6) +
crit ends it in **2 hits (~2-3s)** — fine for a *common* mob, but means the T-Rex should **not** be
the apex. Promote it to a tier-2 threat (HP ~30) and introduce smaller raptors (HP 8-12) as the
early trash mob, with the **Apex Tyrannosaur** as the §8 boss (HP 400+).

---

## 5. Loot & Economy

**Drop tables — weighted, not percentage-per-item.** Use weights (1-10000) so adding an item
doesn't require re-balancing every other entry
([Game Developer — Loot drop best practices](https://www.gamedeveloper.com/design/loot-drop-best-practices)).
Cravera's T-Rex table already mixes **guaranteed + chance**, which is the right pattern:

```gdscript
# current T-Rex (good shape — guaranteed scale + 60% meat)
[ {"item": TRexScale, "quantity": randi_range(1,3), "chance": 100},
  {"item": TRexMeat,  "quantity": randi_range(1,2), "chance": 60} ]
```

Generalize to a weighted bucket for *rare* drops on top of guaranteed mats:

```gdscript
guaranteed: [ {item, qty} ]                     # always
rolls: 1                                          # how many bucket picks
weighted: [ {item, weight}, {item: null, weight} ] # null = "nothing", tunes rarity
```

**Rarity tiers** already exist on `Item.rarity` (common/rare/epic/legendary). Use them to:
color floating loot text, set weighted-table weights (common w=1000, rare w=100, epic w=10,
legendary w=1), and gate which stations can craft what.

**Resource sinks (critical — prevents log-hoarding stagnation):**
- **Stations & upgrades** are the primary sink (Anvil, Forge, Smelter each cost a chunk of mats).
- **Tool durability (optional)** — a soft sink that keeps the gather loop alive; add a `durability`
  field, re-craft on break. Use sparingly; durability can feel like a chore.
- **Taming/breeding** (§7) is a *huge* meat/material sink — feeding tames consumes the food economy.
- **Repair / fuel** — Forge consumes charcoal (burn logs), giving wood a permanent late-game use.

**Currency/trade — add later, not now.** A barter NPC (a wandering trader who appears some
mornings) is the cleanest fit: trade surplus scales/meat for items you can't craft yet (seeds, a
rare tool blueprint). Avoid a hard currency until the item economy is rich enough to need one —
premature currency flattens the craft loop. ([economy/sinks guidance, same source.](https://www.gamedeveloper.com/design/loot-drop-best-practices))

**Chest storage progression.** Cravera's Chest = 18 slots. Make storage a *tier*: Chest (18) →
Reinforced Chest (36) → Vault (54). Storage scarcity early is good pressure; relief is a reward.

---

## 6. Base-Building & Placement Design

Cravera's `PlacementController` already does the hard part well: **16px grid snap**, ghost preview
(green valid / red blocked), 14×14 collision test vs Walls(layer 5)/Player(layer 1), inventory
decrement on place, `set_meta("item_id")` for save persistence. Keep grid-snap — for a top-down
pixel game, grid placement reads cleaner than free placement and makes walls/defenses tile
seamlessly.

**Design guidance:**
- **Building purpose = the four pillars:** *crafting* (Workbench/Anvil/Forge), *storage* (Chests),
  *light/safety* (Torch — and walls/doors), *production* (later: cooking fire, tame pens, farm
  plots). Every placeable should answer "what loop does this serve?"
- **Night threat drives building.** This is the engine (§8). Because T-Rex gets +1.4 speed / +1.5
  aggro at night, the player *needs* a defensible spot: walls to break line-of-sight, torches for
  the temperature/sanity/vision benefit, a chest to stash loot before risking the dark. Make walls
  cheap and placeable in runs so building a perimeter is a satisfying pre-dusk ritual.
- **Validity rules to add:** prevent placement on water/void tiles; require stations to have a
  small clear footprint; optionally require Torches near crafting stations for a "lit workshop"
  bonus (faster craft) to reward base-making.
- **Snapping niceties:** auto-connect wall sprites (bitmask tiling) so a row of walls looks like a
  fence, not 6 disconnected posts — huge perceived-quality win for low cost.

---

## 7. Taming/Breeding Progression (ARK in 2D)

Taming is a **content/loop multiplier**: every tamed dino is a new tool, mount, or weapon, and a
new *reason* to gather (food to tame/feed). Keep this design-level here; coordinate mechanics with
the AI reference file.

**How taming gates progression** (the ARK model —
[ARK Wiki: Taming](https://ark.fandom.com/wiki/Taming)):
- **Mounts** unlock map traversal/speed (cross the tar pits faster) — a *movement* gate.
- **Gathering helpers** multiply yield (a tamed "Bonehead" that auto-harvests nearby nodes) — an
  *economy* gate.
- **War beasts** let you punch above your gear tier into the next biome — a *combat* gate.
- ARK uses creatures themselves as gates (eggs only stolen from nests, etc.) — Cravera can gate a
  tame behind a boss drop or a biome-only creature.

**Taming as a loop:** weaken (tranq darts, §4) → keep unconscious → feed preferred food (consumes
your meat/berry economy) → **Taming Effectiveness** determines bonus stats (ARK: 100% TE → +50% of
wild levels as bonus). This turns combat + gathering + food into one converging system.
Wire it to the existing `creature_tamed` signal.

**Breeding for stats** ([ARK Wiki: Breeding](https://ark.fandom.com/wiki/Breeding)): offspring
inherit each stat from the stronger parent with ~55% chance, plus rare **mutations** that push a
stat past both parents. This is the endgame treadmill — a near-infinite optimization loop (breed
faster/stronger dinos) that costs enormous food/time, soaking the late-game economy. Babies need
*care/time* to raise — a deliberate, weekend-scale sink in ARK; scale it *way* down for a 2D game
(minutes, not days) or it becomes a chore.

**Cravera-sized taming ladder:** Tier 2 tame a small **Raptor** (mount, +speed) → Tier 3 tame a
**Pack-beast** (gathering/carry) → Tier 4 tranq-tame a mid **Carnivore** (war beast) → Tier 5
breed for an apex mount. Taming should *never* be mandatory for the main path, but should make every
tier dramatically easier — the optional-but-irresistible carrot.

---

## 8. Day/Night & Threat Escalation

Night is Cravera's **core tension engine** — the whole game already leans on it (T-Rex +1.4 speed /
+1.5 aggro at night via `TimeCycle.is_night()`). Build the difficulty curve around it.

- **Night as pressure beat:** day = safe-ish gather/build; night = retreat, defend, or risk the
  dark for better loot. The dusk transition (`TimeCycle` dusk 0.70-0.90) is the "get home" warning —
  make it visually loud (sky shift, distant roar SFX).
- **Escalating waves / events.** Tie threat to *progression*, not just the clock: after the player
  kills the first mini-boss, nights start spawning small raptor packs (use the existing
  `NightSpawner`). Occasional **special nights** ("Blood Moon" — denser spawns, better drops) give
  Terraria-style spikes players *prepare* for. ([Terraria Wiki: Bosses](https://terraria.wiki.gg/wiki/Bosses))
- **Biome difficulty gating.** Each biome ramps night danger: plains nights are survivable with
  torches; Bonelands nights need walls; cave/tar-pit "nights" are permanent darkness (temperature/
  sanity pressure §3). The frontier is always "the next-darker place."
- **Bosses as milestones** (the genre's spine — Core Keeper & Terraria both gate tech behind
  bosses; [Wikipedia: Core Keeper](https://en.wikipedia.org/wiki/Core_Keeper)). Cravera roadmap:
  1. **Raptor Pack Alpha** (Tier 2 mini-boss) — summoned/found at night; drops the Bone Forge
     blueprint.
  2. **Bonewalker** (Tier 3 boss) — drops a key/material gating the crystal biome.
  3. **Apex Tyrannosaur** (Tier 4-5 apex) — the current T-Rex, scaled up (HP 400+, multi-phase like
     Terraria's Eye of Cthulhu enrage at <50% HP). Drops the best craftable + taming unlock.

  Fire `creature_defeated` on boss death → unlock the next station/biome (Terraria-style legible
  progress).

---

## 9. "Game Juice" / Feedback Checklist & Balancing Approach

**Juice checklist** (the cheap effects that make hits *feel* real —
[Juice it or Lose it](https://gamejuice.co.uk/resources/juice-it-or-lose-it),
Nijman's "Art of Screenshake"). Cravera already has damage-shake (5.0 intensity, 0.2s) and
FloaterLabel — extend across the board:

- [ ] **Hit-pause** (freeze 0.05-0.1s on a landed hit) — single biggest "weight" upgrade.
- [ ] **Screen shake** scaled to impact (chop < boss-hit < boss-death). You have object shake; add
      camera shake on player hits.
- [ ] **Hurt flash** (white/red modulate) on every damaged entity, ~0.1s.
- [ ] **Knockback** on creatures (you have it for player — mirror it).
- [ ] **Particles:** dust on footsteps/landings, wood chips/stone shards on harvest, blood/scale
      burst on dino death, dust ring on placement. ("Particles are a juicy game's best friend.")
- [ ] **Floating numbers** via FloaterLabel: white normal, yellow crit, green heal/food, red player
      damage — color by `Item.rarity` for loot.
- [ ] **Audio:** layered SFX (you have chop_wood/mine_rock); add pitch-variance so repeats don't
      fatigue; a satisfying low "thunk" on boss hits.
- [ ] **Anticipation/follow-through** on the 0.3s attack swing (squash/stretch, brief wind-up).
- [ ] **Reward stingers:** craft success flash + sound (you emit `item_crafted` — hook a pop), tier
      unlock fanfare, boss-death slow-mo + loot fountain.
- ⚠️ **Don't over-juice** — too much shake/flash harms readability in a top-down game where the
      player tracks many threats ([Wayline — the juice problem](https://www.wayline.io/blog/the-juice-problem-how-exaggerated-feedback-is-harming-game-design)).
      Keep screen shake subtle for routine actions; reserve big effects for milestones.

**Balancing approach:**

- **Spreadsheet-first.** Keep a tuning sheet: per-tier tool damage, node HP, mob HP/DPS, derived
  **TTK** (HP ÷ effective DPS), recipe costs vs per-cycle yield. Change numbers there, then port to
  resources. This catches grind walls (cost ≫ yield) and TTK outliers before playtesting.
- **Tunable exported vars.** Everything in §3/§4/§8 should be `@export` (or in the Item resource) so
  designers tune in-editor without code edits — day length, drain rates, aggro ranges, drop chances,
  damage. Cravera mostly does this already; extend to crit/regen/spawn-rate.
- **Telemetry to log** (cheap, high-value): actual TTK per encounter, deaths-by-cause (starvation
  vs combat vs night), time-to-first-station per tier, resource balances at each day boundary,
  recipe craft counts. Use the SignalBus you already have (`player_died`, `creature_defeated`,
  `item_crafted`) — pipe them to a CSV in debug builds. If players starve more than they're killed,
  hunger is too harsh; if a tier takes >2× the target cycles, lower its costs.

---

## How this maps to Cravera

Cravera today is a solid **Tier 0-1 vertical slice**: the Item resource, 9-recipe CraftingManager
(Tools/Building/Materials/Armor), inventory+hotbar, grid placement (Workbench/Chest/Torch),
TimeCycle with night T-Rex boosts, Hurtbox/AttackArea combat with stamina + i-frames, and a
guaranteed+chance loot table on the T-Rex. The bones are right. Prioritized roadmap:

**P0 — Make the existing loop sing (1-2 weeks of tuning, almost no new systems):**
1. **Swap the damage formula** to the hybrid `damage*(100/(100+defense))` in `player.gd`/creature
   `take_damage` so armor scales into later tiers instead of walling at `max(1, dmg-def)`.
2. **Re-cast the T-Rex's role.** Bump its HP (8 → ~30) and demote it from "apex" — add a small
   **Raptor** trash mob (HP 8-12) via `generate_creature`/`trex.gd` clone so early combat has a TTK
   of 1.5-3s and the T-Rex is a real threat, not a 2-hit kill.
3. **Add passive HP regen** (gated on hunger > 50%) in `player.gd` so food/hunger feels meaningful.
4. **Juice pass:** hit-pause + hurt-flash + creature knockback + harvest/death particles, reusing
   the existing shake and FloaterLabel. Highest feel-per-hour return.

**P1 — Extend the ladder one full tier (proves the progression engine):**
5. **Add Tier 1-2 content:** Stone Anvil + Bone Forge stations (recipes like the existing
   `workbench`), stone/bone tools & armor, and gate copper/bone nodes behind the stone pickaxe via
   `DestructibleObject.harvest_tool_required`.
6. **First mini-boss — Raptor Pack Alpha** at night (use `NightSpawner`); on `creature_defeated`,
   unlock the Bone Forge. This is the template for all boss-gating.
7. **Storage tier** (Reinforced Chest 36 slots) as a craftable Chest upgrade — cheap, satisfying.

**P2 — Turn night into the tension engine (leverages what you already boost):**
8. **NightSpawner waves** that escalate after the mini-boss; add a "Blood Moon" special night.
9. **Walls/doors** as placeables in `PlacementController` (with bitmask auto-tiling) so the
   pre-dusk "build the perimeter" ritual exists. Optionally add **temperature** (torch-driven) to
   give base lighting a survival purpose.

**P3 — Taming/breeding as the content multiplier (the ARK pillar, biggest scope):**
10. **Tranq Dart Gun** (ranged weapon) → tame a Raptor mount via the existing `creature_tamed`
    signal. Then a gathering pack-beast, then breeding-for-stats as the endgame economy sink.
11. **Apex Tyrannosaur boss** (scaled-up current T-Rex, multi-phase) as the Tier-4 milestone that
    unlocks taming/breeding and the top crafting tier.

**Opinionated bottom line:** don't build *wide* (more biomes/creatures) before the *vertical*
loop — gather→craft→build→fight→**boss-gate**→next tier — is proven and juicy through one complete
tier transition. Cravera has every system needed for P0+P1 already; the work is tuning, one new
station+tier, and one boss gate. Nail that 30-minute "first boss → new forge → new biome" arc and
the rest of the ladder is copy-paste-tune.

---

### Sources

- Core Keeper / Terraria loop & boss-gating — [TheGamer](https://www.thegamer.com/core-keeper-terraria-similarities/), [Core Keeper — Wikipedia](https://en.wikipedia.org/wiki/Core_Keeper), [Terraria Wiki: Bosses](https://terraria.wiki.gg/wiki/Bosses)
- Survival stat design / gentle pressure — [Game Design Skills: Survival](https://gamedesignskills.com/game-design/survival/)
- Progression pacing / grind-wall failure mode — [Stardew Valley forums](https://forums.stardewvalley.net/threads/level-up-foraging-fast.11079/)
- Damage formulas (flat vs %) — [RPG Fandom: Damage Formula](https://rpg.fandom.com/wiki/Damage_Formula), [rpgcodex thread](https://rpgcodex.net/forums/threads/percentage-based-damage-reduction-is-awful.140780/)
- Loot tables / weighted drops / sinks — [Game Developer: Loot drop best practices](https://www.gamedeveloper.com/design/loot-drop-best-practices), [Game Developer: Loot tables in ARPG](https://www.gamedeveloper.com/design/defining-loot-tables-in-arpg-game-design)
- Taming & breeding — [ARK Wiki: Taming](https://ark.fandom.com/wiki/Taming), [ARK Wiki: Breeding](https://ark.fandom.com/wiki/Breeding)
- Game juice — [Juice it or Lose it](https://gamejuice.co.uk/resources/juice-it-or-lose-it), [Wayline: the juice problem](https://www.wayline.io/blog/the-juice-problem-how-exaggerated-feedback-is-harming-game-design)
