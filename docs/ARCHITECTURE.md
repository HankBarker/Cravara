# Architecture Overview

## Repository Layout

The repository is organized into four top-level directories:

| Directory | Purpose |
|-----------|---------|
| `game/` | The Godot 4.4 project (all game code, scenes, and in-engine assets) |
| `assets_raw/` | Source assets not used directly by Godot (Aseprite files, music, concept art, asset packs) |
| `docs/` | Project documentation |
| `ai/` | AI-specific development instructions |

The `game/` directory contains `project.godot` and is the directory you open in the Godot editor.

## Godot Project Structure (`game/`)

```
game/
├── project.godot           # Engine config, autoloads, input mappings
├── Autoloads/              # Global singletons
│   └── SignalBus.gd        # Decoupled signal communication
├── Player/
│   ├── player.tscn         # Player scene (CharacterBody2D)
│   ├── Scripts/
│   │   ├── player.gd       # Player controller + state machine
│   │   ├── InventoryManager.gd  # [AUTOLOAD] Inventory singleton
│   │   └── camera_2d.gd    # Camera follow script
│   └── States/             # Player state machine scripts
│       ├── Idle.gd, walk.gd, Run.gd
│       ├── Attack.gd, Hurt.gd, Dead.gd
│       └── (each state has enter_state/exit_state/update_state)
├── Items/
│   ├── Item.gd             # Base Resource class for all items
│   ├── DroppedItem.gd/.tscn  # World representation of dropped items
│   ├── BasicAxe.gd, BasicPickaxe.gd  # Tool items (max_stack: 1)
│   ├── Stone.gd, Log.gd, Plank.gd    # Resource items (max_stack: 99)
│   ├── Torch.gd, TRexMeat.gd, TRexScale.gd  # Other items
│   ├── WorkbenchItem.gd    # Placeable item
│   └── Icons/              # PNG icons for each item
├── WorldObjects/
│   ├── SimpleRock, LargeRock, Tree, Fallenlog, Workbench (.tscn + .gd)
│   └── Images/             # Sprite textures for world objects
├── Sprites/
│   ├── Base Character/     # Player animation sprite sheets
│   └── T-Rex/              # T-Rex scene, script, and sprites
├── UI/
│   ├── InventoryUI.gd      # [AUTOLOAD] Inventory panel + hotbar + crafting UI
│   ├── SlotUI.gd           # Individual inventory slot behavior
│   ├── DragController.gd   # [AUTOLOAD] Drag-and-drop state manager
│   └── Textures/           # UI textures
├── Tile Maps/
│   ├── cravara_tileset.tres # Tileset resource
│   ├── Firsttilemap.tscn   # Tilemap scene
│   └── spr_tileset_sunnysideworld_16px.png
├── Systems/
│   └── Placement/          # Object placement controller
├── Scripts/
│   ├── CraftingManager.gd  # [AUTOLOAD] Crafting recipes and logic
│   ├── DestructibleObject.gd  # Base class for harvestable objects
│   ├── ResourceSpawner.gd  # Procedural resource placement
│   └── RockSpawner.gd      # Rock-specific spawner
├── playground.tscn          # Main test/development scene
└── GrasslandBiome.tscn      # Grassland biome tilemap + resources
```

## Autoload Singletons

These scripts are loaded globally via `project.godot` and accessible from any script:

| Singleton | Path | Responsibility |
|-----------|------|----------------|
| `SignalBus` | `Autoloads/SignalBus.gd` | Global signal bus for decoupled communication |
| `InventoryManager` | `Player/Scripts/InventoryManager.gd` | 35-slot inventory, item add/remove/swap |
| `CraftingManager` | `Scripts/CraftingManager.gd` | Recipe definitions, crafting logic, item factory |
| `DragController` | `UI/DragController.gd` | Drag-and-drop state for inventory UI |

## Key Design Patterns

### Player State Machine
The player (`player.gd`) uses a dictionary-based state machine. Each state is a separate GDScript class with `enter_state()`, `exit_state()`, and `update_state(delta)` methods. States are preloaded at startup and stored in a `states` dictionary. The `switch_state()` method handles transitions.

### Item Class Hierarchy
All items extend `Item` (which extends `Resource`). Each item type is a separate GDScript class that sets properties in `_init()`:
- **Tools**: `BasicAxe`, `BasicPickaxe` (max_stack: 1, have `tool_type`)
- **Resources**: `Stone`, `Log`, `Plank`, `Torch` (max_stack: 99)
- **Creature drops**: `TRexMeat` (max_stack: 5), `TRexScale` (max_stack: 10)
- **Placeables**: `WorkbenchItem` (max_stack: 1)

### DestructibleObject Base Class
All harvestable world objects (`Tree`, `SimpleRock`, `LargeRock`, `Fallenlog`, `Workbench`) extend `DestructibleObject`, which provides:
- Health and damage system
- Tool requirement checking
- Guaranteed and chance-based loot drops
- Shake animation on hit
- Drop animation (arc + bounce)

### Scene Hierarchy
The main scene (`playground.tscn`) contains:
- Player instance
- GrasslandBiome (tilemap + resource spawner)
- UI layer (InventoryUI)
- T-Rex instances
- Static world objects

## Collision Layers

| Layer | Name | Used By |
|-------|------|---------|
| 1 | Player | Player character |
| 5 | Walls | Blocking objects |
| 6 | Ground | Ground collision |
| 7 | Interaction | Interactive areas |

## Signal Flow

Current signal connections:
- `InventoryManager.inventory_changed` → `InventoryUI._on_inventory_changed()` (refreshes display)
- `InventoryManager.item_picked_up` → `InventoryUI._on_item_picked_up()` (pickup feedback)
- `DestructibleObject.object_destroyed` / `object_damaged` (declared but used internally)
- `DroppedItem` uses `body_entered` to detect player for auto-pickup
