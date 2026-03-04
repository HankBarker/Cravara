class_name TRexMeat
extends Item

func _init():
	super("trex_meat", "T-Rex Meat", "Fresh meat from a T-Rex. Restores health when consumed.")
	max_stack = 5
	rarity = "common"
	# Add the icon
	icon = preload("res://Items/Icons/trex_meat_icon.png")
