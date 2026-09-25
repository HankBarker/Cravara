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
var recipe_list: VBoxContainer
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
var sort_button: Button
var quick_stack_button: Button
const FRAME = preload("res://UI/CrystalFrame.gd")
const METER = preload("res://UI/CrystalMeter.gd")
## The interface kit: fonts, palette, plaques, sockets and icons.
const UI = preload("res://UI/SkyfangUI.gd")
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
	_heading_font = UI.TITLE
	_shade = ColorRect.new()
	_shade.color = Color(0.02,0.09,0.08,0.48)
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
func _build_status() -> void:
	var frame := _panel(root,Vector2(6,5),Vector2(158,42))
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
	_bleed_box.position = Vector2(8,48)
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
	_ash_box.position = Vector2(8,61)
	var ash_row := HBoxContainer.new()
	ash_row.add_theme_constant_override("separation",2)
	ash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ash_box.add_child(ash_row)
	ash_label = _label(ash_row,"",Vector2.ZERO,8,ASH)
	ash_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ash_box.visible = false
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
	for i in 8:
		var slot := _slot(frame,i,Vector2(4+i*31,3),28)
		hotbar.append(slot)
		_label(slot,str(i+1),Vector2(4,2),8,GOLD)
	# Caps cycles five pouches of eight: a key cap and five crystal pips.
	var pouch := _backing(root,Vector4(3,2,4,2))
	pouch.position = Vector2(7,229)
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
	if slot in hotbar and slot.slot_index == InventoryManager.selected_slot_index: return UI.box("slot_selected")
	return UI.box("slot_hover" if hovered else "slot")

func _build_inventory() -> void:
	inventory_panel = _panel(root,Vector2(8,58),Vector2(211,176))
	_label(inventory_panel,"FIELD SATCHEL",Vector2(12,7),10,GOLD)
	_button(inventory_panel,"Gear",Vector2(162,7),Vector2(39,16),show_equipment)
	sort_button=_button(inventory_panel,"Sort pack",Vector2(9,25),Vector2(67,14),func():
		var changed:=InventoryManager.sort_backpack()
		show_toast("Backpack sorted; current hotbar protected" if changed else "Backpack is already sorted"))
	sort_button.tooltip_text="Merge and sort backpack stacks. The current hotbar pouch stays exactly as it is."
	quick_stack_button=_button(inventory_panel,"Stack nearby",Vector2(81,25),Vector2(120,14),func():
		var result:=InventoryManager.quick_stack_nearby(player)
		show_toast("Stored %d items in %d chests; hotbar protected" % [result.moved,result.chests] if result.moved else "No matching chest space within reach and clear sight"))
	quick_stack_button.tooltip_text="Store matching item types in nearby visible chests. Current hotbar stays with you."
	for i in 35:
		slots.append(_slot(inventory_panel,i,Vector2(9+(i%7)*28,39+(i/7)*24),23))
	detail = _label(inventory_panel,"Gather. Craft. Make a home.",Vector2(10,159),7,MINT)
	detail.size.x = 190
	detail.clip_text = true
	recipes_panel = _panel(root,Vector2(224,58),Vector2(248,176))
	_label(recipes_panel,"TRIBAL CRAFT",Vector2(12,7),10,GOLD)
	station_label = _label(recipes_panel,"By hand",Vector2(136,10),7,MINT)
	var search := LineEdit.new()
	search.position = Vector2(7,30)
	search.size = Vector2(151,17)
	search.placeholder_text = "Find a recipe..."
	search.text_changed.connect(func(value): query=value; _refresh_recipes())
	recipes_panel.add_child(search)
	search.size = Vector2(151,17)
	var filter := _button(recipes_panel,"Ready only",Vector2(163,30),Vector2(77,17),func(): craftable_only=not craftable_only; _refresh_recipes())
	filter.toggle_mode = true
	var selector := OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	selector.position = Vector2(7,50)
	selector.size = Vector2(233,16)
	for category in CraftingManager.categories: selector.add_item(category)
	selector.item_selected.connect(func(index): selected_category=CraftingManager.categories[index]; _refresh_recipes())
	recipes_panel.add_child(selector)
	selector.size = Vector2(233,16)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(7,71)
	scroll.size = Vector2(233,98)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipes_panel.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation",3)
	scroll.add_child(recipe_list)
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
		var bleeding: bool = player.get("bleed") != null and player.bleed.active()
		_bleed_box.visible = bleeding
		if bleeding: bleed_label.text = "BLEEDING  %ds" % ceili(player.bleed.time_left)
		var ash: float = float(player.get("ash")) if player.get("ash") != null else 0.0
		_ash_box.visible = ash > 0.04
		if _ash_box.visible:
			var choking := ash >= 1.0
			ash_label.text = "CHOKING" if choking else "ASH  %d%%" % int(round(ash * 100.0))
			ash_label.add_theme_color_override("font_color", UI.EMBER if choking else ASH)
			_ash_box.position.y = 61.0 if bleeding else 48.0
	if _last_selected != InventoryManager.selected_slot_index:
		_last_selected = InventoryManager.selected_slot_index
		update_inventory_display()
	_toast_time = maxf(0,_toast_time-delta)
	_toast_box.modulate.a = minf(1,_toast_time)
	_toast_box.visible = _toast_time > 0 and toast.text != ""
	if _toast_box.visible: _toast_box.position.y = _toast_top()
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
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	var focus := get_viewport().gui_get_focus_owner()
	if key == KEY_ESCAPE and is_open():
		close_panels()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_CAPSLOCK and not focus is LineEdit:
		DragController.end_drag()
		InventoryManager.cycle_hotbar()
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
	return (inventory_panel != null and inventory_panel.visible) or (equipment_panel != null and equipment_panel.visible) or (roster_panel != null and roster_panel.visible) or is_instance_valid(command_panel) or (is_instance_valid(appearance_editor) and appearance_editor.is_open())

func open_panels() -> void:
	close_panels()
	_shade.show()
	inventory_panel.show()
	recipes_panel.show()
	AudioManager.play_sfx("satchel_open")
	_unfold_satchel()
	_refresh_recipes()
	update_armor_display()

func close_panels() -> void:
	if is_instance_valid(appearance_editor):
		appearance_editor._cancel()
		appearance_editor=null
	if _interface_ready and inventory_panel and inventory_panel.visible: AudioManager.play_sfx("satchel_close")
	if is_instance_valid(_satchel_tween): _satchel_tween.kill()
	if inventory_panel: inventory_panel.scale = Vector2.ONE
	if recipes_panel: recipes_panel.scale = Vector2.ONE
	inventory_panel.hide()
	recipes_panel.hide()
	close_chest()
	if equipment_panel: equipment_panel.hide()
	if roster_panel: roster_panel.hide()
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
		var head := _label(_tasks_list,str(q.title),Vector2.ZERO,8,GOLD)
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
var _gifts_label: Label
func show_gifts(names: Array) -> void:
	if not is_instance_valid(_gifts_box):
		_gifts_box = _backing(root,Vector4(4,1,5,1))
		_gifts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gifts_label = _label(_gifts_box,"",Vector2.ZERO,8,MINT)
	_gifts_box.visible = not names.is_empty()
	_gifts_label.text = " · ".join(names)
	_gifts_box.reset_size()
	_gifts_box.position = Vector2(8,48)
	if is_instance_valid(_bleed_box): _bleed_box.position = Vector2(8,62 if _gifts_box.visible else 48)

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

func show_banner(title: String, text: String, icon: Texture2D = null) -> void:
	_banners.append([title, text, icon])
	if not is_instance_valid(_banner): _next_banner()

func _next_banner() -> void:
	if _banners.is_empty(): return
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
	station_label.text = "By hand" if CraftingManager.nearby_stations.is_empty() else "At " + CraftingManager.nearby_stations[0].capitalize()
	var recipes: Array = CraftingManager.get_recipes_by_category(selected_category).duplicate()
	recipes.sort_custom(func(a,b): return CraftingManager.can_craft_recipe(a) and not CraftingManager.can_craft_recipe(b))
	for recipe in recipes:
		if not query.is_empty() and not recipe.name.to_lower().contains(query.to_lower()): continue
		var available: bool = CraftingManager.can_craft_recipe(recipe)
		if craftable_only and not available: continue
		var row := Panel.new()
		row.custom_minimum_size = Vector2(221,46)
		row.add_theme_stylebox_override("panel",UI.box("card" if available else "card_dim"))
		recipe_list.add_child(row)
		var socket := Panel.new()
		socket.position = Vector2(4,5)
		socket.size = Vector2(26,26)
		socket.add_theme_stylebox_override("panel",UI.box("slot"))
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(socket)
		var icon := TextureRect.new()
		icon.position = Vector2(5,5)
		icon.size = Vector2(24,24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CraftingManager.get_item_icon(recipe.item_id)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(1,1)
		socket.add_child(icon)
		var quantity: int = recipe.get("quantity",1)
		var recipe_name := _label(row,recipe.name + (" x%d" % quantity if quantity > 1 else ""),Vector2(35,5),8,PAPER if available else UI.DIM)
		recipe_name.size.x = 130
		recipe_name.clip_text = true
		var ingredients: Array[String] = []
		for id in recipe.ingredients:
			ingredients.append("%s %d/%d" % [CraftingManager.get_ingredient_name(id).replace("Wood ","").replace("Plant ",""),InventoryManager.get_item_count(id),recipe.ingredients[id]])
		var need := _label(row,", ".join(ingredients),Vector2(35,16),8,MINT if available else UI.EMBER)
		need.size = Vector2(132,24)
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.clip_text = true
		var station: String = recipe.get("station","")
		var where := _label(row,"BY HAND" if station == "" else station.to_upper(),Vector2(166,5),8,GOLD)
		where.size.x = 50
		where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var craft := _button(row,"Craft",Vector2(172,26),Vector2(44,16),func():
			if CraftingManager.try_craft(recipe.item_id): show_toast("Crafted %s x%d" % [recipe.name,quantity])
			else: show_toast(CraftingManager.last_failure))
		craft.disabled = not available
		row.tooltip_text = preload("res://UI/ItemDetails.gd").text(ItemDB.make(recipe.item_id)) + "\n" + ", ".join(ingredients)
		craft.tooltip_text = row.tooltip_text

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
	close_panels()
	_shade.show()
	_active_chest = chest
	inventory_panel.show()
	AudioManager.play_sfx("satchel_open")
	recipes_panel.hide()
	chest_panel = _panel(root,Vector2(224,58),Vector2(248,172))
	_label(chest_panel,"CAMP STORAGE",Vector2(12,7),10,GOLD)
	_label(chest_panel,"Drag stacks or Shift-click to transfer.",Vector2(8,28),7)
	for i in chest.inventory.size():
		chest_slots.append(_slot(chest_panel,i,Vector2(8+(i%8)*29,42+(i/8)*29),26,chest))
	chest.inventory_changed.connect(update_inventory_display)
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




func select_slot(slot: Control) -> void:
	if slot in hotbar:
		InventoryManager.selected_slot_index = slot.slot_index
		update_inventory_display()

func _exit_tree() -> void:
	# DragController is an autoload; do not let it retain a freed slot across scenes.
	DragController.end_drag()

func _build_equipment() -> void:
	equipment_panel = _panel(root,Vector2(39,25),Vector2(402,211))
	_label(equipment_panel,"KEEPER'S EQUIPMENT",Vector2(14,7),11,GOLD)
	_button(equipment_panel,"Appearance",Vector2(254,7),Vector2(84,17),show_appearance)
	_button(equipment_panel,"Close",Vector2(343,7),Vector2(46,17),close_panels)
	var portrait_frame := _panel(equipment_panel,Vector2(12,33),Vector2(108,111))
	portrait_frame.get_child(0).inset = true
	if is_instance_valid(player) and player.has_method("create_portrait"):
		var portrait: Control = player.create_portrait()
		portrait.position = Vector2(10,6)
		portrait_frame.add_child(portrait)
	elif is_instance_valid(player) and player.animated_sprite:
		var portrait := TextureRect.new()
		portrait.position = Vector2(22,12)
		portrait.size = Vector2(64,88)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = player.animated_sprite.sprite_frames.get_frame_texture(player.animated_sprite.animation,0)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait)
	_label(equipment_panel,"WILDKEEPER",Vector2(33,147),8,GOLD)
	equipment_summary = _label(equipment_panel,"",Vector2(13,163),8,MINT)
	equipment_summary.size = Vector2(107,37)
	equipment_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var targets := ["head","chest","legs","trinket_0","trinket_1","trinket_2","light"]
	var names := ["Head","Chest","Legs","Trinket I","Trinket II","Trinket III","Light"]
	for i in targets.size():
		var target: String = targets[i]
		var b := _button(equipment_panel,names[i],Vector2(130+(i%4)*64,34+(i/4)*31),Vector2(60,27),func():
			_equipment_target=target
			_refresh_equipment())
		b.name = "Equip_"+target
		b.set_meta("caption",names[i])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",14)
		armor_buttons[target] = b
	equipment_hint = _label(equipment_panel,"",Vector2(132,99),8,GOLD)
	_button(equipment_panel,"Unequip",Vector2(322,97),Vector2(64,18),func():
		if player and player.has_method("unequip_to_inventory"):
			if not player.unequip_to_inventory(_equipment_target): show_toast("No item equipped, or your satchel is full")
			else: AudioManager.play_sfx("unequip_gear")
			_refresh_equipment())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(131,119)
	scroll.size = Vector2(255,78)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipment_panel.add_child(scroll)
	equipment_list = VBoxContainer.new()
	equipment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_list.add_theme_constant_override("separation",3)
	scroll.add_child(equipment_list)

func show_equipment() -> void:
	close_panels()
	_shade.show()
	equipment_panel.show()
	_refresh_equipment()

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
		b.text = b.get_meta("caption")
		b.tooltip_text = preload("res://UI/ItemDetails.gd").text(item) if item else "Empty " + str(b.get_meta("caption"))
		if target == _equipment_target: b.add_theme_stylebox_override("normal",UI.box("button_on",Vector4(4,3,4,2)))
		else: b.remove_theme_stylebox_override("normal")
	equipment_summary.text = player.get_equipment_summary().replace(" | ","\n") if player.has_method("get_equipment_summary") else "Armor protects you\nin the wilds."
	equipment_hint.text = "Choose " + str(armor_buttons[_equipment_target].get_meta("caption")).to_lower()
	_clear_children(equipment_list)
	var count := 0
	for i in InventoryManager.inventory.size():
		var item: Item = InventoryManager.inventory[i].item
		if not item or not _matches_slot(item,_equipment_target): continue
		count += 1
		var index := i
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = item.name + "  / Equip"
		b.icon = item.icon
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width",19)
		b.custom_minimum_size = Vector2(239,24)
		b.tooltip_text = preload("res://UI/ItemDetails.gd").text(item)
		b.pressed.connect(func():
			if player.has_method("equip_from_inventory") and player.equip_from_inventory(index,_equipment_target):
				AudioManager.play_sfx("equip_gear")
				show_toast("Equipped " + item.name)
			else: show_toast("Cannot equip this item here")
			_refresh_equipment())
		equipment_list.add_child(b)
	if count == 0:
		var empty := Label.new()
		empty.text = "No matching gear in your satchel.\nCraft equipment at a workbench."
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

func show_roster() -> void:
	close_panels()
	_shade.show()
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
		meter.tint = Color("76c4a5")
		meter.value = 100.0*creature.health/maxi(1,creature.stats.hp)
		row.add_child(meter)
		_label(row,"%d / %d" % [creature.health,creature.stats.hp],Vector2(165,31),8)
		var target: Node = creature
		_button(row,"Locate",Vector2(222,25),Vector2(48,18),func():_locate_companion(target))
		_button(row,"Orders",Vector2(274,25),Vector2(52,18),func():
			if is_instance_valid(target): show_companion_commands(target))

func show_companion_commands(creature: Node = null) -> void:
	if creature != null and (not is_instance_valid(creature) or not creature.tamed or creature.is_dead): return
	close_panels()
	_shade.show()
	_command_target = creature
	_command_is_group = creature == null
	var mountable: bool = creature != null and creature.species in ["stego","trike"]
	var worker: bool=creature!=null and creature.species in ["stego","trike","dodo"]
	command_panel = _panel(root,Vector2(101,12 if worker else (25 if creature else 48)),Vector2(278,246 if worker else (220 if mountable else (196 if creature else 176))))
	var title: String = creature.stats.name if creature != null else "ALL COMPANIONS"
	var title_label := _label(command_panel,title,Vector2(13,8),10,GOLD)
	title_label.size.x = 228
	title_label.clip_text = true
	_button(command_panel,"X",Vector2(247,8),Vector2(18,17),close_panels)
	_label(command_panel,"Choose an order",Vector2(13,31),9,MINT)
	if mountable:
		_label(command_panel,"Saddle fitted" if creature.saddle else "No saddle fitted",Vector2(163,32),8,GOLD)
	var orders := ["follow","stay","guard","roam"]
	var tips := ["Travel with you and wade through shallow water.","Remain exactly here until given another order.","Defend this location, within your chosen stance.","Wander close to this location."]
	if worker:
		orders.append_array(["work","return"])
		tips.append_array(["Gather your specialty near your home and store it in the assigned chest.","Return to your work home."])
	var columns:=3 if worker else 2
	var button_width:=81 if worker else 123
	for i in orders.size():
		var order_name: String = orders[i]
		var b := _button(command_panel,order_name.capitalize(),Vector2(13+(i%columns)*(button_width+5),48+(i/columns)*26),Vector2(button_width,23),func():_apply_companion_command("order",order_name))
		b.tooltip_text = tips[i]
		if creature != null and creature.order == order_name: b.add_theme_stylebox_override("normal",UI.box("button_on",Vector4(5,3,5,2)))
	_label(command_panel,"Temperament",Vector2(13,104),9,MINT)
	for i in 3:
		var stance_name: String = ["passive","neutral","aggressive"][i]
		var b := _button(command_panel,stance_name.capitalize(),Vector2(13+i*86,122),Vector2(81,22),func():_apply_companion_command("stance",stance_name))
		b.tooltip_text = ["Never attack. Use this to withdraw safely.","Defend yourself and your keeper when attacked.","Seek nearby hostile wildlife."][i]
		if creature != null and creature.get("stance") == stance_name: b.add_theme_stylebox_override("normal",UI.box("button_on",Vector4(5,3,5,2)))
	if creature:
		var row_y := 149
		if worker:
			_button(command_panel,"Set work home",Vector2(13,row_y),Vector2(123,21),func():
				if is_instance_valid(creature): show_toast("Work home set" if creature.set_work_home() else "Cannot set work home here"))
			_button(command_panel,"Assign chest",Vector2(141,row_y),Vector2(123,21),func():
				if is_instance_valid(creature): show_toast("Nearby chest assigned" if creature.assign_nearest_work_chest() else "No suitable chest near work home"))
			row_y+=27
		if mountable:
			_button(command_panel,"Equip saddle",Vector2(13,row_y),Vector2(81,23),func():_equip_saddle(creature))
			_button(command_panel,"Remove",Vector2(99,row_y),Vector2(81,23),func():
				if is_instance_valid(creature) and creature.has_method("unequip_saddle"):
					if creature.unequip_saddle():
						AudioManager.play_sfx("unequip_gear")
						show_companion_commands(creature)
						show_toast("Saddle removed")
					else: show_toast("Cannot remove saddle; dismount and check satchel space"))
			_button(command_panel,"Ride",Vector2(185,row_y),Vector2(81,23),func():
				if is_instance_valid(creature) and creature.has_method("mount"):
					if creature.mount(player): close_panels()
					else: show_toast("Equip a saddle and move closer to ride"))
			row_y += 27
		_button(command_panel,"Locate companion",Vector2(13,row_y),Vector2(123,21),func():_locate_companion(creature))
		_button(command_panel,"Back to bonds",Vector2(141,row_y),Vector2(123,21),show_roster)
		_label(command_panel,"Esc closes without changing orders.",Vector2(13,row_y+26),7,GOLD)
		_button(command_panel,"Pet",Vector2(225,row_y+25),Vector2(39,16),func():_pet_companion(creature))
	else:
		_label(command_panel,"Click a command. Esc closes without changes.",Vector2(13,154),7,GOLD)

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
	inventory_panel.pivot_offset = Vector2(inventory_panel.size.x/2,0)
	recipes_panel.pivot_offset = Vector2(recipes_panel.size.x/2,0)
	inventory_panel.scale = Vector2(1,0.07)
	recipes_panel.scale = Vector2(1,0.07)
	_satchel_tween = create_tween().set_parallel(true)
	_satchel_tween.tween_property(inventory_panel,"scale",Vector2.ONE,0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_satchel_tween.tween_property(recipes_panel,"scale",Vector2.ONE,0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

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
