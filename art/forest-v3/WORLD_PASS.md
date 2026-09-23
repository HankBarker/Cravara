# Forest world pass 3

Owned runtime changes: `ForestWorld.gd`, `ForestProp.gd`. New items: `wood_door`, `thatch_roof`.

## Behavior

- Boulders take8 strikes; mineable stone/crystal walls take3. Damage persists in journey saves.
- Harvest hits activate a brief flash, visual-only shake, temporary durability bar and stone cracks. Physics bodies do not shake.
- Placed torches, empty chests, benches, campfires, floors, walls, doors and roofs can be reclaimed with hands or tools. A single placeable item returns. Nonempty chests refuse dismantling before changing durability or contents.
- Existing mushrooms, flower clusters and formerly decorative cattails produce plant fiber. Berry bushes retain berry drops.
- Grounded collision footprints cover the visible tent body, boulder base, tree trunk, workbench, hearth and other structures. Large footprints also inform navigation beyond the anchor tile. New furniture placement refuses overlap with existing structures.
- Doors toggle on E, block when closed and refuse to close on an actor.
- Roofs occupy a separate layer above floors/furniture. Nearby roofs fade to18% opacity while a player stands beneath any roof. Reclaiming a roof preserves the floor beneath it.
- Save extensions `roofs`, `doors`, `damage` are optional on load, preserving earlier saves.

## Integration APIs

- `world.last_hit_material`: `wood`, `stone` or `plant`; consume after successful `mine_at` for material-aware sound and particles.
- `world.get_hazard_damage_at(global_position)`:3 near a campfire's hot ring,0 outside. Caller controls damage cadence.
- `world.is_sheltered_at(global_position)` reports a roof overhead.
- `prop.get_collision_rect()` and `prop.get_shadow_footprint()` return local grounded Rect2 geometry; `get_shadow_height()` returns an approximate visual height. Static ellipse shadows removed.
- `prop.get_target_rect()` describes visual interaction bounds independently of ground collision.

## New original artwork

Built-in image generation created a transparent three-object sheet: closed rope-hinged skywood door, matching open doorway, layered palm-leaf roof. Brief specified native pixel RPG style, prehistoric wood/rope/leaf construction, aqua quartz accents, no labels or background. Source is `build-source.png`.

Aseprite exported native16x28 doors,16x24 roof and32x32 inventory icons through `tools/forest_art_v2.lua --script-param mode=build`, using the existing39-color master palette. Runtime assets live under `game/Forest/art/v3/`. New assets are strongly referenced by ForestProp constants; an initial rendered test caught unretained draw-time texture loads, which were corrected before delivery.

## Verification

- Existing `ForestWorldTest.tscn`: passed.
- New `ForestWorldPass3.tscn`:85 checks,0 failures. Covers durability, feedback, exact-item reclaim, chest conservation, plants, actual collision queries, occupied door closing, roofs over floors, fading, reclaim layering, new state restoration, legacy saves and collision-safe placement.
- `building-outside.png`, `building-inside.png`, `collision-footprints.png`: rendered production props, visually inspected. `building-review.log` is clean.
- Regression outputs: `world-base-test.log`, `world-pass3-test.log`.
