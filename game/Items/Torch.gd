extends Item
class_name Torch

func _init():
	super("torch", "Torch", "A basic light source.")
	max_stack = 99
	rarity = "common"
	icon = preload("res://Items/Icons/torch_icon.png")  # Replace with your icon path
