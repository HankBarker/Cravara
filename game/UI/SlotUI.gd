extends Panel
class_name SlotUI

@export var slot_index: int = -1
var parent_ui = null
# When set, this slot reads/writes its data from `source.inventory` and
# emits `source.inventory_changed` instead of the global InventoryManager.
# Used by chest slots so the same SlotUI code works in both contexts.
var source = null
var _is_hovered: bool = false
var _press_position: Vector2 = Vector2.ZERO

# Distance (in pixels) the mouse must move while held to count as a drag
const DRAG_THRESHOLD := 4.0

func _ready():
	add_to_group("inventory_slots")
	focus_mode=Control.FOCUS_ALL
	focus_entered.connect(_on_mouse_entered)
	focus_exited.connect(_on_mouse_exited)
	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

## The item's name in gold over its details, in the kit's crisp pixel text
## (the tooltip plate itself comes from the theme).
func _make_custom_tooltip(for_text: String) -> Object:
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",3)
	var lines:=for_text.split("\n",true,1)
	for i in lines.size():
		var label:=Label.new()
		label.text=lines[i]
		label.custom_minimum_size=Vector2(188,0)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font",preload("res://Forest/fonts/Tiny5-Regular.ttf"))
		label.add_theme_font_size_override("font_size",8)
		label.add_theme_color_override("font_shadow_color",Color(0.02,0.06,0.06,0.92))
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		if i==0 and lines.size()>1: label.add_theme_color_override("font_color",Color("dcc085"))
		column.add_child(label)
	return column

func _get_source():
	return source if source != null else InventoryManager

func _on_gui_input(event):
	var src = _get_source()
	if slot_index < 0 or slot_index >= src.inventory.size(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var slot_data = src.inventory[slot_index]
			if event.shift_pressed and parent_ui and parent_ui.has_method("transfer_slot"):
				parent_ui.transfer_slot(self)
			elif slot_data.item != null:
				DragController.start_drag(self,slot_data.item.icon,slot_data.quantity,get_global_transform_with_canvas()*event.position)
			elif parent_ui and parent_ui.has_method("select_slot"):
				parent_ui.select_slot(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_try_consume()
func _try_consume():
	var src = _get_source()
	var slot_data = src.inventory[slot_index]
	if slot_data == null or slot_data.item == null or not slot_data.item.consumable:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("eat"):
		return
	if player.has_method("consume_slot"):
		if not player.consume_slot(src, slot_index) and parent_ui and parent_ui.has_method("show_toast"):
			parent_ui.show_toast("Already well fed, healthy, or still finishing a bite.")
		return
	if player.current_hunger >= player.max_hunger:
		if parent_ui and parent_ui.has_method("show_toast"): parent_ui.show_toast("You are already well fed")
		return
	if player.eat(slot_data.item):
		slot_data.quantity -= 1
		if slot_data.quantity <= 0:
			src.inventory[slot_index] = {"item": null, "quantity": 0}
		src.inventory_changed.emit()

func _try_quick_equip():
	if parent_ui and parent_ui.has_method("select_slot"):
		parent_ui.select_slot(self)
	# Quick-equip only makes sense for slots backed by the player's
	# InventoryManager — equipping out of a chest would be confusing.
	if source != null:
		return
	var slot_data = InventoryManager.inventory[slot_index]
	if slot_data == null or slot_data.item == null:
		return
	if slot_data.item.armor_slot == "":
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("equip_armor"):
		return

	var target_slot: String = slot_data.item.armor_slot
	if player.has_method("equip_from_inventory"):
		if player.equip_from_inventory(slot_index,target_slot):
			AudioManager.play_sfx("equip_gear")
		return
	var new_armor: Item = slot_data.item
	var current: Item = player.equipped_armor.get(target_slot)

	if current:
		InventoryManager.inventory[slot_index] = {"item": current, "quantity": 1}
	else:
		InventoryManager.inventory[slot_index] = {"item": null, "quantity": 0}
	InventoryManager.inventory_changed.emit()
	player.equip_armor(target_slot, new_armor)
	AudioManager.play_sfx("equip_gear")
	if parent_ui and parent_ui.has_method("update_armor_display"):
		parent_ui.update_armor_display()

func _on_mouse_entered():
	_is_hovered = true
	if parent_ui and parent_ui.has_method("slot_style"):
		add_theme_stylebox_override("panel", parent_ui.slot_style(self, true))
	else:
		var style = get_theme_stylebox("panel").duplicate()
		if style is StyleBoxFlat:
			style.border_color = style.border_color.lightened(0.3)
			add_theme_stylebox_override("panel", style)

	if parent_ui and slot_index >= 0 and parent_ui.has_method("show_slot_tooltip_for"):
		parent_ui.show_slot_tooltip_for(self)
	elif parent_ui and slot_index >= 0 and parent_ui.has_method("show_slot_tooltip"):
		parent_ui.show_slot_tooltip(slot_index, global_position + Vector2(size.x + 2, 0))

func _on_mouse_exited():
	_is_hovered = false
	if parent_ui:
		parent_ui.hide_slot_tooltip()
		parent_ui.update_inventory_display()
