extends Control
## A Sky-Fang crystal meter: faceted crystal in a bronze casing, notched in
## tenths. Keeps a ProgressBar-like value API (0-100). What was just lost
## lingers as a pale band that drains away after a moment; a low meter
## shimmers. Every edge is a whole pixel (drawn with rects, never lines).
var value := 100.0:
	set(v):
		v = clampf(v,0,100)
		if v < value: _hold = 0.35
		value = v
		queue_redraw()
var tint := Color("cb6e75")
var _ghost := 100.0
var _hold := 0.0
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost = value

func _process(delta: float) -> void:
	_clock += delta
	if _ghost > value:
		_hold -= delta
		if _hold <= 0.0: _ghost = move_toward(_ghost,value,delta*70.0)
		queue_redraw()
	else:
		_ghost = value
	if value < 25.0: queue_redraw()

func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y)
	var inner := w-6
	var fill := floorf(inner*value/100.0)
	var ghost := floorf(inner*_ghost/100.0)
	# Bronze casing with pointed ends around a dark bed.
	draw_colored_polygon(PackedVector2Array([Vector2(3,0),Vector2(w-3,0),Vector2(w,floorf(h/2)),Vector2(w-3,h),Vector2(3,h),Vector2(0,floorf(h/2))]),Color("5c4a33"))
	draw_colored_polygon(PackedVector2Array([Vector2(3,1),Vector2(w-3,1),Vector2(w-1,floorf(h/2)),Vector2(w-3,h-1),Vector2(3,h-1),Vector2(1,floorf(h/2))]),Color("aa986b"))
	draw_rect(Rect2(3,1,inner,h-2),Color("0a1d1d"))
	draw_rect(Rect2(3,h-2,inner,1),Color("162c2b"))
	if ghost > fill:
		draw_rect(Rect2(3+fill,2,ghost-fill,h-4),tint.lerp(Color.WHITE,0.55))
	if fill <= 0: return
	var body := tint
	if value < 25.0: body = tint.lerp(Color.WHITE,0.22*(0.5+0.5*sin(_clock*10.0)))
	var rows := h-4
	draw_rect(Rect2(3,2,fill,rows),body.darkened(0.28))
	draw_rect(Rect2(3,2,fill,ceilf(rows/2.0)),body)
	draw_rect(Rect2(3,2,fill,1),body.lightened(0.45))
	# Facets: a dark cleavage every tenth, lit on its left side.
	for i in range(1,10):
		var x := 3+floorf(inner*i/10.0)
		if x >= 3+fill-1: break
		draw_rect(Rect2(x,3,1,rows-1),body.darkened(0.5))
		draw_rect(Rect2(x-1,3,1,1),body.lightened(0.3))
	# The leading edge catches the light.
	draw_rect(Rect2(3+fill-1,2,1,rows),body.lightened(0.3))
