# SimpleRock.gd
# A simple rock that can be picked up
extends DestructibleObject

func _ready():
	# Set rock-specific properties
	max_health = 1
	current_health = 1
	harvest_tool_required = "none" # Can be picked up by hand
	object_name = "Small Rock"
	
	# Set up what this rock drops
	setup_rock_drops()
	
	# Call parent ready (important!)
	super._ready()

func setup_rock_drops():
	# Now pass the Stone class instead of a scene
	guaranteed_drops = [Stone]
	guaranteed_drop_amounts = [1]
	
	print("Rock created and ready to harvest stone!")
