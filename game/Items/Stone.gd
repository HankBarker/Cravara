# Stone.gd
extends Item
class_name Stone

func _init():
	super("stone", "Stone", "A basic stone resource. Useful for crafting tools and structures.")
	max_stack = 99
	rarity = "common"
	# Add stone icon (once you upload the image)
	icon = preload("res://Items/Icons/stone_icon.png")
