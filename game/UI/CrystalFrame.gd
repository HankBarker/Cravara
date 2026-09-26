extends Control
## A panel of the keeper's field pack (pass 14): a leather body the world
## shows through, a stitched edge, brass rivets at the corners and, for a
## titled panel, a darker flap along the top where the title sits. (Pass 13's
## carved fossil slate read green and heavy.) Geometry follows the native
## pixel grid. This is interface chrome, not world art.
var compact := false
var inset := false

const BODY := Color(0.165, 0.110, 0.075, 0.84)
const EDGE_OUT := Color("140c07")
const BAND := Color("5a3b27")
const BAND_LIGHT := Color("7a5236")
const STITCH := Color("c9a46b")
const FLAP := Color(0.10, 0.065, 0.04, 0.55)
const BRASS := Color("d8ad5f")
const BRASS_DARK := Color("6b4a1f")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := int(size.x)
	var h := int(size.y)
	if w < 12 or h < 12: return
	draw_style_box(_leather(),Rect2(Vector2.ZERO,size))
	# The leather band round the edge: lit along the top, a running stitch inside it.
	draw_rect(Rect2(2,2,w-4,h-4),BAND,false)
	draw_line(Vector2(3,2),Vector2(w-4,2),BAND_LIGHT)
	var inner := 4 if not inset else 3
	for x in range(inner+2,w-inner-2,3):
		draw_rect(Rect2(x,inner,2,1),STITCH)
		draw_rect(Rect2(x,h-1-inner,2,1),STITCH)
	for y in range(inner+2,h-inner-2,3):
		draw_rect(Rect2(inner,y,1,2),STITCH)
		draw_rect(Rect2(w-1-inner,y,1,2),STITCH)
	if not compact and not inset:
		# The flap the title sits on, and its stitched seam.
		draw_rect(Rect2(6,6,w-12,15),FLAP)
		for x in range(8,w-8,3):
			draw_rect(Rect2(x,21,2,1),STITCH.darkened(0.25))
	for corner in [Vector2(0,0),Vector2(w-1,0),Vector2(0,h-1),Vector2(w-1,h-1)]:
		var sx := 1 if corner.x == 0 else -1
		var sy := 1 if corner.y == 0 else -1
		rivet(corner+Vector2(sx*3,sy*3))

func rivet(p: Vector2) -> void:
	draw_rect(Rect2(p-Vector2(1,1),Vector2(3,3)),BRASS_DARK)
	draw_rect(Rect2(p-Vector2(1,1),Vector2(2,2)),BRASS)
	draw_rect(Rect2(p-Vector2(1,1),Vector2(1,1)),Color("f1d38c"))

func _leather() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BODY
	s.border_color = EDGE_OUT
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.corner_detail = 1
	s.shadow_color = Color(0,0,0,0.35)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0,2)
	return s
