# Log.gd
extends Item
class_name Log

func _init():
	super("log", "Wood Log", "A basic piece of wood. Useful for crafting.")
	max_stack = 99
	rarity = "common"
	icon = preload("res://Items/Icons/log_icon.png")  # Replace with your icon path!
