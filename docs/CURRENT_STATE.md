# Current State

Last updated: March 2026

## What Works

- Player movement (walk + sprint) with directional animations
- Player attack with sword swing hitbox
- 35-slot inventory with hotbar (8 slots) and main storage (27 slots)
- Item pickup from world (auto-pickup on proximity)
- Item stacking with smart hotbar priority
- Drag-and-drop inventory slot swapping
- Personal crafting (3 recipes: workbench, torch, plank)
- Destructible objects: trees (axe required), rocks (pickaxe/none), fallen logs
- Loot drop system with arc animation
- T-Rex enemy with wander/chase/attack AI and loot drops
- Workbench placement system with ghost preview
- Procedural resource spawning with distance constraints
- Hotbar selection (keys 1-8) with visual highlight
- Health system with UI health bar (3 HP)
- Pixel-perfect rendering (480x270 scaled to 1920x1080)

## What Is Incomplete or Missing

- **No save/load system** - Game state is lost on exit
- **No taming system** - Core game pillar not yet implemented
- **No biome system** - Only grassland biome exists
- **No NPC/dialogue system** - No towns, tribes, or diplomacy
- **No boss system** - No boss progression
- **No mutation system** - No DNA fusion or fossil resurrection
- **No world events** - No meteor showers, eruptions, etc.
- **No sound effects or music** - Audio files exist in `assets_raw/` but are not integrated
- **No main menu** - Menu addon exists but is not wired into the game
- **No pause menu**
- **No death/respawn system** - Player is removed from scene on death
- **No minimap or world map**
- **No lighting system**
- **No day/night cycle**

## Known Issues

1. ~~**Debug logging every frame**~~ - FIXED: Removed debug prints from player.gd, trex.gd, InventoryManager.gd
2. ~~**Hardcoded scene path**~~ - FIXED: Health bar now uses `@export var health_bar: ProgressBar` with null guards
3. **Hardcoded resource spawner path**: `ResourceSpawner.gd` line 47 uses `get_node_or_null("/root/Playground/Resources")`
4. **Placement system hardcoded to workbench**: `PlacementController.gd` line 48 calls `InventoryManager.remove_item("workbench", 1)` regardless of what's being placed
5. **Item factory uses match statement**: `CraftingManager.create_item_by_id()` must be manually updated for every new item
6. **T-Rex script in wrong directory**: `trex.gd` lives in `Sprites/` instead of with game logic
7. ~~**Inventory display only updates first 12 slots**~~ - FIXED: Now updates all 27 inventory slots with correct index mapping

## Technical Debt

- **No signal bus**: Systems communicate through direct autoload references. A `SignalBus` autoload has been created but not yet adopted by existing systems.
- **Items are hardcoded classes**: Each item is a GDScript class rather than a data-driven resource file. Adding new items requires creating a new `.gd` file.
- **Crafting recipes are hardcoded**: Recipes are defined as arrays in `CraftingManager.gd` rather than external data files.
- **Inconsistent file naming**: Mix of PascalCase (`Run.gd`) and lowercase (`walk.gd`) for state scripts. Mix of styles for world objects (`Fallenlog.gd` vs `LargeRock.gd`).
- ~~**Excessive debug print statements**~~: Cleaned up in player.gd, trex.gd, InventoryManager.gd, DestructibleObject.gd, Attack.gd
- **No base class for enemies**: The T-Rex uses inline AI logic rather than a shared enemy base class.
- **Drop system uses Script arrays**: `DestructibleObject.guaranteed_drops: Array[Script]` stores script references and calls `.new()`, which is fragile if items move to data-driven design.

## Recommended Next Steps

1. **Data-driven items**: Convert item classes to `.tres` resource files in a `Data/Items/` directory
2. **Data-driven recipes**: Move crafting recipes to resource files or JSON in `Data/Recipes/`
3. **Enemy base class**: Create a shared base class for creature AI (wander, chase, attack patterns)
4. **Adopt SignalBus**: Gradually migrate direct autoload references to use `SignalBus` signals
5. **Integrate menu addon**: Wire `maaacks_menus_template` into the game as main menu + pause menu
6. **Save/load system**: Implement persistence for inventory, world state, and player position
7. **Taming system**: First major gameplay system to implement after infrastructure is stable
8. **Audio integration**: Connect existing music tracks from `assets_raw/Music/` to scene playback
9. **File naming standardization**: Rename files to consistent PascalCase
10. ~~**Remove debug prints**~~: Done — cleaned up across all core scripts
