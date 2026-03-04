# LargeRock.gd
extends DestructibleObject

func _ready():
	max_health = 3
	current_health = 3
	harvest_tool_required = "pickaxe"
	object_name = "Large Rock"

	guaranteed_drops = [Stone]
	guaranteed_drop_amounts = [3]  # More stone than small rock

	super._ready()
