# LeatherHelmet.gd
extends Item
class_name LeatherHelmet

func _init():
	super("leather_helmet", "Leather Helmet", "A basic helmet made from T-Rex hide. +2 Defense.")
	max_stack = 1
	rarity = "common"
	armor_slot = "head"
	defense = 2
