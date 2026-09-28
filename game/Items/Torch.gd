extends Item
class_name Torch

func _init():
	super("torch", "Torch", "A basic light source. Right-click to place.")
	max_stack = 99
	rarity = "common"
	icon = preload("res://Items/Icons/torch_icon.png")
	placeable = true
	place_scene = "res://WorldObjects/Torch.tscn"
