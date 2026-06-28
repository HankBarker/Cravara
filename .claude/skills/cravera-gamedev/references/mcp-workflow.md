# godot_mcp — Build/Test/Debug Workflow

Cravera ships its own **FastMCP server** at `godot_mcp/` (wired via `.mcp.json`). It encodes the
project's conventions so you can scaffold game content programmatically instead of hand-writing
`.tscn`/`.gd` boilerplate. **Prefer these tools over hand-editing scene files** — they keep UIDs,
node trees, collision layers, and data files consistent with the T-Rex/Item/Biome patterns.

> If a `mcp__godot_mcp__*` tool isn't loaded, fetch it first:
> `ToolSearch("select:mcp__godot_mcp__<name>")`. The server may take a moment to connect at session start.

## Tool catalog

### Scaffolding (write scenes/scripts/data the Cravera way)
| Tool | Use it to |
|---|---|
| `generate_creature(name, creature_type, biome, abilities, rarity, overwrite)` | Spawn a full creature: CharacterBody2D scene (AnimatedSprite2D + CollisionShape2D + Hurtbox/AttackArea/AggroRange), enum-FSM AI script, `Data/creatures.json` entry, and a biome spawn-table row. Stats auto-scale by `creature_type` × `rarity`. **First stop for any new enemy/animal.** |
| `generate_biome_config(biome_name, terrain_type, creatures, resources, difficulty_level, overwrite)` | Create `Data/Biomes/<Name>.json` (spawn tables, resource nodes, difficulty multipliers, ambient color) + a placeholder biome `.tscn` (TileMapLayer/Creatures/Resources). |
| `generate_game_system(system_name, description, components, autoload, signals, overwrite)` | Scaffold a larger system (Taming, Quests, SkillTree, Boss). `components` ⊂ {manager, ui, data, spawner, component}. Can auto-register an autoload and append signals to `SignalBus.gd`. |
| `create_scene(scene_name, root_node_type, node_tree, root_properties, save_directory, overwrite)` | Generic `.tscn` builder. `node_tree` entries: `{name, type, parent, properties, sub_resources:[{type,properties,assign_to}], connections:[{signal,from,to,method}]}`. |
| `add_node_to_scene(scene_path, parent_node, node_type, node_name, properties, sub_resources, connections)` | Add one node (e.g. an extra Area2D + shape) to an existing scene. |
| `attach_script_to_node(scene_path, node_name, script_name, script_contents, script_directory, overwrite)` | Write a `.gd` and attach it to a node (use root node's name, or `.`). |

### Data (the game's "database")
| Tool | Use it to |
|---|---|
| `read_game_data(file_path, key_path="")` | Read a JSON file or a nested key, e.g. `read_game_data("Data/creatures.json", "raptor.stats.health")`. |
| `update_game_data(file_path, key_path, value)` | Set/delete a nested key (creates file+dirs). `value=None` deletes. Use for tuning stats, recipes, spawn weights without touching code. |

### Inspect / run / debug
| Tool | Use it to |
|---|---|
| `list_project_structure()` | Tree of the project (skips `addons/` and `.import`). Orient before editing. |
| `scan_project_for_errors()` | **Run this after any scaffolding.** Finds missing scripts/resources/preloads and bad `res://` paths before you launch the editor. |
| `run_godot_scene(scene_path, timeout_seconds=10)` | Headless smoke-test a scene from CLI (needs Godot on PATH). |
| `collect_runtime_logs()` | Pull Godot's runtime log for the project after a run. |

## The standard dev loop
1. **Orient** — `list_project_structure()` / `read_game_data(...)` to see current state.
2. **Scaffold** — use the highest-level generator that fits (`generate_creature` > `create_scene` > hand-edit). Pass `overwrite=false` first; only overwrite deliberately.
3. **Wire data** — `update_game_data(...)` for stats/recipes/spawns; remember new code items also need the `create_item_by_id()` factory + `CraftingManager.personal_recipes` (until migrated to `.tres`, see `architecture.md`).
4. **Validate** — `scan_project_for_errors()`. Fix every reported missing reference.
5. **Run** — `run_godot_scene("res://playground.tscn")` (or the target scene) and read `collect_runtime_logs()`. The user can also play it in the editor.
6. **Iterate** — tune via `update_game_data` (no recompile for data-only changes).

## Conventions the generators assume (don't fight them)
- New creatures land in a per-creature dir; AI script is `camelCase.gd`, scene is `PascalCase.tscn`.
- Creature scenes use the **T-Rex node contract**: `AnimatedSprite2D`, `CollisionShape2D`, `Hurtbox`/`AttackArea`/`AggroRange` (Area2D) with the `_on_AttackArea_area_entered` / `_on_AggroRange_body_*` connections.
- Collision layers (from `project.godot`): **1=Player, 5=Walls, 6=Ground, 7=Interaction**. Creature Hurtbox layer=8/mask=4 in the generator — keep damage areas on consistent layers.
- Biome JSON keys: `creature_spawn_table` (`name/weight/max_count/min_level`), `resource_nodes` (`name/scene_path/density`), `difficulty_parameters`, `metadata.ambient_color`.
- Systems generated under `Systems/<Name>/`; new signals go on the global `SignalBus` (don't add cross-autoload hard refs — emit/listen instead).

## When NOT to use the MCP
- Sprite/art creation (see `visual-pixel-art.md`) — the generators leave `AnimatedSprite2D` empty; you still supply `SpriteFrames`.
- Fine-grained gameplay logic — generated AI/manager scripts are **starting templates**; edit the `.gd` directly afterward (e.g. swap random-cardinal wander for steering per `creature-ai.md`).
- Anything the server can't see: it excludes `addons/`. Maaack menu template edits are hand-done.

## Improving the toolchain itself
The server is plain Python (`godot_mcp/tools/*.py`, FastMCP). If a pattern is missing (e.g. a
`generate_item` that writes a `.tres` + recipe + factory entry in one shot, or a `generate_placeable`),
**add a tool** rather than repeating manual edits. New generators should mirror the existing ones:
`safe_write`, `make_response`, `TscnScene`/`serialize`, and `ProjectConfig` path detection.
