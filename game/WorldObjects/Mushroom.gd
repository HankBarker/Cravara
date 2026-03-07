# Mushroom.gd - Decorative mushroom
extends DecorativeObject

var cap_color: Color

func _ready():
	object_name = "Mushroom"
	# Random mushroom color variety
	var mushroom_colors = [
		Color(0.8, 0.2, 0.15),  # Red
		Color(0.75, 0.6, 0.2),  # Brown/tan
		Color(0.6, 0.3, 0.7),   # Purple
	]
	cap_color = mushroom_colors[randi() % mushroom_colors.size()]
	color_primary = cap_color
	color_secondary = Color(0.85, 0.82, 0.75)  # Stem color
	draw_scale = 0.9
	super._ready()

func _draw():
	# Stem
	draw_rect(Rect2(-1.5, -1, 3, 5), color_secondary)
	# Cap (semicircle approximation using a polygon)
	var cap_points: PackedVector2Array = []
	for i in range(9):
		var angle = PI + (PI * i / 8.0)
		cap_points.append(Vector2(cos(angle) * 5, sin(angle) * 4 - 2))
	draw_colored_polygon(cap_points, cap_color)
	# Spots on cap
	draw_circle(Vector2(-2, -3.5), 1.0, Color(1, 1, 1, 0.6))
	draw_circle(Vector2(1.5, -4), 0.8, Color(1, 1, 1, 0.5))
