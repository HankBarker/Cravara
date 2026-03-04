# Tree.gd
extends DestructibleObject

func _ready():
	max_health = 4
	current_health = 4
	harvest_tool_required = "axe"
	object_name = "Tree"

	guaranteed_drops = [Log]
	guaranteed_drop_amounts = [2]  # Drop more later if desired

	super._ready()
