extends Button
## Small stitched hide tags bound to a Sky-Fang crystal. Original vector UI art.
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
	var w := size.x
	var h := size.y
	var hover := is_hovered() or has_focus()
	var shift := 1 if is_pressed() else 0
	var shape := PackedVector2Array([Vector2(13,2),Vector2(w-6,2),Vector2(w-2,5),Vector2(w-5,h-4),Vector2(w-10,h-1),Vector2(14,h-2),Vector2(7,h/2)])
	draw_colored_polygon(shape,Color("a08c5d") if hover else Color("725e42"))
	var hide := PackedVector2Array([Vector2(16,4),Vector2(w-8,4),Vector2(w-4,6),Vector2(w-7,h-5),Vector2(w-11,h-3),Vector2(16,h-4),Vector2(11,h/2)])
	draw_colored_polygon(hide,Color("385346") if hover else Color("273d34"))
	for x in range(21,int(w)-12,7):
		draw_line(Vector2(x,4),Vector2(x+2,5),Color("92845e"))
		draw_line(Vector2(x,h-5),Vector2(x+2,h-4),Color("68583e"))
	var center := Vector2(11,h/2+shift)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-9),center+Vector2(10,0),center+Vector2(0,9),center+Vector2(-10,0)]),Color("816b48"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-7),center+Vector2(8,0),center+Vector2(0,7),center+Vector2(-8,0)]),Color("357c75") if hover else Color("285950"))
	draw_line(center+Vector2(-7,0),center+Vector2(0,-6),Color("b9e3c2"))
	draw_line(center+Vector2(0,6),center+Vector2(7,0),Color("153c3d"))
	var key_size := _font.get_string_size(key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8)
	var key_at := Vector2(roundf(center.x-key_size.x/2),floorf(center.y)+3)
	draw_string(_font,key_at+Vector2(1,1),key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("0b2324"))
	draw_string(_font,key_at,key_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("f4ffe9"))
	var caption_at := Vector2(26,floorf(h/2)+3+shift)
	draw_string(_font,caption_at+Vector2(1,1),caption,HORIZONTAL_ALIGNMENT_LEFT,w-29,8,Color("0b1c1d"))
	draw_string(_font,caption_at,caption,HORIZONTAL_ALIGNMENT_LEFT,w-29,8,Color("f6ffea") if hover else Color("f0dfb7"))
