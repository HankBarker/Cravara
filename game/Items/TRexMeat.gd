class_name TRexMeat
extends Item

func _init():
	super("trex_meat", "T-Rex Meat", "Fresh raw meat. Right-click in inventory to eat (+25 hunger).")
	max_stack = 5
	rarity = "common"
	icon = preload("res://Items/Icons/trex_meat_icon.png")
	consumable = true
	hunger_value = 25
