class_name TRexScale
extends Item

func _init():
	super("trex_scale", "T-Rex Scale", "A tough scale from a defeated T-Rex. Could be useful for crafting armor.")
	max_stack = 10
	rarity = "rare"
	# Add the icon
	icon = preload("res://Items/Icons/trex_scale_icon.png")
