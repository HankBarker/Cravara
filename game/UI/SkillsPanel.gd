extends Control
## The Skills panel (L), pass 14: the keeper's skills as constellations, in the
## manner of Skyrim's sky. Left: the seven skills, each with its level, a bar
## to the next and its unspent points. Right: the chosen skill's constellation
## on a see-through night sky: its stars (gold lit, pale blue ready to light,
## dim not yet), the lines of its tree, and the faint lines that finish its
## figure (Combat a sword, Taming a trike's skull...). Hover a star for what it
## does; click it, then Light it (or click it again). Beneath: the star, or the
## skill's boost so far. Built with the HUD's helpers to match every panel.

const UI = preload("res://UI/SkyfangUI.gd")
const SKILLS = preload("res://Forest/progress/Skills.gd")
const ICON_ITEM := {"combat": "shard_sword", "archery": "reed_bow", "taming": "trike_horn", "breeding": "dodo_egg",
	"farming": "garden_hoe", "gathering": "basic_pickaxe", "fishing": "fishing_rod"}
const BOOST_TEXT := {"melee_damage": "+%d%% melee damage", "bow_damage": "+%d%% arrow damage", "draw_speed": "+%d%% draw speed",
	"feeds_cut": "-%d%% feeds to tame", "mount_speed": "+%d%% mount speed", "hatch_speed": "+%d%% hatch speed",
	"growth_speed": "+%d%% growth", "crop_speed": "+%d%% crop growth", "gather_power": "+%d gathering power",
	"fishing": "+%d%% fishing knack"}
## Where the sky sits in the panel, and the constellation on it (a 150 x 90
## sky drawn at 2x).
const SKY_AT := Vector2(126, 24)
const SKY_SIZE := Vector2(318, 192)
const SKY_SCALE := 2.0
const SKY_PAD := Vector2(9, 6)

var hud: Node
var skills: Node
var panel: Panel
var selected := "combat"
## The star picked on the sky ("" none), and the one under the pointer.
var picked := ""
var hovered := ""
var sky: NightSky
var learn_button: Button
var star_buttons := {}
var _rows: Dictionary = {}
var _info_name: Label
var _info_state: Label
var _info_text: Label


func setup(owner_hud: Node, keeper_skills: Node) -> void:
	hud = owner_hud
	skills = keeper_skills
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = hud._panel(self, Vector2(14, 10), Vector2(452, 250))
	hud._label(panel, "SKILLS", Vector2(12, 5), 11, UI.GOLD)
	hud._label(panel, "Doing a thing makes you better at it. Each level lights two stars.", Vector2(70, 9), 8, UI.MINT)
	hud._button(panel, "Close", Vector2(398, 6), Vector2(46, 15), hud.close_panels)
	for i in SKILLS.ORDER.size():
		var skill: String = SKILLS.ORDER[i]
		var row := Button.new()
		row.position = Vector2(8, 25 + i * 31)
		row.size = Vector2(114, 29)
		row.focus_mode = Control.FOCUS_NONE
		row.flat = true
		row.pressed.connect(func(): select(skill))
		row.pressed.connect(func(): AudioManager.play_sfx("equip_gear"))
		panel.add_child(row)
		var back := Panel.new()
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(back)
		var icon := TextureRect.new()
		icon.position = Vector2(3, 6)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item: Item = ItemDB.make(str(ICON_ITEM.get(skill, "")))
		if item: icon.texture = item.icon
		row.add_child(icon)
		var name: Label = hud._label(row, "", Vector2(22, 2), 8, UI.GOLD)
		var lit: Label = hud._label(row, "", Vector2(80, 2), 8, UI.DIM)
		lit.size.x = 30
		lit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var bar := Bar.new()
		bar.position = Vector2(22, 18)
		bar.size = Vector2(86, 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		_rows[skill] = {"row": row, "back": back, "name": name, "lit": lit, "bar": bar}
	sky = NightSky.new()
	sky.position = SKY_AT
	sky.size = SKY_SIZE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.panel = self
	panel.add_child(sky)
	_info_name = hud._label(panel, "", Vector2(SKY_AT.x + 4, 218), 8, UI.GOLD)
	_info_state = hud._label(panel, "", Vector2(SKY_AT.x + 150, 218), 8, UI.DIM)
	_info_state.size.x = 104
	_info_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_text = hud._label(panel, "", Vector2(SKY_AT.x + 4, 229), 8, UI.PAPER)
	_info_text.size.x = 254
	_info_text.clip_text = true
	learn_button = hud._button(panel, "Light it", Vector2(390, 222), Vector2(54, 17), func(): learn(picked))
	skills.changed.connect(func(): if visible: refresh())


func select(skill: String) -> void:
	selected = skill
	picked = ""
	hovered = ""
	_build_stars()
	refresh()


func open() -> void:
	# Open on a skill with stars to light, if the one last seen has none.
	if int(skills.points.get(selected, 0)) <= 0:
		for skill in SKILLS.ORDER:
			if int(skills.points.get(skill, 0)) > 0:
				selected = skill
				break
	picked = ""
	hovered = ""
	show()
	_build_stars()
	refresh()


func _process(_delta: float) -> void:
	if visible and is_instance_valid(sky): sky.queue_redraw()


## Where a star sits on the sky, in the sky's own coordinates.
static func star_point(id: String) -> Vector2:
	return SKY_PAD + Vector2(SKILLS.PERKS[id].at) * SKY_SCALE


## One small clear button over each star: the pointer and the tests find it.
func _build_stars() -> void:
	for b in star_buttons.values():
		if is_instance_valid(b): b.queue_free()
	star_buttons.clear()
	for id in SKILLS.stars_of(selected):
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.size = Vector2(12, 12)
		b.position = star_point(id) - b.size / 2.0
		b.pressed.connect(func(): _star_clicked(id))
		b.mouse_entered.connect(func(): hovered = id; _show_info())
		b.mouse_exited.connect(func():
			if hovered == id: hovered = ""
			_show_info())
		sky.add_child(b)
		star_buttons[id] = b
	_tip_stars()


func _star_clicked(id: String) -> void:
	# A second click on a star ready to light lights it.
	if picked == id and skills.blocked(id) == "":
		learn(id)
		return
	picked = id
	AudioManager.play_sfx("equip_gear")
	_show_info()


func learn(id: String) -> bool:
	if id == "" or not skills.learn(id): return false
	AudioManager.play_sfx("craft")
	sky.flare(id)
	return true


func refresh() -> void:
	for skill in _rows:
		var r: Dictionary = _rows[skill]
		var lvl: int = skills.level(skill)
		var spare: int = int(skills.points.get(skill, 0))
		r.name.text = "%s %d" % [SKILLS.SKILLS[skill].name, lvl]
		r.lit.text = ("+%d" % spare) if spare > 0 else "%d/%d" % [skills.lit(skill), SKILLS.stars_of(skill).size()]
		r.lit.add_theme_color_override("font_color", UI.GOLD if spare > 0 else UI.DIM)
		var p: Vector2 = skills.progress(skill)
		r.bar.value = 1.0 if lvl >= SKILLS.MAX_LEVEL else (p.x / maxf(1.0, p.y))
		r.bar.queue_redraw()
		r.back.add_theme_stylebox_override("panel", UI.box("card" if skill == selected else "card_dim"))
	_tip_stars()
	_show_info()


func _tip_stars() -> void:
	for id in star_buttons:
		var p: Dictionary = SKILLS.PERKS[id]
		star_buttons[id].tooltip_text = "%s\n%s\n%s" % [p.name, p.text, _state_text(id)]


func _state_text(id: String) -> String:
	if skills.has(id): return "Lit."
	var why: String = skills.blocked(id)
	return "Ready to light (1 point)." if why == "" else why


## The strip beneath the sky: the star in hand (or under the pointer), else
## the skill itself.
func _show_info() -> void:
	var id := hovered if hovered != "" else picked
	learn_button.visible = picked != "" and not skills.has(picked)
	learn_button.disabled = picked == "" or skills.blocked(picked) != ""
	if id != "" and SKILLS.PERKS.has(id):
		var p: Dictionary = SKILLS.PERKS[id]
		_info_name.text = str(p.name)
		_info_state.text = _state_text(id)
		_info_state.add_theme_color_override("font_color", UI.GOLD if skills.has(id) else (UI.CRYSTAL if skills.blocked(id) == "" else UI.DIM))
		_info_text.text = str(p.text)
		return
	var skill := selected
	var lvl: int = skills.level(skill)
	var p2: Vector2 = skills.progress(skill)
	_info_name.text = "%s · %s" % [SKILLS.SKILLS[skill].name, SKILLS.FIGURES[skill].title]
	_info_state.text = "Mastered" if lvl >= SKILLS.MAX_LEVEL else "%d / %d to level %d" % [int(p2.x), int(p2.y), lvl + 1]
	_info_state.add_theme_color_override("font_color", UI.DIM)
	var boosts: Array = []
	for effect in SKILLS.PER_LEVEL[skill]:
		var amount := float(SKILLS.PER_LEVEL[skill][effect]) * float(lvl - 1)
		var shown := int(floor(amount)) if effect == "gather_power" else int(round(amount * 100.0))
		boosts.append(str(BOOST_TEXT.get(effect, effect + " %d")) % shown)
	var spare: int = int(skills.points.get(skill, 0))
	_info_text.text = "So far %s.  %s" % [", ".join(boosts), ("%d star%s to light." % [spare, "" if spare == 1 else "s"]) if spare > 0 else "Stars lit: %d of %d." % [skills.lit(skill), SKILLS.stars_of(skill).size()]]


## A slim XP bar.
class Bar extends Control:
	var value := 0.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.045, 0.9))
		var w := roundf((size.x - 2.0) * clampf(value, 0.0, 1.0))
		if w > 0.0: draw_rect(Rect2(1, 1, w, size.y - 2.0), Color("e8c27a"))


## The night sky and the chosen skill's constellation on it.
class NightSky extends Control:
	var panel
	var _flares := {}
	var _dust: Array = []
	var _dust_for := ""

	func flare(id: String) -> void:
		_flares[id] = 1.0

	func _dust_of(skill: String) -> Array:
		if _dust_for == skill: return _dust
		_dust_for = skill
		_dust.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = skill.hash()
		for i in 90:
			_dust.append([Vector2(rng.randf_range(2, size.x - 2), rng.randf_range(2, size.y - 2)), rng.randf_range(0.15, 0.55), rng.randf_range(0.6, 2.4), rng.randf() * TAU])
		for i in 5:
			_dust.append([Vector2(rng.randf_range(30, size.x - 30), rng.randf_range(20, size.y - 20)), -rng.randf_range(28, 60), 0.0, rng.randi_range(0, 2)])
		return _dust

	func _draw() -> void:
		if panel == null: return
		var skills = panel.skills
		var skill: String = panel.selected
		var t := float(Time.get_ticks_msec()) / 1000.0
		# The sky: deep and see-through, a few soft clouds of far stars.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.03, 0.075, 0.9))
		var dust := _dust_of(skill)
		for d in dust:
			if float(d[1]) < 0.0:
				# A soft cloud: rings of faint colour, denser toward the middle.
				var tint: Color = [Color(0.25, 0.2, 0.55, 0.018), Color(0.15, 0.3, 0.5, 0.018), Color(0.45, 0.25, 0.4, 0.015)][int(d[3])]
				for ring in 5: draw_circle(d[0], -float(d[1]) * (1.0 - 0.18 * ring), tint)
		for d in dust:
			if float(d[1]) < 0.0: continue
			var a: float = float(d[1]) * (0.65 + 0.35 * sin(t * float(d[2]) + float(d[3])))
			draw_rect(Rect2((d[0] as Vector2).floor(), Vector2.ONE), Color(0.85, 0.88, 1.0, a))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.48, 0.36, 0.24, 0.55), false, 1.0)
		# The figure's own faint lines.
		var ghost := Color(0.55, 0.62, 0.9, 0.17)
		for line in panel.SKILLS.FIGURES[skill].lines:
			var pts := PackedVector2Array()
			for p in line: pts.append(panel.SKY_PAD + Vector2(p) * panel.SKY_SCALE)
			if pts.size() >= 2: draw_polyline(pts, ghost, 1.0)
		# The tree's lines: gold between lit stars, pale toward a star ready to light.
		var ids: Array = panel.SKILLS.stars_of(skill)
		for id in ids:
			var here: Vector2 = panel.star_point(id)
			for a in panel.SKILLS.PERKS[id].after:
				var there: Vector2 = panel.star_point(str(a))
				var both: bool = skills.has(id) and skills.has(str(a))
				var half: bool = skills.has(str(a)) and not skills.has(id)
				var c := Color(0.93, 0.78, 0.48, 0.85) if both else (Color(0.62, 0.8, 0.98, 0.5) if half else Color(0.5, 0.56, 0.8, 0.24))
				draw_line(there, here, c, 1.0)
		# The stars.
		for id in ids:
			var at: Vector2 = panel.star_point(id)
			var root: bool = panel.SKILLS.PERKS[id].after.is_empty()
			var lit: bool = skills.has(id)
			var ready: bool = not lit and skills.blocked(id) == ""
			var open: bool = not lit and skills.opened(id)
			if lit:
				var tw := 0.75 + 0.25 * sin(t * 2.0 + at.x * 0.1)
				draw_circle(at, 6.0, Color(1.0, 0.84, 0.5, 0.14 * tw))
				draw_circle(at, 3.5, Color(1.0, 0.88, 0.6, 0.42))
				draw_circle(at, 2.0 if not root else 2.5, Color(1.0, 0.95, 0.8))
				var arm := 4.0 + 1.5 * tw
				draw_line(at - Vector2(arm, 0), at + Vector2(arm, 0), Color(1.0, 0.9, 0.65, 0.45 * tw))
				draw_line(at - Vector2(0, arm), at + Vector2(0, arm), Color(1.0, 0.9, 0.65, 0.45 * tw))
			elif ready:
				var pulse := 0.5 + 0.5 * sin(t * 3.2)
				draw_arc(at, 3.5 + pulse * 1.2, 0.0, TAU, 16, Color(0.62, 0.85, 1.0, 0.35 + 0.35 * pulse), 1.0)
				draw_circle(at, 1.8, Color(0.82, 0.93, 1.0))
			elif open:
				draw_circle(at, 3.0, Color(0.7, 0.78, 1.0, 0.12))
				draw_circle(at, 1.5, Color(0.72, 0.78, 0.95, 0.85))
			else:
				draw_circle(at, 1.2 if not root else 1.6, Color(0.5, 0.55, 0.75, 0.7))
			if id == panel.picked: draw_arc(at, 6.5, 0.0, TAU, 20, Color(0.91, 0.76, 0.48, 0.9), 1.0)
			elif id == panel.hovered: draw_arc(at, 5.5, 0.0, TAU, 18, Color(1, 1, 1, 0.45), 1.0)
			if _flares.has(id):
				var f: float = _flares[id]
				draw_arc(at, 4.0 + (1.0 - f) * 14.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.6, f), 1.0)
				_flares[id] = f - 0.04
				if f <= 0.04: _flares.erase(id)
		# The constellation's name, up in the corner.
		var font: Font = UI.title_font()
		var title: String = panel.SKILLS.FIGURES[skill].title
		var fs: int = UI.title_size(10)
		var w: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x - w - 6, 13), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.91, 0.76, 0.48, 0.75))
