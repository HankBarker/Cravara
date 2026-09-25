extends CanvasLayer
## Talking with the folk (Forest/folk): a small panel in the left column, under
## the vitals, with their portrait, their words and what they can do for the
## keeper, drawn with the interface kit. It never pauses the world or covers
## the middle of the screen: the keeper can walk, fight or run while talking,
## and walking away ends the talk. Pages:
##   talk     greeting and chat, and a button for each service
##   recipes  "what can I make with...?"      trade    buy and sell for ancient coins
##   advice   the warden's beasts              house    homes, and what a house needs
## E says goodbye; Esc steps back to the talk page first.
const UI = preload("res://UI/SkyfangUI.gd")
const FRAME = preload("res://UI/CrystalFrame.gd")
const QuestData = preload("res://Forest/quests/QuestData.gd")
const Folk = preload("res://Forest/folk/Folk.gd")
const Actor = preload("res://Forest/folk/FolkActor.gd")
const Housing = preload("res://Forest/folk/Housing.gd")
## Where the panel starts (top left) and how wide it is; it grows down with
## its page, clear of the keeper in the middle of the screen.
const ORIGIN := Vector2(6, 48)
const WIDTH := 176.0
## Further than this from the person (keeper to them) and the talk ends.
const REACH := 76.0

signal closed
## FolkManager for the folk; TribeTrade (a RefCounted) for a tribe's trader.
var manager: Object
var id := ""
var page := ""
var root: Control
var _box: PanelContainer
var _frame: Control
var _words: Label
var _content: VBoxContainer
var _reveal := 0.0
var _chat := 0
## A scripted talk (Orrin's first words): the lines, where it's up to, and
## what to do when it's through.
var _script: Array = []
var script_step := 0
var _script_done := Callable()


func _ready() -> void:
	layer = 28
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only the panel itself takes the mouse; clicks elsewhere reach the world.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	root.visible = false
	add_child(root)


func is_open() -> bool:
	return root != null and root.visible


## The panel on screen (an empty rect when closed).
func panel_rect() -> Rect2:
	return Rect2(_box.position, _box.size) if is_open() and is_instance_valid(_box) else Rect2()


## Talk to one of the folk (the manager answers for services and housing).
func open(folk_id: String, folk_manager: Object) -> void:
	manager = folk_manager
	id = folk_id
	_chat = randi()
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	_frame = FRAME.new()
	_frame.compact = true
	root.add_child(_frame)
	_box = PanelContainer.new()
	_box.position = ORIGIN
	_box.custom_minimum_size.x = WIDTH
	var margins := StyleBoxEmpty.new()
	margins.set_content_margin_all(7)
	_box.add_theme_stylebox_override("panel", margins)
	_box.resized.connect(_fit_frame)
	root.add_child(_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_box.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	column.add_child(header)
	var face := FRAME.new()
	face.inset = true
	face.custom_minimum_size = Vector2(36, 36)
	header.add_child(face)
	var portrait := TextureRect.new()
	portrait.texture = Actor.portrait(folk_id)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(2, 2)
	portrait.size = Vector2(32, 32)
	face.add_child(portrait)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	header.add_child(names)
	var who := Folk.info(folk_id)
	var name_label := Label.new()
	name_label.text = str(who.name)
	UI.style_title(name_label, 11)
	names.add_child(name_label)
	var title := Label.new()
	title.text = str(who.title).to_upper()
	title.add_theme_color_override("font_color", UI.MINT)
	names.add_child(title)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size.x = WIDTH - 14
	column.add_child(_words)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 3)
	column.add_child(_content)
	root.visible = true
	show_talk(_opening_words())


func close() -> void:
	if not is_open(): return
	root.visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if key in [KEY_E, KEY_ESCAPE]:
		if page == "script":
			# E goes on; Esc skips to the end of what they have to say.
			if key == KEY_ESCAPE: script_step = _script.size() - 1
			_advance_script()
		elif page != "talk" and key == KEY_ESCAPE: show_talk("")
		else: close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open(): return
	# Walking off (or anything happening to them) ends the talk.
	var person: Node2D = manager.actors.get(id) if is_instance_valid(manager) else null
	var keeper := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(person) or not is_instance_valid(keeper) or person.global_position.distance_to(keeper.global_position) > REACH:
		close()
		return
	if _words.visible_ratio < 1.0:
		_reveal += delta * 70.0
		_words.visible_characters = int(_reveal)
		if _words.visible_characters >= _words.text.length(): _words.visible_ratio = 1.0


func say(text: String) -> void:
	if text == "": return
	_words.text = text
	_words.visible_characters = 0
	_reveal = 0.0
	_refit()


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


# --- layout -----------------------------------------------------------------------

func _fit_frame() -> void:
	if not is_instance_valid(_frame) or not is_instance_valid(_box): return
	_frame.position = _box.position
	_frame.size = _box.size


## Shrink or grow the panel to its page once the new rows have their sizes.
func _refit() -> void:
	if is_instance_valid(_box): _box.call_deferred("reset_size")


func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 17)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_content.add_child(grid)
	return grid


## A list that scrolls once it's taller than `height`.
func _list(height: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH - 14, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _item_button(parent: Control, item: Item, text: String, callback: Callable) -> Button:
	var b := _button(parent, text, callback)
	b.icon = item.icon
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


# --- pages ------------------------------------------------------------------------

## Lines said one after another ("Go on", or E), from `from_step`; then
## `on_done` and the usual talk page. Walking away leaves it at script_step.
func open_script(folk_id: String, folk_manager: Object, lines: Array, from_step := 0, on_done := Callable()) -> void:
	open(folk_id, folk_manager)
	_script = lines
	script_step = clampi(from_step, 0, maxi(lines.size() - 1, 0))
	_script_done = on_done
	_show_script_line()


func _show_script_line() -> void:
	page = "script"
	_clear()
	say(str(_script[script_step]))
	var grid := _grid(2)
	_button(grid, "Go on" if script_step < _script.size() - 1 else "Thank you", _advance_script)
	_refit()


func _advance_script() -> void:
	# A tap while the words are still coming shows them all first.
	if _words.visible_ratio < 1.0:
		_words.visible_ratio = 1.0
		_reveal = _words.text.length()
		return
	script_step += 1
	if script_step < _script.size():
		_show_script_line()
		return
	_script = []
	if _script_done.is_valid(): _script_done.call()
	show_talk("")

func show_talk(words: String) -> void:
	page = "talk"
	_clear()
	say(words)
	var state: Dictionary = manager.folk.get(id, {})
	var grid := _grid(2)
	if state.get("stage", "") == "wild" and not bool(state.get("freed", true)):
		_button(grid, "Break the trap", func():
			if manager.release(id):
				manager.meet(id)
				show_talk("Free at last. %s" % str(Folk.info(id).get("ready_line", ""))))
		_button(grid, "Goodbye", close)
		_refit()
		return
	if state.get("stage", "") == "wild":
		manager.meet(id)
	_button(grid, "Chat", func(): say(_pick(Folk.info(id).chat)))
	for service in Folk.info(id).get("services", []):
		match service:
			"help": _button(grid, "What next?", func(): say(manager.help()))
			"recipes": _button(grid, "Recipes", show_recipes)
			"lore": _button(grid, "A story", func(): say(_pick(Folk.info(id).lore)))
			"trade": _button(grid, "Trade", show_trade)
			"advice": _button(grid, "The beasts", show_advice)
			"camp": _button(grid, "The camp", show_camp)
			"tend": _button(grid, "Tend beasts", func(): say(manager.tend()))
	var quests = _quests()
	if quests and not QuestData.for_giver(id).is_empty():
		var mark: String = quests.marker(id)
		_button(grid, "Tasks" + (" (new)" if mark == "!" else (" (done!)" if mark == "?" else "")), show_tasks)
	# Only the folk move in (a tribe's trader has a home of their own).
	if manager.has_method("rooms"): _button(grid, "Home", show_house)
	_button(grid, "Goodbye", close)
	_refit()


func _quests():
	var session := get_tree().get_first_node_in_group("forest_session")
	return session.get("quests") if session else null


## Their task: what they ask (take it or leave it), how it's going, or hand
## it in for the reward.
func show_tasks() -> void:
	page = "tasks"
	_clear()
	var quests = _quests()
	var q: Dictionary = quests.current(id) if quests else {}
	if q.is_empty():
		var any_left := false
		for task in QuestData.for_giver(id):
			if str(quests.state.get(task.id, "")) != "done": any_left = true
		say("Nothing for now. Go and see more of the wilds, and come back to me." if any_left else "You've done everything I could ask, and more. Thank you, Keeper.")
		_button(_content, "Back", func(): show_talk(""))
		_refit()
		return
	var status: String = quests.status(q)
	var title := Label.new()
	title.text = str(q.title) + ("  (taken)" if status == "active" else ("  (ready!)" if status == "ready" else ""))
	title.add_theme_color_override("font_color", UI.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(WIDTH - 16, 0)
	_content.add_child(title)
	for line in quests.goal_lines(q):
		var row := Label.new()
		row.text = "- " + str(line)
		row.add_theme_color_override("font_color", UI.MINT if str(line).ends_with("done") else UI.PAPER)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(WIDTH - 16, 0)
		_content.add_child(row)
	var reward := Label.new()
	reward.text = "Reward: " + quests.reward_text(q)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.custom_minimum_size = Vector2(WIDTH - 16, 0)
	_content.add_child(reward)
	var grid := _grid(2)
	match status:
		"offer":
			say(str(q.ask))
			_button(grid, "I'll do it", func():
				quests.accept(q.id)
				show_tasks())
			_button(grid, "Not now", func(): show_talk(""))
		"active":
			say("How's it going? " + str(q.ask))
			_button(grid, "Back", func(): show_talk(""))
		"ready":
			say("You've done it? Let me see...")
			_button(grid, "Hand it in", func():
				var words := str(q.done)
				var got: String = quests.reward_text(q)
				if quests.turn_in(q.id):
					show_talk(words + " (" + got + ")")
				else:
					show_tasks())
			_button(grid, "Back", func(): show_talk(""))
	_refit()


## "What can I make with...?": the satchel's things; pick one, hear its uses.
func show_recipes() -> void:
	page = "recipes"
	_clear()
	say("Show me something from your satchel and I'll tell you what it makes.")
	var seen := {}
	var grid := _grid(7)
	for slot in InventoryManager.inventory:
		var item: Item = slot.item
		if item == null or seen.has(item.id): continue
		seen[item.id] = true
		var b := Button.new()
		b.icon = item.icon
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(20, 18)
		b.tooltip_text = item.name
		b.add_theme_constant_override("icon_max_width", 14)
		var chosen := item
		b.pressed.connect(func(): say(_uses_of(chosen)))
		grid.add_child(b)
		if seen.size() >= 20: break
	_button(_content, "Back", func(): show_talk(""))
	_refit()


func _uses_of(item: Item) -> String:
	var recipes: Array = manager.recipes_with(item.id)
	if recipes.is_empty():
		return "%s? Nothing I know is made from it. Some things are for eating, trading or taming." % item.name
	var parts: Array = []
	for recipe in recipes.slice(0, 4):
		var station: String = recipe.get("station", "")
		parts.append("%s%s" % [recipe.name, " (%s)" % station if station != "" else ""])
	var more := "" if recipes.size() <= 4 else ", and %d more" % (recipes.size() - 4)
	return "With %s you can make: %s%s." % [item.name, ", ".join(parts), more]


## Buying (everyone who trades) and selling (the trader), a list at a time.
func show_trade(side := "buy") -> void:
	page = "trade"
	_clear()
	var pays: Dictionary = manager.buys_for(id) if manager.has_method("buys_for") else (Folk.BUYS if id == "merchant" else {})
	if pays.is_empty(): side = "buy"
	say("You have %d ancient coins. What'll it be?" % manager.coins() if side == "buy" else "Show me what you've found. One at a time.")
	if not pays.is_empty():
		var tabs := _grid(2)
		var buy_tab := _button(tabs, "Buy", func(): show_trade("buy"))
		var sell_tab := _button(tabs, "Sell", func(): show_trade("sell"))
		buy_tab.toggle_mode = true
		sell_tab.toggle_mode = true
		buy_tab.button_pressed = side == "buy"
		sell_tab.button_pressed = side == "sell"
	var list := _list(78)
	if side == "buy":
		var wares: Dictionary = manager.wares(id)
		for item_id in wares:
			var item: Item = ItemDB.make(item_id)
			if item == null: continue
			var offer: Array = wares[item_id]
			var ware: String = item_id
			_item_button(list, item, "%s%s  %dc" % [item.name, " x%d" % int(offer[1]) if int(offer[1]) > 1 else "", int(offer[0])], func():
				say(manager.buy(id, ware)))
	else:
		for item_id in pays:
			var count := InventoryManager.get_item_count(item_id)
			if count <= 0: continue
			var item: Item = ItemDB.make(item_id)
			if item == null: continue
			var find: String = item_id
			_item_button(list, item, "%s (%d)  +%dc" % [item.name, count, int(pays[item_id])], func():
				var said: String = manager.sell(find)
				show_trade("sell")
				say(said))
		if list.get_child_count() == 0:
			var none := Label.new()
			none.text = "Nothing they want yet. Bring fossils, hides, scales, horns or fangs."
			none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			none.custom_minimum_size.x = WIDTH - 20
			none.add_theme_color_override("font_color", UI.DIM)
			list.add_child(none)
	_button(_content, "Back", func(): show_talk(""))
	_refit()


## A tribe's camp (pass 13): its name, how it stands with the keeper, what it
## asks for, a gift of coins.
func show_camp() -> void:
	page = "camp"
	_clear()
	if not manager.has_method("camp_page"):
		show_talk("")
		return
	var info: Dictionary = manager.camp_page(id)
	if info.is_empty():
		say("We're a long way from any camp.")
	else:
		var r: Dictionary = info.request
		var ask := ""
		if not r.is_empty():
			ask = str(r.text)
			if r.has("hunt"): ask += " (%d of %d)" % [int(r.done), int(r.count)]
		say("%s. You are %s here (%d). %s" % [info.name, str(info.word).to_lower(), int(info.standing), ask])
		var grid := _grid(2)
		if not r.is_empty():
			var give := _button(grid, "Hand it over" if r.has("bring") else "It's done", func():
				say(manager.camp_give(id))
				show_camp())
			give.disabled = not bool(info.ready)
		_button(grid, "A gift (5 coins)", func():
			say(manager.camp_gift(id)))
	_button(_content, "Back", func(): show_talk(""))
	_refit()


func show_advice() -> void:
	page = "advice"
	_clear()
	say("Pick a beast. Every one is won its own way: I'll tell you how, what it eats, and whether you can ride it.")
	# (Pass 13: twenty beasts; the list scrolls.)
	var list := _list(92)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	list.add_child(grid)
	for species in Folk.BEASTS:
		var facts: Array = Folk.BEASTS[species]
		_button(grid, str(facts[0]), func():
			say("%s. Eats: %s. %s %s" % [facts[0], facts[1], facts[2], facts[3]]))
	_button(_content, "Back", func(): show_talk(""))
	_refit()


## Where they live, and the houses standing: move in, swap, or see what one
## lacks. (H shows every house and everyone at once.)
func show_house() -> void:
	page = "house"
	_clear()
	var state: Dictionary = manager.folk.get(id, {})
	var rooms: Dictionary = manager.rooms()
	var home: Dictionary = rooms.get(state.get("home", ""), {})
	match state.get("stage", ""):
		"home": say("I live in the %s. Suits me fine." % Housing.describe(home).to_lower())
		"camp": say("I'm camped by the fire for now. Build me a house and I'll move in.")
		_: say("I'd live by your camp if there were a house for me.")
	var list := _list(74)
	if rooms.is_empty():
		var none := Label.new()
		none.text = "No houses yet: walls all round, a door, a floor, a roof over every tile, a torch and a bed."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = WIDTH - 20
		none.add_theme_color_override("font_color", UI.DIM)
		list.add_child(none)
	for key in rooms:
		var room: Dictionary = rooms[key]
		var lives: String = manager.who_lives_in(key)
		var missing: Array = []
		for check in room.checks:
			if not check.ok: missing.append(str(check.label).to_lower())
		var label := Label.new()
		label.text = Housing.describe(room) + (": " + str(Folk.info(lives).name) if lives != "" else "") + ("" if room.valid else ". Needs " + ", ".join(missing))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = WIDTH - 20
		label.add_theme_color_override("font_color", UI.GOLD if lives == id else (UI.PAPER if room.valid else UI.EMBER))
		list.add_child(label)
		# A free house: move in. Someone else's: trade houses with them (nobody
		# is put out into the cold).
		if room.valid and lives == "":
			var target_key: String = key
			_button(list, "Move in here", func():
				if manager.move_in(id, target_key): show_house()
				else: say("I can't live there."))
		elif room.valid and lives != id and state.get("stage", "") == "home":
			var other: String = lives
			_button(list, "Swap with " + str(Folk.info(other).name), func():
				manager.swap(id, other)
				show_house())
	var row := _grid(2)
	if state.get("stage", "") == "home":
		_button(row, "Leave house", func():
			manager.leave_home(id)
			show_house())
	_button(row, "Back", func(): show_talk(""))
	_refit()
