extends CanvasLayer
## Original balance game: feather Space to keep the reed cradle around the fish.
signal finished(won: bool)
signal cancelled
const FRAME = preload("res://UI/CrystalFrame.gd")
var fish: Dictionary
var progress := 0.28
## Seconds before the fish slips the hook (longer with a Long Line).
var _time_limit := 24.0
var cradle := 0.45
var cradle_velocity := 0.0
var fish_position := 0.5
var held := false
var elapsed := 0.0
var waiting := 0.85
var resolved := false
var inside := false
var play_area: Control
var status: Label
var title: Label
var _phase := 0.0
var panel_on_left := true

func configure(profile: Dictionary, seed_value: int, on_left := true):
	fish=profile
	_phase=float(posmod(seed_value,97))/97.0*TAU
	panel_on_left=on_left

func _ready():
	layer=75
	# Fishing stars (pass 14): a wider band to hold the fish in, longer before it slips.
	var sk = get_tree().get_first_node_in_group("skills")
	if sk:
		fish=fish.duplicate()
		fish.cradle=minf(0.3,float(fish.cradle)*(1.0+float(sk.value("fish_cradle"))))
		_time_limit=24.0*(1.0+float(sk.value("fish_time")))
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade:=ColorRect.new()
	shade.color=Color(0.06,0.04,0.02,0.43)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var origin:=Vector2(8 if panel_on_left else 256,24)
	var frame:=FRAME.new()
	frame.position=origin
	frame.size=Vector2(216,222)
	root.add_child(frame)
	root.theme=preload("res://UI/SkyfangUI.gd").theme()
	title=_label(root,"RIVER FISHING",origin+Vector2(14,8),13)
	title.add_theme_font_override("font",preload("res://UI/SkyfangUI.gd").title_font())
	title.add_theme_color_override("font_color",Color("dcc085"))
	_label(root,str(fish.name),origin+Vector2(94,48),12)
	_label(root,str(fish.difficulty)+" current",origin+Vector2(94,65),9)
	_label(root,"Hold SPACE to lift.\nRelease to fall.\n\nKeep the fish in\nthe green cradle.\nFill the catch bar.",origin+Vector2(94,90),9)
	status=_label(root,"A ripple gathers around your line...",origin+Vector2(14,179),8)
	_label(root,"Esc / right-click: reel in & leave",origin+Vector2(14,201),8)
	play_area=Control.new()
	play_area.position=origin+Vector2(12,42)
	play_area.size=Vector2(78,129)
	play_area.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(play_area)
	play_area.draw.connect(_draw_track)
	var close:=Button.new()
	close.text="X"
	close.position=origin+Vector2(184,8)
	close.size=Vector2(18,17)
	for state in ["normal","hover","pressed","focus"]:
		var style:=_rim()
		style.set_content_margin_all(0)
		if state=="hover": style.bg_color=Color("4a3321")
		close.add_theme_stylebox_override(state,style)
	close.pressed.connect(_cancel)
	root.add_child(close)
	close.size=Vector2(18,17)

func _notification(what: int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: held=false

func _label(parent: Control, text: String, pos: Vector2, font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.position=pos
	# Names in the old hand; instructions in the kit's crisp Tiny5.
	if font_size>=12: preload("res://UI/SkyfangUI.gd").style_title(label,font_size,Color("eee3c7"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _input(event: InputEvent):
	if resolved: return
	if event is InputEventKey:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if key==KEY_SPACE:
			held=event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.echo and key in [KEY_ESCAPE,KEY_TAB,KEY_K,KEY_P,KEY_J]:
			_cancel()
			get_viewport().set_input_as_handled()
		# The complete fishing modal owns keyboard input; numeric hotbar bindings
		# are handled by HUD _unhandled_input and otherwise slip past its guard.
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		_cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()

func _cancel():
	if resolved: return
	resolved=true
	held=false
	cancelled.emit()

func _process(delta: float):
	if resolved: return
	if waiting>0:
		waiting=maxf(0,waiting-delta)
		play_area.queue_redraw()
		return
	elapsed+=delta
	cradle_velocity=move_toward(cradle_velocity,0.64 if held else -0.50,2.6*delta)
	cradle=clampf(cradle+cradle_velocity*delta,float(fish.cradle),1.0-float(fish.cradle))
	if cradle<=float(fish.cradle) or cradle>=1-float(fish.cradle): cradle_velocity*=0.35
	fish_position=clampf(0.50+sin(elapsed*float(fish.speed)+_phase)*float(fish.range)+sin(elapsed*float(fish.speed)*2.3+_phase)*float(fish.dart),0.08,0.92)
	inside=absf(cradle-fish_position)<=float(fish.cradle)
	# A Mirefang Tooth, a Bog-iron Band (pass 14): the fish tires sooner.
	var knack: float = preload("res://Forest/items/Trinkets.gd").of(get_tree(), "fishing")
	progress=clampf(progress+(float(fish.gain)*(1.0+knack) if inside else -float(fish.loss)*(1.0-knack*0.5))*delta,0,1)
	status.text="Steady hands... %d%%" % int(progress*100) if inside else "The fish is slipping away... %d%%" % int(progress*100)
	play_area.queue_redraw()
	if progress>=1 or progress<=0 or elapsed>=_time_limit:
		resolved=true
		held=false
		finished.emit(progress>=1)

func _draw_track():
	play_area.draw_style_box(_rim(),Rect2(4,0,42,129))
	play_area.draw_rect(Rect2(8,4,34,121),Color("12383e"))
	for y in range(10,121,12):
		play_area.draw_line(Vector2(9,y),Vector2(15,y),Color("39626a"))
		play_area.draw_line(Vector2(35,y+4),Vector2(40,y+4),Color("285359"))
	var h: float=float(fish.cradle)*2*116
	var cradle_y: float=7+(1-cradle)*116-h/2
	play_area.draw_rect(Rect2(10,roundf(cradle_y),30,roundf(h)),Color("c9a063") if inside else Color("8a6d45"))
	play_area.draw_rect(Rect2(10,roundf(cradle_y),30,roundf(h)),Color("f2e6c9"),false)
	var icon: Texture2D=ItemDB.get_prototype(str(fish.id)).icon
	var y: float=7+(1-fish_position)*116
	play_area.draw_texture_rect(icon,Rect2(14,roundf(y)-6,23,12),false,Color(1,1,1,0.45 if waiting>0 else 1))
	play_area.draw_style_box(_rim(),Rect2(57,0,14,129))
	play_area.draw_rect(Rect2(60,4,8,121),Color("2a1d13"))
	play_area.draw_rect(Rect2(60,125-roundf(progress*121),8,roundf(progress*121)),Color("d0b46d"))
	for notch in [30,60,90]: play_area.draw_line(Vector2(59,notch),Vector2(69,notch),Color("8a6d45"))

func _rim() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("22170f")
	style.border_color=Color("b79e69")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.corner_detail=1
	return style
