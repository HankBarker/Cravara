extends Control
## Faceted gemstone-filled meter. Keeps ProgressBar-compatible value API.
var value := 100.0:
	set(v):
		value = clampf(v,0,100)
		queue_redraw()
var tint := Color("cb6e75")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y)
	var fill := floorf((w-6)*value/100.0)
	draw_colored_polygon(PackedVector2Array([Vector2(3,0),Vector2(w-3,0),Vector2(w,h/2),Vector2(w-3,h),Vector2(3,h),Vector2(0,h/2)]),Color("aa986b"))
	draw_rect(Rect2(3,1,w-6,h-2),Color("0a211f"))
	if fill > 0:
		draw_rect(Rect2(3,2,fill,h-4),tint.darkened(0.20))
		draw_rect(Rect2(3,2,fill,2),tint.lightened(0.2))
		for x in range(5,int(fill),11):
			draw_line(Vector2(x,2),Vector2(x+3,h-3),tint.lightened(0.33))
		draw_line(Vector2(3,2),Vector2(3+fill,2),tint.lightened(0.50))
