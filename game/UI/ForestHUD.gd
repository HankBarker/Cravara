extends CanvasLayer
# Compact native-resolution field interface. Existing inventory remains authoritative.
var player: Node = null
var root: Control
var inventory_panel: Panel
var recipes_panel: Panel
var toast: Label
var context_label: Label
var bleed_label: Label
var ash_label: Label
var _ash_box: PanelContainer
const ASH := Color("ddd6c6")
var station_label: Label
var detail: Label
var recipe_list: Container
var slots: Array[Control] = []
var hotbar: Array[Control] = []
var selected_category := "All"
var craftable_only := false
var query := ""
var bars: Dictionary = {}
var _toast_time := 0.0
var _last_selected := -1
var _active_chest: Node = null
var chest_panel: Panel
var chest_slots: Array[Control] = []
var armor_buttons: Dictionary = {}
var equipment_panel: Panel
var roster_panel: Panel
var command_panel: Panel
var equipment_list: VBoxContainer
var equipment_summary: Label
var equipment_hint: Label
var roster_list: VBoxContainer
var _equipment_target := "head"
var _roster_tick := 0.0
var _command_target: Node = null
var _command_is_group := false
var _shade: ColorRect
var _satchel_tween: Tween
var _hotbar_page: Label
var shortcut_buttons: Array[Button] = []
var _interface_ready := false
var appearance_editor: CanvasLayer
## The Skills panel (pass 13, UI/SkillsPanel.gd; L).
var skills_panel: Control
var sort_button: Button
var quick_stack_button: Button
var pack_close_button: Button
## Pass 14: the field pack's parts. The hotbar hides into the pack's first row
## while it's open (the pouch in hand is marked beside its row).
var _hotbar_frame: Control
var _pouch_box: Control
var _pouch_marker: Label
var _candidates: Panel
## The order wheel (hold Q): the one pointed at, and whether letting go of Q picks it.
var _wheel: Control
var _wheel_pick: Button = null
var _wheel_hold := false
## Where the pointer was when the wheel came up: nothing is picked until it
## moves, so a tap-and-let-go of Q leaves the wheel up to be clicked.
var _wheel_from := Vector2.INF
var _wheel_moved := false
var _wheel_outer: Array = []
var _wheel_inner: Array = []
const FRAME = preload("res://UI/CrystalFrame.gd")
const METER = preload("res://UI/CrystalMeter.gd")
## The interface kit: fonts, palette, plaques, sockets and icons.
const UI = preload("res://UI/SkyfangUI.gd")
const SetBonus = preload("res://Forest/equipment/SetBonus.gd")
var _heading_font: Font
const INK := UI.INK
const DARK := UI.DARK
const EDGE := UI.EDGE
const GOLD := UI.GOLD
const PAPER := UI.PAPER
const MINT := UI.MINT
## Status plate: icon and number beside each meter; low meters pulse.
var status_icons: Dictionary = {}
var status_values: Dictionary = {}
var _pulse := 0.0
## Pouch pips beside the hotbar (Caps cycles the five pouches).
var _pouch_pips: Array[TextureRect] = []
## The context line as key caps and actions (context_label keeps the text).
var _hint: PanelContainer
var _hint_row: HBoxContainer
var _hint_text := ""
var _toast_box: PanelContainer
var _bleed_box: PanelContainer
## News that matters (someone arrived, someone moved in): a plate with a
## portrait slides down from the top, one at a time.
var _banners: Array = []
var _banner: Control

func _ready() -> void:
	layer = 20
	add_to_group("inventory_ui")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# One kit for every panel: carved slate, bronze, crystal, crisp pixel text.
	root.theme = UI.theme()
	_heading_font = UI.title_font()
	_shade = ColorRect.new()
	_shade.color = Color(0.06,0.04,0.02,0.45)
	_shade.size = Vector2(480,270)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)
	_build_status()
	_build_hotbar()
	GameSettings.settings_changed.connect(_apply_shortcut_visibility)
	_apply_shortcut_visibility()
	root.move_child(_shade,root.get_child_count()-1)
	_build_inventory()
	_build_equipment()
	_build_roster()
	if is_instance_valid(player) and player.has_signal("equipment_changed"):
		player.equipment_changed.connect(_refresh_equipment)
	InventoryManager.inventory_changed.connect(update_inventory_display)
	InventoryManager.item_picked_up.connect(func(item,quantity): show_toast("+%d  %s" % [quantity,item.name]))
	CraftingManager.stations_changed.connect(_refresh_recipes)
	SignalBus.armor_changed.connect(func(_slot,_item): update_armor_display())
	update_inventory_display()
	close_panels()
	_interface_ready = true

func _panel(parent: Node, pos: Vector2, dimensions: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = dimensions
	p.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	parent.add_child(p)
	var frame := FRAME.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.compact = dimensions.y < 65
	p.add_child(frame)
	return p

## Titles (size 10 and up) in the old hand; everything else in crisp Tiny5
## at its one true size (the theme's 8).
func _label(parent: Node, text: String, pos: Vector2, font_size: int = 8, tint: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if font_size >= 10:
		UI.style_title(l,font_size,tint)
	else:
		l.add_theme_color_override("font_color",tint)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## A soft dark backing that hugs its content (words over bright ground).
func _backing(parent: Node, content: Vector4) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel",UI.box("shade",content))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plate)
	return plate

## A small icon from the kit (heart, meat, drop, shield, crystal).
func _icon(parent: Node, name: String, pos: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = UI.icon(name)
	icon.position = pos
	icon.size = icon.texture.get_size()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = dimensions
	# Mouse-driven HUD: a clicked button must not keep keyboard focus, or Space
	# (dodge) / Enter would press it again through ui_accept.
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	b.pressed.connect(func(): AudioManager.play_sfx("equip_gear"))
	parent.add_child(b)
	b.size = dimensions
	return b

## The status plate: a heart and a haunch, each with its crystal meter and the
## number itself. Region name top right; bleeding, toasts and the context line
## sit on soft dark backings so they read over the brightest meadow.
## Where the lines under the status plate start (the gifts, a bleed, the ash).
const UNDER_PLATE := 53.0

func _build_status() -> void:
	var frame := _panel(root,Vector2(6,5),Vector2(158,47))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var name: String = ["VITALITY","HUNGER"][i]
		var y := 5+i*16
		status_icons[name] = _icon(frame,["heart","meat"][i],Vector2(9,y))
		var bar := METER.new()
		bar.position = Vector2(28,y+4)
		bar.size = Vector2(100,9)
		bar.tint = [UI.VITALITY,UI.HUNGER][i]
		frame.add_child(bar)
		bars[name] = bar
		var amount := _label(frame,"",Vector2(131,y+4),8,PAPER)
		amount.size = Vector2(17,9)
		status_values[name] = amount
	_region_plate = _backing(root,Vector4(7,1,7,2))
	_region_label = _label(_region_plate,"The Skyfang Wilds",Vector2.ZERO,11,GOLD)
	_region_plate.reset_size()
	_region_plate.position = Vector2(475-_region_plate.size.x,3)
	# A bleeding cut (a stego's tail): a drop and the seconds left, under the plate.
	_bleed_box = _backing(root,Vector4(3,1,6,1))
	_bleed_box.position = Vector2(8,UNDER_PLATE)
	var bleed_row := HBoxContainer.new()
	bleed_row.add_theme_constant_override("separation",2)
	bleed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bleed_box.add_child(bleed_row)
	_icon(bleed_row,"drop",Vector2.ZERO)
	bleed_label = _label(bleed_row,"",Vector2.ZERO,8,UI.EMBER)
	bleed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bleed_box.visible = false
	# The ash (pass 12, the Pale Lands): how much the keeper has breathed, then CHOKING.
	_ash_box = _backing(root,Vector4(3,1,6,1))
	_ash_box.position = Vector2(8,UNDER_PLATE)
	var ash_row := HBoxContainer.new()
	ash_row.add_theme_constant_override("separation",2)
	ash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ash_box.add_child(ash_row)
	ash_label = _label(ash_row,"",Vector2.ZERO,8,ASH)
	ash_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ash_box.visible = false
	# Pass 15: what the keeper last ate, and how long its buffs last.
	_meal_box = _backing(root,Vector4(4,1,5,1))
	_meal_box.position = Vector2(8,UNDER_PLATE)
	_meal_label = _label(_meal_box,"",Vector2.ZERO,8,MEAL)
	_meal_box.visible = false
	context_label = _label(root,"",Vector2(10,218),8)
	context_label.size = Vector2(460,12)
	context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context_label.visible = false
	_hint = _backing(root,Vector4(5,2,5,2))
	_hint.visible = false
	_hint_row = HBoxContainer.new()
	_hint_row.add_theme_constant_override("separation",3)
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(_hint_row)
	_toast_box = _backing(root,Vector4(5,2,5,2))
	toast = _label(_toast_box,"",Vector2.ZERO,8,MINT)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_hotbar() -> void:
	var frame := _panel(root,Vector2(113,235),Vector2(254,34))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_frame = frame
	for i in 8:
		var slot := _slot(frame,i,Vector2(4+i*31,3),28)
		hotbar.append(slot)
		_label(slot,str(i+1),Vector2(4,2),8,GOLD)
	# Caps cycles five pouches of eight: a key cap and five crystal pips.
	var pouch := _backing(root,Vector4(3,2,4,2))
	pouch.position = Vector2(7,229)
	_pouch_box = pouch
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pouch.add_child(row)
	_hotbar_page = _label(row,"CAPS",Vector2.ZERO,8,Color("f4e4b9"))
	_hotbar_page.add_theme_stylebox_override("normal",UI.box("chip",Vector4(3,1,3,2)))
	var gap := Control.new()
	gap.custom_minimum_size.x = 2
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	for i in 5:
		var pip := TextureRect.new()
		pip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
		_pouch_pips.append(pip)
	_shortcut("Satchel","Tab",Vector2(8,246),Vector2(96,21),func():
		if is_open(): close_panels()
		else: open_panels())
	_shortcut("Gear","K",Vector2(380,222),Vector2(94,21),show_equipment)
	_shortcut("Companions","P",Vector2(380,246),Vector2(94,21),show_roster)
	_shortcut("Skills","L",Vector2(380,198),Vector2(94,21),show_skills)

func _slot(parent: Node, index: int, pos: Vector2, pixels: int, source = null) -> Control:
	var slot := Panel.new()
	slot.set_script(preload("res://UI/SlotUI.gd"))
	slot.slot_index = index
	slot.parent_ui = self
	slot.source = source
	slot.position = pos
	slot.size = Vector2(pixels,pixels)
	slot.add_theme_stylebox_override("panel",UI.box("slot"))
	parent.add_child(slot)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(4,4)
	icon.size = Vector2(pixels-8,pixels-8)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var qty := _label(slot,"",Vector2(2,pixels-11),8)
	qty.name = "Quantity"
	qty.size.x = pixels-5
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return slot

## The socket a slot shows: lit crystal when it is the hotbar's choice, a
## brighter rim under the pointer.
func slot_style(slot: Control, hovered := false) -> StyleBox:
	if slot.get("source") == null and slot.slot_index == InventoryManager.selected_slot_index and (slot in hotbar or slot in slots): return UI.box("slot_selected")
	return UI.box("slot_hover" if hovered else "slot")

## Pass 14: the keeper's field pack, laid out Terraria's way: the pack's
## pockets top left (eight across, a pouch of eight to a row; the pouch in hand
## is the hotbar), crafting beneath it, the gear down the right edge
## (_build_equipment). It unzips over the world, which stays in view.
const PACK_AT := Vector2(6, 54)
const POCKET := 20
const POCKET_STEP := 21
func _build_inventory() -> void:
	inventory_panel = _panel(root,PACK_AT,Vector2(184,140))
	_label(inventory_panel,"Field Pack",Vector2(10,3),12,GOLD)
	sort_button=_button(inventory_panel,"Sort",Vector2(88,6),Vector2(32,13),func():
		var changed:=InventoryManager.sort_backpack()
		show_toast("Pack sorted; the pouch in hand stays as it is" if changed else "Your pack is already sorted"))
	sort_button.tooltip_text="Merge and sort your pack. The pouch in hand (the hotbar row) stays exactly as it is."
	quick_stack_button=_button(inventory_panel,"Stack",Vector2(123,6),Vector2(38,13),func():
		var result:=InventoryManager.quick_stack_nearby(player)
		show_toast("Stored %d items in %d chests; the pouch in hand stays" % [result.moved,result.chests] if result.moved else "No chest in reach holds any of these"))
	quick_stack_button.tooltip_text="Quick stack: everything a chest nearby already holds goes into it (chests in sight, within five tiles). The pouch in hand stays with you."
	# Zip it shut (Tab, K or Esc do the same).
	pack_close_button=_button(inventory_panel,"X",Vector2(164,6),Vector2(13,13),close_panels)
	pack_close_button.tooltip_text="Close your pack [Tab]"
	for i in InventoryManager.MAX_INVENTORY_SIZE:
		slots.append(_slot(inventory_panel,i,Vector2(10+(i%8)*POCKET_STEP,22+(i/8)*POCKET_STEP),POCKET))
	# The pouch in hand (the hotbar row): a brass mark beside it.
	_pouch_marker = _label(inventory_panel,">",Vector2(3,27),8,GOLD)
	detail = _label(inventory_panel,"Right-click wears or eats; Shift-click moves.",Vector2(10,128),8,MINT)
	# Clip first: a label grows to its text until it clips, and then keeps that width.
	detail.clip_text = true
	detail.size.x = 168
	# Crafting: whatever the stations in reach allow (a workbench counts from
	# five tiles off: stand by it and open your pack).
	recipes_panel = _panel(root,Vector2(6,197),Vector2(320,70))
	_label(recipes_panel,"Crafting",Vector2(10,3),12,GOLD)
	station_label = _label(recipes_panel,"By hand",Vector2(78,8),8,MINT)
	station_label.clip_text = true
	station_label.size.x = 62
	var search := LineEdit.new()
	search.position = Vector2(142,5)
	search.placeholder_text = "Find..."
	search.text_changed.connect(func(value): query=value; _refresh_recipes())
	recipes_panel.add_child(search)
	search.size = Vector2(66,14)
	var selector := OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	selector.position = Vector2(211,5)
	for category in CraftingManager.categories: selector.add_item(category)
	selector.item_selected.connect(func(index): selected_category=CraftingManager.categories[index]; _refresh_recipes())
	recipes_panel.add_child(selector)
	selector.size = Vector2(62,14)
	var filter := _button(recipes_panel,"Ready",Vector2(276,5),Vector2(36,14),func(): craftable_only=not craftable_only; _refresh_recipes())
	filter.toggle_mode = true
	filter.tooltip_text = "Only what you can make now"
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8,22)
	scroll.size = Vector2(305,44)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipes_panel.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 14
	grid.add_theme_constant_override("h_separation",1)
	grid.add_theme_constant_override("v_separation",1)
	scroll.add_child(grid)
	recipe_list = grid
	_refresh_recipes()

func _process(delta: float) -> void:
	if is_instance_valid(player):
		bars.VITALITY.value = 100.0 * player.current_health / maxi(1,player.max_health)
		bars.HUNGER.value = 100.0 * player.current_hunger / maxi(1,player.max_hunger)
		status_values.VITALITY.text = str(ceili(player.current_health))
		status_values.HUNGER.text = str(ceili(player.current_hunger))
		# A low meter's icon beats: faster as it empties.
		_pulse += delta
		for name in ["VITALITY","HUNGER"]:
			var low: bool = bars[name].value < (30.0 if name == "VITALITY" else 20.0)
			var beat := 0.5 + 0.5 * sin(_pulse * (9.0 if name == "VITALITY" else 5.0))
			status_icons[name].modulate = Color(1.0 + 0.5 * beat, 1.0 + 0.2 * beat, 1.0 + 0.2 * beat) if low else Color.WHITE
			status_values[name].add_theme_color_override("font_color",UI.EMBER if low else PAPER)
		# News waits under an open panel (pass 13).
		if is_instance_valid(_banner): _banner.visible = not is_open()
		var bleeding: bool = player.get("bleed") != null and player.bleed.active()
		_bleed_box.visible = bleeding
		if bleeding: bleed_label.text = "BLEEDING  %ds" % ceili(player.bleed.time_left)
		_tick_meal_line(bleeding)
		var ash: float = float(player.get("ash")) if player.get("ash") != null else 0.0
		_ash_box.visible = ash > 0.04
		if _ash_box.visible:
			var choking := ash >= 1.0
			ash_label.text = "CHOKING" if choking else "ASH  %d%%" % int(round(ash * 100.0))
			ash_label.add_theme_color_override("font_color", UI.EMBER if choking else ASH)
			# Under the gifts line and the bleed box, whichever show.
			var gifts_on: bool = is_instance_valid(_gifts_box) and _gifts_box.visible
			_ash_box.position.y = UNDER_PLATE + (14.0 if gifts_on else 0.0) + (14.0 if bleeding else 0.0)
	if _last_selected != InventoryManager.selected_slot_index:
		_last_selected = InventoryManager.selected_slot_index
		update_inventory_display()
	_toast_time = maxf(0,_toast_time-delta)
	_toast_box.modulate.a = minf(1,_toast_time)
	_toast_box.visible = _toast_time > 0 and toast.text != ""
	if _toast_box.visible: _toast_box.position.y = _toast_top()
	if is_instance_valid(command_panel) and is_instance_valid(_wheel): _tick_wheel()
	# Pass 15: a cache (a container with a place) closes when the keeper walks away.
	if is_instance_valid(_active_chest) and _active_chest.has_meta("at") and is_instance_valid(player):
		if player.global_position.distance_to(_active_chest.get_meta("at")) > 72.0: close_panels()
	_roster_tick -= delta
	if roster_panel.visible and _roster_tick <= 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_roster_tick = 1.0
		_refresh_roster()

# Tab closes even while the recipe search owns keyboard focus. Letter shortcuts
# remain text while typing in that field.
func _input(event: InputEvent) -> void:
	if is_instance_valid(appearance_editor) and appearance_editor.is_open(): return
	if is_instance_valid(player) and player.get("respawning") == true: return
	var session := get_tree().get_first_node_in_group("forest_session")
	if session and is_instance_valid(session.get("fishing")) and session.fishing.is_active(): return
	if event is InputEventKey and not event.pressed and _wheel_hold and (event.keycode == KEY_Q or event.physical_keycode == KEY_Q):
		_wheel_hold = false
		# Let go pointing at an order: that order. Let go without pointing:
		# the wheel stays up, to be clicked (Esc closes it).
		if is_instance_valid(_wheel_pick) and is_instance_valid(command_panel): _wheel_pick.emit_signal("pressed")
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	var focus := get_viewport().gui_get_focus_owner()
	# Pass 15: Q over a pocket of the open pack drops one (Shift or Ctrl: the stack).
	if key == KEY_Q and inventory_panel and inventory_panel.visible and not focus is LineEdit:
		for slot in slots + hotbar:
			if is_instance_valid(slot) and slot.is_visible_in_tree() and slot.get("_is_hovered") == true:
				drop_to_world(slot, event.shift_pressed or event.ctrl_pressed)
				get_viewport().set_input_as_handled()
				return
	if key == KEY_ESCAPE and is_open():
		close_panels()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_CAPSLOCK and not focus is LineEdit:
		DragController.end_drag()
		InventoryManager.cycle_hotbar()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_L and not focus is LineEdit and is_instance_valid(skills_panel):
		if skills_panel.visible: close_panels()
		else: show_skills()
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_K,KEY_P] and not focus is LineEdit:
		if key == KEY_K:
			if equipment_panel.visible: close_panels()
			else: show_equipment()
		else:
			if roster_panel.visible: close_panels()
			else: show_roster()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_TAB or (key in [KEY_I,KEY_C] and not focus is LineEdit):
		if is_open(): close_panels()
		else: open_panels()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(appearance_editor) and appearance_editor.is_open(): return
	if event is InputEventMouseButton and event.pressed and not is_open():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventoryManager.scroll_hotbar(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled()

	for i in 8:
		if event.is_action_pressed("hotbar_%d" % (i+1)):
			InventoryManager.select_hotbar(i)
			get_viewport().set_input_as_handled()

func is_open() -> bool:
	return (is_instance_valid(skills_panel) and skills_panel.visible) or (inventory_panel != null and inventory_panel.visible) or (equipment_panel != null and equipment_panel.visible) or (roster_panel != null and roster_panel.visible) or is_instance_valid(command_panel) or (is_instance_valid(appearance_editor) and appearance_editor.is_open())

func open_panels() -> void:
	close_panels()
	inventory_panel.show()
	recipes_panel.show()
	equipment_panel.show()
	_set_pack_mode(true)
	AudioManager.play_sfx("pack_unzip")
	_unfold_satchel()
	_refresh_recipes()
	update_armor_display()

## While the pack is open its first row is the hotbar: the bottom hotbar, the
## pouch chip and the Satchel charm under the crafting bar step aside, and the
## task list (behind the gear) fades.
func _set_pack_mode(open: bool) -> void:
	if is_instance_valid(_hotbar_frame): _hotbar_frame.visible = not open
	if is_instance_valid(_pouch_box): _pouch_box.visible = not open
	if not shortcut_buttons.is_empty(): shortcut_buttons[0].visible = GameSettings.shortcut_buttons_visible and not open
	if is_instance_valid(_tasks_box): _tasks_box.modulate.a = 0.0 if open else 1.0

## The see-through full panels (skills, companions) would show the charms
## through them: they step aside while one is up.
func _set_charms_aside(aside: bool) -> void:
	for button in shortcut_buttons: button.visible = GameSettings.shortcut_buttons_visible and not aside

func close_panels() -> void:
	if is_instance_valid(appearance_editor):
		appearance_editor._cancel()
		appearance_editor=null
	if _interface_ready and inventory_panel and inventory_panel.visible: AudioManager.play_sfx("pack_zip")
	if is_instance_valid(_satchel_tween): _satchel_tween.kill()
	for panel in [inventory_panel, recipes_panel, equipment_panel]:
		if panel: panel.scale = Vector2.ONE
	inventory_panel.hide()
	recipes_panel.hide()
	close_chest()
	if equipment_panel: equipment_panel.hide()
	if is_instance_valid(_candidates): _candidates.hide()
	_set_pack_mode(false)
	_set_charms_aside(false)
	_wheel_hold = false
	_wheel_pick = null
	if roster_panel: roster_panel.hide()
	if is_instance_valid(skills_panel): skills_panel.hide()
	if _shade: _shade.hide()
	if is_instance_valid(command_panel):
		command_panel.hide()
		command_panel.queue_free()
	command_panel = null
	_command_target = null
	DragController.end_drag()

## The region plate (top right): where the keeper is.
var _region_plate: Control
var _region_label: Label
func set_region(title: String) -> void:
	if not is_instance_valid(_region_label): return
	_region_label.text = title
	_region_plate.reset_size()
	_region_plate.position = Vector2(475-_region_plate.size.x,3)
	_place_tasks()

## The tasks being followed (QuestManager), under the region plate: the task,
## then a line per goal. Refreshed when the tasks change.
var _tasks_box: Control
var _tasks_list: VBoxContainer
func show_tasks(tasks: Array, lines_for: Callable) -> void:
	if not is_instance_valid(_tasks_box):
		_tasks_box = _backing(root,Vector4(5,2,5,3))
		_tasks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tasks_list = VBoxContainer.new()
		_tasks_list.add_theme_constant_override("separation",0)
		_tasks_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tasks_box.add_child(_tasks_list)
	for child in _tasks_list.get_children(): child.queue_free()
	_tasks_box.visible = not tasks.is_empty()
	for q in tasks.slice(0, 3):
		var head := _label(_tasks_list,preload("res://Forest/world/Regions.gd").say(str(q.title),get_tree().get_first_node_in_group("forest_world")),Vector2.ZERO,8,GOLD)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for line in lines_for.call(q):
			var row := _label(_tasks_list,str(line),Vector2.ZERO,8,MINT if str(line).ends_with("done") else PAPER)
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place_tasks()

func _place_tasks() -> void:
	if not is_instance_valid(_tasks_box): return
	_tasks_box.reset_size()
	var top := 3.0 + (_region_plate.size.y + 3.0 if is_instance_valid(_region_plate) else 16.0)
	_tasks_box.position = Vector2(475-_tasks_box.size.x, top)

## The companions' gifts (Buffs.gd), a line under the vitals plate.
var _gifts_box: Control
var _meal_box: PanelContainer
var _meal_label: Label
var _meal_text := ""
const MEAL := Color("f0c27a")

## The meal line(s) under the plate, below the gifts, a bleed and the ash.
func _tick_meal_line(bleeding: bool) -> void:
	var buffs = player.get("food_buffs")
	var text := ""
	if buffs is Dictionary and not buffs.is_empty():
		text = "
".join(preload("res://Forest/life/Foods.gd").meal_lines(buffs))
	_meal_box.visible = text != ""
	if not _meal_box.visible: return
	if text != _meal_text:
		_meal_text = text
		_meal_label.text = text
		_meal_box.reset_size()
	var gifts_on: bool = is_instance_valid(_gifts_box) and _gifts_box.visible
	var ash_on: bool = is_instance_valid(_ash_box) and _ash_box.visible
	_meal_box.position.y = UNDER_PLATE + (14.0 if gifts_on else 0.0) + (14.0 if bleeding else 0.0) + (14.0 if ash_on else 0.0)
var _gifts_label: Label
func show_gifts(names: Array) -> void:
	if not is_instance_valid(_gifts_box):
		_gifts_box = _backing(root,Vector4(4,1,5,1))
		_gifts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gifts_label = _label(_gifts_box,"",Vector2.ZERO,8,MINT)
	_gifts_box.visible = not names.is_empty()
	_gifts_label.text = " · ".join(names)
	_gifts_box.reset_size()
	_gifts_box.position = Vector2(8,UNDER_PLATE)
	if is_instance_valid(_bleed_box): _bleed_box.position = Vector2(8,UNDER_PLATE + 14.0 if _gifts_box.visible else UNDER_PLATE)

## A boss's name and health across the top of the screen while the fight
## lasts (AlphaBoss): fades in on the first call, then just follows the health.
var _boss_plate: Control
var _boss_name: Label
var _boss_bar: Control
func show_boss(title: String, fraction: float) -> void:
	if not is_instance_valid(_boss_plate):
		_boss_plate = _panel(root,Vector2(170,4),Vector2(170,31))
		_boss_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_name = _label(_boss_plate,title,Vector2(6,1),11,GOLD)
		_boss_name.size.x = 158
		_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_bar = METER.new()
		_boss_bar.position = Vector2(8,18)
		_boss_bar.size = Vector2(154,8)
		_boss_bar.tint = UI.VITALITY
		_boss_plate.add_child(_boss_bar)
		_boss_plate.modulate.a = 0.0
		_boss_plate.create_tween().tween_property(_boss_plate,"modulate:a",1.0,0.5)
	_boss_name.text = title
	_boss_bar.value = clampf(fraction,0.0,1.0)*100.0

func hide_boss() -> void:
	if not is_instance_valid(_boss_plate): return
	var plate := _boss_plate
	_boss_plate = null
	var fade := plate.create_tween()
	fade.tween_property(plate,"modulate:a",0.0,0.6)
	fade.tween_callback(plate.queue_free)

func show_banner(title: String, text: String, icon: Texture2D = null, key := "") -> void:
	# (Pass 15: a banner with a key takes the place of a waiting one with the
	# same key: several levels at once make one banner.)
	if key != "":
		for i in _banners.size():
			if _banners[i].size() > 3 and str(_banners[i][3]) == key:
				_banners[i] = [title, text, icon, key]
				return
	_banners.append([title, text, icon, key])
	if not is_instance_valid(_banner): _next_banner()

## Whether a banner with this key is still waiting its turn.
func banner_waiting(key: String) -> bool:
	for entry in _banners:
		if entry.size() > 3 and str(entry[3]) == key: return true
	return false

func _next_banner() -> void:
	if _banners.is_empty(): return
	# Pass 13: the news waits while a panel is open.
	if is_open():
		get_tree().create_timer(0.6).timeout.connect(func(): if not is_instance_valid(_banner): _next_banner())
		return
	var entry: Array = _banners.pop_front()
	# Below the vitals plate, dropping a few pixels into place as it fades in.
	var plate := _panel(root,Vector2(100,42),Vector2(280,44))
	plate.modulate.a = 0.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.z_index = 10
	_banner = plate
	if entry[2] is Texture2D:
		var face := TextureRect.new()
		face.texture = entry[2]
		face.position = Vector2(8,6)
		face.size = Vector2(32,32)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(face)
	var title := _label(plate,str(entry[0]),Vector2(44,4),11,GOLD)
	title.size.x = 228
	var words := _label(plate,str(entry[1]),Vector2(45,21),8,PAPER)
	words.size = Vector2(228,20)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AudioManager.play_sfx("satchel_open")
	var tween := plate.create_tween()
	tween.tween_property(plate,"position:y",52.0,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(plate,"modulate:a",1.0,0.25)
	tween.tween_interval(5.0)
	tween.tween_property(plate,"modulate:a",0.0,0.6)
	tween.tween_callback(func():
		plate.queue_free()
		_banner = null
		_next_banner())

func show_toast(text: String) -> void:
	if toast:
		toast.text = text
		# Hug the words, right-aligned under the region name; long news wraps.
		toast.autowrap_mode = TextServer.AUTOWRAP_OFF
		toast.custom_minimum_size = Vector2.ZERO
		_toast_box.reset_size()
		if _toast_box.size.x > 300:
			toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			toast.custom_minimum_size.x = 290
			_toast_box.reset_size()
		_toast_box.position = Vector2(474-_toast_box.size.x,_toast_top())
	_toast_time = 3.0

## News goes under the region name, or under the tasks being tracked.
func _toast_top() -> float:
	if is_instance_valid(_tasks_box) and _tasks_box.visible:
		return _tasks_box.position.y + _tasks_box.size.y + 2.0
	return 22.0

func set_context(text: String) -> void:
	if context_label: context_label.text = text
	if text == _hint_text or _hint_row == null: return
	_hint_text = text
	_clear_children(_hint_row)
	for part in hint_parts(text):
		if _hint_row.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size.x = 5
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hint_row.add_child(gap)
		if part[0] != "":
			var cap := Label.new()
			cap.text = part[0]
			cap.add_theme_stylebox_override("normal",UI.box("chip",Vector4(3,1,3,2)))
			cap.add_theme_color_override("font_color",Color("f4e4b9"))
			_hint_row.add_child(cap)
		var action := Label.new()
		action.text = part[1]
		_hint_row.add_child(action)
	_hint.visible = text != ""
	_hint.reset_size()
	_hint.position = Vector2(roundi(240-_hint.size.x/2.0),216)

## Split a context line into [key, action] pairs: "E  Ride   Hold E  Commands"
## (two spaces inside a pair, three between pairs, or " · ") and world hints
## "AXE · Skywood tree" (a key in capitals first). Plain sentences stay whole.
static func hint_parts(text: String) -> Array:
	if text == "": return []
	if text.contains(" · ") and not text.contains("  "):
		var pieces := text.split(" · ",false,1)
		if pieces.size() == 2 and pieces[0] == pieces[0].to_upper(): return [[pieces[0],pieces[1]]]
		return [["",text]]
	var parts: Array = []
	for segment in text.split("   ",false):
		for piece in segment.split(" · ",false):
			var pair := piece.strip_edges().split("  ",false,1)
			if pair.size() == 2: parts.append([pair[0].strip_edges(),pair[1].strip_edges()])
			elif pair.size() == 1: parts.append(["",pair[0].strip_edges()])
	return parts

func update_inventory_display() -> void:
	var indices := InventoryManager.get_hotbar_indices()
	for i in hotbar.size():
		hotbar[i].slot_index = indices[i] if i < indices.size() else -1
		hotbar[i].visible = i < indices.size()
	var pouch: int = InventoryManager.hotbar_start/8
	for i in _pouch_pips.size():
		_pouch_pips[i].texture = load(UI.ART + ("pip_lit.png" if i == pouch else "pip.png"))
	if _hotbar_page: _hotbar_page.tooltip_text = "Caps Lock: next pouch of eight (pouch %d of 5)" % (pouch+1)
	if is_instance_valid(_pouch_marker): _pouch_marker.position.y = 27 + pouch * POCKET_STEP
	for slot in slots + hotbar + chest_slots:
		var source = slot._get_source()
		if not is_instance_valid(source) or slot.slot_index < 0 or slot.slot_index >= source.inventory.size(): continue
		var data: Dictionary = source.inventory[slot.slot_index]
		slot.tooltip_text=preload("res://UI/ItemDetails.gd").text(data.item) if data.item else ""
		slot.get_node("Icon").texture = data.item.icon if data.item else null
		slot.get_node("Quantity").text = str(data.quantity) if data.quantity > 1 else ""
		slot.add_theme_stylebox_override("panel",slot_style(slot))
	if recipe_list and is_open(): _refresh_recipes()
	if equipment_panel and equipment_panel.visible: _refresh_equipment()

func _refresh_recipes() -> void:
	if recipe_list == null: return
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	station_label.text = "By hand" if CraftingManager.nearby_stations.is_empty() else "At the " + str(CraftingManager.nearby_stations[0]).replace("_"," ")
	var recipes: Array = CraftingManager.get_recipes_by_category(selected_category).duplicate()
	recipes.sort_custom(func(a,b): return CraftingManager.can_craft_recipe(a) and not CraftingManager.can_craft_recipe(b))
	for recipe in recipes:
		if not query.is_empty() and not recipe.name.to_lower().contains(query.to_lower()): continue
		var available: bool = CraftingManager.can_craft_recipe(recipe)
		if craftable_only and not available: continue
		var quantity: int = recipe.get("quantity",1)
		var ingredients: Array[String] = []
		for id in recipe.ingredients:
			ingredients.append("%s %d/%d" % [CraftingManager.get_ingredient_name(id),InventoryManager.get_item_count(id),recipe.ingredients[id]])
		var station: String = recipe.get("station","")
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(POCKET,POCKET)
		b.add_theme_stylebox_override("normal",UI.box("slot"))
		b.add_theme_stylebox_override("hover",UI.box("slot_hover"))
		b.add_theme_stylebox_override("pressed",UI.box("slot_selected"))
		b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		b.icon = CraftingManager.get_item_icon(recipe.item_id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width",16)
		# What can't be made yet shows faded.
		b.modulate = Color.WHITE if available else Color(1,1,1,0.4)
		b.set_meta("recipe",recipe.item_id)
		b.name = "Recipe_" + str(recipe.item_id)
		b.tooltip_text = "%s%s\n%s\n%s\n%s" % [recipe.name," x%d" % quantity if quantity > 1 else "",str(recipe.get("description","")),", ".join(ingredients),("Click to make it" if available else ("Needs the " + station.replace("_"," ") if station != "" and not station in CraftingManager.nearby_stations else "Not enough yet")) + ("" if station == "" else "  (" + station.replace("_"," ") + ")")]
		b.pressed.connect(func():
			if CraftingManager.try_craft(recipe.item_id): show_toast("Crafted %s x%d" % [recipe.name,quantity])
			else: show_toast(CraftingManager.last_failure))
		recipe_list.add_child(b)

func show_slot_tooltip_for(slot: Control) -> void:
	var data: Dictionary = slot._get_source().inventory[slot.slot_index]
	if data.item:
		slot.tooltip_text = preload("res://UI/ItemDetails.gd").text(data.item)
		detail.text = data.item.name
	else: detail.text = "Empty slot"

func hide_slot_tooltip() -> void:
	if detail: detail.text = "Gather. Craft. Make a home."

func _unequip(slot_name: String) -> void:
	if not is_instance_valid(player): return
	var item: Item = player.equipped_armor.get(slot_name)
	if item == null: return
	if InventoryManager.add_item(item):
		player.equip_armor(slot_name,null)
		update_armor_display()
	else: show_toast("Your satchel is full")

func update_armor_display() -> void:
	_refresh_equipment()
	update_inventory_display()

func cross_swap(from_slot: Control, to_slot: Control) -> void:
	var a_source = from_slot._get_source()
	var b_source = to_slot._get_source()
	if a_source == b_source and from_slot.slot_index == to_slot.slot_index: return
	var a: Dictionary = a_source.inventory[from_slot.slot_index]
	var b: Dictionary = b_source.inventory[to_slot.slot_index]
	if a.item and b.item and a.item.id == b.item.id:
		var amount := mini(int(a.quantity),maxi(0,b.item.max_stack-int(b.quantity)))
		b.quantity += amount
		a.quantity -= amount
		if a.quantity == 0: a_source.inventory[from_slot.slot_index] = {"item":null,"quantity":0}
	else:
		a_source.inventory[from_slot.slot_index] = b
		b_source.inventory[to_slot.slot_index] = a
	a_source.inventory_changed.emit()
	if b_source != a_source: b_source.inventory_changed.emit()
	update_inventory_display()

func is_chest_open_for(chest: Node) -> bool:
	return _active_chest == chest

func open_chest(chest: Node) -> void:
	open_panels()
	_active_chest = chest
	var rows: int = ceili(float(chest.inventory.size()) / 9.0)
	chest_panel = _panel(root,Vector2(194,54),Vector2(208,42+rows*POCKET_STEP))
	var title := _label(chest_panel,str(chest.get("bag_title")) if chest.get("bag_title") != null else "Camp Storage",Vector2(10,3),12,GOLD)
	title.size.x = 188
	title.clip_text = true
	var take := _button(chest_panel,"Take all",Vector2(9,21),Vector2(46,13),func(): _chest_move_all(true))
	take.tooltip_text = "Everything in here into your pack"
	var put := _button(chest_panel,"Put all",Vector2(58,21),Vector2(42,13),func(): _chest_move_all(false))
	put.tooltip_text = "Everything in your pack in here (the pouch in hand stays with you)"
	var stack := _button(chest_panel,"Stack",Vector2(103,21),Vector2(36,13),_chest_stack)
	stack.tooltip_text = "Whatever this already holds, from your pack into it"
	var sort := _button(chest_panel,"Sort",Vector2(142,21),Vector2(32,13),_chest_sort)
	sort.tooltip_text = "Merge and sort what's in here"
	for i in chest.inventory.size():
		chest_slots.append(_slot(chest_panel,i,Vector2(10+(i%9)*POCKET_STEP,37+(i/9)*POCKET_STEP),POCKET,chest))
	chest.inventory_changed.connect(update_inventory_display)
	update_inventory_display()

## Take all (into the pack) or put all (out of the pack, the pouch in hand kept).
func _chest_move_all(take: bool) -> void:
	if not is_instance_valid(_active_chest): return
	var source = _active_chest if take else InventoryManager
	var target = InventoryManager if take else _active_chest
	var keep: Array = [] if take else InventoryManager.get_hotbar_indices()
	var moved := 0
	var left := 0
	for i in source.inventory.size():
		if i in keep: continue
		var entry: Dictionary = source.inventory[i]
		if entry.item == null: continue
		# Whatever fits goes (Terraria's way); the rest stays where it was.
		var fit: int = mini(int(entry.quantity), int(target.capacity_for(entry.item)))
		if fit > 0 and target.add_item(entry.item, fit):
			moved += fit
			source.inventory[i] = {"item":null,"quantity":0} if fit >= int(entry.quantity) else {"item":entry.item,"quantity":int(entry.quantity) - fit}
		if fit < int(entry.quantity): left += 1
	source.inventory_changed.emit()
	target.inventory_changed.emit()
	update_inventory_display()
	if moved == 0 and left > 0: show_toast("No room for any of it")
	elif left > 0: show_toast("Moved %d; %d stacks didn't fit" % [moved, left])

## Whatever this chest already holds, from the pack (not the pouch in hand).
func _chest_stack() -> void:
	if not is_instance_valid(_active_chest): return
	var have := {}
	for entry in _active_chest.inventory:
		if entry.item: have[entry.item.id] = true
	var keep := InventoryManager.get_hotbar_indices()
	var moved := 0
	for i in InventoryManager.inventory.size():
		var entry: Dictionary = InventoryManager.inventory[i]
		if i in keep or entry.item == null or not have.has(entry.item.id): continue
		var fit: int = mini(int(entry.quantity), int(_active_chest.capacity_for(entry.item)))
		if fit > 0 and _active_chest.add_item(entry.item, fit):
			moved += fit
			InventoryManager.inventory[i] = {"item":null,"quantity":0} if fit >= int(entry.quantity) else {"item":entry.item,"quantity":int(entry.quantity) - fit}
	InventoryManager.inventory_changed.emit()
	_active_chest.inventory_changed.emit()
	update_inventory_display()
	show_toast("Stacked %d into it" % moved if moved else "Nothing in your pack matches what's in here")

## Merge the chest's stacks and sort them by name.
func _chest_sort() -> void:
	if not is_instance_valid(_active_chest): return
	var stacks: Array = []
	for entry in _active_chest.inventory:
		if entry.item == null: continue
		var left: int = int(entry.quantity)
		for stack in stacks:
			if stack.item.id == entry.item.id:
				var add := mini(left, maxi(0, int(stack.item.max_stack) - int(stack.quantity)))
				stack.quantity += add
				left -= add
		if left > 0: stacks.append({"item":entry.item,"quantity":left})
	stacks.sort_custom(func(a, b): return (a.item.name + "/" + a.item.id).naturalnocasecmp_to(b.item.name + "/" + b.item.id) < 0)
	for i in _active_chest.inventory.size():
		_active_chest.inventory[i] = stacks[i] if i < stacks.size() else {"item":null,"quantity":0}
	_active_chest.inventory_changed.emit()
	update_inventory_display()

func close_chest() -> void:
	if is_instance_valid(_active_chest) and _active_chest.inventory_changed.is_connected(update_inventory_display):
		_active_chest.inventory_changed.disconnect(update_inventory_display)
	_active_chest = null
	chest_slots.clear()
	if is_instance_valid(chest_panel): chest_panel.queue_free()
	chest_panel = null

func close_chest_if_open() -> void:
	close_chest()

func transfer_slot(slot_control: Control) -> void:
	if not is_instance_valid(_active_chest): return
	var source = slot_control._get_source()
	var target = _active_chest if source == InventoryManager else InventoryManager
	var data: Dictionary = source.inventory[slot_control.slot_index]
	if data.item == null: return
	var capacity := 0
	for other in target.inventory:
		if other.item == null: capacity += data.item.max_stack
		elif other.item.id == data.item.id: capacity += maxi(0,data.item.max_stack-int(other.quantity))
	if capacity < int(data.quantity):
		show_toast("Destination has no room for this stack")
		return
	if target.add_item(data.item,data.quantity):
		source.inventory[slot_control.slot_index] = {"item":null,"quantity":0}
		source.inventory_changed.emit()
	update_inventory_display()




## Pass 15: drop what's in one of the keeper's pack slots (not a chest's) at
## their feet, a step ahead: one of it, or the whole stack.
func drop_to_world(slot: Control, all := true) -> bool:
	if not is_instance_valid(slot) or slot.get("source") != null or not is_instance_valid(player): return false
	var index: int = int(slot.slot_index)
	if index < 0 or index >= InventoryManager.inventory.size(): return false
	var entry: Dictionary = InventoryManager.inventory[index]
	if entry.item == null or int(entry.quantity) <= 0: return false
	var count: int = int(entry.quantity) if all else 1
	var item: Item = entry.item
	InventoryManager.inventory[index] = {"item": null, "quantity": 0} if count >= int(entry.quantity) else {"item": item, "quantity": int(entry.quantity) - count}
	InventoryManager.inventory_changed.emit()
	var facing := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(str(player.get("last_facing")), Vector2.DOWN) as Vector2
	var drop = preload("res://Items/DroppedItem.tscn").instantiate()
	drop.setup_item(item, count)
	var holder: Node = get_tree().get_first_node_in_group("forest_session")
	if holder == null: holder = player.get_parent()
	holder.add_child(drop)
	drop.global_position = player.global_position + facing * 16.0 + Vector2(0, 4)
	drop.hold_off()
	AudioManager.play_sfx("unequip_gear")
	update_inventory_display()
	show_toast("Dropped %s%s" % [item.name, (" x%d" % count) if count > 1 else ""])
	return true

## Whether a screen point is over one of the open panels (a drag let go there
## isn't a drop into the world), or within `margin` px of one (a drag that
## just slipped past a panel's edge is let go, not thrown away).
func is_over_panel(pos: Vector2, margin := 0.0) -> bool:
	for p in [inventory_panel, recipes_panel, equipment_panel, chest_panel, _candidates, roster_panel, skills_panel, command_panel]:
		if p is Control and is_instance_valid(p) and p.is_visible_in_tree() and p.get_global_rect().grow(margin).has_point(pos): return true
	return false

func select_slot(slot: Control) -> void:
	if slot in hotbar:
		InventoryManager.selected_slot_index = slot.slot_index
		update_inventory_display()

func _exit_tree() -> void:
	# DragController is an autoload; do not let it retain a freed slot across scenes.
	DragController.end_drag()

## Pass 14: the gear down the pack's right edge: head, body, legs and the
## light in one column, five trinkets in the other. Right-click something in
## the pack to wear it; click a worn piece to take it off; click an empty place
## for a short list of what fits it.
const GEAR_AT := Vector2(406, 54)
const GEAR_SLOTS := [["head","Head",0,0],["chest","Body",0,1],["legs","Legs",0,2],["light","Light",0,3],
	["trinket_0","Trinket I",1,0],["trinket_1","Trinket II",1,1],["trinket_2","Trinket III",1,2],["trinket_3","Trinket IV",1,3],["trinket_4","Trinket V",1,4]]
func _build_equipment() -> void:
	equipment_panel = _panel(root,GEAR_AT,Vector2(70,142))
	_label(equipment_panel,"Gear",Vector2(10,3),12,GOLD)
	for entry in GEAR_SLOTS:
		var target: String = entry[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.name = "Equip_" + target
		b.position = Vector2(10 + int(entry[2]) * 28, 22 + int(entry[3]) * POCKET_STEP)
		b.set_meta("caption",entry[1])
		b.add_theme_stylebox_override("normal",UI.box("slot"))
		b.add_theme_stylebox_override("hover",UI.box("slot_hover"))
		b.add_theme_stylebox_override("pressed",UI.box("slot_selected"))
		b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width",16)
		b.pressed.connect(func(): _gear_clicked(target))
		b.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: _take_off(target))
		equipment_panel.add_child(b)
		b.size = Vector2(POCKET,POCKET)
		armor_buttons[target] = b
	equipment_summary = _label(equipment_panel,"",Vector2(9,106),8,MINT)
	equipment_summary.size = Vector2(24,20)
	_button(equipment_panel,"Appearance",Vector2(6,126),Vector2(58,13),show_appearance)
	# (The old gear screen's hint line; kept for callers that still set it.)
	equipment_hint = _label(equipment_panel,"",Vector2(0,0),8,GOLD)
	equipment_hint.hide()
	# What fits an empty place: a short list beside the gear.
	_candidates = _panel(root,Vector2(280,54),Vector2(124,104))
	_label(_candidates,"Wear...",Vector2(10,3),12,GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(7,22)
	scroll.size = Vector2(111,76)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_candidates.add_child(scroll)
	equipment_list = VBoxContainer.new()
	equipment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_list.add_theme_constant_override("separation",2)
	scroll.add_child(equipment_list)
	_candidates.hide()

## A place in the gear clicked: take off what's there, or list what fits it.
func _gear_clicked(target: String) -> void:
	if not is_instance_valid(player): return
	if player.get_equipment(target) != null:
		_take_off(target)
		return
	_equipment_target = target
	_candidates.show()
	_refresh_equipment()

func _take_off(target: String) -> void:
	if not is_instance_valid(player) or player.get_equipment(target) == null: return
	if player.unequip_to_inventory(target):
		AudioManager.play_sfx("unequip_gear")
		_refresh_equipment()
		update_inventory_display()
	else: show_toast("Your pack is full")

func show_equipment() -> void:
	open_panels()

func show_appearance() -> void:
	if not is_instance_valid(player) or is_instance_valid(appearance_editor): return
	appearance_editor=preload("res://UI/CharacterCreator.gd").new()
	appearance_editor.configure(player.appearance,player,false)
	appearance_editor.accepted.connect(func(value):
		player.apply_appearance(value)
		_refresh_equipment()
		show_toast("Your keeper's appearance is saved with the journey"))
	add_child(appearance_editor)

func _refresh_equipment() -> void:
	if not equipment_panel or not is_instance_valid(player): return
	for target in armor_buttons:
		var item: Item = player.get_equipment(target) if player.has_method("get_equipment") else player.equipped_armor.get(target)
		var b: Button = armor_buttons[target]
		b.icon = item.icon if item else null
		b.text = ""
		b.tooltip_text = (preload("res://UI/ItemDetails.gd").text(item) + "\nClick to take it off") if item else "%s: empty. Click for what fits (or right-click it in your pack)." % str(b.get_meta("caption"))
		b.modulate = Color.WHITE if item else Color(1,1,1,0.7)
	var defence: int = int(player.defense) + (SetBonus.defense_bonus(player) if SetBonus else 0)
	equipment_summary.text = "DEF\n%d" % defence
	equipment_summary.tooltip_text = player.get_equipment_summary() if player.has_method("get_equipment_summary") else ""
	if not is_instance_valid(_candidates) or not _candidates.visible: return
	_clear_children(equipment_list)
	var count := 0
	for i in InventoryManager.inventory.size():
		var item: Item = InventoryManager.inventory[i].item
		if not item or not _matches_slot(item,_equipment_target): continue
		count += 1
		var index := i
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = item.name
		b.icon = item.icon
		b.expand_icon = true
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width",14)
		b.custom_minimum_size = Vector2(108,18)
		b.tooltip_text = preload("res://UI/ItemDetails.gd").text(item)
		b.pressed.connect(func():
			if player.has_method("equip_from_inventory") and player.equip_from_inventory(index,_equipment_target):
				AudioManager.play_sfx("equip_gear")
				show_toast("Wearing " + item.name)
				_candidates.hide()
			else: show_toast("That can't go there")
			_refresh_equipment()
			update_inventory_display())
		equipment_list.add_child(b)
	if count == 0:
		var empty := Label.new()
		empty.text = "Nothing in your pack fits.\nCraft some at a workbench."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(108,0)
		empty.add_theme_color_override("font_color",MINT)
		equipment_list.add_child(empty)

func _matches_slot(item: Item,target: String) -> bool:
	if target in ["head","chest","legs"]: return item.armor_slot == target
	if target == "light": return item.id in ["torch","lantern"] or item.get("equipment_slot") == "light"
	return item.get("equipment_slot") == "trinket"

func _build_roster() -> void:
	roster_panel = _panel(root,Vector2(54,27),Vector2(372,205))
	_label(roster_panel,"BONDED COMPANIONS",Vector2(14,7),11,GOLD)
	_button(roster_panel,"Close",Vector2(313,7),Vector2(46,17),close_panels)
	_label(roster_panel,"Your companions, their health and their orders.",Vector2(13,29),8,MINT)
	_button(roster_panel,"Command all",Vector2(251,47),Vector2(106,18),func():show_companion_commands(null))
	_label(roster_panel,"Hold E: orders / Tap E: ride / F: feed",Vector2(13,50),7,GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12,70)
	scroll.size = Vector2(348,124)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_panel.add_child(scroll)
	roster_list = VBoxContainer.new()
	roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_list.add_theme_constant_override("separation",4)
	scroll.add_child(roster_list)

## The skills (pass 13): built once the session hands its Skills node over.
func setup_skills(skills: Node) -> void:
	skills_panel = preload("res://UI/SkillsPanel.gd").new()
	root.add_child(skills_panel)
	skills_panel.setup(self, skills)
	skills_panel.hide()
	root.move_child(skills_panel, root.get_child_count() - 1)

func show_skills() -> void:
	if not is_instance_valid(skills_panel): return
	close_panels()
	_shade.show()
	_set_charms_aside(true)
	skills_panel.open()

func show_roster() -> void:
	close_panels()
	_shade.show()
	_set_charms_aside(true)
	roster_panel.show()
	_refresh_roster()

func _companions() -> Array[Node]:
	var result: Array[Node] = []
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.tamed and not creature.is_dead: result.append(creature)
	return result

func _refresh_roster() -> void:
	if not roster_list: return
	_clear_children(roster_list)
	var companions := _companions()
	if companions.is_empty():
		var label := Label.new()
		label.text = "No bonds yet.\nOffer berries to herbivores.\nRestrain predators before offering meat."
		roster_list.add_child(label)
		return
	for creature in companions:
		var row := Panel.new()
		row.custom_minimum_size = Vector2(335,47)
		row.add_theme_stylebox_override("panel",UI.box("card"))
		roster_list.add_child(row)
		var image := TextureRect.new()
		image.position = Vector2(3,3)
		image.size = Vector2(43,38)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if creature._sprite and creature._sprite.sprite_frames:
			image.texture = creature._sprite.sprite_frames.get_frame_texture("idle_side",0)
		row.add_child(image)
		_label(row,creature.stats.name,Vector2(50,4),8,GOLD)
		var stance: String = creature.get("stance") if creature.get("stance") != null else "neutral"
		var distance := int(creature.global_position.distance_to(player.global_position)/16.0) if player else 0
		var status_text: String=creature.get_status_summary() if creature.has_method("get_status_summary") else "%s / %s / %d tiles away" % [creature.order.capitalize(),stance.capitalize(),distance]
		var status_label:=_label(row,status_text,Vector2(50,16),8,MINT)
		status_label.size.x=270
		status_label.clip_text=true
		row.tooltip_text=status_text
		var meter := METER.new()
		meter.position = Vector2(50,31)
		meter.size = Vector2(110,9)
		meter.tint = Color("e08a74")
		meter.value = 100.0*creature.health/maxi(1,creature.stats.hp)
		row.add_child(meter)
		_label(row,"%d / %d" % [creature.health,creature.stats.hp],Vector2(165,31),8)
		var target: Node = creature
		_button(row,"Locate",Vector2(222,25),Vector2(48,18),func():_locate_companion(target))
		_button(row,"Orders",Vector2(274,25),Vector2(52,18),func():
			if is_instance_valid(target): show_companion_commands(target))

## Pass 14: orders on a wheel, ARK's way (hold Q): the orders round an oval
## rim, the temperaments stacked in its middle, the rarer things in a row
## beneath. Point at one and let go of Q, or click it. Small and see-through:
## the world stays in view.
const WHEEL_AT := Vector2(240, 120)
## The wheel's middle in its own panel, and the oval the orders sit on.
const WHEEL_MID := Vector2(116, 104)
const WHEEL_RX := 84.0
const WHEEL_RY := 58.0
func show_companion_commands(creature: Node = null, from_hold := false) -> void:
	if creature != null and (not is_instance_valid(creature) or not creature.tamed or creature.is_dead): return
	close_panels()
	_command_target = creature
	_command_is_group = creature == null
	_wheel_hold = from_hold
	_wheel_pick = null
	_wheel_from = Vector2.INF
	_wheel_moved = false
	_wheel_outer.clear()
	_wheel_inner.clear()
	var mountable: bool = creature != null and creature.species in ["stego","trike"]
	var worker: bool=creature!=null and creature.species in ["stego","trike","dodo"]
	command_panel = Panel.new()
	command_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	command_panel.position = WHEEL_AT - WHEEL_MID
	command_panel.size = Vector2(232,184)
	root.add_child(command_panel)
	_wheel = OrderWheel.new()
	_wheel.center = WHEEL_MID
	_wheel.rx = WHEEL_RX
	_wheel.ry = WHEEL_RY
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	command_panel.add_child(_wheel)
	var title: String = creature.stats.name if creature != null else "All companions"
	# The name, in the oval between the top orders and the temperaments.
	var title_label := _label(command_panel,title,Vector2(0,WHEEL_MID.y - 36.0),8,GOLD)
	title_label.size.x = 232
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	# The rim: the orders, and a companion's own doings.
	var rim: Array = []
	var orders := ["follow","stay","guard","roam"]
	var tips := {"follow":"Travel with you and wade through shallow water.","stay":"Remain exactly here until given another order.","guard":"Defend this spot, within your chosen temperament.","roam":"Wander close to this spot.","work":"Gather your specialty near your home and store it in the assigned chest.","return":"Return to your work home."}
	if worker: orders.append_array(["work","return"])
	for order_name in orders:
		var b := _wheel_button(order_name.capitalize(),func():_apply_companion_command("order",order_name))
		b.tooltip_text = tips[order_name]
		if creature != null and creature.order == order_name: b.add_theme_stylebox_override("normal",UI.box("button_on",Vector4(4,2,4,2)))
		rim.append(b)
	if creature:
		if mountable:
			rim.append(_wheel_button("Ride",func():
				if is_instance_valid(creature) and creature.has_method("mount"):
					if creature.mount(player): close_panels()
					else: show_toast("Equip a saddle and move closer to ride")))
		rim.append(_wheel_button("Care",func():show_companion_care(creature)))
		rim.append(_wheel_button("Pet",func():_pet_companion(creature)))
	for i in rim.size():
		_place_on_wheel(rim[i], -PI/2 + TAU * float(i) / float(rim.size()))
	_wheel_outer = rim
	_wheel.slots = rim.size()
	# In the middle, stacked: the temperaments.
	for i in 3:
		var stance_name: String = ["passive","neutral","aggressive"][i]
		var b := _wheel_button(stance_name.capitalize(),func():_apply_companion_command("stance",stance_name))
		b.tooltip_text = ["Never attack. Use this to withdraw safely.","Defend yourself and your keeper when attacked.","Seek nearby hostile wildlife."][i]
		if creature != null and creature.get("stance") == stance_name: b.add_theme_stylebox_override("normal",UI.box("button_on",Vector4(4,2,4,2)))
		b.size.x = 58.0
		b.position = WHEEL_MID + Vector2(-29.0, -22.0 + 15.0 * i)
		_wheel_inner.append(b)
	# Beneath: the rarer things.
	var row: Array = []
	if creature:
		if worker:
			row.append(_wheel_button("Set work home",func():
				if is_instance_valid(creature): show_toast("Work home set" if creature.set_work_home() else "Cannot set work home here")))
			row.append(_wheel_button("Assign chest",func():
				if is_instance_valid(creature): show_toast("Nearby chest assigned" if creature.assign_nearest_work_chest() else "No suitable chest near work home")))
		if mountable:
			row.append(_wheel_button("Equip saddle",func():_equip_saddle(creature)))
			row.append(_wheel_button("Remove",func():
				if is_instance_valid(creature) and creature.has_method("unequip_saddle"):
					if creature.unequip_saddle():
						AudioManager.play_sfx("unequip_gear")
						show_companion_commands(creature)
						show_toast("Saddle removed")
					else: show_toast("Cannot remove saddle; dismount and check satchel space")))
		row.append(_wheel_button("Locate companion",func():_locate_companion(creature)))
		row.append(_wheel_button("Back to bonds",show_roster))
	var line_y := 186.0
	var widths: Array = []
	for b in row: widths.append(b.size.x)
	# Two lines when they won't fit in one.
	var per_line: int = row.size() if row.size() <= 3 else ceili(row.size() / 2.0)
	for i in row.size():
		var line: int = i / maxi(1, per_line)
		var first: int = line * per_line
		var count: int = mini(per_line, row.size() - first)
		var span := 0.0
		for j in count: span += float(widths[first + j]) + 3.0
		var left := WHEEL_MID.x - span / 2.0
		for j in i - first: left += float(widths[first + j]) + 3.0
		row[i].position = Vector2(left, line_y + line * 17.0)
	if not row.is_empty(): command_panel.size.y = 186.0 + 17.0 * ceilf(float(row.size()) / maxf(1.0, float(per_line)))
	var hint := _label(command_panel,"Point, let go of Q" if from_hold else "Click an order",Vector2(0,WHEEL_MID.y + 27.0),8,MINT)
	hint.size.x = 232
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.visible = creature == null or from_hold

## A small leather tab for the wheel (a direct child of the panel: the tests
## and the mouse find it by its text).
func _wheel_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	b.pressed.connect(func(): AudioManager.play_sfx("equip_gear"))
	command_panel.add_child(b)
	b.size = Vector2(maxf(40.0, float(text.length()) * 5.0 + 10.0), 14)
	return b

func _place_on_wheel(b: Button, angle: float) -> void:
	b.set_meta("angle", angle)
	b.position = WHEEL_MID + Vector2(cos(angle) * WHEEL_RX, sin(angle) * WHEEL_RY) - b.size / 2.0

## While the wheel is up: the order the pointer is toward (the rim, or the
## temperaments nearer the middle), lit, and taken when Q is let go.
func _tick_wheel() -> void:
	if not is_instance_valid(command_panel) or not is_instance_valid(_wheel): return
	var mouse: Vector2 = command_panel.get_local_mouse_position()
	if _wheel_from == Vector2.INF: _wheel_from = mouse
	if not _wheel_moved and mouse.distance_to(_wheel_from) > 4.0: _wheel_moved = true
	var local: Vector2 = mouse - WHEEL_MID
	# How far round the oval (1.0 on the rim the orders sit on).
	var oval := Vector2(local.x / WHEEL_RX, local.y / WHEEL_RY)
	var pick: Button = null
	var best := INF
	if not _wheel_moved: pass
	elif absf(local.x) < 34.0 and absf(local.y) < 26.0:
		# The middle: the temperament nearest the pointer.
		for b in _wheel_inner:
			if not is_instance_valid(b): continue
			var gap: float = (b.position + b.size / 2.0).distance_to(mouse)
			if gap < best:
				best = gap
				pick = b
	# The rim (not down in the row of rarer things beneath the wheel).
	elif oval.length() > 0.62 and oval.length() < 1.45 and local.y < 80.0:
		for b in _wheel_outer:
			if not is_instance_valid(b): continue
			var diff: float = absf(wrapf(oval.angle() - float(b.get_meta("angle")), -PI, PI))
			if diff < best:
				best = diff
				pick = b
	if pick != _wheel_pick:
		if is_instance_valid(_wheel_pick): _wheel_pick.remove_theme_stylebox_override("hover")
		_wheel_pick = pick
		for b in _wheel_outer + _wheel_inner:
			if is_instance_valid(b): b.modulate = Color(1,1,1,1) if b == pick or pick == null else Color(1,1,1,0.7)
	_wheel.pick_angle = float(pick.get_meta("angle")) if pick and pick in _wheel_outer else INF
	_wheel.pick_rect = Rect2(pick.position - Vector2(2, 1), pick.size + Vector2(4, 2)) if pick and pick in _wheel_inner else Rect2()
	_wheel.queue_redraw()

## The wheel's backdrop: a see-through leather oval, a brass rim, and the
## slice (or the temperament) the pointer is toward, lit.
class OrderWheel extends Control:
	var center := Vector2.ZERO
	var rx := 84.0
	var ry := 58.0
	var slots := 4
	var pick_angle := INF
	var pick_rect := Rect2()

	func _oval(sx: float, sy: float, a0 := 0.0, a1 := TAU, steps := 48) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in steps + 1:
			var a: float = a0 + (a1 - a0) * float(k) / float(steps)
			pts.append(center + Vector2(cos(a) * sx, sin(a) * sy))
		return pts

	func _draw() -> void:
		var disc := _oval(rx + 28.0, ry + 20.0)
		draw_colored_polygon(disc, Color(0.11, 0.07, 0.045, 0.5))
		draw_polyline(disc, Color(0.85, 0.66, 0.37, 0.7), 1.0)
		draw_polyline(_oval(rx * 0.56, ry * 0.58), Color(0.85, 0.66, 0.37, 0.3), 1.0)
		if pick_angle != INF:
			var span: float = PI / float(maxi(slots, 1))
			var outer := _oval((rx + 28.0) * 0.98, (ry + 20.0) * 0.98, pick_angle - span, pick_angle + span, 10)
			var inner := _oval(rx * 0.58, ry * 0.6, pick_angle + span, pick_angle - span, 10)
			outer.append_array(inner)
			draw_colored_polygon(outer, Color(0.85, 0.66, 0.37, 0.2))
		if pick_rect.has_area():
			draw_rect(pick_rect, Color(0.85, 0.66, 0.37, 0.25))

## Pass 13: a companion's care. What it is (temperament, traits, a mutation's
## colour; its stats once the Sky-Fang lens is won), its saddlebags, the lead
## rope and the hitching post, and a little training.
func show_companion_care(creature: Node) -> void:
	if not is_instance_valid(creature) or not creature.tamed or creature.is_dead: return
	close_panels()
	_shade.show()
	_command_target = creature
	_command_is_group = false
	command_panel = _panel(root,Vector2(101,20),Vector2(278,226))
	var title := _label(command_panel,str(creature.stats.name),Vector2(13,8),10,GOLD)
	title.size.x = 228
	title.clip_text = true
	_button(command_panel,"X",Vector2(247,8),Vector2(18,17),close_panels)
	var looks: String = preload("res://Forest/creatures/Genes.gd").looks(creature.genes) if creature.get("genes") != null else ""
	var about := _label(command_panel,looks if looks != "" else "An ordinary one of its kind.",Vector2(13,30),8,MINT)
	about.size.x = 252
	about.clip_text = true
	var reading: String = creature.stat_reading() if creature.has_method("stat_reading") else ""
	var stats_line := _label(command_panel,"",Vector2(13,42),7 if reading == "" else 8,PAPER if reading != "" else EDGE)
	stats_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_line.size = Vector2(252,20)
	stats_line.text = reading if reading != "" else "Its strengths can't be read yet (beat two great beasts: the Sky-Fang lens)."
	# Saddlebags.
	_label(command_panel,"Saddlebags",Vector2(13,64),9,MINT)
	var bag = creature.get("bag")
	_label(command_panel,("%d of %d slots used" % [bag.used(), bag.inventory.size()]) if bag else "None fitted",Vector2(96,66),8,GOLD)
	if bag:
		_button(command_panel,"Open",Vector2(13,80),Vector2(81,21),func():
			if is_instance_valid(creature) and creature.bag: open_chest(creature.bag))
		_button(command_panel,"Take off",Vector2(99,80),Vector2(81,21),func():
			var why: String = creature.remove_bag()
			show_toast("Saddlebags taken off." if why == "" else why)
			show_companion_care(creature))
	else:
		_button(command_panel,"Fit saddlebags",Vector2(13,80),Vector2(123,21),func():
			var why: String = creature.fit_bag()
			show_toast("Saddlebags fitted: %d slots." % creature.bag_slots() if why == "" else why)
			show_companion_care(creature))
	# The rope.
	_label(command_panel,"Rope",Vector2(13,106),9,MINT)
	var roped: bool = creature.order in ["lead", "tether"]
	_label(command_panel,{"lead": "On the lead", "tether": "Tied to a post"}.get(creature.order, "Free (a lead rope: %d)" % InventoryManager.get_item_count("lead_rope")),Vector2(56,108),8,GOLD)
	_button(command_panel,"Lead",Vector2(13,122),Vector2(81,21),func():
		show_toast("On the lead rope: it heels and won't fight." if creature.set_order("lead") else "You need a lead rope (Taming: Rope-craft).")
		show_companion_care(creature))
	_button(command_panel,"Tie to post",Vector2(99,122),Vector2(81,21),func():
		show_toast("Tied to the hitching post." if creature.set_order("tether") else "Bring it next to a hitching post, with a lead rope.")
		show_companion_care(creature))
	var untie := _button(command_panel,"Let go",Vector2(185,122),Vector2(81,21),func():
		creature.set_order("follow")
		show_toast("The rope comes off: it follows you.")
		show_companion_care(creature))
	untie.disabled = not roped
	# Training.
	_label(command_panel,"Training",Vector2(13,148),9,MINT)
	var rest: float = float(creature.get("_train_rest")) if creature.get("_train_rest") != null else 0.0
	_label(command_panel,("Rested: ready" if rest <= 0.0 else "Resting %d s" % int(ceil(rest))) + ("  ·  4 %s a session" % preload("res://Forest/creatures/TamingWays.gd").food_name(str(creature.stats.food))),Vector2(76,150),8,GOLD)
	var train: Dictionary = creature.genes.get("train", {}) if creature.get("genes") != null else {}
	var names := {"hp": "Health", "damage": "Bite", "speed": "Pace"}
	var i := 0
	for stat in ["hp", "damage", "speed"]:
		var ranks := int(train.get(stat, 0))
		var b := _button(command_panel,"%s %d/3" % [names[stat], ranks],Vector2(13 + i * 86,164),Vector2(81,21),func():
			var why: String = creature.train(stat)
			show_toast(("%s trained: +1.7%% %s." % [creature.stats.name, names[stat].to_lower()]) if why == "" else why)
			show_companion_care(creature))
		b.disabled = ranks >= 3
		i += 1
	_button(command_panel,"Back",Vector2(185,196),Vector2(81,21),func():show_companion_commands(creature))

func _apply_companion_command(kind: String,value: String) -> void:
	var targets: Array[Node] = []
	if _command_is_group: targets = _companions()
	elif is_instance_valid(_command_target): targets.append(_command_target)
	else:
		close_panels()
		show_toast("This companion is no longer available")
		return
	var count := 0
	for creature in targets:
		if not is_instance_valid(creature) or creature.is_dead or not creature.tamed: continue
		if kind == "order" and creature.has_method("set_order"): creature.set_order(value)
		elif kind == "stance" and creature.has_method("set_stance"): creature.set_stance(value)
		else: continue
		count += 1
	close_panels()
	show_toast("%s: %d companion%s" % [value.capitalize(),count,"" if count == 1 else "s"])

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _unfold_satchel() -> void:
	if is_instance_valid(_satchel_tween): _satchel_tween.kill()
	# The flap drops open from the top, crafting rises from below, the gear
	# swings in from the edge.
	inventory_panel.pivot_offset = Vector2(inventory_panel.size.x/2,0)
	recipes_panel.pivot_offset = Vector2(0,recipes_panel.size.y)
	equipment_panel.pivot_offset = Vector2(equipment_panel.size.x,0)
	inventory_panel.scale = Vector2(1,0.06)
	recipes_panel.scale = Vector2(1,0.06)
	equipment_panel.scale = Vector2(0.06,1)
	_satchel_tween = create_tween().set_parallel(true)
	_satchel_tween.tween_property(inventory_panel,"scale",Vector2.ONE,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_satchel_tween.tween_property(recipes_panel,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(0.06)
	_satchel_tween.tween_property(equipment_panel,"scale",Vector2.ONE,0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(0.09)

func _locate_companion(creature: Node) -> void:
	var session := get_tree().get_first_node_in_group("forest_session")
	if is_instance_valid(creature) and session and session.has_method("locate_companion"):
		close_panels()
		session.locate_companion(creature)

func _pet_companion(creature: Node) -> void:
	if not is_instance_valid(creature) or creature.is_dead or not creature.tamed: return
	if player.global_position.distance_to(creature.global_position)>50:
		show_toast("Move closer to pet your companion")
		return
	var query:=PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,8),creature.global_position+Vector2(0,8),16)
	query.exclude=[player.get_rid(),creature.get_rid()]
	if not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		show_toast("Move around the obstacle to your companion")
		return
	close_panels()
	player.play_action("pet",creature.global_position)
	show_toast("A quiet moment with "+creature.stats.name)

func _equip_saddle(creature: Node) -> void:
	if not is_instance_valid(creature) or not creature.has_method("equip_saddle_from_inventory"): return
	var id: String = creature.species+"_saddle"
	for i in InventoryManager.inventory.size():
		var item: Item = InventoryManager.inventory[i].item
		if item and item.id == id:
			if creature.equip_saddle_from_inventory(i):
				AudioManager.play_sfx("equip_gear")
				show_companion_commands(creature)
				show_toast("Saddle fitted. Your companion is ready to ride.")
			else: show_toast("A saddle is already equipped")
			return
	show_toast("Craft a matching saddle at a workbench first")

func _shortcut(caption: String,key: String,pos: Vector2,dimensions: Vector2,action: Callable) -> void:
	var button := preload("res://UI/ShortcutCharm.gd").new()
	button.focus_mode = Control.FOCUS_NONE
	button.caption = caption
	button.key_hint = key
	button.position = pos
	button.size = dimensions
	root.add_child(button)
	button.pressed.connect(action)
	shortcut_buttons.append(button)

func _apply_shortcut_visibility() -> void:
	for button in shortcut_buttons: button.visible = GameSettings.shortcut_buttons_visible
