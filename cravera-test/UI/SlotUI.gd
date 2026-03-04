extends Panel
class_name SlotUI

@export var slot_index: int = -1

func _ready():
	connect("gui_input", _on_gui_input)

func _process(_delta):
	if DragController.dragged_icon:
		DragController.update_drag_position()

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var slot_data = InventoryManager.inventory[slot_index]
			if slot_data.item != null:
				DragController.start_drag(self, slot_data.item.icon)
		else:
			if DragController.dragged_slot and DragController.dragged_slot != self:
				InventoryManager.swap_items(DragController.dragged_slot.slot_index, self.slot_index)
			DragController.end_drag()
