---
name: cravera-gamedev
description: Expert playbook for building Cravera, a Godot 4.6 top-down pixel-art dinosaur survival/crafting game. Use whenever working on Cravera's gameplay code, creatures/AI, world & biome generation, pixel-art/visual pipeline, inventory/crafting/HUD UI, or survival/progression design — and for the godot_mcp build/test workflow. Covers architecture, content scaffolding, and game-feel.
---

# Cravera Game Development

You are the developer of **Cravera** (internally "Cravara"), a 2D **top-down pixel-art dinosaur
survival/crafting** game in **Godot 4.6**. This skill is your accumulated, project-specific
expertise. Read this file first, then load the relevant `references/*.md` for depth before doing
substantive work in that area. **Keep it updated** — see "Continuous improvement" at the bottom.

## Project profile (the constraints everything must respect)
- **Engine:** Godot 4.6, Forward+. GDScript, typed where it matters.
- **Resolution:** native **480×270**, integer-scaled to 1080p (exactly 4×). `stretch/mode="canvas_items"`,
  pixel snapping ON, **Nearest** texture filter (`default_texture_filter=0`). Everything is low-res pixel art at one consistent pixels-per-unit.
- **Genre/north stars:** Core Keeper + Terraria (mining/biome/boss progression), Stardew/Forager
  (cozy readable gather→craft loop), **ARK in 2D** (creature taming, breeding, base-building, tech tiers).
- **Art pipeline:** **HYBRID** — AI-generated + curated asset packs for bulk world-filling;
  hand-authored pixel art for hero assets (player, key dinos, UI). One master palette unifies all sources.

## Architecture you must stay compatible with
- **Autoload singletons:** `SignalBus` (global decoupled signals — emit/listen, don't hard-ref across
  autoloads), `InventoryManager`, `CraftingManager`, `DragController`, `AudioManager`, `GameSettings`,
  `TimeCycle` (day/night), `SaveManager`.
- **Items** = `class_name Item extends Resource` (id, name, icon, max_stack, tool_type, damage,
  placeable, place_scene, armor_slot, defense, consumable, hunger_value). Concrete items are **code
  subclasses** + a `create_item_by_id()` factory `match` in `CraftingManager` (migration to `.tres`
  recommended — see architecture.md). Adding an item today touches ~4 places (subclass, factory,
  recipe, SaveManager).
- **Inventory:** `Array[Dictionary]` of `{item, quantity}`, 35 slots, hotbar = slots 0–7.
- **Crafting:** recipe dicts `{name,item_id,ingredients{id:qty},category,description}` in
  `CraftingManager.personal_recipes`; categories All/Tools/Building/Materials/Armor.
- **Player:** node-based FSM (Idle/walk/run/Attack/Hurt/Dead; each has `enter_state/update_state/exit_state`; `player.switch_state()`).
- **Creatures:** `CharacterBody2D` + `AnimatedSprite2D` + `Hurtbox`/`AttackArea`/`AggroRange` (Area2D);
  FSM in `_physics_process`; loot via `DroppedItem.tscn`; emit `SignalBus.creature_defeated`. Stats in `Data/creatures.json`.
- **World:** spawners (`ResourceSpawner` etc.) scatter PackedScenes; biomes described by `Data/Biomes/*.json`.
- **Physics layers:** 1=Player, 5=Walls, 6=Ground, 7=Interaction.
- **Anim naming:** `walk_<dir>`, `bite_<dir>`, `death` (4-dir facing: up/down/left/right).

## How to work (standard loop)
1. **Orient** with the godot_mcp tools (`list_project_structure`, `read_game_data`) — see `references/mcp-workflow.md`.
2. **Scaffold** content with the highest-level generator that fits (`generate_creature` >
   `generate_biome_config` / `generate_game_system` > `create_scene` > hand-edit). They keep
   conventions/UIDs/layers correct.
3. **Edit the generated `.gd`/data** to add real behavior (templates are starting points).
4. **Validate** with `scan_project_for_errors()` — fix every missing reference.
5. **Run** (`run_godot_scene` / editor) and read `collect_runtime_logs()`.
6. **Tune** data via `update_game_data` (no recompile for data-only changes).

## Reference map — load the file(s) for the task at hand
| Working on… | Read |
|---|---|
| Code structure, Resources/`.tres`, save/load, components, FSM, performance at scale | `references/architecture.md` |
| Terrain/biomes, noise, TileMapLayer, object scatter, seeds, world model | `references/world-generation.md` |
| Enemy/animal behavior, steering, pathfinding (NavigationAgent2D/AStarGrid2D), bosses, **taming/breeding** | `references/creature-ai.md` |
| Sprites, palettes, tilesets, the **AI+pack hybrid art workflow**, import settings, shaders, lighting, game feel | `references/visual-pixel-art.md` |
| Inventory/hotbar/chest UI, drag-drop, crafting menu, HUD bars, Theme/fonts at 480×270 | `references/ui-ux.md` |
| Core loop, tech-tree pacing, survival stats, damage formula, loot, base-building, progression roadmap | `references/game-design-progression.md` |
| The `godot_mcp` toolchain + build/test/debug loop | `references/mcp-workflow.md` |

## Cross-cutting principles (from the research)
- **One palette, one PPU, integer scale.** Never mix sprite resolutions or non-integer scale/rotate
  pixel art. 16px canonical tile/object grid; 32px for hero dinos. Quantize every art source to the master palette.
- **Data-driven > hardcoded.** Push stats/recipes/spawns into JSON (`update_game_data`); the `match`-factory
  for items is the main debt — prefer `.tres` + an `ItemDB` registry for new growth.
- **Decouple via SignalBus**, compose via components (HealthComponent, Hitbox/Hurtbox); evolve the FSM,
  don't rewrite it (add steering/pathfinding/taming as components).
- **Determinism:** introduce a stored `world_seed`; feed `FastNoiseLite` + a seeded RNG so worlds are reproducible.
- **Game feel is a feature:** hit-flash, screenshake, hitstop, pickup toasts, tween UI, juicy SFX — budget time for it.
- **Balance starting numbers are playtest hypotheses**, not law. Tune the damage formula to
  `damage * 100/(100+defense)` before adding armor tiers.
- **Always `scan_project_for_errors()` after scaffolding**, before declaring something done.

## Highest-priority opportunities (synthesized; confirm scope with the user before large refactors)
1. **Combat/stat foundation:** fix the armor formula; re-cast the T-Rex (HP 8 → ~30, make it a boss) and
   add a Raptor trash mob for sane early TTK. *(game-design-progression.md)*
2. **Item system debt:** migrate `create_item_by_id()` → `.tres` ItemData + `ItemDB` autoload. *(architecture.md)*
3. **Creature AI realism:** replace random-cardinal wander with steering; add `NavigationAgent2D` so dinos
   don't walk into walls; add a `TamingComponent` + extend `creatures.json`. *(creature-ai.md)*
4. **World determinism:** add `world_seed`, swap rejection-sampling for Poisson-disk, wire biome JSON into
   real TileMapLayer generation. *(world-generation.md)*
5. **Visual cohesion:** lock 3/4 view, one Lospec master palette + quantize gate, add `scale_mode="integer"`. *(visual-pixel-art.md)*
6. **UI polish:** fix drag merge/drop semantics, centralize a Theme + pixel font, add "craftable-only"+station-gated crafting. *(ui-ux.md)*

## Continuous improvement (this skill is a living document)
This skill is meant to get better every time you use it. When you learn something durable about Cravera
— a new convention, a gotcha, a tool you added to `godot_mcp`, a balance decision that stuck, a workflow
that worked — **update the relevant `references/*.md` (or this file)** in the same session. Keep entries
concrete and Cravera-specific. When the codebase diverges from what a reference says, fix the reference.
Cross-link related project facts in your memory (`MEMORY.md`).
