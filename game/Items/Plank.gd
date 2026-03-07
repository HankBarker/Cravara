extends Item
class_name Plank

func _init():
	super("plank", "Wooden Plank", "Refined wood for crafting.")
	max_stack = 99
	rarity = "common"
	icon = preload("res://Items/Icons/plank_icon.png")  # Replace with your icon path
