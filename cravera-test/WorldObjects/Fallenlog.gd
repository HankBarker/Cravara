# FallenLog.gd
extends DestructibleObject

func _ready():
	max_health = 1
	current_health = 1
	harvest_tool_required = "none"
	object_name = "Fallen Log"

	guaranteed_drops = [Log]
	guaranteed_drop_amounts = [1]

	super._ready()
