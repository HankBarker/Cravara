# LeatherLeggings.gd
extends Item
class_name LeatherLeggings

func _init():
	super("leather_leggings", "Leather Leggings", "Protective leg armor from T-Rex hide. +3 Defense.")
	max_stack = 1
	rarity = "common"
	armor_slot = "legs"
	defense = 3
