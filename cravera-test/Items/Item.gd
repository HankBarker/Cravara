# ===========================================
# Item.gd - Base item class
# ===========================================
class_name Item
extends Resource

@export var id: String
@export var name: String
@export var description: String
@export var icon: Texture2D
@export var max_stack: int = 1
@export var rarity: String = "common"  # common, rare, epic, legendary
@export var tool_type: String = ""  # Optional: "axe", "pickaxe", etc.

func _init(item_id: String = "", item_name: String = "", item_desc: String = ""):
	id = item_id
	name = item_name
	description = item_desc
