# DecorativeObject.gd - Base class for non-interactable decorative world objects
# These are purely visual - no collision, no drops, no health
class_name DecorativeObject
extends Node2D

@export var object_name: String = "Decoration"
@export var color_primary: Color = Color(0.3, 0.6, 0.2)
@export var color_secondary: Color = Color(0.2, 0.5, 0.15)
@export var draw_scale: float = 1.0

func _ready():
	# Slight random variation
	var scale_var = randf_range(0.8, 1.2)
	scale = Vector2(scale_var, scale_var) * draw_scale
	# Random flip for variety
	if randf() > 0.5:
		scale.x *= -1
	z_index = 0
