extends "res://Forest/ForestWorld.gd"
## The forest exactly as it generated before points of interest existed (for
## the save-compatibility checks in world_poi_suite.gd).


func _place_points_of_interest() -> void:
	pois.clear()
	lore_at.clear()
