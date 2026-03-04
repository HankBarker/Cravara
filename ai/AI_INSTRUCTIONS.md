# AI Development Instructions

Instructions for AI agents contributing to the Cravara project.

## Project Overview

Cravara is a Godot 4.4 GDScript project. The Godot project lives in `game/` (open `game/project.godot` in the editor). All `res://` paths in code are relative to the `game/` directory.

## Codebase Navigation

### Autoloads (Global Singletons)
These are always available from any script - no need to pass references:
- `SignalBus` - Global signal bus (`game/Autoloads/SignalBus.gd`)
- `InventoryManager` - Inventory state (`game/Player/Scripts/InventoryManager.gd`)
- `CraftingManager` - Crafting logic (`game/Scripts/CraftingManager.gd`)
- `DragController` - UI drag state (`game/UI/DragController.gd`)

### Key Base Classes
- `Item` (extends Resource) - `game/Items/Item.gd` - All items inherit from this
- `DestructibleObject` (extends StaticBody2D) - `game/Scripts/DestructibleObject.gd` - All harvestable world objects inherit from this

### Scene Files
Scene files (`.tscn`) are text-based and reference scripts via `res://` paths AND UIDs:
```
[ext_resource type="Script" uid="uid://30qj6ug7v6fq" path="res://Player/Scripts/player.gd" id="1_onrkg"]
```
If you move a script, you MUST update the `path=` in every `.tscn` that references it. The UID provides a fallback, but paths should stay correct.

### UID Files
Godot 4 creates `.uid` files alongside scripts. When moving a script, move its `.uid` file too. These provide stable references across renames.

## How to Add New Items

1. Create a new GDScript in `game/Items/` extending `Item`:
```gdscript
class_name MyItem
extends Item

func _init():
    super("my_item", "My Item", "Description here.")
    max_stack = 99
    rarity = "common"
    icon = preload("res://Items/Icons/my_item_icon.png")
```

2. Add the icon PNG to `game/Items/Icons/`

3. Register it in `CraftingManager.create_item_by_id()` if it can be crafted:
```gdscript
"my_item":
    return MyItem.new()
```

4. If it's craftable, add a recipe to `CraftingManager.personal_recipes`:
```gdscript
{"name": "My Item", "item_id": "my_item", "ingredients": {"log": 2, "stone": 1}}
```

5. If a world object drops it, add the script to the object's `guaranteed_drops` or `chance_drops` array in its `.tscn` scene.

## How to Add New World Objects

1. Create a new scene (`.tscn`) in `game/WorldObjects/` with a root `StaticBody2D`
2. Create a script extending `DestructibleObject`:
```gdscript
extends DestructibleObject

func _ready():
    object_name = "My Object"
    max_health = 2
    harvest_tool_required = "pickaxe"
    super._ready()
```

3. Configure drops in the scene inspector or script:
   - `guaranteed_drops`: Array of item Script resources
   - `guaranteed_drop_amounts`: Matching array of quantities
   - `chance_drops` + `chance_drop_probabilities` + `chance_drop_amounts` for random drops

## How to Add New Player States

1. Create a new GDScript in `game/Player/States/`:
```gdscript
var player

func enter_state():
    pass

func exit_state():
    pass

func update_state(delta):
    pass
```

2. Register it in `player.gd`'s `states` dictionary:
```gdscript
"my_state": preload("res://Player/States/MyState.gd").new()
```

3. Transition to it with `player.switch_state("my_state")`

## How to Add New Creatures

Currently there is no creature base class. The T-Rex (`game/Sprites/trex.gd`) can serve as a reference implementation. Future creatures should follow a shared base class pattern.

Key elements of a creature:
- CharacterBody2D with AnimatedSprite2D
- Aggro range (Area2D) for player detection
- Attack area for damage dealing
- State-based behavior (wander, chase, attack)
- Loot drops using DroppedItem scene

## Important Rules

1. **Never modify asset files** in `Sprites/`, `Items/Icons/`, `WorldObjects/Images/`, `Tile Maps/` textures, or `assets_raw/`. These are human-created.
2. **Always use `res://` paths** when referencing files in GDScript or scenes.
3. **Prefer signals over direct references** for system communication. Use `SignalBus` for cross-system events.
4. **Keep scenes lightweight** - Scenes should define node layout and visuals. Gameplay logic belongs in scripts.
5. **Test in the Playground scene** - `game/playground.tscn` is the main development scene.
6. **Match existing patterns** - Follow the conventions established in existing code before introducing new patterns.

## Display and Input

- Viewport: 480x270 (pixel art), window: 1920x1080
- Movement: W/A/S/D (Up/Down/Left/Right actions)
- Sprint: Shift
- Attack: Left mouse click
- Hotbar: Number keys 1-8
- Inventory toggle: ESC (ui_cancel)
- Place object: Left click (in placement mode)
- Cancel placement: Right click

## Collision Layers

| Layer | Name | Purpose |
|-------|------|---------|
| 1 | Player | Player body |
| 5 | Walls | Blocking objects |
| 6 | Ground | Ground surfaces |
| 7 | Interaction | Interactable areas |
