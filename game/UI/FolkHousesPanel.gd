extends RefCounted
## Folk & houses (H, or from the pause menu): everyone who has come to the
## wilds and every house there is, Terraria-style. Pick someone, then move them
## into a free house or swap houses with whoever lives there. A house that
## isn't a home yet says what it still needs, so the panel is also the
## builder's checklist. Drawn in the session's overlay (kind "houses").
const UI = preload("res://UI/SkyfangUI.gd")
const Folk = preload("res://Forest/folk/Folk.gd")
const Housing = preload("res://Forest/folk/Housing.gd")
const Actor = preload("res://Forest/folk/FolkActor.gd")


static func open(session, selected := "") -> void:
	var manager = session.folk
	var column: VBoxContainer = session._make_overlay("FOLK & HOUSES", "houses")
	var ids: Array = []
	for id in Folk.CAST:
		if manager.folk.has(id): ids.append(id)
	if not manager.folk.has(selected): selected = ids[0] if not ids.is_empty() else ""
	var rooms: Dictionary = manager.rooms()
	if ids.is_empty():
		session._overlay_text(column, "Nobody has come to the wilds yet.")
	else:
		var who_row := HBoxContainer.new()
		who_row.add_theme_constant_override("separation", 4)
		column.add_child(who_row)
		for id in ids:
			var b := Button.new()
			b.text = str(Folk.info(id).name)
			b.icon = head(id)
			b.toggle_mode = true
			b.button_pressed = id == selected
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 22)
			var pick: String = id
			b.pressed.connect(func(): open(session, pick))
			who_row.add_child(b)
		var status := Label.new()
		status.text = status_of(manager, selected)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size = Vector2(304, 20)
		status.add_theme_color_override("font_color", UI.MINT)
		column.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 104)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if rooms.is_empty():
		var none := Label.new()
		none.text = "No houses yet. A house: walls all round, a door, a floor, a roof over every tile, a torch and a bed."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 296
		none.add_theme_color_override("font_color", UI.DIM)
		list.add_child(none)
	# Nearest the first camp first.
	var keys: Array = rooms.keys()
	keys.sort_custom(func(a, b): return (rooms[a].centre as Vector2).length() < (rooms[b].centre as Vector2).length())
	var state: Dictionary = manager.folk.get(selected, {})
	var movable: bool = str(state.get("stage", "")) in ["camp", "ready", "home"]
	for key in keys:
		var room: Dictionary = rooms[key]
		var lives: String = manager.who_lives_in(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		list.add_child(row)
		var missing: Array = []
		for check in room.checks:
			if not check.ok: missing.append(str(check.label).to_lower())
		var label := Label.new()
		label.text = Housing.describe(room) + (": " + str(Folk.info(lives).name) if lives != "" else "") + ("" if room.valid else "\n  Needs: " + ", ".join(missing))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 232
		label.add_theme_color_override("font_color", UI.GOLD if lives == selected and lives != "" else (UI.PAPER if room.valid else UI.EMBER))
		row.add_child(label)
		if not (room.valid and movable) or lives == selected: continue
		var target: String = key
		var action: Button
		if lives == "":
			action = session._overlay_button(row, "Move in", func():
				manager.move_in(selected, target)
				open(session, selected))
		elif state.get("stage", "") == "home":
			var other: String = lives
			action = session._overlay_button(row, "Swap", func():
				manager.swap(selected, other)
				open(session, selected))
		if action: action.custom_minimum_size.x = 64
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	column.add_child(bottom)
	if state.get("stage", "") == "home":
		var leave: Button = session._overlay_button(bottom, "LEAVE THE HOUSE", func():
			manager.leave_home(selected)
			open(session, selected))
		leave.custom_minimum_size.x = 120
	var back: Button = session._overlay_button(bottom, "RETURN (H / ESC)", session._close_overlay)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Where someone is and what they're waiting for, in a line.
static func status_of(manager, id: String) -> String:
	var who := Folk.info(id)
	var state: Dictionary = manager.folk.get(id, {})
	match str(state.get("stage", "")):
		"home":
			return "%s lives in the %s." % [who.name, Housing.describe(manager.home_of(id)).to_lower()]
		"ready":
			return "%s is ready to move in. Pick a house below, or build one." % who.name
		"camp":
			if id == "guide": return "%s keeps to the camp fire. Give him a house if you like." % who.name
			return "%s has no house and camps by the fire." % who.name
		"wild":
			var site: Dictionary = state.get("site", {})
			var where: String = manager._direction(Vector2(int(site.cell[0]), int(site.cell[1]))) if not site.is_empty() else "in the wilds"
			if not bool(state.get("freed", true)):
				return "%s is caught in a trap %s. Break %s out." % [who.name, where, manager._pronoun(id)]
			return "%s waits %s. Go and talk to %s." % [who.name, where, manager._pronoun(id)]
	return ""


## Head and shoulders from their portrait, for buttons (16x16, crisp).
static func head(id: String) -> Texture2D:
	var portrait := Actor.portrait(id) as AtlasTexture
	if portrait == null: return null
	var t := AtlasTexture.new()
	t.atlas = portrait.atlas
	t.region = Rect2(portrait.region.position + Vector2(8, 2), Vector2(16, 16))
	return t
