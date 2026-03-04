# Code Style Guide

GDScript conventions for the Cravara project.

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes / class_name | PascalCase | `DestructibleObject`, `BasicAxe` |
| Script files | PascalCase.gd | `InventoryManager.gd`, `BasicAxe.gd` |
| Scene files | PascalCase.tscn | `DroppedItem.tscn`, `SimpleRock.tscn` |
| Functions | snake_case | `add_item()`, `take_damage()` |
| Variables | snake_case | `current_health`, `max_stack` |
| Constants | UPPER_SNAKE_CASE | `MAX_INVENTORY_SIZE` |
| Signals | snake_case (past tense for events) | `inventory_changed`, `item_picked_up` |
| Exported variables | snake_case | `@export var walk_speed` |
| Node references | snake_case with @onready | `@onready var animated_sprite` |
| Enums | PascalCase (type), UPPER_SNAKE_CASE (values) | `enum Rarity { COMMON, RARE }` |
| Item IDs | snake_case strings | `"basic_axe"`, `"trex_meat"` |

## Script Structure

Order elements in scripts as follows:

```gdscript
# Header comment (optional)
class_name ClassName
extends BaseClass

# Signals
signal something_happened

# Constants
const MAX_VALUE = 100

# Exports
@export var speed: float = 100.0

# @onready references
@onready var sprite := $Sprite2D

# Regular variables
var current_state: String = "idle"

# Built-in callbacks (_ready, _process, _physics_process, _input)
func _ready():
    pass

func _physics_process(delta):
    pass

# Public methods
func take_damage(amount: int):
    pass

# Private methods (prefixed with _)
func _calculate_knockback():
    pass

# Signal callbacks (prefixed with _on_)
func _on_body_entered(body):
    pass
```

## Type Hints

Use type hints for function parameters and return types:

```gdscript
func add_item(item: Item, quantity: int = 1) -> bool:
    ...

func get_selected_item() -> Item:
    ...
```

Use `:=` for type inference on variable declarations:

```gdscript
var current_health := max_health
@onready var sprite := $Sprite2D
```

## Signals

Declare signals with typed parameters:

```gdscript
signal item_picked_up(item: Item, quantity: int)
```

Prefer `signal_name.emit()` over `emit_signal("signal_name")`:

```gdscript
# Preferred
inventory_changed.emit()

# Avoid
emit_signal("inventory_changed")
```

Connect signals in `_ready()`:

```gdscript
func _ready():
    InventoryManager.inventory_changed.connect(_on_inventory_changed)
```

## Resource Paths

Always use `res://` paths (relative to `project.godot`):

```gdscript
var scene = preload("res://Items/DroppedItem.tscn")
var icon = preload("res://Items/Icons/basic_axe_icon.png")
```

## Comments

Use comments sparingly - prefer clear naming over comments. Add comments when:
- Explaining non-obvious business logic
- Documenting workarounds or known issues
- Describing complex algorithms

Do not add emoji to comments in new code.

## Scene Organization

- Keep scene trees shallow when possible
- Name nodes descriptively: `SwordHitbox`, `InteractionArea`, `AnimatedSprite2D`
- Attach scripts to root nodes of scenes
- Use groups for cross-scene node discovery when needed

## Error Handling

- Use `print()` for development-time debugging (tag with context)
- Check for null before accessing properties on potentially-null values
- Use `get_node_or_null()` when a node might not exist
- Prefer `is_instance_valid(node)` over null checks for freed nodes
