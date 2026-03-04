extends Item
class_name WorkbenchItem

func _init():
	super("workbench", "Workbench", "A sturdy table for crafting advanced items.")
	max_stack = 1
	rarity = "common"
	icon = preload("res://Items/Icons/workbench_icon.png")  # Replace with your icon path
