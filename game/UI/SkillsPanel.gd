extends Control
## Pass 13: the Skills panel (L). Left: the six skills, each with its level,
## a bar to the next and any unspent points. Right: the chosen skill's boost
## so far, its perk tree (a column per branch; gold learned, mint ready, dim
## locked; hover for what it does) and, at levels 5 and 10, the calling to
## pick. Built with the HUD's own helpers so it matches every other panel.

const UI = preload("res://UI/SkyfangUI.gd")
const SKILLS = preload("res://Forest/progress/Skills.gd")
const ICON_ITEM := {"combat": "shard_sword", "archery": "reed_bow", "taming": "net", "breeding": "dodo_egg",
	"farming": "berry_seed", "gathering": "basic_pickaxe"}
const BOOST_TEXT := {"melee_damage": "+%d%% melee damage", "bow_damage": "+%d%% arrow damage", "draw_speed": "+%d%% draw speed",
	"feeds_cut": "-%d%% feeds to tame", "mount_speed": "+%d%% mount speed", "hatch_speed": "+%d%% hatch speed",
	"growth_speed": "+%d%% growth", "crop_speed": "+%d%% crop growth", "gather_power": "+%d gathering power"}

var hud: Node
var skills: Node
var panel: Panel
var selected := "combat"
var _rows: Dictionary = {}
var _detail: Control


func setup(owner_hud: Node, keeper_skills: Node) -> void:
	hud = owner_hud
	skills = keeper_skills
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = hud._panel(self, Vector2(40, 22), Vector2(400, 222))
	hud._label(panel, "SKILLS", Vector2(14, 7), 11, UI.GOLD)
	hud._label(panel, "Doing a thing makes you better at it.", Vector2(70, 10), 8, UI.MINT)
	hud._button(panel, "Close", Vector2(341, 7), Vector2(46, 17), hud.close_panels)
	for i in SKILLS.ORDER.size():
		var skill: String = SKILLS.ORDER[i]
		var row := Button.new()
		row.position = Vector2(10, 30 + i * 30)
		row.size = Vector2(124, 28)
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
		icon.position = Vector2(3, 5)
		icon.size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item: Item = ItemDB.make(str(ICON_ITEM.get(skill, "")))
		if item: icon.texture = item.icon
		row.add_child(icon)
		var name: Label = hud._label(row, "", Vector2(22, 2), 8, UI.GOLD)
		var bar := Bar.new()
		bar.position = Vector2(22, 17)
		bar.size = Vector2(96, 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		_rows[skill] = {"row": row, "back": back, "name": name, "bar": bar}
	_detail = Control.new()
	_detail.position = Vector2(142, 28)
	_detail.size = Vector2(250, 188)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_detail)
	skills.changed.connect(func(): if visible: refresh())


func select(skill: String) -> void:
	selected = skill
	refresh()


func open() -> void:
	# A calling waiting to be picked opens on its skill.
	if not skills.pending.is_empty(): selected = str(skills.pending[0]).split(":")[0]
	show()
	refresh()


func refresh() -> void:
	for skill in _rows:
		var r: Dictionary = _rows[skill]
		var lvl: int = skills.level(skill)
		var spare: int = int(skills.points.get(skill, 0))
		r.name.text = "%s %d%s" % [SKILLS.SKILLS[skill].name, lvl, ("  +%d" % spare) if spare > 0 else ""]
		var p: Vector2 = skills.progress(skill)
		r.bar.value = 1.0 if lvl >= SKILLS.MAX_LEVEL else (p.x / maxf(1.0, p.y))
		r.bar.queue_redraw()
		r.back.add_theme_stylebox_override("panel", UI.box("card" if skill == selected else "card_dim"))
	_build_detail()


func _build_detail() -> void:
	for child in _detail.get_children(): child.queue_free()
	var skill := selected
	var info: Dictionary = SKILLS.SKILLS[skill]
	var lvl: int = skills.level(skill)
	var head: Label = hud._label(_detail, "%s  ·  level %d" % [info.name, lvl], Vector2(2, 0), 8, UI.GOLD)
	head.size.x = 246
	var p: Vector2 = skills.progress(skill)
	var next := "Mastered." if lvl >= SKILLS.MAX_LEVEL else "%d / %d to level %d" % [int(p.x), int(p.y), lvl + 1]
	hud._label(_detail, next, Vector2(2, 11), 8, UI.DIM)
	var about: Label = hud._label(_detail, "", Vector2(2, 22), 8, UI.PAPER)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.size = Vector2(246, 18)
	about.text = str(info.text)
	var boosts: Array = []
	for effect in SKILLS.PER_LEVEL[skill]:
		var amount := float(SKILLS.PER_LEVEL[skill][effect]) * float(lvl - 1)
		var shown := int(round(amount * (1.0 if effect == "gather_power" else 100.0)))
		if effect == "gather_power": shown = int(floor(amount))
		boosts.append(str(BOOST_TEXT.get(effect, effect + " %d")) % shown)
	hud._label(_detail, "So far: " + ", ".join(boosts), Vector2(2, 41), 8, UI.MINT).size.x = 246
	var spare: int = int(skills.points.get(skill, 0))
	hud._label(_detail, "Perk points: %d" % spare, Vector2(2, 52), 8, UI.GOLD if spare > 0 else UI.DIM)
	# The calling, when one is waiting.
	var waiting := ""
	for key in skills.pending:
		if str(key).begins_with(skill + ":"): waiting = str(key)
	if waiting != "":
		_calling_choice(skill, int(waiting.split(":")[1]))
		return
	_tree(skill)
	# Callings already chosen.
	var chosen: Array = []
	for tier in [5, 10]:
		var c: String = skills.calling(skill, tier)
		if c != "": chosen.append(str(SKILLS.CALLING[c].name))
	if not chosen.is_empty():
		hud._label(_detail, "Callings: " + ", ".join(chosen), Vector2(2, 176), 8, UI.GOLD)


func _tree(skill: String) -> void:
	var branches: Array = []
	var by_branch := {}
	for perk in SKILLS.PERKS:
		var p: Dictionary = SKILLS.PERKS[perk]
		if str(p.skill) != skill: continue
		if not by_branch.has(p.branch):
			by_branch[p.branch] = []
			branches.append(p.branch)
		by_branch[p.branch].append(perk)
	var width := floorf(246.0 / maxf(1.0, float(branches.size())))
	for b in branches.size():
		var x := 2.0 + b * width
		hud._label(_detail, str(branches[b]), Vector2(x, 66), 8, UI.DIM)
		var list: Array = by_branch[branches[b]]
		for n in list.size():
			var perk: String = list[n]
			var p: Dictionary = SKILLS.PERKS[perk]
			var learned: bool = skills.perks.has(perk)
			var why: String = skills.blocked(perk)
			var button: Button = hud._button(_detail, str(p.name), Vector2(x, 78 + n * 30), Vector2(width - 6, 18), func():
				if skills.learn(perk): AudioManager.play_sfx("craft"))
			button.tooltip_text = "%s\n%s%s" % [p.name, p.text, "" if learned else "\n" + ("Ready to learn." if why == "" else why)]
			button.disabled = not learned and why != ""
			button.add_theme_color_override("font_color", UI.GOLD if learned else (UI.MINT if why == "" else UI.DIM))
			button.add_theme_color_override("font_disabled_color", UI.DIM)
			var sub: Label = hud._label(_detail, ("Lv %d" % int(p.needs)) if not learned else "learned", Vector2(x + 2, 97 + n * 30), 8, UI.GOLD if learned else UI.DIM)
			sub.size.x = width - 8


func _calling_choice(skill: String, tier: int) -> void:
	hud._label(_detail, "Level %d: choose your calling" % tier, Vector2(2, 68), 8, UI.GOLD)
	var options: Array = SKILLS.CALLINGS[skill][tier]
	for i in options.size():
		var id: String = options[i]
		var c: Dictionary = SKILLS.CALLING[id]
		var y := 82 + i * 48
		hud._button(_detail, str(c.name), Vector2(2, y), Vector2(110, 18), func():
			if skills.choose(skill, tier, id): AudioManager.play_sfx("craft"))
		var words: Label = hud._label(_detail, "", Vector2(118, y + 1), 8, UI.PAPER)
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size = Vector2(128, 40)
		words.text = str(c.text)


## A slim XP bar.
class Bar extends Control:
	var value := 0.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.09, 0.9))
		var w := roundf((size.x - 2.0) * clampf(value, 0.0, 1.0))
		if w > 0.0: draw_rect(Rect2(1, 1, w, size.y - 2.0), Color("dcc085"))
