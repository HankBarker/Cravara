extends Control

const PLAY_SCENE := "res://Forest/ForestPlaytest.tscn"
const PIXEL_FONT = preload("res://Forest/fonts/IMFellEnglish.ttf")
var _time := 0.0
var _buttons: VBoxContainer
var _details: PanelContainer
var _starting := false
var _creator: CanvasLayer

func _ready():
	SaveManager.disable_for_playtest()
	TimeCycle.paused = true
	get_tree().paused = false
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://Forest/art/skyfang-title.png")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.02, 0.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_label("A WORLD CHANGED BY THE FALL", Vector2(28, 35), 9, Color("d9c79f"))
	_label("CRAVERA", Vector2(25, 43), 36, Color("f4e4b9"), true)
	_label("THE SKYFANG WILDS", Vector2(29, 89), 12, Color("9fd4f0"), true)
	_label("Build a home. Earn their trust.\nFollow the fragments of a fallen sky.", Vector2(29, 112), 9, Color("f2e6c9"))
	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(29, 135)
	_buttons.size.x = 147
	_buttons.add_theme_constant_override("separation", 3)
	add_child(_buttons)
	var has_save := FileAccess.file_exists("user://skyfang_forest_v1.json")
	if has_save:
		_button("CONTINUE JOURNEY", func(): _start(true))
	_button("NEW EXPEDITION", _new_expedition)
	_button("FIELD GUIDE", _show_guide)
	_button("SETTINGS", _show_settings)
	_button("LEAVE THE WILDS", _quit_game)
	_label("FOREST PLAYTEST  /  01", Vector2(29, 252), 8, Color("a8977e"))
	_label("THE FALL OF THE SKY-FANGS", Vector2(324, 252), 8, Color("e4d5b0"))
	AudioManager.play_music("res://Forest/audio/main-theme.mp3")
	var motes := Node2D.new()
	motes.name = "Fireflies"
	motes.draw.connect(_draw_motes)
	add_child(motes)
	_buttons.get_child(0).grab_focus()
	if "--capture-menu" in OS.get_cmdline_user_args():
		_capture()

func _label(text: String, pos: Vector2, font_size: int, color: Color, pixel := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("140c07"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	if pixel:
		label.add_theme_font_override("font", PIXEL_FONT)
	add_child(label)
	return label

func _button(text: String, callback: Callable):
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(147, 19)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color("f2e6c9"))
	for kind in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("2b1e15") if kind == "normal" else Color("4a3321")
		style.bg_color.a = 0.93
		style.border_color = Color("7a5a3c") if kind == "normal" else Color("e8c27a")
		style.set_border_width_all(1)
		style.border_width_left = 3
		style.content_margin_left = 10
		button.add_theme_stylebox_override(kind, style)
	button.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		callback.call())
	_buttons.add_child(button)

func _new_expedition():
	if FileAccess.file_exists("user://skyfang_forest_v1.json"):
		_show_text("START A NEW EXPEDITION", "Your current forest journey will be replaced\nwhen the new expedition is saved.\nThe original playground save is separate.", "CREATE YOUR KEEPER", _show_creator)
	else:
		_show_creator()

func _show_creator():
	_close_details()
	if is_instance_valid(_creator): return
	_creator=preload("res://UI/CharacterCreator.gd").new()
	_creator.configure({},null,true)
	_creator.accepted.connect(func(appearance):
		get_tree().set_meta("forest_appearance",appearance)
		# A new expedition opens with the story of the wilds.
		get_tree().set_meta("forest_intro",true)
		_start(false))
	add_child(_creator)

func _start(continue_save: bool):
	if _starting:
		return
	_starting = true
	get_tree().set_meta("forest_continue", continue_save)
	get_tree().change_scene_to_file(PLAY_SCENE)

func _show_guide():
	_show_text("FIELD GUIDE", "WASD Move    SHIFT Sprint    SPACE Roll    1-8 Tools\nLEFT CLICK Harvest or attack, including on a mount\nRIGHT CLICK Eat, fill vessels, build, or cast a rod\nE Interact, talk, ride or dismount    F Feed your mount\nHold E / Q Companion orders    Q away: group orders\nTAB Satchel / craft    CAPS Next pouch    K Gear\nP Companions / locator    M Map    J Journal    H Folk & houses\nESC Pause / settings    F5 Save\n\nBuild floors, walls, doors and optional thatch roofing.\nTame, equip a stego/trike saddle, then tap E to ride.\nCraft a Hide Bed; press E beside it to set home.\nAfter death, awaken at home in five seconds.\nFish at silver ripples: hold/release SPACE to reel.\nMix armour pieces from six sets; gems glow at night.\nRoast meals for lasting fullness; no energy costs.", "RETURN", _close_details)
func _show_text(title: String, text: String, action: String, callback: Callable):
	_close_details()
	_details = PanelContainer.new()
	_details.position = Vector2(90, 8)
	_details.size = Vector2(300, 218)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22170f")
	style.border_color = Color("b08a55")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_details.add_theme_stylebox_override("panel", style)
	add_child(_details)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_details.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", PIXEL_FONT)
	heading.add_theme_font_size_override("font_size", 16)
	column.add_child(heading)
	var body := Label.new()
	body.text = text
	body.add_theme_font_size_override("font_size", 8)
	body.add_theme_constant_override("line_spacing", -2)
	column.add_child(body)
	var button := Button.new()
	button.text = action
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(callback)
	column.add_child(button)
	if action != "RETURN":
		var cancel := Button.new()
		cancel.text = "KEEP CURRENT JOURNEY"
		cancel.add_theme_font_size_override("font_size", 10)
		cancel.pressed.connect(_close_details)
		column.add_child(cancel)

func _close_details():
	if is_instance_valid(_details):
		_details.queue_free()
		_details = null

func _process(delta):
	_time += delta
	if has_node("Fireflies"):
		$Fireflies.queue_redraw()

func _draw_motes():
	for i in range(20):
		var pos := Vector2(fmod(i * 83.0 + sin(_time * 0.3 + i) * 12, 480), fposmod(i * 37.0 - _time * (2 + i % 3), 270))
		$Fireflies.draw_rect(Rect2(pos.round(), Vector2.ONE), Color(1.0, 0.9, 0.6, 0.2 + 0.45 * absf(sin(_time + i))))

func _capture():
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../art/forest-playtest/menu.png")
	AudioManager.stop_music()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _quit_game():
	AudioManager.stop_music()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _show_settings():
	var settings = preload("res://UI/SettingsPanel.gd").new()
	add_child(settings)
	settings.closed.connect(settings.queue_free)
	settings.show_settings()

