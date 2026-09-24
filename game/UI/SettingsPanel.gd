extends CanvasLayer
## Reusable from title or pause. Caller owns pause state; changes preview live.
signal closed
var panel: Panel
var controls: Dictionary = {}
var _baseline: Dictionary
var _root: Control

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.size = Vector2(480,270)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.04,0.035,0.85)
	shade.size = Vector2(480,270)
	_root.add_child(shade)
	panel = Panel.new()
	panel.position = Vector2(68,9)
	panel.size = Vector2(344,252)
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_root.add_child(panel)
	var frame := preload("res://UI/CrystalFrame.gd").new()
	frame.size = panel.size
	panel.add_child(frame)
	_root.theme = preload("res://UI/SkyfangUI.gd").theme()
	var title := _label("The Keeper's Settings",Vector2(13,5),16)
	title.add_theme_font_override("font",load("res://Forest/fonts/IMFellEnglish.ttf"))
	_slider("master","Master volume",34,AudioManager.master_volume,AudioManager.set_master_volume)
	_slider("music","Music",57,AudioManager.music_volume,AudioManager.set_music_volume)
	_slider("sfx","Effects",80,AudioManager.sfx_volume,AudioManager.set_sfx_volume)
	_label("Camera follow",Vector2(14,106))
	var camera := OptionButton.new()
	camera.position = Vector2(157,102)
	camera.size = Vector2(169,23)
	camera.add_item("Tight / steady")
	camera.add_item("Smooth / drifting")
	camera.selected = 1 if GameSettings.camera_follow_mode == "smooth" else 0
	camera.item_selected.connect(func(index):GameSettings.set_camera_follow("smooth" if index == 1 else "tight"))
	panel.add_child(camera)
	controls.camera = camera
	_toggle("shadows","World shadows",130,GameSettings.shadows_enabled,GameSettings.set_shadows)
	_toggle("fullscreen","Fullscreen",153,GameSettings.fullscreen,GameSettings.set_fullscreen)
	_toggle("shortcuts","Corner shortcut buttons",176,GameSettings.shortcut_buttons_visible,GameSettings.set_shortcut_buttons)
	_toggle("shake","Screen shake",199,GameSettings.screen_shake,GameSettings.set_screen_shake)
	_button("Save & return",Vector2(14,226),Vector2(195,21),func():_close(true))
	_button("Cancel",Vector2(216,226),Vector2(110,21),func():_close(false))
	hide()

func _label(text: String,pos: Vector2,size: int = 10) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	# Titles in the old hand; the rest in the kit's crisp Tiny5 (theme).
	if size >= 12: preload("res://UI/SkyfangUI.gd").style_title(label,size,Color("eee3c7"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

func _button(text: String,pos: Vector2,size: Vector2,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.pressed.connect(callback)
	panel.add_child(button)
	button.size = size
	return button

func _slider(id: String,label: String,y: int,value: float,callback: Callable) -> void:
	_label(label,Vector2(14,y))
	var slider := HSlider.new()
	slider.position = Vector2(139,y)
	slider.size = Vector2(152,16)
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = value
	panel.add_child(slider)
	var amount := _label("%d%%" % roundi(value*100),Vector2(299,y),9)
	slider.value_changed.connect(func(v):callback.call(v);amount.text="%d%%" % roundi(v*100))
	controls[id] = slider

func _toggle(id: String,label: String,y: int,value: bool,callback: Callable) -> void:
	_label(label,Vector2(14,y+3))
	var button := _button("On" if value else "Off",Vector2(250,y),Vector2(76,21),func():pass)
	button.toggle_mode = true
	button.button_pressed = value
	button.toggled.connect(func(v):button.text="On" if v else "Off";callback.call(v))
	controls[id] = button

func show_settings() -> void:
	_baseline = {"master":AudioManager.master_volume,"music":AudioManager.music_volume,"sfx":AudioManager.sfx_volume,"camera":GameSettings.camera_follow_mode,"shadows":GameSettings.shadows_enabled,"fullscreen":GameSettings.fullscreen,"shortcuts":GameSettings.shortcut_buttons_visible,"shake":GameSettings.screen_shake}
	for key in ["master","music","sfx"]: controls[key].value = _baseline[key]
	controls.camera.select(1 if GameSettings.camera_follow_mode == "smooth" else 0)
	controls.shadows.set_pressed_no_signal(GameSettings.shadows_enabled)
	controls.fullscreen.set_pressed_no_signal(GameSettings.fullscreen)
	controls.shadows.text = "On" if GameSettings.shadows_enabled else "Off"
	controls.fullscreen.text = "On" if GameSettings.fullscreen else "Off"
	controls.shortcuts.set_pressed_no_signal(GameSettings.shortcut_buttons_visible)
	controls.shortcuts.text = "On" if GameSettings.shortcut_buttons_visible else "Off"
	controls.shake.set_pressed_no_signal(GameSettings.screen_shake)
	controls.shake.text = "On" if GameSettings.screen_shake else "Off"
	show()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close(false)
		get_viewport().set_input_as_handled()

func _close(save: bool) -> void:
	if save: GameSettings.save_settings()
	else:
		AudioManager.set_master_volume(_baseline.master)
		AudioManager.set_music_volume(_baseline.music)
		AudioManager.set_sfx_volume(_baseline.sfx)
		GameSettings.set_camera_follow(_baseline.camera)
		GameSettings.set_shadows(_baseline.shadows)
		GameSettings.set_shortcut_buttons(_baseline.shortcuts)
		GameSettings.set_screen_shake(_baseline.shake)
		if GameSettings.fullscreen != _baseline.fullscreen: GameSettings.set_fullscreen(_baseline.fullscreen)
	hide()
	closed.emit()
