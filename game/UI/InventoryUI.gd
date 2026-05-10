extends CanvasLayer

# --- Node References (set in _ready) ---
var inventory_panel: Panel
var inventory_grid: GridContainer
var crafting_panel: Panel
var crafting_scroll: ScrollContainer
var crafting_recipe_list: VBoxContainer
var hotbar_panel: HBoxContainer
var hotbar_bg: Panel
var tooltip: PanelContainer

var inventory_slots: Array[Control] = []
var hotbar_slots: Array[Control] = []
var selected_hotbar_index: int = 0
var selected_category: String = "All"
var category_buttons: Array[Button] = []

# Health bar references
var health_bar_border: Panel
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var health_label: Label

# Settings panel
var settings_panel: Panel
var settings_panel_visible := false

# Armor equipment panel
var armor_panel: Panel
var armor_slots_ui: Dictionary = {}
var defense_label: Label

# --- Colors (Terraria-inspired) ---
const PANEL_BG = Color(0.08, 0.07, 0.1, 0.92)
const PANEL_BORDER = Color(0.35, 0.3, 0.4, 0.8)
const SLOT_BG = Color(0.12, 0.11, 0.15, 0.95)
const SLOT_BORDER = Color(0.3, 0.3, 0.35, 1.0)
const SLOT_HOVER = Color(0.45, 0.4, 0.5, 1.0)
const SELECTED_BORDER = Color(1.0, 1.0, 1.0, 1.0)
const HOTBAR_BG = Color(0.06, 0.05, 0.08, 0.85)

const RARITY_COLORS = {
	"common": Color(0.5, 0.5, 0.5),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.85, 0.2)
}

const SLOT_SIZE = 28
const HOTBAR_SLOT_SIZE = 30
const SLOT_GAP = 2
const INV_COLUMNS = 9

func _ready():
	_build_ui()

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		InventoryManager.item_picked_up.connect(_on_item_picked_up)

	create_inventory_slots()
	create_hotbar_slots()

	inventory_panel.visible = false
	crafting_panel.visible = false

	# Sync initial hotbar selection with InventoryManager
	InventoryManager.selected_slot_index = selected_hotbar_index

# =========================================
# UI CONSTRUCTION
# =========================================

func _build_ui():
	var ui_container = $UIContainer

	# --- Tooltip (add first so it's always accessible) ---
	var tooltip_script = load("res://UI/TooltipUI.gd")
	tooltip = PanelContainer.new()
	tooltip.set_script(tooltip_script)
	tooltip.name = "Tooltip"
	ui_container.add_child(tooltip)

	# --- Hotbar background strip ---
	hotbar_bg = Panel.new()
	hotbar_bg.name = "HotbarBG"
	var hb_style = StyleBoxFlat.new()
	hb_style.bg_color = HOTBAR_BG
	hb_style.set_border_width_all(1)
	hb_style.border_color = PANEL_BORDER
	hb_style.set_corner_radius_all(3)
	hb_style.content_margin_left = 4
	hb_style.content_margin_right = 4
	hb_style.content_margin_top = 10
	hb_style.content_margin_bottom = 3
	hotbar_bg.add_theme_stylebox_override("panel", hb_style)
	ui_container.add_child(hotbar_bg)

	# --- Hotbar container ---
	hotbar_panel = $UIContainer/HotbarPanel
	# Clear the pre-existing placeholder slots from the scene
	for child in hotbar_panel.get_children():
		child.queue_free()
	hotbar_panel.add_theme_constant_override("separation", SLOT_GAP)

	# --- Inventory Panel ---
	inventory_panel = $UIContainer/InventoryPanel
	# Clear old grid children
	var old_grid = inventory_panel.find_child("GridContainer")
	if old_grid:
		old_grid.queue_free()

	var inv_style = _make_panel_style()
	inventory_panel.add_theme_stylebox_override("panel", inv_style)

	# Inventory title
	var inv_title = Label.new()
	inv_title.name = "InvTitle"
	inv_title.text = "Inventory"
	inv_title.add_theme_font_size_override("font_size", 7)
	inv_title.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	inv_title.position = Vector2(6, 3)
	inventory_panel.add_child(inv_title)

	# New grid
	inventory_grid = GridContainer.new()
	inventory_grid.name = "InvGrid"
	inventory_grid.columns = INV_COLUMNS
	inventory_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	inventory_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	inventory_grid.position = Vector2(6, 14)
	inventory_panel.add_child(inventory_grid)

	# Size and position the inventory panel
	var grid_w = INV_COLUMNS * SLOT_SIZE + (INV_COLUMNS - 1) * SLOT_GAP + 12
	var grid_rows = ceili(27.0 / INV_COLUMNS)
	var grid_h = grid_rows * SLOT_SIZE + (grid_rows - 1) * SLOT_GAP + 22
	inventory_panel.size = Vector2(grid_w, grid_h)

	# --- Crafting Panel ---
	crafting_panel = $UIContainer/PersonalCraftingPanel
	var craft_style = _make_panel_style()
	crafting_panel.add_theme_stylebox_override("panel", craft_style)

	# Clear old crafting children
	for child in crafting_panel.get_children():
		child.queue_free()

	# Crafting title
	var craft_title = Label.new()
	craft_title.name = "CraftTitle"
	craft_title.text = "Crafting"
	craft_title.add_theme_font_size_override("font_size", 7)
	craft_title.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	craft_title.position = Vector2(6, 3)
	crafting_panel.add_child(craft_title)

	# Category tabs
	var tab_container = HBoxContainer.new()
	tab_container.name = "CategoryTabs"
	tab_container.position = Vector2(4, 13)
	tab_container.add_theme_constant_override("separation", 2)
	crafting_panel.add_child(tab_container)

	for cat in CraftingManager.categories:
		var btn = Button.new()
		btn.text = cat
		btn.add_theme_font_size_override("font_size", 5)
		btn.custom_minimum_size = Vector2(28, 10)
		btn.focus_mode = Control.FOCUS_NONE

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.14, 0.18, 0.9) if cat != "All" else Color(0.25, 0.22, 0.35, 0.95)
		btn_style.set_border_width_all(1)
		btn_style.border_color = Color(0.35, 0.3, 0.45, 0.8)
		btn_style.set_corner_radius_all(2)
		btn_style.content_margin_left = 2
		btn_style.content_margin_right = 2
		btn_style.content_margin_top = 1
		btn_style.content_margin_bottom = 1
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color(0.3, 0.25, 0.4, 0.95)
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed = btn_style.duplicate()
		btn_pressed.bg_color = Color(0.25, 0.22, 0.35, 0.95)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		btn.pressed.connect(_on_category_selected.bind(cat))
		tab_container.add_child(btn)
		category_buttons.append(btn)

	# Scrollable recipe list
	crafting_scroll = ScrollContainer.new()
	crafting_scroll.name = "CraftScroll"
	crafting_scroll.position = Vector2(4, 26)
	crafting_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crafting_panel.add_child(crafting_scroll)

	crafting_recipe_list = VBoxContainer.new()
	crafting_recipe_list.name = "RecipeList"
	crafting_recipe_list.add_theme_constant_override("separation", 2)
	crafting_scroll.add_child(crafting_recipe_list)

	# Size the crafting panel
	crafting_panel.size = Vector2(155, grid_h)
	crafting_scroll.size = Vector2(147, grid_h - 32)
	crafting_recipe_list.custom_minimum_size.x = 143

	# Position both panels centered & side-by-side
	var total_w = inventory_panel.size.x + 4 + crafting_panel.size.x
	var viewport_w = 480
	var viewport_h = 270
	var start_x = (viewport_w - total_w) / 2.0
	var start_y = (viewport_h - inventory_panel.size.y) / 2.0 - 10

	inventory_panel.position = Vector2(start_x, start_y)
	crafting_panel.position = Vector2(start_x + inventory_panel.size.x + 4, start_y)

	# Position hotbar centered at bottom
	_position_hotbar()

	# Build health bar
	_build_health_bar()

	# Build armor equipment panel
	_build_armor_panel()

	# Build settings menu (hidden by default)
	_build_settings_panel()

func _build_health_bar():
	var ui = $UIContainer

	# Border panel
	health_bar_border = Panel.new()
	health_bar_border.name = "HealthBarBorder"
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0.15, 0.12, 0.08, 0.9)
	border_style.set_border_width_all(1)
	border_style.border_color = Color(0.3, 0.25, 0.15, 1.0)
	border_style.set_corner_radius_all(1)
	health_bar_border.add_theme_stylebox_override("panel", border_style)
	health_bar_border.position = Vector2(3, 3)
	health_bar_border.size = Vector2(56, 8)
	ui.add_child(health_bar_border)

	# Background (dark fill behind the bar)
	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.color = Color(0.08, 0.06, 0.04, 0.85)
	health_bar_bg.position = Vector2(4, 4)
	health_bar_bg.size = Vector2(54, 6)
	ui.add_child(health_bar_bg)

	# Fill (the actual green bar)
	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.color = Color(0.2, 0.7, 0.2, 0.9)
	health_bar_fill.position = Vector2(4, 4)
	health_bar_fill.size = Vector2(54, 6)
	ui.add_child(health_bar_fill)

	# Label showing current/max
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.add_theme_font_size_override("font_size", 5)
	health_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	health_label.position = Vector2(61, 2)
	ui.add_child(health_label)

	SignalBus.player_health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(current: int, max_hp: int):
	if not health_bar_fill:
		return
	var ratio = clampf(float(current) / float(max_hp), 0.0, 1.0)
	var target_width = 54.0 * ratio

	# Smooth tween animation
	var tween = create_tween()
	tween.tween_property(health_bar_fill, "size:x", target_width, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Color shift based on health ratio
	var target_color: Color
	if ratio > 0.5:
		target_color = Color(0.2, 0.7, 0.2, 0.9)  # Green
	elif ratio > 0.25:
		target_color = Color(0.8, 0.7, 0.1, 0.9)  # Yellow
	else:
		target_color = Color(0.8, 0.2, 0.1, 0.9)  # Red
	tween.parallel().tween_property(health_bar_fill, "color", target_color, 0.3)

	health_label.text = str(current) + "/" + str(max_hp)

func _make_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(1)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(4)
	return style

func _position_hotbar():
	var total_hotbar_w = 8 * HOTBAR_SLOT_SIZE + 7 * SLOT_GAP + 8
	var viewport_w = 480
	var x = (viewport_w - total_hotbar_w) / 2.0
	var y = 270 - HOTBAR_SLOT_SIZE - 12

	hotbar_panel.position = Vector2(x + 4, y + 8)
	hotbar_panel.size = Vector2(total_hotbar_w - 8, HOTBAR_SLOT_SIZE)

	hotbar_bg.position = Vector2(x, y)
	hotbar_bg.size = Vector2(total_hotbar_w, HOTBAR_SLOT_SIZE + 14)

# =========================================
# INPUT
# =========================================

func _input(event):
	# Escape key priority: settings > inventory > open settings
	if Input.is_action_just_pressed("ui_cancel"):
		if settings_panel_visible:
			_toggle_settings_menu()
		elif inventory_panel.visible:
			toggle_inventory()
		else:
			_toggle_settings_menu()
		return

	if Input.is_action_just_pressed("use_hotbar_item"):
		if inventory_panel.visible or settings_panel_visible:
			return
		if get_viewport().gui_get_hovered_control():
			return

		var selected_item: Item = null
		if selected_hotbar_index < InventoryManager.inventory.size():
			selected_item = InventoryManager.inventory[selected_hotbar_index].item
		if selected_item != null and selected_item.placeable and selected_item.place_scene != "":
			var placement_controller = preload("res://Systems/Placement/PlacementController.tscn").instantiate()
			placement_controller.object_to_place = load(selected_item.place_scene)
			placement_controller.item_id = selected_item.id
			get_tree().get_root().add_child(placement_controller)
			AudioManager.play_sfx("place_object")

	for i in range(8):
		if Input.is_action_just_pressed("hotbar_" + str(i + 1)):
			selected_hotbar_index = i
			InventoryManager.selected_slot_index = i
			_update_hotbar_selection()

func toggle_inventory():
	var is_open = !inventory_panel.visible
	inventory_panel.visible = is_open
	crafting_panel.visible = is_open
	if is_open:
		populate_crafting_panel()
	else:
		tooltip.hide_tooltip()

# =========================================
# SLOT CREATION
# =========================================

func create_inventory_slots():
	for child in inventory_grid.get_children():
		child.queue_free()
	inventory_slots.clear()

	for i in range(8, 35):
		var slot = _create_slot(i, SLOT_SIZE)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)

func create_hotbar_slots():
	for child in hotbar_panel.get_children():
		child.queue_free()
	hotbar_slots.clear()

	for i in range(8):
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 0)

		# Slot number label
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 5)
		num_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.custom_minimum_size = Vector2(HOTBAR_SLOT_SIZE, 6)
		container.add_child(num_label)

		# Slot
		var slot = _create_slot(i, HOTBAR_SLOT_SIZE)
		container.add_child(slot)
		hotbar_panel.add_child(container)
		hotbar_slots.append(slot)

	_update_hotbar_selection()

func _create_slot(index: int, slot_size: int) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.name = "Slot_" + str(index)

	var slot_ui_script = load("res://UI/SlotUI.gd")
	slot.set_script(slot_ui_script)
	slot.set("slot_index", index)
	slot.set("parent_ui", self)

	# Style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = SLOT_BG
	style_box.set_border_width_all(1)
	style_box.border_color = SLOT_BORDER
	style_box.set_corner_radius_all(2)
	slot.add_theme_stylebox_override("panel", style_box)

	# Icon
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2
	icon.offset_top = 2
	icon.offset_right = -2
	icon.offset_bottom = -2
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	# Quantity label
	var quantity_label = Label.new()
	quantity_label.name = "Quantity"
	quantity_label.add_theme_font_size_override("font_size", 7)
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	quantity_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	quantity_label.offset_left = 1
	quantity_label.offset_top = 1
	quantity_label.offset_right = -2
	quantity_label.offset_bottom = -1
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Shadow effect via duplicate label behind
	var shadow = Label.new()
	shadow.name = "QuantityShadow"
	shadow.add_theme_font_size_override("font_size", 7)
	shadow.add_theme_color_override("font_color", Color(0, 0, 0, 0.8))
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shadow.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 2
	shadow.offset_top = 2
	shadow.offset_right = -1
	shadow.offset_bottom = 0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(shadow)
	slot.add_child(quantity_label)

	return slot

# =========================================
# DISPLAY UPDATES
# =========================================

func _on_inventory_changed():
	update_inventory_display()
	if inventory_panel.visible:
		populate_crafting_panel()

func _on_item_picked_up(_item: Item, _quantity: int):
	pass

func update_inventory_display():
	# Main inventory slots (indices 8-34)
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		var inv_index = i + 8
		var inv_item = null
		if inv_index < InventoryManager.inventory.size():
			inv_item = InventoryManager.inventory[inv_index]

		_update_slot_display(slot, inv_item)

	# Hotbar (indices 0-7)
	for i in range(min(8, hotbar_slots.size())):
		var slot = hotbar_slots[i]
		var inv_item = InventoryManager.inventory[i]
		_update_slot_display(slot, inv_item)

func _update_slot_display(slot: Panel, inv_item):
	var icon = slot.get_node("Icon")
	var qty_label = slot.get_node("Quantity")
	var qty_shadow = slot.get_node("QuantityShadow")

	if inv_item and inv_item.item:
		icon.texture = inv_item.item.icon
		var qty_text = str(inv_item.quantity) if inv_item.quantity > 1 else ""
		qty_label.text = qty_text
		qty_shadow.text = qty_text

		# Rarity border
		var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		var rarity = inv_item.item.rarity if inv_item.item.rarity else "common"
		style.border_color = RARITY_COLORS.get(rarity, SLOT_BORDER)
		slot.add_theme_stylebox_override("panel", style)
	else:
		icon.texture = null
		qty_label.text = ""
		qty_shadow.text = ""

		# Reset border
		var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = SLOT_BORDER
		slot.add_theme_stylebox_override("panel", style)

func _update_hotbar_selection():
	for i in range(hotbar_slots.size()):
		var slot = hotbar_slots[i]
		var style = slot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if i == selected_hotbar_index:
			style.border_color = SELECTED_BORDER
			style.set_border_width_all(2)
		else:
			# Restore rarity border or default
			var inv_item = InventoryManager.inventory[i] if i < InventoryManager.inventory.size() else null
			if inv_item and inv_item.item:
				var rarity = inv_item.item.rarity if inv_item.item.rarity else "common"
				style.border_color = RARITY_COLORS.get(rarity, SLOT_BORDER)
			else:
				style.border_color = SLOT_BORDER
			style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", style)

# =========================================
# CRAFTING PANEL
# =========================================

func _on_category_selected(category: String):
	selected_category = category
	_update_category_tabs()
	populate_crafting_panel()

func _update_category_tabs():
	for i in range(category_buttons.size()):
		var btn = category_buttons[i]
		var cat = CraftingManager.categories[i]
		var style = btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if cat == selected_category:
			style.bg_color = Color(0.25, 0.22, 0.35, 0.95)
			style.border_color = Color(0.5, 0.4, 0.65, 0.9)
		else:
			style.bg_color = Color(0.15, 0.14, 0.18, 0.9)
			style.border_color = Color(0.35, 0.3, 0.45, 0.8)
		btn.add_theme_stylebox_override("normal", style)

func populate_crafting_panel():
	for child in crafting_recipe_list.get_children():
		child.queue_free()

	var recipes = CraftingManager.get_recipes_by_category(selected_category)

	for recipe in recipes:
		var row = _create_recipe_row(recipe)
		crafting_recipe_list.add_child(row)

func _create_recipe_row(recipe: Dictionary) -> PanelContainer:
	var craftable = CraftingManager.can_craft(recipe.ingredients)

	# Row container with styling
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.1, 0.1, 0.13, 0.8) if craftable else Color(0.08, 0.08, 0.1, 0.6)
	row_style.set_border_width_all(1)
	row_style.border_color = Color(0.3, 0.35, 0.3, 0.7) if craftable else Color(0.25, 0.2, 0.25, 0.5)
	row_style.set_corner_radius_all(2)
	row_style.content_margin_left = 3
	row_style.content_margin_right = 3
	row_style.content_margin_top = 2
	row_style.content_margin_bottom = 2
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 3)
	row_panel.add_child(hbox)

	# Result icon
	var result_icon = TextureRect.new()
	result_icon.texture = CraftingManager.get_item_icon(recipe.item_id)
	result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_icon.custom_minimum_size = Vector2(20, 20)
	result_icon.modulate = Color(1, 1, 1, 1) if craftable else Color(0.5, 0.5, 0.5, 0.7)
	hbox.add_child(result_icon)

	# Info column
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 0)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Recipe name
	var name_label = Label.new()
	name_label.text = recipe.name
	name_label.add_theme_font_size_override("font_size", 6)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95) if craftable else Color(0.5, 0.5, 0.5))
	info_vbox.add_child(name_label)

	# Ingredients row
	var ing_hbox = HBoxContainer.new()
	ing_hbox.add_theme_constant_override("separation", 2)
	info_vbox.add_child(ing_hbox)

	for ingredient_id in recipe.ingredients.keys():
		var required = int(str(recipe.ingredients[ingredient_id]))
		var have = InventoryManager.get_item_count(ingredient_id)
		var enough = have >= required

		# Ingredient icon (small)
		var ing_icon = TextureRect.new()
		var ing_item = CraftingManager.create_item_by_id(ingredient_id)
		if ing_item and ing_item.icon:
			ing_icon.texture = ing_item.icon
		ing_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ing_icon.custom_minimum_size = Vector2(10, 10)
		ing_icon.modulate = Color(1, 1, 1, 0.9) if enough else Color(0.6, 0.4, 0.4, 0.8)
		ing_hbox.add_child(ing_icon)

		# Quantity text: "have/need"
		var ing_label = Label.new()
		ing_label.text = str(have) + "/" + str(required)
		ing_label.add_theme_font_size_override("font_size", 5)
		ing_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if enough else Color(0.9, 0.35, 0.3))
		ing_hbox.add_child(ing_label)

	# Craft button
	var craft_btn = Button.new()
	craft_btn.text = "Craft"
	craft_btn.add_theme_font_size_override("font_size", 5)
	craft_btn.custom_minimum_size = Vector2(26, 14)
	craft_btn.disabled = not craftable
	craft_btn.focus_mode = Control.FOCUS_NONE

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.35, 0.2, 0.9) if craftable else Color(0.15, 0.15, 0.15, 0.6)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.35, 0.55, 0.35, 0.8) if craftable else Color(0.2, 0.2, 0.2, 0.5)
	btn_style.set_corner_radius_all(2)
	btn_style.content_margin_left = 2
	btn_style.content_margin_right = 2
	btn_style.content_margin_top = 1
	btn_style.content_margin_bottom = 1
	craft_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.45, 0.25, 0.95)
	craft_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.12, 0.12, 0.12, 0.5)
	craft_btn.add_theme_stylebox_override("disabled", btn_disabled)

	craft_btn.pressed.connect(func():
		if CraftingManager.can_craft(recipe.ingredients):
			CraftingManager.try_craft(recipe.item_id, recipe.ingredients)
			populate_crafting_panel()
			update_inventory_display()
	)
	hbox.add_child(craft_btn)

	# Tooltip on hover for the row
	row_panel.mouse_entered.connect(func():
		tooltip.show_recipe_tooltip(recipe, row_panel.global_position + Vector2(row_panel.size.x, 0))
	)
	row_panel.mouse_exited.connect(func():
		tooltip.hide_tooltip()
	)

	return row_panel

# =========================================
# TOOLTIP (called by SlotUI)
# =========================================

func show_slot_tooltip(slot_index: int, global_pos: Vector2):
	if slot_index < 0 or slot_index >= InventoryManager.inventory.size():
		return
	var inv_item = InventoryManager.inventory[slot_index]
	if inv_item and inv_item.item:
		tooltip.show_item_tooltip(inv_item.item, inv_item.quantity, global_pos)

func hide_slot_tooltip():
	tooltip.hide_tooltip()

# =========================================
# SETTINGS PANEL
# =========================================

func _build_settings_panel():
	var ui = $UIContainer

	settings_panel = Panel.new()
	settings_panel.name = "SettingsPanel"
	var style = _make_panel_style()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	settings_panel.add_theme_stylebox_override("panel", style)
	settings_panel.size = Vector2(160, 120)
	settings_panel.position = Vector2((480 - 160) / 2.0, (270 - 120) / 2.0)
	settings_panel.visible = false
	ui.add_child(settings_panel)

	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
	title.position = Vector2(55, 4)
	settings_panel.add_child(title)

	# Volume sliders
	var y_offset = 20
	_add_settings_slider(settings_panel, "Master", AudioManager.master_volume, y_offset,
		func(val): AudioManager.set_master_volume(val))
	y_offset += 22
	_add_settings_slider(settings_panel, "SFX", AudioManager.sfx_volume, y_offset,
		func(val): AudioManager.set_sfx_volume(val))
	y_offset += 22
	_add_settings_slider(settings_panel, "Music", AudioManager.music_volume, y_offset,
		func(val): AudioManager.set_music_volume(val))

	# Buttons row
	y_offset += 26
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.18, 0.25, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	btn_style.set_corner_radius_all(2)
	btn_style.content_margin_left = 3
	btn_style.content_margin_right = 3
	btn_style.content_margin_top = 1
	btn_style.content_margin_bottom = 1

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.25, 0.4, 0.95)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.add_theme_font_size_override("font_size", 6)
	save_btn.custom_minimum_size = Vector2(40, 14)
	save_btn.position = Vector2(35, y_offset)
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.add_theme_stylebox_override("normal", btn_style)
	save_btn.add_theme_stylebox_override("hover", btn_hover)
	save_btn.pressed.connect(func():
		GameSettings.save_settings()
		AudioManager.play_sfx("ui_click")
	)
	settings_panel.add_child(save_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 6)
	close_btn.custom_minimum_size = Vector2(40, 14)
	close_btn.position = Vector2(85, y_offset)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_stylebox_override("normal", btn_style.duplicate())
	close_btn.add_theme_stylebox_override("hover", btn_hover.duplicate())
	close_btn.pressed.connect(_toggle_settings_menu)
	settings_panel.add_child(close_btn)

func _add_settings_slider(parent: Panel, label_text: String, initial_value: float, y_pos: int, callback: Callable):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	lbl.position = Vector2(8, y_pos + 1)
	parent.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(80, 12)
	slider.position = Vector2(48, y_pos)
	slider.size = Vector2(80, 12)
	slider.value_changed.connect(callback)
	parent.add_child(slider)

	var val_label = Label.new()
	val_label.text = str(int(initial_value * 100)) + "%"
	val_label.add_theme_font_size_override("font_size", 5)
	val_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	val_label.position = Vector2(132, y_pos + 2)
	parent.add_child(val_label)

	slider.value_changed.connect(func(val): val_label.text = str(int(val * 100)) + "%")

func _toggle_settings_menu():
	settings_panel_visible = !settings_panel_visible
	settings_panel.visible = settings_panel_visible
	SignalBus.settings_menu_toggled.emit(settings_panel_visible)
	if settings_panel_visible:
		AudioManager.play_sfx("ui_click")

# =========================================
# ARMOR EQUIPMENT PANEL
# =========================================

func _build_armor_panel():
	var ui = $UIContainer

	armor_panel = Panel.new()
	armor_panel.name = "ArmorPanel"
	var style = _make_panel_style()
	armor_panel.add_theme_stylebox_override("panel", style)
	armor_panel.size = Vector2(38, 108)
	armor_panel.position = Vector2(3, 14)
	ui.add_child(armor_panel)

	var title = Label.new()
	title.text = "Armor"
	title.add_theme_font_size_override("font_size", 5)
	title.add_theme_color_override("font_color", Color(0.65, 0.6, 0.75))
	title.position = Vector2(5, 2)
	armor_panel.add_child(title)

	var slot_names = ["head", "chest", "legs"]
	var slot_labels = ["H", "C", "L"]
	var y_start = 14

	for i in range(slot_names.size()):
		var slot_name = slot_names[i]

		var slot = Panel.new()
		slot.name = "ArmorSlot_" + slot_name
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.position = Vector2(5, y_start + i * (SLOT_SIZE + 4))

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.12, 0.18, 0.95)
		slot_style.set_border_width_all(1)
		slot_style.border_color = Color(0.4, 0.35, 0.5, 0.8)
		slot_style.set_corner_radius_all(2)
		slot.add_theme_stylebox_override("panel", slot_style)

		# Slot type indicator
		var s_label = Label.new()
		s_label.text = slot_labels[i]
		s_label.add_theme_font_size_override("font_size", 5)
		s_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.45, 0.6))
		s_label.position = Vector2(1, 1)
		s_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(s_label)

		# Icon for equipped armor
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 2
		icon.offset_top = 2
		icon.offset_right = -2
		icon.offset_bottom = -2
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		slot.gui_input.connect(_on_armor_slot_input.bind(slot_name))
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

		armor_panel.add_child(slot)
		armor_slots_ui[slot_name] = slot

	# Defense stat display
	defense_label = Label.new()
	defense_label.name = "DefenseLabel"
	defense_label.text = "DEF: 0"
	defense_label.add_theme_font_size_override("font_size", 5)
	defense_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	defense_label.position = Vector2(4, y_start + 3 * (SLOT_SIZE + 4))
	armor_panel.add_child(defense_label)

	SignalBus.armor_changed.connect(_on_armor_changed)

func _on_armor_slot_input(event: InputEvent, slot_name: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_armor_slot_clicked(slot_name)

func _on_armor_slot_clicked(slot_name: String):
	var player = get_node_or_null("/root/Playground/Player")
	if not player:
		return

	# If armor is equipped, unequip it back to inventory
	if player.equipped_armor.get(slot_name):
		var old_item = player.unequip_armor(slot_name)
		if old_item:
			InventoryManager.add_item(old_item)
			AudioManager.play_sfx("ui_click")
		update_armor_display()
		return

	# Try to equip the currently selected hotbar item
	var selected_item: Item = null
	if selected_hotbar_index < InventoryManager.inventory.size():
		selected_item = InventoryManager.inventory[selected_hotbar_index].item

	if selected_item and selected_item.armor_slot == slot_name:
		InventoryManager.remove_item(selected_item.id, 1)
		player.equip_armor(slot_name, selected_item)
		AudioManager.play_sfx("ui_click")
		update_armor_display()

func update_armor_display():
	var player = get_node_or_null("/root/Playground/Player")
	if not player:
		return

	for slot_name in armor_slots_ui:
		var slot = armor_slots_ui[slot_name]
		var icon = slot.get_node("Icon")
		var armor_item = player.equipped_armor.get(slot_name)

		if armor_item and armor_item is Item:
			icon.texture = armor_item.icon
		else:
			icon.texture = null

	if defense_label:
		defense_label.text = "DEF: " + str(player.get_defense())

func _on_armor_changed(_slot: String, _item):
	update_armor_display()
