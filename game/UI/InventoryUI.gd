extends CanvasLayer

@onready var inventory_grid = $UIContainer/InventoryPanel/GridContainer
@onready var inventory_panel = $UIContainer/InventoryPanel
@onready var crafting_panel = $UIContainer/PersonalCraftingPanel
@onready var recipe_list = $UIContainer/PersonalCraftingPanel
@onready var hotbar_panel = $UIContainer/HotbarPanel
@onready var slot_script = preload("res://UI/SlotUI.gd")

var inventory_slots: Array[Control] = []
var hotbar_slots: Array[Control] = []
var selected_hotbar_index: int = 0

func _ready():
	inventory_panel.visible = false
	crafting_panel.visible = false

	# Stick close to your original layout style, just scaled for 35 slots
	inventory_panel.size = Vector2(280, 100)  # Wider and taller to fit 35 slots
	inventory_panel.position = Vector2(100, 120)  # Keep in middle-left region (your base layout)

	# Grid with 7 columns to support 35 items
	inventory_grid.columns = 9
	inventory_grid.position = Vector2(10, 10)  # Padding inside panel

	# Resize crafting panel, and place it up and to the LEFT of inventory
	crafting_panel.size = Vector2(100, 70)
	crafting_panel.position = Vector2(100, 45)  # Move left and down a little

	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		InventoryManager.item_picked_up.connect(_on_item_picked_up)

	create_inventory_slots()
	create_hotbar_slots()


func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_inventory()

	# Use item from selected hotbar slot
	if Input.is_action_just_pressed("use_hotbar_item"):
		var selected_item: Item = null
		if selected_hotbar_index < InventoryManager.inventory.size():
			selected_item = InventoryManager.inventory[selected_hotbar_index].item

		if selected_item != null:
			if selected_item.id == "workbench":
				print("🎯 Initiating placement mode for:", selected_item.name)
				var placement_controller = preload("res://Systems/Placement/PlacementController.tscn").instantiate()
				placement_controller.object_to_place = preload("res://WorldObjects/Workbench.tscn")
				get_tree().get_root().add_child(placement_controller)
			else:
				print("🛠️ Using non-placeable item:", selected_item.name)
		else:
			print("❌ No item in selected hotbar slot.")

	# Handle hotbar selection 1–8
	for i in range(8):
		if Input.is_action_just_pressed("hotbar_" + str(i + 1)):
			selected_hotbar_index = i
			create_hotbar_slots()

func toggle_inventory():
	var is_open = !inventory_panel.visible
	inventory_panel.visible = is_open
	crafting_panel.visible = is_open
	if is_open:
		populate_personal_crafting()

func create_inventory_slots():
	for child in inventory_grid.get_children():
		child.queue_free()
	inventory_slots.clear()

	for i in range(8, 35):  # Inventory = slots 8–34
		var slot = create_inventory_slot(i)
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)

func create_inventory_slot(index: int) -> Control:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(26, 26)
	slot.name = "Slot_" + str(index)

	var slot_script = preload("res://UI/SlotUI.gd").new()
	slot.set_script(slot_script)
	slot.set("slot_index", index)

	# Style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_box.set_border_width_all(1)
	style_box.border_color = Color(1, 1, 1, 1) if index == selected_hotbar_index else Color(0.5, 0.5, 0.5, 1)
	slot.add_theme_stylebox_override("panel", style_box)

	# Icon
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = 0
	icon.anchor_top = 0
	icon.anchor_right = 1
	icon.anchor_bottom = 1
	icon.offset_left = -7
	icon.offset_top = -7
	icon.offset_right = -250
	icon.offset_bottom = 0
	icon.custom_minimum_size = Vector2(40, 40)
	slot.add_child(icon)

	# Quantity
	var quantity_label = Label.new()
	quantity_label.name = "Quantity"
	quantity_label.size = Vector2(15, 15)
	quantity_label.add_theme_color_override("font_color", Color.YELLOW)
	quantity_label.add_theme_font_size_override("font_size", 10)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(quantity_label)

	return slot

func create_hotbar_slots():
	for child in hotbar_panel.get_children():
		child.queue_free()
	hotbar_slots.clear()

	for i in range(8):
		var slot = create_inventory_slot(i)  # Reuse inventory slot builder
		hotbar_panel.add_child(slot)
		hotbar_slots.append(slot)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 1) if i == selected_hotbar_index else Color(0.5, 0.5, 0.5, 1)
		slot.add_theme_stylebox_override("panel", style)

		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.add_child(icon)

		hotbar_panel.add_child(slot)
		hotbar_slots.append(slot)

func _on_inventory_changed():
	update_inventory_display()

func _on_item_picked_up(item: Item, quantity: int):
	print("Picked up ", quantity, "x ", item.name)

func update_inventory_display():
	for i in range(min(12, inventory_slots.size())):
		var slot = inventory_slots[i]
		var inventory_item = null
		if i < InventoryManager.inventory.size():
			inventory_item = InventoryManager.inventory[i]
		var icon = slot.get_node("Icon")
		var quantity_label = slot.get_node("Quantity")

		if inventory_item and inventory_item.item:
			icon.texture = inventory_item.item.icon
			quantity_label.text = str(inventory_item.quantity) if inventory_item.quantity > 1 else ""
		else:
			icon.texture = null
			quantity_label.text = ""

	# Update hotbar
	for i in range(min(8, hotbar_slots.size())):
		var slot = hotbar_slots[i]
		var inventory_item = InventoryManager.inventory[i]
		var icon = slot.get_node("Icon")

		if inventory_item and inventory_item.item:
			icon.texture = inventory_item.item.icon
		else:
			icon.texture = null

func populate_personal_crafting():
	for child in recipe_list.get_children():
		child.queue_free()

	var start_x = 4  # Padding from the left edge of the panel
	var y_offset = 4  # Padding from the top edge
	var spacing = 24  # Space between icons

	var x_offset = -15

	for recipe in CraftingManager.personal_recipes:
		var can_craft = CraftingManager.can_craft(recipe.ingredients)

		var icon_button = TextureButton.new()
		icon_button.texture_normal = CraftingManager.get_item_icon(recipe.item_id)
		icon_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		icon_button.custom_minimum_size = Vector2(20, 20)
		icon_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_button.focus_mode = Control.FOCUS_NONE
		icon_button.position = Vector2(x_offset, 0)  # 👈 Position icon manually

		var y_center = (recipe_list.size.y - icon_button.custom_minimum_size.y) / 2
		icon_button.position = Vector2(x_offset, y_center)
	
		# Lighten icon if it's craftable
		icon_button.disabled = not can_craft
		icon_button.modulate = Color(1, 1, 1, 1) if can_craft else Color(0.4, 0.4, 0.4, 0.7)

		icon_button.pressed.connect(func():
			if CraftingManager.can_craft(recipe.ingredients):
				CraftingManager.try_craft(recipe.item_id, recipe.ingredients)
				populate_personal_crafting()
				update_inventory_display()
		)

		recipe_list.add_child(icon_button)
		x_offset += spacing  # 👈 Move next icon to the right
