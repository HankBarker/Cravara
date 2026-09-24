extends CanvasLayer
## Talking with the folk (Forest/folk): a portrait, their words, and what they
## can do for the keeper, drawn with the interface kit. Pages:
##   talk     greeting and chat, and a button for each service
##   help     the guide's next step            recipes  "what can I make with...?"
##   lore     the guide's stories              trade    buy and sell for ancient coins
##   advice   the warden's beasts              tend     heal hurt companions
##   house    where they live, the houses they could move to, what a house needs
## The plate sits at the foot of the screen and grows with its page, so the
## world (and whoever is talking) stays in view above it. The world pauses
## while it is open; E or Esc closes it.
const UI = preload("res://UI/SkyfangUI.gd")
const FRAME = preload("res://UI/CrystalFrame.gd")
const Folk = preload("res://Forest/folk/Folk.gd")
const Actor = preload("res://Forest/folk/FolkActor.gd")
const Housing = preload("res://Forest/folk/Housing.gd")
const PANEL := Rect2(36, 16, 408, 238)
const BOTTOM := 262.0
const MIN_HEIGHT := 148.0

signal closed
var manager: Node
var id := ""
var page := ""
var root: Control
var _box: Control
var _frame: Control
var _words: Label
var _title: Label
var _content: Control
var _reveal := 0.0
var _chat := 0


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.visible = false
	add_child(root)


func is_open() -> bool:
	return root != null and root.visible


## Talk to one of the folk (the manager answers for services and housing).
func open(folk_id: String, folk_manager: Node) -> void:
	manager = folk_manager
	id = folk_id
	_chat = randi()
	for child in root.get_children(): child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.07, 0.45)
	shade.size = Vector2(480, 270)
	root.add_child(shade)
	_box = Control.new()
	_box.position = PANEL.position
	_box.size = PANEL.size
	root.add_child(_box)
	_frame = FRAME.new()
	_frame.size = PANEL.size
	_box.add_child(_frame)
	var portrait_frame := FRAME.new()
	portrait_frame.inset = true
	portrait_frame.position = Vector2(12, 12)
	portrait_frame.size = Vector2(76, 76)
	_box.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.texture = Actor.portrait(folk_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(18, 16)
	portrait.size = Vector2(64, 64)
	_box.add_child(portrait)
	var who := Folk.info(folk_id)
	var name_label := Label.new()
	name_label.text = str(who.name)
	UI.style_title(name_label, 13)
	name_label.position = Vector2(98, 8)
	_box.add_child(name_label)
	_title = Label.new()
	_title.text = str(who.title).to_upper()
	_title.add_theme_color_override("font_color", UI.MINT)
	_title.position = Vector2(100, 27)
	_box.add_child(_title)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.position = Vector2(98, 40)
	_words.size = Vector2(PANEL.size.x - 112, 50)
	_box.add_child(_words)
	_content = Control.new()
	_content.position = Vector2(12, 96)
	_content.size = Vector2(PANEL.size.x - 24, PANEL.size.y - 106)
	_box.add_child(_content)
	root.visible = true
	get_tree().paused = true
	show_talk(_opening_words())


func close() -> void:
	if not is_open(): return
	root.visible = false
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if key in [KEY_E, KEY_ESCAPE]:
		if page != "talk" and key == KEY_ESCAPE: show_talk("")
		else: close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open() or _words == null: return
	if _words.visible_ratio < 1.0:
		_reveal += delta * 70.0
		_words.visible_characters = int(_reveal)
		if _words.visible_characters >= _words.text.length(): _words.visible_ratio = 1.0


func say(text: String) -> void:
	if text == "": return
	_words.text = text
	_words.visible_characters = 0
	_reveal = 0.0


func _opening_words() -> String:
	var who := Folk.info(id)
	var state: Dictionary = manager.folk.get(id, {})
	if state.get("stage", "") == "wild":
		var kind: String = state.get("site", {}).get("kind", "")
		return str(who.get("found_line", {}).get(kind, _pick(who.greet)))
	if state.get("stage", "") == "ready": return str(who.get("ready_line", _pick(who.greet)))
	return _pick(who.greet)


func _pick(lines: Array) -> String:
	_chat += 1
	return str(lines[posmod(_chat, lines.size())]) if not lines.is_empty() else ""


# --- pages ------------------------------------------------------------------------

func _clear() -> void:
	for child in _content.get_children(): child.queue_free()


## Size the plate to a page: rows of buttons (19 high, 3 apart) below the
## portrait, or the whole plate.
func _fit_rows(rows: int) -> void:
	_fit(rows * 19.0 + maxf(rows - 1, 0) * 3.0)


func _fit(content_height: float) -> void:
	var h := clampf(96.0 + content_height + 12.0, MIN_HEIGHT, PANEL.size.y)
	_frame.size = Vector2(PANEL.size.x, h)
	_box.position = Vector2(PANEL.position.x, BOTTOM - h)


func _button(parent: Control, text: String, callback: Callable, width := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 19)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size = _content.size
	_content.add_child(grid)
	return grid


func show_talk(words: String) -> void:
	page = "talk"
	_clear()
	say(words)
	var state: Dictionary = manager.folk.get(id, {})
	var grid := _grid(3)
	var width := int((_content.size.x - 8) / 3)
	if state.get("stage", "") == "wild" and not bool(state.get("freed", true)):
		_button(grid, "Break the trap open", func():
			if manager.release(id):
				manager.meet(id)
				show_talk("")
				say("Free at last. %s" % str(Folk.info(id).get("ready_line", ""))), width)
		_button(grid, "Goodbye  [E]", close, width)
		_fit_rows(1)
		return
	if state.get("stage", "") == "wild":
		manager.meet(id)
	_button(grid, "Chat", func(): say(_pick(Folk.info(id).chat)), width)
	for service in Folk.info(id).get("services", []):
		match service:
			"help": _button(grid, "What should I do?", func(): say(manager.help()), width)
			"recipes": _button(grid, "What can I make?", show_recipes, width)
			"lore": _button(grid, "Tell me a story", func(): say(_pick(Folk.info(id).lore)), width)
			"trade": _button(grid, "Trade", show_trade, width)
			"advice": _button(grid, "About the beasts", show_advice, width)
			"tend": _button(grid, "Tend my companions", func(): say(manager.tend()), width)
	_button(grid, "Your home", show_house, width)
	_button(grid, "Goodbye  [E]", close, width)
	_fit_rows(ceili(grid.get_child_count() / 3.0))


## "What can I make with...?": the satchel's things; pick one, hear its uses.
func show_recipes() -> void:
	page = "recipes"
	_clear()
	say("Show me something from your satchel and I'll tell you what it makes.")
	var seen := {}
	var grid := _grid(9)
	for slot in InventoryManager.inventory:
		var item: Item = slot.item
		if item == null or seen.has(item.id): continue
		seen[item.id] = true
		var b := Button.new()
		b.icon = item.icon
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 22)
		b.tooltip_text = item.name
		b.add_theme_constant_override("icon_max_width", 16)
		var chosen := item
		b.pressed.connect(func(): say(_uses_of(chosen)))
		grid.add_child(b)
		if seen.size() >= 27: break
	_button(grid, "Back", func(): show_talk(""), 40)
	var rows := ceili(grid.get_child_count() / 9.0)
	_fit(rows * 22.0 + (rows - 1) * 3.0)


func _uses_of(item: Item) -> String:
	var recipes: Array = manager.recipes_with(item.id)
	if recipes.is_empty():
		return "%s? Nothing I know is made from it. Some things are for eating, trading or taming." % item.name
	var parts: Array = []
	for recipe in recipes.slice(0, 5):
		var station: String = recipe.get("station", "")
		parts.append("%s%s" % [recipe.name, " (at a %s)" % station if station != "" else ""])
	var more := "" if recipes.size() <= 5 else ", and %d more" % (recipes.size() - 5)
	return "With %s you can make: %s%s." % [item.name, ", ".join(parts), more]


func show_trade() -> void:
	page = "trade"
	_clear()
	say("You have %d ancient coins. What'll it be?" % manager.coins())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	columns.size = _content.size
	_content.add_child(columns)
	var buy := VBoxContainer.new()
	buy.add_theme_constant_override("separation", 2)
	buy.custom_minimum_size.x = 220
	columns.add_child(buy)
	var heading := Label.new()
	heading.text = "BUY"
	heading.add_theme_color_override("font_color", UI.GOLD)
	buy.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220, 104)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	buy.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var wares: Dictionary = manager.wares(id)
	for item_id in wares:
		var item: Item = ItemDB.make(item_id)
		if item == null: continue
		var offer: Array = wares[item_id]
		var b := _button(list, "%s%s  %d c" % [item.name, " x%d" % int(offer[1]) if int(offer[1]) > 1 else "", int(offer[0])], func():
			say(manager.buy(id, item_id)), 208)
		b.icon = item.icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sell := VBoxContainer.new()
	sell.add_theme_constant_override("separation", 2)
	columns.add_child(sell)
	var sell_heading := Label.new()
	sell_heading.text = "SELL (one at a time)" if id == "merchant" else "BACK"
	sell_heading.add_theme_color_override("font_color", UI.GOLD)
	sell.add_child(sell_heading)
	if id == "merchant":
		var any := false
		for item_id in Folk.BUYS:
			var count := InventoryManager.get_item_count(item_id)
			if count <= 0: continue
			any = true
			var item: Item = ItemDB.make(item_id)
			var b := _button(sell, "%s (%d)  +%d c" % [item.name, count, int(Folk.BUYS[item_id])], func():
				say(manager.sell(item_id))
				show_trade(), 140)
			b.icon = item.icon
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 14)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not any:
			var none := Label.new()
			none.text = "Bring fossils, idols,\ncrystal, scales, fangs."
			none.add_theme_color_override("font_color", UI.DIM)
			sell.add_child(none)
	_button(sell, "Back", func(): show_talk(""), 140)
	_fit(PANEL.size.y)


func show_advice() -> void:
	page = "advice"
	_clear()
	say("Pick a beast. I'll tell you what it eats, how to earn its trust, and whether you can ride it.")
	var grid := _grid(3)
	var width := int((_content.size.x - 8) / 3)
	for species in Folk.BEASTS:
		var facts: Array = Folk.BEASTS[species]
		_button(grid, species.capitalize(), func():
			say("%s. Eats: %s. %s %s" % [species.capitalize(), facts[0], facts[1], facts[2]]), width)
	_button(grid, "Back", func(): show_talk(""), width)
	_fit_rows(ceili(grid.get_child_count() / 3.0))


## Where they live, and the houses standing: move in, or see what one lacks.
func show_house() -> void:
	page = "house"
	_clear()
	var state: Dictionary = manager.folk.get(id, {})
	var rooms: Dictionary = manager.rooms()
	var home: Dictionary = rooms.get(state.get("home", ""), {})
	match state.get("stage", ""):
		"home": say("I live in the %s. Suits me fine." % Housing.describe(home).to_lower())
		"camp": say("I'm camped by the fire for now. Build me a house and I'll move in.")
		_: say("I'd live by your camp if there were a house for me. %s" % str(Folk.info(id).get("ready_line", "")))
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(_content.size.x, _content.size.y - 24)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if rooms.is_empty():
		var none := Label.new()
		none.text = "No houses yet. A house: walls all round, a door, a floor, a roof over every tile, a torch and a bed."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = _content.size.x - 12
		none.add_theme_color_override("font_color", UI.DIM)
		list.add_child(none)
	for key in rooms:
		var room: Dictionary = rooms[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		list.add_child(row)
		var label := Label.new()
		var lives: String = manager.who_lives_in(key)
		var missing: Array = []
		for check in room.checks:
			if not check.ok: missing.append(str(check.label).to_lower())
		label.text = Housing.describe(room) + ("  (%s lives here)" % Folk.info(lives).name if lives != "" else "") + ("" if room.valid else "\n  Needs: " + ", ".join(missing))
		label.custom_minimum_size.x = 290
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", UI.PAPER if room.valid else UI.EMBER)
		row.add_child(label)
		# A free house: move in. Someone else's: trade houses with them (nobody
		# is put out into the cold).
		if room.valid and lives == "":
			var target_key: String = key
			_button(row, "Move here", func():
				if manager.move_in(id, target_key): show_house()
				else: say("I can't live there."), 80)
		elif room.valid and lives != id and state.get("stage", "") == "home":
			var other: String = lives
			_button(row, "Swap with " + str(Folk.info(other).name), func():
				manager.swap(id, other)
				show_house(), 96)
	var back := HBoxContainer.new()
	back.position = Vector2(0, _content.size.y - 20)
	_content.add_child(back)
	if state.get("stage", "") == "home":
		_button(back, "Leave the house", func():
			manager.leave_home(id)
			show_house(), 120)
	_button(back, "Back", func(): show_talk(""), 80)
	_fit(PANEL.size.y)
