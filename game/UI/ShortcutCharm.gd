extends Button
## Small stitched leather tags set with a Sky-Fang crystal. Original vector UI art.
var caption := "Satchel"
var key_hint := "Tab"
var _font: Font

func _ready() -> void:
	# The interface kit's crisp pixel text (Tiny5 at its 8px size).
	_font = load("res://Forest/fonts/Tiny5-Regular.ttf")
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	tooltip_text = "%s [%s]" % [caption,key_hint]

func _draw() -> void:
	# Pass 14: a leather tag on a brass-set sky crystal (no more green).
	var w := size.x
	var h := size.y
	var hover := is_hovered() or has_focus()
	var shift := 1 if is_pressed() else 0
	var shape := PackedVector2Array([Vector2(13,2),Vector2(w-6,2),Vector2(w-2,5),Vector2(w-5,h-4),Vector2(w-10,h-1),Vector2(14,h-2),Vector2(7,h/2)])
	draw_colored_polygon(shape,Color("b08a55") if hover else Color("7a5a3c"))
	var hide := PackedVector2Array([Vector2(16,4),Vector2(w-8,4),Vector2(w-4,6),Vector2(w-7,h-5),Vector2(w-11,h-3),Vector2(16,h-4),Vector2(11,h/2)])
	draw_colored_polygon(hide,Color(0.29,0.2,0.13,0.94) if hover else Color(0.2,0.135,0.085,0.9))
	for x in range(21,int(w)-12,7):
		draw_line(Vector2(x,4),Vector2(x+2,5),Color("a88a5c"))
		draw_line(Vector2(x,h-5),Vector2(x+2,h-4),Color("5e4630"))
	var center := Vector2(11,h/2+shift)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-9),center+Vector2(10,0),center+Vector2(0,9),center+Vector2(-10,0)]),Color("c9a063"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-7),center+Vector2(8,0),center+Vector2(0,7),center+Vector2(-8,0)]),Color("3f6f8c") if hover else Color("2d4a5e"))
	draw_line(center+Vector2(-7,0),center+Vector2(0,-6),Color("cfe9f7"))
	draw_line(center+Vector2(0,6),center+Vector2(7,0),Color("14222b"))
	var key_size := _font.get_string_size(key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8)
	var key_at := Vector2(roundf(center.x-key_size.x/2),floorf(center.y)+3)
	draw_string(_font,key_at+Vector2(1,1),key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("140c07"))
	draw_string(_font,key_at,key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("f2e6c9"))
	var caption_at := Vector2(26,floorf(h/2)+3+shift)
	draw_string(_font,caption_at+Vector2(1,1),caption,HORIZONTAL_ALIGNMENT_LEFT,w-29,8,Color("140c07"))
	draw_string(_font,caption_at,caption,HORIZONTAL_ALIGNMENT_LEFT,w-29,8,Color("e8c27a") if hover else Color("f2e6c9"))
