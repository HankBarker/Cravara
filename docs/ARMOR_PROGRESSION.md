# Armour progression

Six armour sets, one per tier. Every set can be crafted in a single journey
without the `--armor-playtest` grant. Recipes live in
`game/Scripts/CraftingManager.gd` (workbench, category "Armor"), items in
`game/Items/Data/<set>_<helmet|chestplate|leggings>.tres`, and set names and tier
order in `game/UI/ItemDetails.gd` (`ARMOR_SETS`). The id prefix is also the
Keeper rig's visual set.

## Tier table

Damage taken uses `CombatMath.mitigate`: `max(1, round(dmg * 100 / (100 + defense)))`.

| Tier | Set (id prefix) | Rarity | Head | Body | Legs | Set | Full-set hits deal | Raptor 7 / Rex 18 hit | Gate |
|---|---|---|---|---|---|---|---|---|---|
| - | none | - | 0 | 0 | 0 | 0 | 100% | 7 / 18 | - |
| 1 | Mossweave Warden (`moss`) | common | 2 | 4 | 3 | **9** | 92% | 6 / 17 | forage |
| 2 | Trail Leather (`leather`) | common | 3 | 5 | 4 | **12** | 89% | 6 / 16 | fishing rod, reed perch |
| 3 | Fangbound (`bone`) | rare | 4 | 7 | 5 | **16** | 86% | 6 / 16 | kill one raptor |
| 4 | Skyshard (`crystal`) | epic | 5 | 9 | 6 | **20** | 83% | 6 / 15 | Shardbound Pickaxe (power 2) |
| 5 | Moonscale Tidecaller (`tide`) | epic | 7 | 11 | 8 | **26** | 79% | 6 / 14 | "Wild" and "Restless" fishing holes |
| 6 | Emerald Tyrant (`rex`) | legendary | 8 | 14 | 10 | **32** | 76% | 5 / 14 | kill the rex |

Each slot rises with each tier: head 2-8, body 4-14, legs 3-10. Pieces mix
freely, so a keeper upgrades one slot at a time.

## Recipes (all at a workbench)

| Piece | Name | Ingredients |
|---|---|---|
| moss_helmet | Mossweave Hood | 6 plant fiber, 2 berry |
| moss_chestplate | Mossweave Chestpiece | 3 log, 8 plant fiber |
| moss_leggings | Mossweave Leggings | 7 plant fiber, 2 log |
| leather_helmet | Trail Leather Cap | 2 reed perch, 3 plant fiber, 1 log |
| leather_chestplate | Trail Leather Tunic | 4 reed perch, 4 plant fiber, 2 log |
| leather_leggings | Trail Leather Leggings | 3 reed perch, 3 plant fiber, 1 log |
| bone_helmet | Fangbound Helmet | 1 raptor fang, 2 reed perch, 4 plant fiber |
| bone_chestplate | Fangbound Chestplate | 1 raptor fang, 4 reed perch, 6 plant fiber |
| bone_leggings | Fangbound Leggings | 1 raptor fang, 3 reed perch, 5 plant fiber |
| crystal_helmet | Skyshard Helmet | 2 prism crystal, 4 crystal shard, 1 reed perch |
| crystal_chestplate | Skyshard Chestplate | 4 prism crystal, 6 crystal shard, 2 reed perch |
| crystal_leggings | Skyshard Leggings | 3 prism crystal, 4 crystal shard, 1 reed perch |
| tide_helmet | Tidecaller Helm | 2 moonscale, 2 shardfin, 1 prism crystal |
| tide_chestplate | Tidecaller Cuirass | 5 moonscale, 2 shardfin, 2 prism crystal |
| tide_leggings | Tidecaller Leggings | 3 moonscale, 2 shardfin, 1 prism crystal |
| rex_helmet | Tyrant Skull Helm | 1 crystal scale (`trex_scale`), 2 prism crystal, 2 shardfin |
| rex_chestplate | Tyrant Chestplate | 1 crystal scale, 4 prism crystal, 3 shardfin |
| rex_leggings | Tyrant Greaves | 1 crystal scale, 3 prism crystal, 2 shardfin |

Every recipe has at most three ingredients, so the crafting row never clips.

## Supply in one journey

These counts come from a fresh world (seed 726151) and the wildlife spawn table.

| Material | Supply | Armour uses (all 18 pieces) | Other uses (one of each) |
|---|---|---|---|
| raptor_fang | **6** (2 raptors x 3), finite | 3 | Hunter's Fang 3, bone arrows 1 per 8, bone dagger 2 |
| trex_scale | **5** (1 rex), finite | 3 | Hide Bed 2; Hide Tent 3 (optional: 3 landmark tents can be packed up) |
| prism_crystal | 66 rich veins, finite, needs power 2 | 22 | Skyshard Sword 3 |
| crystal_shard | 139 ore, finite | 14 | about 36 (tools, rod, saddles, relics) |
| plant_fiber | 341 wild + 12 starter, **finite** | 46 | about 95, plus roofing and torches |
| log | 909, finite | 9 | plentiful |
| berry | renewable (garden: 3 per 90 s per plot) | 2 | food, seeds |
| reed_perch | renewable (6 holes, 1 catch per hole per 90 s) | 22 | Roasted Perch |
| shardfin | renewable (5 holes, "Restless") | 13 | food |
| moonscale | renewable (7 holes, "Wild") | 10 | food |

## Reasoning

- **The old recipes could not be completed.** They needed 12 crystal scales for
  leather, 14 fangs and 9 scales for bone, and 12 prism and 9 scales for crystal.
  A world supplies 3 scales and 4 fangs, so only one leather helmet was ever
  craftable.
- **Bulk materials are renewable or plentiful.** Fishing is the renewable
  backbone. Reed perch skins become "river leather": the hide for Trail Leather,
  the straps for Fangbound and the Skyshard harness. The two rare fish are the
  Tidecaller's moonstone scales and jade fins. The fish already existed as
  renewable scale sources, so no new items were needed.
- **Scarce drops are used once per piece, and only from tier 3 up.** One raptor
  fang per Fangbound piece. One crystal scale per Tyrant piece. A small amount
  of prism for tiers 4-6 (22 of 66 in the world).
- **Each tier has its own gate.** In order: forage; fishing rod; a raptor kill;
  the power 2 pickaxe; mastering the hard fishing holes; the rex. Tide needs
  prism, so it cannot skip the tier 4 pickaxe gate.

## Loot changes (`game/Forest/creatures/ForestCreature.gd`, `_die`)

- **Raptor fangs: 2 to 3 per raptor** (6 per journey). Raptors can be tamed, so
  a keeper who tames one raptor and hunts the other still has the 3 fangs for
  Fangbound. Hunting both leaves 3 more for the Hunter's Fang or 24 arrows.
- **Rex crystal scales: 3 to 5.** The Tyrant set (3) and the Hide Bed respawn
  point (2) both fit. Before, the bed alone used 2 of the 3 scales.

## Known limits (not changed here)

- **Plant fiber is not renewable.** Ferns, flowers and cattails never regrow, and
  gardening only yields berries and mushrooms. There is enough for every recipe,
  but a keeper who roofs a large camp should ration it. A fiber crop or regrowing
  cattails would fix this.
- **Taming the rex forfeits its scales.** Without them there is no Hide Bed and
  no Tyrant set, as before this change. A tamed rex that sheds a scale now and
  then, as a worker cargo like dodo eggs, would make `trex_scale` renewable.
