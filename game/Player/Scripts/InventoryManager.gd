
# InventoryManager.gd - Singleton for managing items
# ===========================================
extends Node

const MAX_INVENTORY_SIZE = 35
var inventory: Array[Dictionary] = []

signal inventory_changed
signal item_picked_up(item: Item, quantity: int)

var selected_slot_index: int = 0  # Default to slot 0

func _ready():
	# Initialize empty inventory
	for i in range(MAX_INVENTORY_SIZE):
		inventory.append({"item": null, "quantity": 0})
	
	print("📦 Inventory System initialized with ", MAX_INVENTORY_SIZE, " slots")

func add_item(item: Item, quantity: int = 1) -> bool:
	print("📦 Attempting to add ", quantity, "x ", item.name)

	# 🔁 First, try stacking in the HOTBAR (slots 0–7)
	for i in range(8):
		var slot = inventory[i]
		if slot.item and slot.item.id == item.id:
			var space_available = item.max_stack - slot.quantity
			if space_available > 0:
				var amount_to_add = min(quantity, space_available)
				slot.quantity += amount_to_add
				quantity -= amount_to_add
				print("📦 Stacked ", amount_to_add, "x ", item.name, " in hotbar slot ", i)
				if quantity <= 0:
					inventory_changed.emit()
					item_picked_up.emit(item, amount_to_add)
					return true

	# 🔁 Then stack in slots 8+
	for i in range(8, inventory.size()):
		var slot = inventory[i]
		if slot.item and slot.item.id == item.id:
			var space_available = item.max_stack - slot.quantity
			if space_available > 0:
				var amount_to_add = min(quantity, space_available)
				slot.quantity += amount_to_add
				quantity -= amount_to_add
				print("📦 Stacked ", amount_to_add, "x ", item.name, " in inventory slot ", i)
				if quantity <= 0:
					inventory_changed.emit()
					item_picked_up.emit(item, amount_to_add)
					return true

	# ✅ Try to add to EMPTY hotbar slots
	for i in range(8):
		if inventory[i].item == null:
			var amount_to_add = min(quantity, item.max_stack)
			inventory[i] = {"item": item, "quantity": amount_to_add}
			quantity -= amount_to_add
			print("📦 Added ", amount_to_add, "x ", item.name, " to empty hotbar slot ", i)
			inventory_changed.emit()
			item_picked_up.emit(item, amount_to_add)
			return true

	# 🔚 Then to empty slots in the rest of inventory
	for i in range(8, inventory.size()):
		if inventory[i].item == null:
			var amount_to_add = min(quantity, item.max_stack)
			inventory[i] = {"item": item, "quantity": amount_to_add}
			quantity -= amount_to_add
			print("📦 Added ", amount_to_add, "x ", item.name, " to empty inventory slot ", i)
			inventory_changed.emit()
			item_picked_up.emit(item, amount_to_add)
			return true

	print("📦 Inventory full! Couldn't add ", quantity, "x ", item.name)
	return false


func find_empty_slot() -> int:
	for i in range(inventory.size()):
		if inventory[i].item == null:
			return i
	return -1

func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot.item and slot.item.id == item_id:
			if slot.quantity >= quantity:
				slot.quantity -= quantity
				if slot.quantity <= 0:
					slot.item = null
					slot.quantity = 0
				inventory_changed.emit()
				return true
	return false

func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in inventory:
		if slot.item and slot.item.id == item_id:
			total += slot.quantity
	return total

func print_inventory():
	print("📦 === INVENTORY ===")
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot.item:
			print("Slot ", i, ": ", slot.quantity, "x ", slot.item.name)
			
func get_selected_item() -> Item:
	if selected_slot_index < 0 or selected_slot_index >= inventory.size():
		return null
	return inventory[selected_slot_index].item

func swap_items(from_index: int, to_index: int) -> void:
	var temp = inventory[from_index]
	inventory[from_index] = inventory[to_index]
	inventory[to_index] = temp

	inventory_changed.emit()
