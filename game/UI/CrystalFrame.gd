extends Control
## Authored interface ornament: fossil stone, bronze lashings and Sky-Fang inlays.
## Geometry follows the native pixel grid. This is interface chrome, not world art.
var compact := false
var inset := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	if w < 12 or h < 12: return
	var rim := Color("547f76")
	draw_style_box(_stone(),Rect2(Vector2.ZERO,size))
	# Recessed green slate and a thin warm carved line create depth without noise.
	draw_rect(Rect2(3,3,w-6,h-6),Color("1b3835"),false)
	draw_line(Vector2(7,4),Vector2(w-8,4),Color("91a17b"))
	draw_line(Vector2(5,h-5),Vector2(w-6,h-5),Color("314b40"))
	if not compact and not inset:
		draw_rect(Rect2(7,6,w-14,18),Color("213b33"))
		draw_line(Vector2(10,25),Vector2(w-11,25),Color("5d7260"))
		draw_line(Vector2(14,26),Vector2(w-15,26),Color("0c201f"))
		# Little overlapping fern blades grow over the outside of the old carved frame.
		# Their outline is kept clear of the usable panel interior.
		for y in [31,h-35]:
			draw_line(Vector2(1,y-8),Vector2(2,y+11),Color("3d694c"))
			draw_colored_polygon(PackedVector2Array([Vector2(1,y),Vector2(-3,y-5),Vector2(-2,y+1),Vector2(2,y+4)]),Color("547e51"))
			draw_colored_polygon(PackedVector2Array([Vector2(2,y+6),Vector2(5,y+2),Vector2(5,y+6),Vector2(2,y+10)]),Color("385a42"))
	for corner in [Vector2(0,0),Vector2(w-1,0),Vector2(0,h-1),Vector2(w-1,h-1)]:
		var sx := 1 if corner.x == 0 else -1
		var sy := 1 if corner.y == 0 else -1
		var p: Vector2 = corner + Vector2(sx*2,sy*2)
		draw_line(p,p+Vector2(sx*11,0),Color("bc9e67"),2)
		draw_line(p,p+Vector2(0,sy*9),Color("806743"),2)
		draw_line(p+Vector2(sx*2,sy*3),p+Vector2(sx*2,sy*7),rim)
		gem(corner+Vector2(sx*5,sy*5),3 if compact else 4)
	# Etched seed-runes on the lower rim, far from text and icons.
	if w > 90 and not compact:
		for x in range(w/2-15,w/2+16,10):
			draw_line(Vector2(x-2,h-3),Vector2(x,h-5),Color("9a855d"))
			draw_line(Vector2(x,h-5),Vector2(x+2,h-3),Color("9a855d"))

func gem(p: Vector2,r: int) -> void:
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r+1),p+Vector2(-r,0)]),Color("0b272b"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,1-r),p+Vector2(r-1,0),p,p+Vector2(1-r,0)]),Color("a2e3ca"))
	draw_colored_polygon(PackedVector2Array([p,p+Vector2(r-1,0),p+Vector2(0,r),p+Vector2(1-r,0)]),Color("459a93"))
	draw_line(p+Vector2(0,1-r),p,Color("f0f5d2"))

func _stone() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("152c2b")
	s.border_color = Color("091b1e")
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.corner_detail = 1
	s.shadow_color = Color(0,0,0,0.55)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0,2)
	return s
