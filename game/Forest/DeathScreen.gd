extends CanvasLayer
## The scene keeps ticking the countdown; this layer captures all game input.
var spawn_name := "THE FIRST CAMP"
var countdown: Label

func _ready():
	layer = 80
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.055,0.06,0.87)
	shade.size = Vector2(480,270)
	add_child(shade)
	var frame := preload("res://UI/CrystalFrame.gd").new()
	frame.position = Vector2(82,64)
	frame.size = Vector2(316,145)
	add_child(frame)
	_label("THE WILDS REMEMBER",Vector2(95,80),Vector2(290,26),19,true)
	_label("Your journey continues. Your satchel is safe.",Vector2(95,114),Vector2(290,20),11)
	_label("AWAKENING AT " + spawn_name,Vector2(95,143),Vector2(290,16),10)
	countdown = _label("5",Vector2(95,162),Vector2(290,30),24,true)

func _label(text: String, at: Vector2, extent: Vector2, size: int, heading := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",preload("res://Forest/fonts/IMFellEnglish.ttf") if heading else preload("res://Forest/fonts/Tiny5-Regular.ttf"))
	label.add_theme_font_size_override("font_size",size if heading else 8)
	label.add_theme_color_override("font_shadow_color",Color(0.08,0.05,0.03,0.92))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	label.add_theme_color_override("font_color",Color("ead7ae") if heading else Color("aad4bf"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func set_countdown(seconds: float):
	if is_instance_valid(countdown): countdown.text = str(maxi(1,ceili(seconds)))
