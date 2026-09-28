extends Control
## The field map (M): the wilds from a picture of them, coloured by region and
## ground: forest greens, the Bonelands' and the dunes' sand, the Pale Hills'
## chalk, shallows and deep water, paths. Over it: the bosses and their dens
## (red), caves, ruins (gold), villages, the keeper's camp, their beasts, the
## great roaming beasts (orange), nests (cream), wild animals, the folk
## (violet) and the keeper (yellow).
##
## Pass 15: the picture keeps the world's shape (a ring world is square), with
## the small places tinted in (the red meadow, the bog's haven, the oases) and
## the caves' mouths marked; underground, the keeper shows at the mouth they
## went in by.
##
## Pass 16 (Hank: "like a Terraria... when you start the map off, it's just
## your location, and as you move around the map more, more things appear...
## unless it's a big point of interest, like a boss... have the capability to
## turn on and off which points of interest pop up on the map"):
##  - the night lies over all the keeper hasn't seen (world/MapMemory.gd), and
##    a mark shows only where they have, but for the bosses, the events under
##    way and what a parasaur heard;
##  - each kind of mark can be hidden (the key: click a line, or its number);
##  - the wheel (or +/-) zooms, a drag (or WASD/arrows) moves it, C finds the
##    keeper again. A streamed world's picture is MapMemory's, a chunk at a
##    time; the others' is painted here when the map opens.
##
## Pass 17 (Hank: "we could add in icons for everything instead of it being,
## like, just little dots... so I can add my own icons, and then those own
## icons I can name as well"):
##  - every mark is a little icon (ICONS: 9 x 9 pixel drawings, made into one
##    strip the first time a map opens): a skull for a boss, a cave's door,
##    a temple for ruins, a hut for a village, a tent for the keeper's camp,
##    a nest with its eggs, a paw for a beast, a star for the keeper...; zoomed
##    far out, the small things (nests, wild beasts, old buildings) are dots;
##  - the keeper's own pins: right-click the map to set one, click one to pick
##    it; the key names it and changes its icon and colour, or takes it away.
##    They're the session's (`pins`: saved with the journey).
const Regions = preload("res://Forest/world/Regions.gd")
const FOG = preload("res://UI/map_fog.gdshader")
## The small places' tints over their land.
const MICRO_TINT := {"red_meadow": Color("9a4038"), "haven": Color("6f9a5e"), "oasis": Color("3f8f78")}
## A cave's mouth: a dark door in a pale stone rim (the key draws it the same).
const CAVE := Color("d8dce0")
const CAVE_DARK := Color("16121c")
## The Bonelands' sand on the map: rustier than the dunes' gold.
const BONE_SAND := Color("8c6a4c")
const NIGHT := Color("0b252c")
const OUTLINE := Color("2e241f")
## The marks the keeper may hide, in the key's order: [kind, words, colour, icon].
const KINDS := [
	["bosses", "Bosses", Color("d0503c"), "skull"],
	["caves", "Caves", Color("d8dce0"), "cave"],
	["ruins", "Ruins", Color("e8d49a"), "ruin"],
	["villages", "Villages", Color("5ec8c0"), "hut"],
	["home", "Your camp", Color("bca276"), "home"],
	["tamed", "Your beasts", Color("8fd18a"), "paw"],
	["beasts", "Great beasts", Color("f0a040"), "claw"],
	["nests", "Nests", Color("f2e6c8"), "nest"],
	["wild", "Wild animals", Color("d9dac2"), "wild"],
	["folk", "Folk", Color("c9a8f0"), "person"],
	["buildings", "Old places", Color("b09a7c"), "house"],
	["pins", "Your pins", Color("ffd166"), "flag"],
]
## Pass 17: the marks' icons, 9 x 9 (a letter a colour: PALETTE; "." clear).
const ICONS := {
	"skull": ["..ooooo..", ".oRRRRRo.", "oRRRRRRRo", "oRkkRkkRo", "oRkkRkkRo", "oRRRkRRRo", ".oRRRRRo.", "..oRoRo..", "...o.o..."],
	"cave": ["..ooooo..", ".oSSSSSo.", "oSSkkkSSo", "oSkkkkkSo", "oSkkkkkSo", "oSkkkkkSo", "oskkkkkso", "ooooooooo", "........."],
	"ruin": ["....o....", "..ooGoo..", ".oGGGGGo.", "ooooooooo", ".oGoGoGo.", ".oGoGoGo.", ".oGoGoGo.", "ooooooooo", "ogggggggo"],
	"hut": ["....o....", "...oTo...", "..oTTTo..", ".oTTTTTo.", "ooooooooo", ".oWWWWWo.", ".oWWkWWo.", ".oWWkWWo.", ".ooooooo."],
	"hut_red": ["....o....", "...oRo...", "..oRRRo..", ".oRRRRRo.", "ooooooooo", ".oWWWWWo.", ".oWWkWWo.", ".oWWkWWo.", ".ooooooo."],
	"home": ["....o....", "...oHo...", "..oHHHo..", "..oHkHo..", ".oHHkHHo.", ".oHkkkHo.", "oHHkkkHHo", "ooooooooo", "........."],
	"house": [".........", "....oo...", "...oDDo..", "..oDDDDo.", ".ooooooo.", ".oLkoLLo.", ".oLkoLLo.", ".oLLoLLo.", ".ooooooo."],
	"tent": [".........", "....o....", "...oBo...", "..oBBBo..", "..oBkBo..", ".oBBkBBo.", ".oBkkkBo.", "ooooooooo", "........."],
	"paw": [".........", "..o.o.o..", ".oNoNoNo.", "..o.o.o..", "...ooo...", "..oNNNo..", ".oNNNNNo.", "..ooooo..", "........."],
	"wild": [".........", "..o.o.o..", ".oLoLoLo.", "..o.o.o..", "...ooo...", "..oLLLo..", "..ooooo..", ".........", "........."],
	"claw": ["....o....", "...oOo...", "...oOo...", "..oOkOo..", "..oOkOo..", ".oOOkOOo.", ".oOOOOOo.", "oOOOkOOOo", "ooooooooo"],
	"nest": [".........", "..oo.oo..", ".oEEoEEo.", ".oEEoEEo.", "oBoooooBo", "oBBBBBBBo", ".oBBBBBo.", "..ooooo..", "........."],
	"person": ["...ooo...", "..oVVVo..", "..oVVVo..", "...ooo...", ".ooVVVoo.", "oVVVVVVVo", ".ooVVVoo.", "..oVoVo..", "..oo.oo.."],
	"fin": [".........", ".....o...", "....oRo..", "...oRRo..", "..oRRRo..", ".oRRRRo..", "oRRRRRRo.", "ooooooooo", "........."],
	"you": ["....o....", "...oYo...", "ooooYoooo", "oYYYYYYYo", ".oYYYYYo.", "..oYYYo..", ".oYYoYYo.", ".oYo.oYo.", ".oo...oo."],
	"crystal": ["....o....", "...oCo...", "..oCCCo..", "..oCWCo..", "..oCCCo..", "..oCCCo..", "...oCo...", "....o....", "........."],
	"flame": ["....o....", "...oFo...", "...oFFo..", "..oFYFo..", ".oFYYFo..", ".oFYYYFo.", ".oFFYFFo.", "..ooooo..", "........."],
	"heard": [".........", "....o....", "...oAo...", "..oAAAo..", ".oAAAAAo.", "..oAAAo..", "...oAo...", "....o....", "........."],
	# The keeper's pins: drawn white, tinted with the pin's colour.
	"flag": [".oo......", ".oPoooo..", ".oPPPPPo.", ".oPPPPPo.", ".oPPPPo..", ".oPoooo..", ".oo......", ".oo......", "oooo....."],
	"star": ["....o....", "...oPo...", "ooooPoooo", "oPPPPPPPo", ".oPPPPPo.", "..oPPPo..", ".oPPoPPo.", ".oPo.oPo.", ".oo...oo."],
	"cross": ["oo.....oo", "oPo...oPo", ".oPo.oPo.", "..oPoPo..", "...oPo...", "..oPoPo..", ".oPo.oPo.", "oPo...oPo", "oo.....oo"],
	"pin_house": ["....o....", "...oPo...", "..oPPPo..", ".oPPPPPo.", "ooooooooo", ".oPPPPPo.", ".oPPkPPo.", ".oPPkPPo.", ".ooooooo."],
	"pin_skull": ["..ooooo..", ".oPPPPPo.", "oPPPPPPPo", "oPkkPkkPo", "oPkkPkkPo", "oPPPkPPPo", ".oPPPPPo.", "..oPoPo..", "...o.o..."],
	"chest": [".........", ".ooooooo.", "oPPPPPPPo", "oPPPkPPPo", "ooooooooo", "oPPPkPPPo", "oPPPPPPPo", "ooooooooo", "........."],
}
const PALETTE := {"o": Color("1c1612"), "k": Color("2a2230"), "W": Color("f2e8d0"), "R": Color("d0503c"), "S": Color("d8dce0"),
	"s": Color("9aa0a8"), "G": Color("e8d49a"), "g": Color("a88c50"), "T": Color("5ec8c0"), "H": Color("bca276"), "N": Color("8fd18a"),
	"O": Color("f0a040"), "E": Color("f2e6c8"), "B": Color("8a6440"), "V": Color("c9a8f0"), "Y": Color("ffe199"), "C": Color("7fe6ff"),
	"F": Color("ff7a2a"), "L": Color("d9dac2"), "D": Color("b09a7c"), "A": Color("f2c84b"), "P": Color("ffffff")}
## The pins' icons and colours, in the order the key's buttons step through them.
const PIN_ICONS := ["flag", "star", "cross", "pin_house", "pin_skull", "chest"]
const PIN_COLOURS := [Color("ffd166"), Color("e0605a"), Color("7fe6ff"), Color("8fd18a"), Color("c9a8f0"), Color("f2e8d0")]
## Zoomed out past this (px a cell), the small things are dots.
const DOTS_BELOW := 0.35
static var _atlas: ImageTexture
static var _slot := {}
## What a keeper keeps at their camp, marked as it.
const HOME_KINDS := ["workbench", "tent", "hide_bed", "campfire", "chest", "cooking_pot", "incubator", "folk_hut"]
## Hidden kinds (kind -> true): the session's, saved with the journey.
var hidden_kinds := {}
## Pass 17: the keeper's pins ([{x, y, name, icon, colour}]), the session's
## (saved with the journey), and the one picked (-1: none).
var pins: Array = []
var picked := -1
var _press_at := Vector2.INF
var _editor: Control
var _pin_name: LineEdit
## Pixels a cell (0 until the first opening), kept between openings.
static var zoom := 0.0

var world: Node2D
var player: Node2D
var _bounds := Rect2i()
## The picture, and how many cells each of its pixels is.
var _picture: Texture2D
var _pic_scale := 1
var _fog_tex: ImageTexture
var _fog: Control
var _marks: Control
## The view's middle (cells).
var _centre := Vector2.ZERO
var _drag_from := Vector2.INF
var _key_lines := {}
## The last picture painted here (a world not streamed), kept a little while
## (a ring world's is 420 x 420 cells: opening the map twice in a row
## shouldn't paint it twice).
static var _kept := {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fog = Control.new()
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fog_look := ShaderMaterial.new()
	fog_look.shader = FOG
	fog_look.set_shader_parameter("night", NIGHT)
	_fog.material = fog_look
	add_child(_fog)
	_fog.draw.connect(_draw_fog)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	_marks.draw.connect(_draw_marks)
	resized.connect(_fit_layers)
	_fit_layers()
	find_keeper()


func _fit_layers() -> void:
	for layer in [_fog, _marks]:
		if layer:
			layer.position = Vector2.ZERO
			layer.size = size
	_clamp_view()
	queue_redraw_all()


func queue_redraw_all() -> void:
	queue_redraw()
	if _fog: _fog.queue_redraw()
	if _marks: _marks.queue_redraw()


# ------------------------------------------------------------------ the view

## The view back on the keeper (underground: the mouth they went in by).
func find_keeper() -> void:
	_centre = _keeper_at() / 16.0
	_clamp_view()
	queue_redraw_all()


func _keeper_at() -> Vector2:
	if not is_instance_valid(player): return Vector2.ZERO
	var at: Vector2 = player.global_position
	var caves = world.get("caves") if world else null
	if caves:
		var below: Dictionary = caves.cave_at(world.to_cell(at))
		if not below.is_empty() and below.mouth != Vector2i(9999, 9999): at = Vector2(below.mouth) * 16 + Vector2(8, 8)
	return at


## The zoom that shows the whole world, and the closest.
func _fit_zoom() -> float:
	var b := _world_bounds()
	if size.x <= 0.0 or size.y <= 0.0: return 1.0
	return minf(size.x / float(b.size.x), size.y / float(b.size.y))


func _max_zoom() -> float:
	return 4.0


func _world_bounds() -> Rect2i:
	if _bounds.has_area(): return _bounds
	_bounds = world.bounds() if world and world.has_method("bounds") else Rect2i(-56, -56, 112, 112)
	return _bounds


func _clamp_view() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	var b := _world_bounds()
	var fit := _fit_zoom()
	if zoom <= 0.0:
		# A first look: the lands round the keeper (a small world whole).
		zoom = clampf(size.y / 260.0, fit, _max_zoom()) if b.size.x > 600 else fit
	zoom = clampf(zoom, fit, _max_zoom())
	# The view keeps some of the world in it.
	var half := size / zoom * 0.5
	var lo := Vector2(b.position) + half * 0.2
	var hi := Vector2(b.end) - half * 0.2
	_centre = Vector2(clampf(_centre.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)), clampf(_centre.y, minf(lo.y, hi.y), maxf(lo.y, hi.y)))


## A world point (px) on the map.
func to_view(world_px: Vector2) -> Vector2:
	return (world_px / 16.0 - _centre) * zoom + size * 0.5


## The cell under a point of the map.
func to_cell_at(view: Vector2) -> Vector2i:
	return Vector2i(((view - size * 0.5) / zoom + _centre).floor())


# ------------------------------------------------------------------ pins (pass 17)

## A new pin at a cell (named for its number), picked for naming.
func add_pin(cell: Vector2i) -> int:
	if not _world_bounds().has_point(cell): return -1
	pins.append({"x": cell.x, "y": cell.y, "name": "Pin %d" % (pins.size() + 1), "icon": 0, "colour": 0})
	hidden_kinds.erase("pins")
	_style_key_line("pins")
	pick(pins.size() - 1)
	if is_instance_valid(_pin_name):
		_pin_name.grab_focus()
		_pin_name.select_all()
	return pins.size() - 1


## The pin whose icon is under a point of the map, or -1.
func pin_at(view: Vector2) -> int:
	for i in range(pins.size() - 1, -1, -1):
		if to_view(_cell_px(_pin_cell(i))).distance_to(view) <= 6.0: return i
	return -1


func _pin_cell(i: int) -> Vector2i:
	return Vector2i(int(pins[i].x), int(pins[i].y))


func pick(i: int) -> void:
	picked = i if i >= 0 and i < pins.size() else -1
	_show_editor()
	queue_redraw_all()


func rename_pin(i: int, words: String) -> void:
	if i < 0 or i >= pins.size(): return
	var name := words.strip_edges().left(18)
	pins[i].name = name if name != "" else "Pin %d" % (i + 1)
	queue_redraw_all()


func step_pin(i: int, what: String) -> void:
	if i < 0 or i >= pins.size(): return
	var count := PIN_ICONS.size() if what == "icon" else PIN_COLOURS.size()
	pins[i][what] = (int(pins[i].get(what, 0)) + 1) % count
	queue_redraw_all()


func remove_pin(i: int) -> void:
	if i < 0 or i >= pins.size(): return
	pins.remove_at(i)
	pick(-1)


## The picked pin's name, icon, colour and a way to take it off the map.
func _show_editor() -> void:
	if not is_instance_valid(_editor): return
	_editor.visible = picked >= 0
	if picked >= 0 and is_instance_valid(_pin_name): _pin_name.text = str(pins[picked].name)


func _zoom_by(factor: float, about: Vector2) -> void:
	var before := (about - size * 0.5) / zoom + _centre
	zoom = clampf(zoom * factor, _fit_zoom(), _max_zoom())
	_centre = before - (about - size * 0.5) / zoom
	_clamp_view()
	queue_redraw_all()


func _pan(cells: Vector2) -> void:
	_centre += cells
	_clamp_view()
	queue_redraw_all()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _zoom_by(1.25, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _zoom_by(0.8, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = event.position
			_press_at = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT: add_pin(to_cell_at(event.position))
		accept_event()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = Vector2.INF
		# A click, not a drag: the pin under it picked (or none).
		if _press_at != Vector2.INF and event.position.distance_to(_press_at) < 3.0: pick(pin_at(event.position))
		_press_at = Vector2.INF
		accept_event()
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF:
		_pan(-(event.position - _drag_from) / zoom)
		_drag_from = event.position
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed: return
	var step := 24.0 / zoom
	match event.physical_keycode:
		KEY_W, KEY_UP: _pan(Vector2(0, -step))
		KEY_S, KEY_DOWN: _pan(Vector2(0, step))
		KEY_A, KEY_LEFT: _pan(Vector2(-step, 0))
		KEY_D, KEY_RIGHT: _pan(Vector2(step, 0))
		KEY_EQUAL, KEY_KP_ADD: _zoom_by(1.25, size * 0.5)
		KEY_MINUS, KEY_KP_SUBTRACT: _zoom_by(0.8, size * 0.5)
		KEY_C: find_keeper()
		_:
			var n: int = event.physical_keycode - KEY_1
			if event.physical_keycode == KEY_0: n = 9
			if n < 0 or n >= KINDS.size(): return
			toggle(str(KINDS[n][0]))
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ the key

## Hide (or show again) a kind of mark.
func toggle(kind: String) -> void:
	if hidden_kinds.has(kind): hidden_kinds.erase(kind)
	else: hidden_kinds[kind] = true
	_style_key_line(kind)
	queue_redraw_all()


## The key: a line a kind of mark, its number and its colour; a click hides
## it (or shows it again).
func build_key(into: Container) -> void:
	_key_lines.clear()
	# (Pass 17: two to a row, each with its icon.)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 1)
	into.add_child(grid)
	for i in KINDS.size():
		var entry: Array = KINDS[i]
		var kind := str(entry[0])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		line.mouse_filter = Control.MOUSE_FILTER_STOP
		line.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip := TextureRect.new()
		chip.texture = icon_texture(str(entry[3]))
		chip.custom_minimum_size = Vector2(9, 9)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "pins": chip.modulate = PIN_COLOURS[0]
		line.add_child(chip)
		var words := Label.new()
		words.text = ("%d " % ((i + 1) % 10) if i < 10 else "") + str(entry[1])
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(words)
		line.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				toggle(kind)
				line.accept_event())
		grid.add_child(line)
		_key_lines[kind] = [line, chip, words]
		_style_key_line(kind)
	# The picked pin: its name, its icon and colour, or away with it.
	_editor = VBoxContainer.new()
	_editor.add_theme_constant_override("separation", 2)
	_editor.visible = false
	into.add_child(_editor)
	_pin_name = LineEdit.new()
	_pin_name.max_length = 18
	_pin_name.placeholder_text = "Name this pin"
	_pin_name.custom_minimum_size = Vector2(0, 15)
	_pin_name.text_changed.connect(func(words: String): rename_pin(picked, words))
	_pin_name.text_submitted.connect(func(_words: String): _pin_name.release_focus())
	_editor.add_child(_pin_name)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 3)
	_editor.add_child(buttons)
	for spec in [["Icon", func(): step_pin(picked, "icon")], ["Colour", func(): step_pin(picked, "colour")], ["Remove", func(): remove_pin(picked)]]:
		var b := Button.new()
		b.text = str(spec[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		buttons.add_child(b)
	_show_editor()


func _style_key_line(kind: String) -> void:
	var parts = _key_lines.get(kind)
	if parts == null: return
	var off := hidden_kinds.has(kind)
	parts[1].modulate = Color(PIN_COLOURS[0] if kind == "pins" else Color.WHITE, 0.25 if off else 1.0)
	parts[2].add_theme_color_override("font_color", Color("6f7f78") if off else Color("e9dcc0"))


# ------------------------------------------------------------------ the picture

## A world not streamed: its picture from its cells, a cell a pixel.
func _painted_picture() -> ImageTexture:
	var b := _world_bounds()
	if _kept.get("world", 0) == world.get_instance_id() and Time.get_ticks_msec() - int(_kept.get("at", 0)) < 30000 and _kept.get("bounds") == b:
		return _kept.tex
	var img := Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGBA8)
	var deep: Dictionary = world.get("deep") if world.get("deep") != null else {}
	var micro: Dictionary = world.get("micro") if world.get("micro") != null else {}
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var cell := Vector2i(x, y)
			var region: String = world.region_of(cell) if world.has_method("region_of") else "forest"
			var color: Color = Regions.INFO.get(region, Regions.INFO.forest).map
			if micro.has(cell): color = MICRO_TINT.get(world.micro_of(cell), color)
			if region in ["bonelands", "dunes"] and world.ground_style.get(cell, "") != "sand": color = Color("5a7a4c")
			elif world.ground_style.get(cell, "") == "sand": color = (BONE_SAND if region == "bonelands" else Color("9a8458")) if region != "dunes" else Color("b89a5e")
			if int(world.terrain.get(cell, 0)) == 1: color = Color("7a7750")
			if world.water.has(cell): color = Color("2a6e8c") if deep.has(cell) else Color("4ab6c4")
			var p = world.props.get(cell)
			if is_instance_valid(p) and (p.kind in ["wall", "ore"] or str(p.kind).begins_with("seam_")): color = color.darkened(0.35)
			img.set_pixel(x - b.position.x, y - b.position.y, color)
	var tex := ImageTexture.create_from_image(img)
	_kept = {"world": world.get_instance_id(), "at": Time.get_ticks_msec(), "bounds": b, "tex": tex}
	return tex


## (Tools and tests: the picture a world not streamed is drawn from.)
func _picture_of() -> ImageTexture:
	return _painted_picture()


## Where the whole world's picture sits in the box, zoomed out to fit it.
func picture_rect() -> Rect2:
	var b := _world_bounds()
	if b.size.x <= 0 or b.size.y <= 0: return Rect2(Vector2.ZERO, size)
	var drawn := (Vector2(b.size) * _fit_zoom()).floor()
	return Rect2(((size - drawn) * 0.5).floor(), drawn)


func _ensure_picture() -> void:
	if _picture != null: return
	var memory = world.get("map_memory")
	if memory and memory.picture != null:
		_picture = ImageTexture.create_from_image(memory.picture)
		memory.picture_changed = false
		_pic_scale = memory.SCALE
	else:
		_picture = _painted_picture()
		_pic_scale = 1
	if memory: _fog_tex = ImageTexture.create_from_image(memory.fog_image())


## Whether a cell has been seen (a world with no memory: all of it).
func seen(c: Vector2i) -> bool:
	var memory = world.get("map_memory")
	return memory == null or memory.seen_at(c)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NIGHT)
	_ensure_picture()
	var b := _world_bounds()
	var top_left := to_view(Vector2(b.position * 16))
	draw_texture_rect(_picture, Rect2(top_left, Vector2(b.size) * zoom), false)


func _draw_fog() -> void:
	if _fog_tex == null: return
	var memory = world.get("map_memory")
	var top_left := to_view(Vector2(memory.origin * 16))
	_fog.draw_texture_rect(_fog_tex, Rect2(top_left, Vector2(memory.tiles * memory.TILE) * zoom), false)


# ------------------------------------------------------------------ the marks

func _mark(at: Vector2, colour: Color, big := 1) -> void:
	var r := Vector2(big + 1, big + 1)
	_marks.draw_rect(Rect2(at - r, r * 2.0 + Vector2.ONE), OUTLINE)
	_marks.draw_rect(Rect2(at - r + Vector2.ONE, r * 2.0 - Vector2.ONE), colour)


## The icons' strip, made the first time (a column of 9 x 9 for each icon).
static func _icons() -> ImageTexture:
	if _atlas != null: return _atlas
	var names := ICONS.keys()
	var img := Image.create(names.size() * 9, 9, false, Image.FORMAT_RGBA8)
	for n in names.size():
		_slot[names[n]] = n
		var rows: Array = ICONS[names[n]]
		for y in rows.size():
			var row := str(rows[y])
			for x in mini(row.length(), 9):
				var ch := row[x]
				if PALETTE.has(ch): img.set_pixel(n * 9 + x, y, PALETTE[ch])
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## One icon, for the key.
static func icon_texture(name: String) -> AtlasTexture:
	var strip := _icons()
	var t := AtlasTexture.new()
	t.atlas = strip
	t.region = Rect2(int(_slot.get(name, 0)) * 9, 0, 9, 9)
	return t


## An icon at a point of the map (centred on it), tinted (a pin's colour).
func _icon(at: Vector2, name: String, tint := Color.WHITE) -> void:
	var strip := _icons()
	_marks.draw_texture_rect_region(strip, Rect2((at - Vector2(4, 4)).round(), Vector2(9, 9)), Rect2(int(_slot.get(name, 0)) * 9, 0, 9, 9), tint)


## A small thing's mark: its icon close in, a dot of its colour far out.
func _small(at: Vector2, name: String, colour: Color) -> void:
	if zoom < DOTS_BELOW:
		_marks.draw_rect(Rect2(at.round() - Vector2(1, 1), Vector2(3, 3)), OUTLINE)
		_marks.draw_rect(Rect2(at.round(), Vector2(1, 1)), colour)
	else:
		_icon(at, name)


func _on_map(at: Vector2) -> bool:
	return at.x >= -4.0 and at.y >= -4.0 and at.x < size.x + 4.0 and at.y < size.y + 4.0


## A kind shown, at a cell seen (or wherever it is, `always`).
func _shows(kind: String, cell: Vector2i, always := false) -> bool:
	return not hidden_kinds.has(kind) and (always or seen(cell))


func _cell_px(c: Vector2i) -> Vector2:
	return Vector2(c) * 16.0 + Vector2(8, 8)


func _draw_marks() -> void:
	var caves = world.get("caves")
	var session := get_tree().get_first_node_in_group("forest_session")
	# The keeper's camp: the first camp, and what they've built to live by.
	if not hidden_kinds.has("home"):
		var homes: Array = [Vector2i(-1, -4)]
		var placed: Dictionary = world.get("placed") if world.get("placed") != null else {}
		for c in placed:
			if str(placed[c]) in HOME_KINDS: homes.append(c)
		var done := {}
		for c in homes:
			var key: Vector2i = c / 6
			if done.has(key): continue
			done[key] = true
			var at := to_view(_cell_px(c))
			if _on_map(at): _icon(at, "home")
	# Nests.
	var nesting = world.get("nesting")
	if nesting and not hidden_kinds.has("nests"):
		for cell in nesting.nests:
			var at := to_view(_cell_px(cell))
			if _on_map(at) and seen(cell): _small(at, "nest", KINDS[7][2])
	# Ruins, idols, shrines, camps and villages (the caves' mouths below).
	for poi in world.get("pois") if world.get("pois") != null else []:
		var kind := str(poi.kind)
		if kind == "cave_mouth": continue
		var cell: Vector2i = poi.cell
		var at := to_view(_cell_px(cell))
		if not _on_map(at): continue
		if kind == "ossuary":
			if _shows("bosses", cell, true): _icon(at, "skull")
			continue
		# Pass 18: the Reaper's hollow and Stormcrest's eyrie are their bosses'
		# (a skull below, at the lair); the crater a flame.
		if kind in ["reaper_hollow", "eyrie"]: continue
		if kind == "volcano":
			if _shows("ruins", cell): _icon(at, "flame")
			continue
		# Pass 17: the fallen buildings and the lost camps.
		if kind in ["building", "lost_camp"]:
			if _shows("buildings", cell): _small(at, "house" if kind == "building" else "tent", KINDS[10][2])
			continue
		var village := kind == "village" or str(poi.name).contains("Camp")
		if not _shows("villages" if village else "ruins", cell): continue
		if village: _icon(at, "hut_red" if str(poi.name).contains("Ashen") else "hut")
		else: _icon(at, "ruin")
	# The caves' mouths (a lair's Sleeper is a boss: red while it waits).
	if caves:
		for cave in caves.caves:
			if cave.mouth == Vector2i(9999, 9999): continue
			var at := to_view(_cell_px(cave.mouth))
			if not _on_map(at): continue
			var sleeping: bool = str(cave.kind) == "lair" and session != null and session.has_method("boss_down") and not session.boss_down("sleeper_" + str(cave.id))
			if sleeping and _shows("bosses", cave.mouth, true):
				_icon(at + Vector2(0, -8), "skull")
			if not _shows("caves", cave.mouth): continue
			_icon(at, "cave")
	# The alpha's den (red) until Skarn is beaten.
	var boss = get_tree().get_first_node_in_group("alpha_boss")
	if boss and boss.den != Vector2i(9999, 9999) and is_instance_valid(boss.alpha) and not boss.alpha.is_dead and not hidden_kinds.has("bosses"):
		var den := to_view(boss.centre())
		if _on_map(den): _icon(den, "skull")
	# Pass 18: the lands' great bosses at their lairs (hidden while one is down, back when it rises again).
	if session != null and not hidden_kinds.has("bosses") and session.get("land_bosses") != null:
		for great in session.land_bosses:
			if great.lair == Vector2i(9999, 9999) or session.boss_down(great.boss_id()): continue
			var lair_at := to_view(great.centre())
			if _on_map(lair_at): _icon(lair_at, "skull")
	# Old Maw, somewhere under the bog's deep water.
	if not hidden_kinds.has("bosses"):
		for beast in get_tree().get_nodes_in_group("sea_beasts"):
			if beast.is_dead: continue
			var at := to_view(beast.global_position)
			if _on_map(at): _icon(at, "fin")
	# The beasts: the keeper's own, the great roamers, the rest.
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.is_dead: continue
		var at := to_view(creature.global_position)
		if not _on_map(at): continue
		var cell: Vector2i = world.to_cell(creature.global_position)
		if caves and caves.strip.has_point(cell): continue
		if creature.tamed:
			if not hidden_kinds.has("tamed"): _icon(at, "paw")
		elif creature.get_node_or_null("Nameplate"):
			if _shows("beasts", cell): _icon(at, "claw")
		elif _shows("wild", cell):
			_small(at, "wild", KINDS[8][2])
	# The folk, wherever they are (their huts and traps too, while they wait there).
	if not hidden_kinds.has("folk"):
		for group in ["folk", "tribesmen"]:
			for person in get_tree().get_nodes_in_group(group):
				var spot := to_view(person.global_position)
				if _on_map(spot) and (group == "folk" or seen(world.to_cell(person.global_position))): _icon(spot, "person")
	# What a parasaur has heard (pass 13): amber diamonds.
	var heard: Dictionary = world.get("sensed") if world.get("sensed") != null else {}
	for cell in heard:
		var at := to_view(_cell_px(cell))
		if not _on_map(at): continue
		_icon(at, "heard")
	# The world's events under way (pass 13: a Sky-Fang spire, a fire...).
	var events = get_tree().get_first_node_in_group("world_events")
	if events and events.has_method("markers"):
		for mark in events.markers():
			var at := to_view(Vector2(mark.at))
			if not _on_map(at): continue
			if mark.has("icon"): _icon(at, str(mark.icon))
			else: _mark(at, mark.color, 2)
	# The keeper's own pins, named (pass 17); the one picked blinks a ring.
	if not hidden_kinds.has("pins"):
		var font: Font = preload("res://UI/SkyfangUI.gd").PIXEL
		for i in pins.size():
			var at := to_view(_cell_px(_pin_cell(i)))
			if not _on_map(at): continue
			var colour: Color = PIN_COLOURS[int(pins[i].get("colour", 0)) % PIN_COLOURS.size()]
			if i == picked: _marks.draw_arc(at.round(), 7.0, 0.0, TAU, 16, Color(colour, 0.9), 1.0)
			_icon(at, str(PIN_ICONS[int(pins[i].get("icon", 0)) % PIN_ICONS.size()]), colour)
			var words := str(pins[i].get("name", ""))
			if words != "":
				var spot := (at + Vector2(6, 3)).round()
				_marks.draw_string(font, spot + Vector2(1, 1), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.8))
				_marks.draw_string(font, spot, words, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, colour.lightened(0.3))
	# The keeper; underground, at the mouth they went in by.
	_icon(to_view(_keeper_at()), "you")
	_marks.draw_rect(Rect2(Vector2.ZERO, size), Color("709d87"), false, 1)
