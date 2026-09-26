extends Node
## Pass 13: a companion's saddlebags. A bag of slots it carries (more for a
## bigger beast, more still with the Saddlebags perk), opened from its Care
## panel in the same storage panel as a chest. Saved with the beast; if the
## beast falls, the bag and all in it drop where it lies.

signal inventory_changed

const SLOTS := {"small": 4, "medium": 8, "large": 12}
var inventory: Array[Dictionary] = []
var bag_title := "SADDLEBAGS"


func setup(slots: int, title: String) -> void:
	bag_title = title
	resize(slots)


## Grow (or, only into empty slots, shrink) the bag.
func resize(slots: int) -> void:
	while inventory.size() < slots:
		inventory.append({"item": null, "quantity": 0})
	while inventory.size() > slots and inventory[-1].item == null:
		inventory.pop_back()
	inventory_changed.emit()


func is_empty() -> bool:
	for slot in inventory:
		if slot.item != null and int(slot.quantity) > 0: return false
	return true


func used() -> int:
	var n := 0
	for slot in inventory:
		if slot.item != null and int(slot.quantity) > 0: n += 1
	return n


## Everything in it, as {id: quantity} (for the drop when its bearer falls).
func contents() -> Dictionary:
	var out := {}
	for slot in inventory:
		if slot.item != null and int(slot.quantity) > 0:
			out[slot.item.id] = int(out.get(slot.item.id, 0)) + int(slot.quantity)
	return out


func get_save_data() -> Dictionary:
	var items := []
	for slot in inventory:
		items.append({"id": slot.item.id if slot.item else "", "qty": int(slot.quantity) if slot.item else 0})
	return {"slots": inventory.size(), "contents": items}


func apply_save_data(data: Dictionary) -> void:
	var items: Array = data.get("contents", [])
	resize(maxi(int(data.get("slots", inventory.size())), items.size()))
	for i in inventory.size():
		inventory[i] = {"item": null, "quantity": 0}
		if i >= items.size(): continue
		var id := str(items[i].get("id", ""))
		var qty := int(items[i].get("qty", 0))
		if id != "" and qty > 0:
			var item: Item = ItemDB.make(id)
			if item: inventory[i] = {"item": item, "quantity": qty}
	inventory_changed.emit()


## Room this bag has for more of an item (its stacks' room plus empty slots).
func capacity_for(item: Item) -> int:
	if item == null: return 0
	var room := 0
	for slot in inventory:
		if slot.item == null: room += item.max_stack
		elif slot.item.id == item.id: room += maxi(0, item.max_stack - int(slot.quantity))
	return room

## All or nothing (pass 14), like InventoryManager.add_item: false means the
## bag is untouched. (It used to keep what fitted and still say false, and
## a caller that left its own stack alone on false made items from nothing.)
func add_item(item: Item, quantity: int = 1) -> bool:
	if item == null or quantity <= 0 or capacity_for(item) < quantity: return false
	for slot in inventory:
		if slot.item and slot.item.id == item.id:
			var room: int = item.max_stack - int(slot.quantity)
			if room > 0:
				var take := mini(quantity, room)
				slot.quantity = int(slot.quantity) + take
				quantity -= take
				if quantity <= 0:
					inventory_changed.emit()
					return true
	for i in inventory.size():
		if inventory[i].item == null:
			var take := mini(quantity, item.max_stack)
			inventory[i] = {"item": item, "quantity": take}
			quantity -= take
			if quantity <= 0:
				inventory_changed.emit()
				return true
	inventory_changed.emit()
	return false
