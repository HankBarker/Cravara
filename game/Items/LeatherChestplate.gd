# LeatherChestplate.gd
extends Item
class_name LeatherChestplate

const _ArmorIconFactory = preload("res://Items/ArmorIconFactory.gd")

func _init():
	super("leather_chestplate", "Leather Chestplate", "A sturdy chestplate from T-Rex hide. +5 Defense.")
	max_stack = 1
	rarity = "common"
	armor_slot = "chest"
	defense = 5
	icon = _ArmorIconFactory.make("chest")
