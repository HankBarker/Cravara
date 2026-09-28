extends CanvasModulate

# Listens to TimeCycle and smoothly tracks the ambient color so the world
# is dim at night and full-bright at noon. PointLight2D nodes (torches)
# add light back additively on top of this multiply pass.

func _ready():
	if TimeCycle:
		TimeCycle.time_changed.connect(_on_time_changed)
		color = TimeCycle.get_ambient_color()

func _on_time_changed(_t: float, ambient: Color):
	# Smoothly approach the target so transitions don't pop on phase boundaries
	color = color.lerp(ambient, 0.15)
