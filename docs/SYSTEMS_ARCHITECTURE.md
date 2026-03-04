# Systems Architecture

Detailed documentation of each game system in Cravara.

---

## Inventory System

**File**: `game/Player/Scripts/InventoryManager.gd` (Autoload)

A 35-slot inventory split into hotbar and main storage.

**Layout**:
- Slots 0-7: Hotbar (quick access, number keys 1-8)
- Slots 8-34: Main inventory (opened with ESC)

**Data structure**: `Array[Dictionary]` where each slot is `{"item": Item, "quantity": int}`

**Stacking logic** (priority order):
1. Stack onto existing items in hotbar (slots 0-7)
2. Stack onto existing items in main inventory (slots 8-34)
3. Place in empty hotbar slot
4. Place in empty main inventory slot

**Key methods**:
- `add_item(item: Item, quantity: int) -> bool` - Add with smart stacking
- `remove_item(item_id: String, quantity: int) -> bool` - Remove by ID
- `get_item_count(item_id: String) -> int` - Count across all slots
- `swap_items(from_index, to_index)` - Used by drag-and-drop
- `get_selected_item() -> Item` - Currently selected hotbar item

**Signals**:
- `inventory_changed` - Emitted on any state change
- `item_picked_up(item: Item, quantity: int)` - Emitted on item acquisition

---

## Crafting System

**File**: `game/Scripts/CraftingManager.gd` (Autoload)

Hardcoded recipe-based crafting with an item factory.

**Current recipes**:
| Recipe | Ingredients | Output |
|--------|------------|--------|
| Workbench | 5x Log | 1x Workbench |
| Torch | 1x Log | 1x Torch |
| Wooden Plank | 1x Log | 1x Plank |

**Key methods**:
- `try_craft(item_id, ingredients)` - Attempt crafting (checks + removes + creates)
- `can_craft(ingredients) -> bool` - Check if player has required materials
- `create_item_by_id(id) -> Item` - Factory method using match statement
- `get_item_icon(item_id) -> Texture2D` - Returns item icon for UI

**Recipe format**: `{"name": String, "item_id": String, "ingredients": {"item_id": amount}}`

---

## Player State Machine

**Files**: `game/Player/Scripts/player.gd` + `game/Player/States/*.gd`

Dictionary-based state machine with 6 states.

**States**:
| State | File | Behavior |
|-------|------|----------|
| idle | Idle.gd | No movement, can transition to walk/run/attack |
| walk | walk.gd | WASD movement at `walk_speed` (100) |
| run | Run.gd | Movement at `sprint_speed` (180) while Shift held |
| attack | Attack.gd | Sword swing, tool-aware harvesting, hitbox positioning |
| hurt | Hurt.gd | Knockback animation (200ms) |
| dead | Dead.gd | Death animation, then `queue_free()` |

**State interface**: Each state implements:
- `enter_state()` - Called when transitioning into this state
- `exit_state()` - Called when leaving this state
- `update_state(delta)` - Called every physics frame

**Player properties**:
- `walk_speed`: 100, `sprint_speed`: 180, `max_health`: 3
- `direction`: current movement vector
- `last_facing`: "up"/"down"/"left"/"right" for animation

---

## Combat System

**Player attack** (`game/Player/States/Attack.gd`):
- Activates `SwordHitbox` area based on facing direction
- Checks `InventoryManager.get_selected_item()` for tool type
- Passes tool type to `DestructibleObject.take_damage()`
- 50ms delay for hit detection

**T-Rex enemy** (`game/Sprites/trex.gd`):
- Wander: random movement at speed 20
- Chase: follows player at speed 40 within `AGGRO_RANGE` (100px)
- Attack: bite at 50px range, 1.8s cooldown
- Drops: TRexScale (100%, 1-3), TRexMeat (60%, 1-2)

**Health**: Player has 3 HP, synced to UI health bar via direct node reference.

---

## Destructible Object System

**File**: `game/Scripts/DestructibleObject.gd` (base class)

All harvestable world objects extend this class.

**Properties** (exported):
- `max_health` / `current_health`
- `harvest_tool_required`: "none", "axe", "pickaxe"
- `guaranteed_drops`: `Array[Script]` + `guaranteed_drop_amounts`: `Array[int]`
- `chance_drops`: `Array[Script]` + `chance_drop_probabilities`: `Array[float]` + `chance_drop_amounts`: `Array[int]`

**Current objects**:
| Object | Health | Tool Required | Drops |
|--------|--------|---------------|-------|
| SimpleRock | 1 | none | 1x Stone |
| LargeRock | 3 | pickaxe | 3x Stone |
| Tree | 4 | axe | 2x Log |
| Fallenlog | 1 | none | 1x Log |
| Workbench | 3 | none | (none) |

**Drop system**: Creates `DroppedItem` instances with arc animation (pop up + land + bounce).

---

## Placement System

**Files**: `game/Systems/Placement/PlacementController.gd` + `.tscn`

Ghost preview system for placing objects in the world.

**Flow**:
1. Player selects workbench in hotbar and left-clicks
2. `InventoryUI` instantiates `PlacementController` with `object_to_place`
3. Ghost follows mouse at 50% transparency
4. Left-click: place final object, remove from inventory
5. Right-click: cancel placement

---

## Resource Spawning

**Files**: `game/Scripts/ResourceSpawner.gd`, `game/Scripts/RockSpawner.gd`

Procedural placement of world objects at scene start.

**ResourceSpawner** properties:
- `resource_scenes`: Array of PackedScenes to spawn
- `total_resources`: target count (default 100)
- `min_distance_between_resources`: 80px minimum spacing
- `map_top_left` / `map_bottom_right`: spawn area bounds
- `avoid_water`, `avoid_edges`, `edge_buffer`: constraint options

**Algorithm**: Random position attempts with distance/boundary/water validation, max 10x attempts.

---

## UI System

**File**: `game/UI/InventoryUI.gd` (Autoload, CanvasLayer)

**Components**:
- Hotbar panel: 8 slots, always visible, number key selection (1-8)
- Inventory panel: 27 slots (grid, 9 columns), toggled with ESC
- Personal crafting panel: recipe icons, grayed out when uncraftable

**Slot behavior** (`game/UI/SlotUI.gd`):
- Left-click: start drag from occupied slot
- Left-click release on another slot: swap items
- Uses `DragController` for drag state management

**DragController** (`game/UI/DragController.gd`, Autoload):
- `start_drag(slot, icon_texture)` - Begin drag with visual feedback
- `update_drag_position()` - Follow mouse during drag
- `end_drag()` - Complete or cancel drag operation
- Creates temporary TextureRect at z_index 1000
