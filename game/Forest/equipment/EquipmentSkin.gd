extends "res://Forest/keeper/KeeperSkin.gd"
## Compatibility name. Pass 8 replaced the pass-7 anchor painter with the
## Keeper v2 skeletal rig (res://Forest/keeper/): armour is part of every
## rendered cel, so it can no longer slide off the body in any animation.
## Existing preload("res://Forest/equipment/EquipmentSkin.gd").new() callers
## (player, character creator, mounts) keep working unchanged.
