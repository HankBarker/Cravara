extends CanvasLayer
# Compact native-resolution field interface. Existing inventory remains authoritative.
var player: Node = null
var root: Control
var inventory_panel: Panel
var recipes_panel: Panel
var toast: Label
var context_label: Label
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
var _heading_font: Font
const INK := Color("172f31")
const DARK := Color("102224")
const EDGE := Color("658579")
const GOLD := Color("dcc085")
const PAPER := Color("eee3c7")
const MINT := Color("9fddbb")

func _ready() -> void:
	layer = 20
	add_to_group("inventory_ui")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 9
	theme.default_font = load("res://Forest/fonts/AlegreyaSans.ttf")
	# Godot's bundled Noto Sans has softer, more articulate letterforms at this scale.
	# Body text stays readable; ornament supplies the ancient identity.
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	for kind in ["normal","hover","pressed","focus","disabled"]:
		theme.set_stylebox(kind,"Button",_style(INK if kind != "hover" else Color("35594c"), GOLD if kind == "focus" else EDGE))
		theme.set_stylebox(kind,"OptionButton",_style(INK if kind != "hover" else Color("35594c"), GOLD if kind == "focus" else EDGE))
	theme.set_stylebox("panel","PopupMenu",_style(DARK,GOLD))
	theme.set_stylebox("hover","PopupMenu",_style(Color("35594c"),EDGE))
	theme.set_font_size("font_size","PopupMenu",9)
	theme.set_stylebox("panel","TooltipPanel",_style(DARK,GOLD))
	theme.set_font_size("font_size","TooltipLabel",8)
	theme.set_color("font_color","TooltipLabel",PAPER)
	theme.set_color("font_disabled_color","Button",Color("85998b"))
	for kind in ["grabber","grabber_highlight","grabber_pressed"]:
		var grip := _style(Color("6a947a"),Color("b7ad77"))
		grip.content_margin_left = 2
		grip.content_margin_right = 2
		theme.set_stylebox(kind,"VScrollBar",grip)
	root.theme = theme
	if ResourceLoader.exists("res://Forest/fonts/IMFellEnglish.ttf"):
		_heading_font = load("res://Forest/fonts/IMFellEnglish.ttf")
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

func _style(bg: Color = INK, border: Color = EDGE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.corner_detail = 1
	s.content_margin_left = 3
	s.content_margin_right = 3
	s.shadow_color = Color(0,0,0,0.35)
	s.shadow_size = 1
	s.shadow_offset = Vector2(0,1)
	return s

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

func _label(parent: Node, text: String, pos: Vector2, font_size: int = 8, tint: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size",maxi(8,font_size))
	if font_size >= 10 and _heading_font:
		l.add_theme_font_override("font",_heading_font)
	l.add_theme_color_override("font_shadow_color", Color(0.04,0.08,0.07,0.85))
	l.add_theme_constant_override("shadow_offset_x",1)
	l.add_theme_constant_override("shadow_offset_y",1)
	l.add_theme_color_override("font_color",tint)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = dimensions
	# Mouse-driven HUD: a clicked button must not keep keyboard focus, or Space
	# (dodge) / Enter would press it again through ui_accept.
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",9)
	b.add_theme_color_override("font_hover_color",Color("dcffe6"))
	b.pressed.connect(callback)
	b.pressed.connect(func(): AudioManager.play_sfx("equip_gear"))
	parent.add_child(b)
	b.size = dimensions
	return b

func _build_status() -> void:
	var frame := _panel(root,Vector2(8,7),Vector2(146,40))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(frame,"SKYFANG WILDS",Vector2(13,5),9,GOLD)
	for i in 2:
		var name: String = ["VITALITY","HUNGER"][i]
		_label(frame,name,Vector2(9,17+i*9),7,PAPER)
		var bar := METER.new()
		bar.position = Vector2(51,20+i*9)
		bar.size = Vector2(86,7)
		bar.tint = [Color("d77877"),Color("d4b76b")][i]
		frame.add_child(bar)
		bars[name] = bar
	_label(root,"THE SKYFANG WILDS",Vector2(346,8),8,GOLD)
	context_label = _label(root,"",Vector2(10,218),8)
	context_label.size = Vector2(460,12)
	context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _label(root,"",Vector2(170,32),8,MINT)
	toast.size = Vector2(295,24)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_hotbar() -> void:
	var frame := _panel(root,Vector2(113,235),Vector2(254,34))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 8:
		var slot := _slot(frame,i,Vector2(4+i*31,3),28)
		hotbar.append(slot)
		_label(slot,str(i+1),Vector2(2,0),6,GOLD)
	_hotbar_page = _label(root,"Caps  Pouch 1/5",Vector2(10,234),7,GOLD)
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
	slot.add_theme_stylebox_override("panel",_style(DARK,EDGE))
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
	var qty := _label(slot,"",Vector2(3,pixels-10),7)
	qty.name = "Quantity"
	qty.size.x = pixels-5
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty.add_theme_color_override("font_shadow_color",DARK)
	qty.add_theme_constant_override("shadow_offset_x",1)
	qty.add_theme_constant_override("shadow_offset_y",1)
	return slot

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
	search.add_theme_font_size_override("font_size",8)
	search.text_changed.connect(func(value): query=value; _refresh_recipes())
	search.add_theme_stylebox_override("normal",_style(DARK,EDGE))
	search.add_theme_stylebox_override("focus",_style(DARK,GOLD))
	recipes_panel.add_child(search)
	search.size = Vector2(151,17)
	var filter := _button(recipes_panel,"Ready only",Vector2(163,30),Vector2(77,17),func(): craftable_only=not craftable_only; _refresh_recipes())
	filter.toggle_mode = true
	var selector := OptionButton.new()
	selector.focus_mode = Control.FOCUS_NONE
	selector.position = Vector2(7,50)
	selector.size = Vector2(233,16)
	selector.add_theme_font_size_override("font_size",8)
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
	if _last_selected != InventoryManager.selected_slot_index:
		_last_selected = InventoryManager.selected_slot_index
		update_inventory_display()
	_toast_time = maxf(0,_toast_time-delta)
	toast.modulate.a = minf(1,_toast_time)
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

func show_toast(text: String) -> void:
	if toast: toast.text = text
	_toast_time = 3.0

func set_context(text: String) -> void:
	if context_label: context_label.text = text

func update_inventory_display() -> void:
	var indices := InventoryManager.get_hotbar_indices()
	for i in hotbar.size():
		hotbar[i].slot_index = indices[i] if i < indices.size() else -1
		hotbar[i].visible = i < indices.size()
	if _hotbar_page: _hotbar_page.text = "Caps  Pouch %d/5" % (InventoryManager.hotbar_start/8+1)
	for slot in slots + hotbar + chest_slots:
		var source = slot._get_source()
		if not is_instance_valid(source) or slot.slot_index < 0 or slot.slot_index >= source.inventory.size(): continue
		var data: Dictionary = source.inventory[slot.slot_index]
		slot.tooltip_text=preload("res://UI/ItemDetails.gd").text(data.item) if data.item else ""
		slot.get_node("Icon").texture = data.item.icon if data.item else null
		slot.get_node("Quantity").text = str(data.quantity) if data.quantity > 1 else ""
		var selected: bool = slot in hotbar and slot.slot_index == InventoryManager.selected_slot_index
		slot.add_theme_stylebox_override("panel",_style(Color("365448") if selected else DARK,GOLD if selected else EDGE))
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
		row.add_theme_stylebox_override("panel",_style(DARK,Color("4d7563") if available else Color("334a42")))
		recipe_list.add_child(row)
		var icon := TextureRect.new()
		icon.position = Vector2(4,6)
		icon.size = Vector2(24,24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CraftingManager.get_item_icon(recipe.item_id)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var quantity: int = recipe.get("quantity",1)
		var recipe_name := _label(row,recipe.name + (" x%d" % quantity if quantity > 1 else ""),Vector2(32,3),8,PAPER if available else EDGE)
		recipe_name.size.x = 185
		recipe_name.clip_text = true
		var ingredients: Array[String] = []
		for id in recipe.ingredients:
			ingredients.append("%s %d/%d" % [CraftingManager.get_ingredient_name(id).replace("Wood ","").replace("Plant ",""),InventoryManager.get_item_count(id),recipe.ingredients[id]])
		var need := _label(row,", ".join(ingredients),Vector2(32,16),6,MINT if available else Color("c69a82"))
		need.size.x = 176
		need.clip_text = true
		var station: String = recipe.get("station","")
		_label(row,"BY HAND" if station == "" else station.to_upper(),Vector2(32,31),7,GOLD)
		var craft := _button(row,"Craft",Vector2(175,28),Vector2(40,16),func():
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
		b.add_theme_stylebox_override("normal",_style(Color("345749") if target == _equipment_target else DARK,GOLD if target == _equipment_target else EDGE))
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
		b.add_theme_font_size_override("font_size",8)
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
		empty.add_theme_font_size_override("font_size",8)
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
		label.add_theme_font_size_override("font_size",9)
		roster_list.add_child(label)
		return
	for creature in companions:
		var row := Panel.new()
		row.custom_minimum_size = Vector2(335,47)
		row.add_theme_stylebox_override("panel",_style(DARK,EDGE))
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
		_label(row,creature.stats.name,Vector2(50,3),9,GOLD)
		var stance: String = creature.get("stance") if creature.get("stance") != null else "neutral"
		var distance := int(creature.global_position.distance_to(player.global_position)/16.0) if player else 0
		var status_text: String=creature.get_status_summary() if creature.has_method("get_status_summary") else "%s / %s / %d tiles away" % [creature.order.capitalize(),stance.capitalize(),distance]
		var status_label:=_label(row,status_text,Vector2(50,17),7,MINT)
		status_label.size.x=270
		status_label.clip_text=true
		row.tooltip_text=status_text
		var meter := METER.new()
		meter.position = Vector2(50,33)
		meter.size = Vector2(110,7)
		meter.tint = Color("76c4a5")
		meter.value = 100.0*creature.health/maxi(1,creature.stats.hp)
		row.add_child(meter)
		_label(row,"%d / %d" % [creature.health,creature.stats.hp],Vector2(166,29),7)
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
		if creature != null and creature.order == order_name: b.add_theme_stylebox_override("normal",_style(Color("36594c"),GOLD))
	_label(command_panel,"Temperament",Vector2(13,104),9,MINT)
	for i in 3:
		var stance_name: String = ["passive","neutral","aggressive"][i]
		var b := _button(command_panel,stance_name.capitalize(),Vector2(13+i*86,122),Vector2(81,22),func():_apply_companion_command("stance",stance_name))
		b.tooltip_text = ["Never attack. Use this to withdraw safely.","Defend yourself and your keeper when attacked.","Seek nearby hostile wildlife."][i]
		if creature != null and creature.get("stance") == stance_name: b.add_theme_stylebox_override("normal",_style(Color("36594c"),GOLD))
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
