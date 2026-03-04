# BasicPickaxe.gd
extends Item
class_name BasicPickaxe

func _init():
	super("basic_pickaxe", "Basic Pickaxe", "A beginner pickaxe for breaking rocks.")
	max_stack = 1
	rarity = "common"
	icon = preload("res://Items/Icons/basic_pickaxe_icon.png")  # Replace with your icon path!
	tool_type = "pickaxe"
