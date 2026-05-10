# Bush.gd - Decorative bush
extends DecorativeObject

func _ready():
	object_name = "Bush"
	color_primary = Color(0.25, 0.55, 0.2)
	color_secondary = Color(0.18, 0.42, 0.14)
	super._ready()

func _draw():
	# Simple bush shape - clustered circles
	draw_circle(Vector2(0, 2), 6, color_secondary)
	draw_circle(Vector2(-5, -1), 5, color_primary)
	draw_circle(Vector2(5, -1), 5, color_primary)
	draw_circle(Vector2(0, -4), 5.5, Color(color_primary.r, color_primary.g, color_primary.b, 0.9))
