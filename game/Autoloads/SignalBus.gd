# SignalBus.gd - Global signal bus for decoupled system communication
# Systems should emit and connect to these signals rather than
# referencing other autoloads directly when possible.
extends Node

# Inventory
signal inventory_changed
signal item_picked_up(item: Item, quantity: int)

# Crafting
signal item_crafted(item_id: String)

# World objects
signal object_destroyed(object: Node)
signal object_placed(object: Node, position: Vector2)

# Player
signal player_health_changed(current: int, max_health: int)
signal player_died

# Creatures
signal creature_tamed(creature: Node)
signal creature_defeated(creature: Node)

# Equipment
signal armor_changed(slot: String, item)

# Settings
signal settings_menu_toggled(is_open: bool)
