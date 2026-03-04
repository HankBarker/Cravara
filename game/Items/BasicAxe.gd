# BasicAxe.gd
extends Item
class_name BasicAxe

func _init():
	super("basic_axe", "Basic Axe", "A simple axe for chopping down trees.")
	max_stack = 1
	rarity = "common"
	icon = preload("res://Items/Icons/basic_axe_icon.png")  # Replace with your icon path!
	tool_type = "axe"
