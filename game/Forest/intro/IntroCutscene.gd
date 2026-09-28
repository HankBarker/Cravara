extends CanvasLayer
## The opening of a new journey, after the keeper is made: painted plates of
## how the wilds came to be, a line of narration under each, the Cravara theme
## beneath it all, then a fade to the first camp, where the keeper wakes in the
## tent. Space, Enter or a click shows the whole line or moves on; holding Esc
## skips it. The world waits (paused) until it's over; `finished` fires once.
##
## Lore it keeps to: Forest/world/Lore.gd (the carvings) and Folk.gd (Orrin).
const UI = preload("res://UI/SkyfangUI.gd")
const FRAME = preload("res://UI/CrystalFrame.gd")
const ART := "res://Forest/intro/art/"
const MUSIC := "res://Forest/audio/cravara-ost.mp3"
const PLATES := [
	{"art": "01-green", "fx": "motes", "text": "Long ago the wilds were green and quiet, and the beasts were smaller. Gentler."},
	{"art": "02-fall", "fx": "meteors", "text": "Then, in a single night, the Sky-Fangs fell, like hail made of stars."},
	{"art": "03-crystal", "fx": "motes", "text": "Where they struck, crystal grew: through stone, through root, through living bone."},
	{"art": "04-beasts", "fx": "", "text": "And the beasts began to change. The crystal-backed ones no longer sleep."},
	{"art": "05-tribe", "fx": "embers", "text": "The old tribe did not flee. They listened, and chose a Keeper: one who spoke for the beasts."},
	{"art": "06-north", "fx": "", "text": "The last Keeper went north, past the Pale Hills. No Keeper has been seen since."},
	{"art": "07-carving", "fx": "motes", "text": "Their carvings still say it: WHAT FALLS FROM THE SKY MUST BE KEPT."},
	{"art": "08-star", "fx": "star", "text": "Long after, on a still night, one more star fell."},
]
## Where each painting sits (they're 400x224, shown pixel for pixel).
const PLATE := Rect2(40, 8, 400, 224)
const REVEAL := 34.0
const HOLD := 2.8
const FADE := 1.0
const SKIP_HOLD := 1.0

signal finished
var _index := -1
var _state := ""
var _t := 0.0
var _clock := 0.0
var _reveal := 0.0
var _skip := 0.0
var _done := false
var _root: Control
var _plate: TextureRect
var _fx: Control
var _veil: ColorRect
var _words: Label
var _hint: Label
var _rng := RandomNumberGenerator.new()
var _meteors: Array = []


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 17
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UI.theme()
	add_child(_root)
	var night := ColorRect.new()
	night.color = Color("07090d")
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(night)
	var frame := FRAME.new()
	frame.compact = true
	frame.position = PLATE.position - Vector2(4, 4)
	frame.size = PLATE.size + Vector2(8, 8)
	_root.add_child(frame)
	_plate = TextureRect.new()
	_plate.position = PLATE.position
	_plate.size = PLATE.size
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_plate)
	_fx = Control.new()
	_fx.position = PLATE.position
	_fx.size = PLATE.size
	_fx.clip_contents = true
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)
	_veil = ColorRect.new()
	_veil.color = Color("07090d")
	_veil.position = PLATE.position - Vector2(4, 4)
	_veil.size = PLATE.size + Vector2(8, 8)
	_root.add_child(_veil)
	_words = Label.new()
	_words.position = Vector2(34, 238)
	_words.size = Vector2(412, 30)
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.style_title(_words, 11, UI.PAPER)
	_root.add_child(_words)
	_hint = Label.new()
	_hint.text = "Hold Esc to skip"
	_hint.add_theme_color_override("font_color", UI.DIM)
	_hint.position = Vector2(392, 258)
	_root.add_child(_hint)
	AudioManager.play_music(MUSIC)
	_next()


func _next() -> void:
	_index += 1
	if _index >= PLATES.size():
		_finish()
		return
	var plate: Dictionary = PLATES[_index]
	var path: String = ART + str(plate.art) + ".png"
	_plate.texture = load(path) if ResourceLoader.exists(path) else null
	_words.text = str(plate.text)
	_words.visible_characters = 0
	_reveal = 0.0
	_meteors.clear()
	_state = "fade_in"
	_t = 0.0


func _finish() -> void:
	if _done: return
	_done = true
	finished.emit()


func _process(delta: float) -> void:
	if _done: return
	_clock += delta
	_t += delta
	match _state:
		"fade_in":
			_veil.modulate.a = 1.0 - clampf(_t / FADE, 0.0, 1.0)
			if _t >= FADE * 0.6: _state = "reveal"
		"reveal":
			_veil.modulate.a = maxf(0.0, _veil.modulate.a - delta / FADE)
			_reveal += delta * REVEAL
			_words.visible_characters = int(_reveal)
			if _words.visible_characters >= _words.text.length():
				_words.visible_ratio = 1.0
				_state = "hold"
				_t = 0.0
		"hold":
			_veil.modulate.a = maxf(0.0, _veil.modulate.a - delta / FADE)
			if _t >= HOLD: _begin_fade_out()
		"fade_out":
			_veil.modulate.a = clampf(_t / FADE, 0.0, 1.0)
			_words.modulate.a = 1.0 - _veil.modulate.a
			if _t >= FADE:
				_words.modulate.a = 1.0
				_next()
	if Input.is_key_pressed(KEY_ESCAPE):
		_skip += delta
		_hint.text = "Skipping..."
		if _skip >= SKIP_HOLD: _finish()
	else:
		_skip = 0.0
		_hint.text = "Hold Esc to skip"
	_fx.queue_redraw()


func _begin_fade_out() -> void:
	_state = "fade_out"
	_t = 0.0


func _input(event: InputEvent) -> void:
	if _done: return
	# While the story plays nothing else hears the keys (Esc would otherwise
	# open the pause menu under it); holding Esc to skip reads the key itself.
	if event is InputEventKey or event is InputEventMouseButton: get_viewport().set_input_as_handled()
	var go := false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]: go = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: go = true
	if not go: return
	match _state:
		"fade_in", "reveal":
			_words.visible_ratio = 1.0
			_reveal = _words.text.length()
			_state = "hold"
			_t = 0.0
		"hold":
			_begin_fade_out()


# --- a little life on each painting --------------------------------------------

func _draw_fx() -> void:
	if _index < 0 or _index >= PLATES.size(): return
	match str(PLATES[_index].fx):
		"meteors": _draw_meteors()
		"star": _draw_last_star()
		"motes": _draw_drift(Color("8fd4d6"), -6.0)
		"embers": _draw_drift(Color("e88a2e"), -14.0)


## Sky-Fangs streaking down, each with a fading tail.
func _draw_meteors() -> void:
	if _meteors.size() < 7 and _rng.randf() < 0.08:
		_meteors.append({"p": Vector2(_rng.randf_range(60, 460), _rng.randf_range(-20, 20)), "v": Vector2(-_rng.randf_range(70, 110), _rng.randf_range(90, 140)), "life": 0.0, "span": _rng.randf_range(1.2, 2.0)})
	var alive: Array = []
	for m in _meteors:
		m.life += get_process_delta_time()
		if m.life > m.span: continue
		alive.append(m)
		var head: Vector2 = m.p + m.v * m.life
		var fade: float = 1.0 - m.life / m.span
		for i in 14:
			var back: Vector2 = head - m.v.normalized() * i * 2.0
			draw_rect_fx(back.round(), Color(0.56, 0.9, 1.0, fade * (1.0 - i / 14.0)))
		draw_rect_fx(head.round(), Color(1, 1, 1, fade))
	_meteors = alive


## The last star (painted in): its head pulses as it falls, then a soft flash
## as it comes down beyond the trees.
const STAR_HEAD := Vector2(153, 74)
func _draw_last_star() -> void:
	var t := _clock - _plate_started()
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	for r in range(9, 0, -1):
		_fx.draw_circle(STAR_HEAD, r * (1.0 + 0.15 * pulse), Color(1.0, 0.85, 0.55, 0.05 + 0.03 * pulse))
	if t > 3.4:
		var flash := clampf(1.0 - (t - 3.4) / 1.4, 0.0, 1.0)
		_fx.draw_rect(Rect2(Vector2.ZERO, PLATE.size), Color(1.0, 0.92, 0.75, flash * 0.3))


## Specks drifting up through the painting (crystal motes, or embers).
func _draw_drift(tint: Color, speed: float) -> void:
	for i in 26:
		var seed_x := float(posmod(hash(Vector2i(i, _index)), 400))
		var seed_y := float(posmod(hash(Vector2i(i * 7, _index)), 224))
		var y := fposmod(seed_y + _clock * speed * (0.6 + (i % 5) * 0.15), 224.0)
		var x := seed_x + sin(_clock * 0.7 + i) * 3.0
		var a := 0.35 + 0.35 * sin(_clock * 2.0 + i * 1.7)
		draw_rect_fx(Vector2(x, y).round(), Color(tint, a))


func draw_rect_fx(at: Vector2, color: Color) -> void:
	_fx.draw_rect(Rect2(at, Vector2.ONE), color)


var _started_at := {}
func _plate_started() -> float:
	if not _started_at.has(_index): _started_at[_index] = _clock
	return _started_at[_index]
