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
signal player_hunger_changed(current: int, max_hunger: int)
signal player_stamina_changed(current: float, max_stamina: float)
signal player_died

# Creatures
signal creature_tamed(creature: Node)
signal creature_defeated(creature: Node)
## Pass 11: young, eggs, nests, regions and quests.
signal creature_grew(creature: Node)
signal egg_hatched(creature: Node)
signal nest_robbed(cell: Vector2i, species: String)
signal region_entered(region: String)
signal lore_read(id: String)
signal structure_built(kind: String, cell: Vector2i)
signal fish_caught(id: String)
signal relic_dug(cell: Vector2i)
signal bones_searched(cell: Vector2i)
signal place_visited(id: String)

# Equipment
signal armor_changed(slot: String, item)

# Settings
signal settings_menu_toggled(is_open: bool)
