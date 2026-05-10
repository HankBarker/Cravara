# Bones.gd - Decorative bone pile
extends DecorativeObject

func _ready():
	object_name = "Bones"
	color_primary = Color(0.85, 0.82, 0.72)
	color_secondary = Color(0.7, 0.65, 0.55)
	super._ready()

func _draw():
	# Small bone pile - a few crossed lines and circles
	draw_line(Vector2(-6, 2), Vector2(6, -3), color_primary, 1.5)
	draw_line(Vector2(-5, -3), Vector2(5, 2), color_primary, 1.5)
	# Bone ends (small circles)
	draw_circle(Vector2(-6, 2), 1.5, color_secondary)
	draw_circle(Vector2(6, -3), 1.5, color_secondary)
	draw_circle(Vector2(-5, -3), 1.5, color_secondary)
	draw_circle(Vector2(5, 2), 1.5, color_secondary)
	# Small skull shape
	draw_circle(Vector2(0, -1), 2.5, color_primary)
	draw_circle(Vector2(-1, -1.5), 0.8, color_secondary)
	draw_circle(Vector2(1, -1.5), 0.8, color_secondary)
