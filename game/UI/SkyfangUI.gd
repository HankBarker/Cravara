extends RefCounted
## Cravera's interface kit: a keeper's field pack (pass 14). Stitched leather
## tabs and pockets, brass for whatever is chosen, the Sky-Fang's pale blue for
## whatever is lit (the look of UI/CrystalFrame.gd); crisp Tiny5 pixel text for
## everything read at a glance, and titles in the heading font the keeper
## picked in the settings (the hand-lettered Field Hand by default).
##
## One Theme serves the HUD, the satchel, the journal and every panel:
##   control.theme = SkyfangUI.theme()
## The art is drawn by tools/ui/make_ui_art.py into UI/art (nine.json holds
## each piece's nine-patch margins).
const PIXEL: Font = preload("res://Forest/fonts/Tiny5-Regular.ttf")
const TITLE: Font = preload("res://Forest/fonts/IMFellEnglish.ttf")
## Pass 14: a hand-lettered pixel face for titles (PixelLab, drawn on a 16 px grid).
const FIELD_HAND: Font = preload("res://Forest/fonts/FieldHand.ttf")
## The heading fonts the settings offer: id -> [name, font, the size it's crisp at (0: any)].
const HEADINGS := {"field": ["Field hand", FIELD_HAND, 16], "old": ["Old serif", TITLE, 0], "pixel": ["Pixel", PIXEL, 16]}
## Tiny5 is drawn on an 8px grid: at 8 (or 16) every stroke is a whole pixel.
const TEXT := 8
const BIG := 16
const ART := "res://UI/art/"

const VOID := Color("140c07")
const INK := Color("2b1e15")
const DARK := Color("22170f")
const EDGE := Color("7a5a3c")
const GOLD := Color("e8c27a")
const PAPER := Color("f2e6c9")
## (Named for the old mint; now the Sky-Fang's pale blue for good news.)
const MINT := Color("b9dff0")
const CRYSTAL := Color("9fd4f0")
const EMBER := Color("e39a7f")
const DIM := Color("a8977e")
const VITALITY := Color("d96c6c")
const HUNGER := Color("d8a95a")
const SHADOW := Color(0.06, 0.03, 0.01, 0.9)

static var _theme: Theme
static var _nine: Dictionary = {}


## A nine-patch piece of the kit as a StyleBox, with room for its content.
static func box(piece: String, content := Vector4(5, 2, 5, 3)) -> StyleBoxTexture:
	if _nine.is_empty():
		_nine = JSON.parse_string(FileAccess.get_file_as_string(ART + "nine.json"))
	var margins: Array = _nine.get(piece, [4, 4, 4, 4])
	var style := StyleBoxTexture.new()
	style.texture = load(ART + piece + ".png")
	style.texture_margin_left = margins[0]
	style.texture_margin_top = margins[1]
	style.texture_margin_right = margins[2]
	style.texture_margin_bottom = margins[3]
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


static func icon(name: String) -> Texture2D:
	return load(ART + "icon_" + name + ".png")


## Keyboard focus: a thin gold line over the plaque (mouse-only HUD buttons
## never take focus).
static func _focus() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.corner_detail = 1
	return style


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = PIXEL
	t.default_font_size = TEXT
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 1)
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox", "MenuButton"]:
		t.set_stylebox("normal", type, box("button_normal"))
		t.set_stylebox("hover", type, box("button_hover"))
		t.set_stylebox("pressed", type, box("button_on" if type != "Button" else "button_pressed", Vector4(5, 3, 5, 2)))
		t.set_stylebox("hover_pressed", type, box("button_on", Vector4(5, 3, 5, 2)))
		t.set_stylebox("disabled", type, box("button_disabled"))
		t.set_stylebox("focus", type, _focus())
		t.set_color("font_color", type, PAPER)
		t.set_color("font_hover_color", type, Color("f6ffea"))
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_hover_pressed_color", type, GOLD)
		t.set_color("font_focus_color", type, PAPER)
		t.set_color("font_disabled_color", type, DIM)
		t.set_constant("h_separation", type, 3)
	# Toggles (Ready only) sit pressed in the lit crystal plaque.
	t.set_stylebox("pressed", "Button", box("button_on", Vector4(5, 3, 5, 2)))
	t.set_icon("arrow", "OptionButton", load(ART + "arrow.png"))
	t.set_constant("arrow_margin", "OptionButton", 4)
	t.set_stylebox("normal", "LineEdit", box("field", Vector4(5, 3, 5, 3)))
	t.set_stylebox("focus", "LineEdit", _focus())
	t.set_stylebox("read_only", "LineEdit", box("field", Vector4(5, 3, 5, 3)))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", Color("8a7862"))
	t.set_color("caret_color", "LineEdit", CRYSTAL)
	t.set_color("selection_color", "LineEdit", Color("5a3e28"))
	t.set_stylebox("panel", "PopupMenu", box("tip", Vector4(4, 4, 4, 4)))
	t.set_stylebox("hover", "PopupMenu", box("button_hover"))
	t.set_color("font_color", "PopupMenu", PAPER)
	t.set_color("font_hover_color", "PopupMenu", Color("f6ffea"))
	t.set_font_size("font_size", "PopupMenu", TEXT)
	t.set_constant("v_separation", "PopupMenu", 3)
	t.set_stylebox("panel", "TooltipPanel", box("tip", Vector4(6, 5, 6, 5)))
	t.set_font("font", "TooltipLabel", PIXEL)
	t.set_font_size("font_size", "TooltipLabel", TEXT)
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_color("font_shadow_color", "TooltipLabel", SHADOW)
	t.set_constant("shadow_offset_x", "TooltipLabel", 1)
	t.set_constant("shadow_offset_y", "TooltipLabel", 1)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.05, 0.03, 0.7)
	track.content_margin_left = 2
	track.content_margin_right = 2
	t.set_stylebox("scroll", "VScrollBar", track)
	for kind in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = Color("a9803c") if kind == "grabber" else Color("d8ad5f")
		grip.border_color = VOID
		grip.set_border_width_all(1)
		grip.content_margin_left = 2
		grip.content_margin_right = 2
		t.set_stylebox(kind, "VScrollBar", grip)
	var groove := box("field", Vector4(0, 2, 0, 2))
	t.set_stylebox("slider", "HSlider", groove)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color("a9803c")
	lit.content_margin_top = 2
	lit.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", lit)
	t.set_stylebox("grabber_area_highlight", "HSlider", lit)
	t.set_icon("grabber", "HSlider", load(ART + "pip_lit.png"))
	t.set_icon("grabber_highlight", "HSlider", load(ART + "pip_lit.png"))
	_theme = t
	return t


## The heading font the keeper picked (GameSettings.heading_font).
static func title_font() -> Font:
	var pick: String = str(GameSettings.get("heading_font")) if GameSettings.get("heading_font") != null else "field"
	return HEADINGS.get(pick, HEADINGS.field)[1]


## The size a heading is drawn at: a pixel face only at the size it was drawn
## for (Field Hand at 16), the old serif at the size asked.
static func title_size(font_size: int) -> int:
	var pick: String = str(GameSettings.get("heading_font")) if GameSettings.get("heading_font") != null else "field"
	var native: int = int(HEADINGS.get(pick, HEADINGS.field)[2])
	return native if native > 0 else font_size


## A title in the heading font, gold by default.
static func style_title(label: Label, font_size := 11, tint := GOLD) -> Label:
	label.add_theme_font_override("font", title_font())
	label.add_theme_font_size_override("font_size", title_size(font_size))
	label.add_theme_color_override("font_color", tint)
	return label
