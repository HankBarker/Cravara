extends Panel
class_name SlotUI

@export var slot_index: int = -1
var parent_ui = null
var _is_hovered: bool = false

func _ready():
	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

func _on_gui_input(event):
	if slot_index < 0 or slot_index >= InventoryManager.inventory.size():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var slot_data = InventoryManager.inventory[slot_index]
			if slot_data.item != null:
				DragController.start_drag(self, slot_data.item.icon, slot_data.quantity)
		else:
			if DragController.dragged_slot and DragController.dragged_slot != self:
				InventoryManager.swap_items(DragController.dragged_slot.slot_index, self.slot_index)
			DragController.end_drag()

func _on_mouse_entered():
	_is_hovered = true
	# Brighten border on hover
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = style.border_color.lightened(0.3)
	add_theme_stylebox_override("panel", style)

	# Show tooltip
	if parent_ui and slot_index >= 0:
		parent_ui.show_slot_tooltip(slot_index, global_position + Vector2(size.x + 2, 0))

func _on_mouse_exited():
	_is_hovered = false
	# Restore border
	if parent_ui:
		parent_ui.hide_slot_tooltip()
		parent_ui.update_inventory_display()
