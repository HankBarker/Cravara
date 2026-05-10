extends Item
class_name WorkbenchItem

func _init():
	super("workbench", "Workbench", "A sturdy table for crafting advanced items. Place with left-click.")
	max_stack = 5
	rarity = "common"
	icon = preload("res://Items/Icons/workbench_icon.png")
	placeable = true
	place_scene = "res://WorldObjects/Workbench.tscn"
