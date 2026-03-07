# Godot MCP Server (`godot_mcp`)

MCP (Model Context Protocol) server that enables Claude Code to programmatically create, modify, and expand Godot 4 game project files for the Cravara project.

## Installation

```bash
cd godot_mcp
pip install -e .
```

Or with `uv`:

```bash
cd godot_mcp
uv pip install -e .
```

## Running

### Stdio mode (for Claude Code integration)

```bash
python server.py
```

### Dev mode (interactive testing dashboard)

```bash
mcp dev server.py
```

## Adding to Claude Code

Add to your MCP settings (`.claude/settings.json` or via `claude mcp add`):

```json
{
  "mcpServers": {
    "godot_mcp": {
      "command": "python",
      "args": ["/path/to/Cravara/godot_mcp/server.py"]
    }
  }
}
```

Or via CLI:

```bash
claude mcp add godot_mcp python /path/to/Cravara/godot_mcp/server.py
```

## Tools Reference

### Scene Builder

**`create_scene`** — Create a new `.tscn` scene file.

```json
{
  "scene_name": "Raptor",
  "root_node_type": "CharacterBody2D",
  "node_tree": [
    {"name": "AnimatedSprite2D", "type": "AnimatedSprite2D", "parent": "."},
    {
      "name": "CollisionShape2D", "type": "CollisionShape2D", "parent": ".",
      "sub_resources": [
        {"type": "CapsuleShape2D", "properties": {"radius": 7.0, "height": 26.0}, "assign_to": "shape"}
      ]
    }
  ],
  "save_directory": "Sprites/Raptor"
}
```

**`add_node_to_scene`** — Add a node to an existing scene.

```json
{
  "scene_path": "res://Sprites/Raptor/Raptor.tscn",
  "parent_node": ".",
  "node_type": "Area2D",
  "node_name": "AttackArea",
  "properties": {"collision_layer": 2}
}
```

### Script Manager

**`attach_script_to_node`** — Create a GDScript and attach it to a scene node.

```json
{
  "scene_path": "res://Sprites/Raptor/Raptor.tscn",
  "node_name": "Raptor",
  "script_name": "raptor",
  "script_contents": "extends CharacterBody2D\n\nvar health := 5\n\nfunc _ready():\n\tpass\n"
}
```

### Game Data Manager

**`update_game_data`** — Read/modify JSON data files with nested key support.

```json
{
  "file_path": "Data/creatures.json",
  "key_path": "raptor.stats.health",
  "value": 8
}
```

**`read_game_data`** — Read data from JSON files.

```json
{
  "file_path": "Data/creatures.json",
  "key_path": "raptor.stats"
}
```

### World Generator

**`generate_biome_config`** — Generate biome configuration with spawn tables.

```json
{
  "biome_name": "TarPitBiome",
  "terrain_type": "swamp",
  "creatures": [
    {"name": "ThornbackAnkylosaur", "weight": 5, "max_count": 2},
    {"name": "SwampRaptor", "weight": 15, "max_count": 6}
  ],
  "resources": [
    {"name": "Tree", "scene_path": "res://WorldObjects/Tree.tscn", "density": 5}
  ],
  "difficulty_level": 3
}
```

### Creature Generator

**`generate_creature`** — Auto-generate a complete creature (scene + AI script + data + spawn rules).

```json
{
  "name": "JungleRaptor",
  "creature_type": "predator",
  "biome": "jungle",
  "abilities": ["bite", "pounce"],
  "rarity": "uncommon"
}
```

This creates:
- `Sprites/JungleRaptor/JungleRaptor.tscn` — CharacterBody2D scene matching T-Rex pattern
- `Sprites/JungleRaptor/jungleRaptor.gd` — AI script with state machine
- `Data/creatures.json` — Stats entry with rarity-scaled values
- Updates biome spawn table if biome config exists

### System Generator

**`generate_game_system`** — Generate a complete gameplay system.

```json
{
  "system_name": "TamingSystem",
  "description": "Allows players to tame and ride dinosaurs",
  "components": ["manager", "ui", "data"],
  "autoload": true,
  "signals": [
    {"name": "creature_tamed", "params": "creature_name: String"},
    {"name": "taming_failed", "params": "creature_name: String, reason: String"}
  ]
}
```

### Debug Tools

**`scan_project_for_errors`** — Scan for missing scripts, broken references, invalid paths.

**`run_godot_scene`** — Run a scene via Godot CLI for testing.

```json
{
  "scene_path": "res://playground.tscn",
  "timeout_seconds": 10
}
```

**`collect_runtime_logs`** — Read Godot runtime log files.

**`list_project_structure`** — Show the full project directory tree.

## Example Workflows

### Create a jungle raptor enemy with a bite attack

```
1. generate_creature(name="JungleRaptor", creature_type="predator", biome="jungle", abilities=["bite"], rarity="uncommon")
2. scan_project_for_errors()
```

### Generate a tar pit biome with ankylosaur enemies

```
1. generate_biome_config(biome_name="TarPitBiome", terrain_type="swamp", difficulty_level=4, creatures=[...])
2. generate_creature(name="ThornbackAnkylosaur", creature_type="herbivore", biome="tarpit", abilities=["ground_slam", "charge"], rarity="rare")
```

### Create a new crafting station

```
1. create_scene(scene_name="AdvancedWorkbench", root_node_type="StaticBody2D", ...)
2. attach_script_to_node(scene_path="...", node_name="AdvancedWorkbench", ...)
3. update_game_data(file_path="Data/crafting_stations.json", key_path="advanced_workbench.recipes", value=[...])
```

### Generate a taming system

```
1. generate_game_system(system_name="TamingSystem", components=["manager", "ui", "data"], autoload=true, ...)
```

## How Claude Should Use These Tools

1. **Start with `list_project_structure`** to understand the current state.
2. **Use `scan_project_for_errors`** before and after making changes to verify integrity.
3. **Use high-level tools first** (`generate_creature`, `generate_game_system`) — they compose the lower-level tools automatically.
4. **Use low-level tools for precision** (`create_scene`, `add_node_to_scene`, `attach_script_to_node`) when modifying existing content or building something custom.
5. **Use `update_game_data`** to maintain structured data that scripts can load at runtime.
6. **Always set `overwrite=False`** (default) to avoid accidentally destroying existing work.

## Architecture

The server uses FastMCP with a modular tool registration pattern:

```
server.py          → Entry point, registers all tools
config.py          → Path resolution, project config
utils.py           → ID generation, file safety, value formatting
tscn_parser.py     → .tscn read/write/modify engine
tools/
  scene_builder.py     → create_scene, add_node_to_scene
  script_manager.py    → attach_script_to_node
  data_manager.py      → update_game_data, read_game_data
  world_generator.py   → generate_biome_config
  creature_generator.py → generate_creature
  system_generator.py  → generate_game_system
  debug_tools.py       → scan, run, logs, structure
```

All tools return structured responses: `{success, files_modified, summary}`.
