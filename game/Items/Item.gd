# ===========================================
# Item.gd - Base item class
# ===========================================
class_name Item
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var icon: Texture2D
# When a `.tres` item has no baked icon, ItemDB generates one at load time from
# this hint (e.g. "armor_head", "armor_chest", "armor_legs", "chest"). Lets data
# files keep using the procedural pixel-icon factories without a PNG asset.
@export var icon_generator: String = ""
@export var max_stack: int = 1
@export var rarity: String = "common"  # common, rare, epic, legendary
@export var tool_type: String = ""  # Optional: "axe", "pickaxe", etc.
@export var damage: int = 1  # Damage dealt when this item is the active weapon
## Pass 13: the shape of a weapon's blow (ForestPlayer.BLOWS): "sweep" (an arc,
## every foe in it), "stab" (a quick jab at one), "smash" (a heavy blow on a
## spot: knocks back, staggers), "thrust" (a long line through several). ""
## = sweep for blades, a tool's own swing otherwise.
@export var weapon_class: String = ""
@export var mining_power: int = 0
@export var chop_power: int = 0
@export var placeable: bool = false  # Can be placed in the world
@export var place_scene: String = ""  # Path to the scene to place

# Armor properties
@export var armor_slot: String = ""  # "head", "chest", "legs", or ""
@export var defense: int = 0
@export var equipment_slot: String = ""
@export var stamina_bonus: float = 0.0
@export var damage_bonus: int = 0
@export var wading_bonus: float = 0.0
# Pass 12: a weapon whose blows bleed (per second, for 4 s): the Plate Maul.
@export var bleed_dps: float = 0.0
# Pass 12: how much of the Pale Lands' ash a trinket keeps out (1 = all).
@export var ash_guard: float = 0.0
## Pass 14: a trinket's effects, {effect: amount} (Forest/items/Trinkets.gd
## names them: "crit", "bleed", "speed", "luck"...). They add up across the
## keeper's trinket slots.
@export var effects: Dictionary = {}

# Consumables
@export var consumable: bool = false
@export var hunger_value: int = 0  # Hunger restored when eaten
@export var healing_total: float = 0.0
@export var healing_duration: float = 20.0
@export var food_satiation_seconds: float = 0.0
@export var consumed_container_id: String = ""
@export var recovery_bonus: float = 0.0

func _init(item_id: String = "", item_name: String = "", item_desc: String = ""):
	id = item_id
	name = item_name
	description = item_desc
