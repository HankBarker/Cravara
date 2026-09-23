extends StaticBody2D

# A placeable storage chest. Stores its own 18-slot inventory. Press E
# while standing inside its proximity area to open/close.

const CHEST_SIZE := 18
const _ChestItem = preload("res://Items/ChestItem.gd")

signal inventory_changed

var inventory: Array[Dictionary] = []
var _player_in_range: bool = false

func _ready():
	add_to_group("chests")
	# Initialize empty slots
	for i in CHEST_SIZE:
		inventory.append({"item": null, "quantity": 0})

	# Reuse the item icon as the world sprite (scaled up).
	var sprite: Sprite2D = $Sprite2D
	if sprite:
		sprite.texture = _ChestItem._make_icon()
		sprite.scale = Vector2(1.4, 1.4)

	if has_node("ProximityArea"):
		var area: Area2D = $ProximityArea
		area.body_entered.connect(_on_player_entered)
		area.body_exited.connect(_on_player_exited)

func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

func _on_player_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		# Close the UI if it was looking at this chest
		var ui = get_tree().get_first_node_in_group("inventory_ui")
		if ui and ui.has_method("close_chest_if_open") and ui.is_chest_open_for(self):
			ui.close_chest()

func is_player_nearby() -> bool:
	return _player_in_range

func get_save_data() -> Dictionary:
	var contents := []
	for slot in inventory:
		if slot.item:
			contents.append({"id": slot.item.id, "qty": slot.quantity})
		else:
			contents.append({"id": "", "qty": 0})
	return {"contents": contents}

func apply_save_data(data: Dictionary) -> void:
	var contents = data.get("contents", [])
	for i in range(min(contents.size(), inventory.size())):
		var entry = contents[i]
		var id: String = str(entry.get("id", ""))
		var qty: int = int(entry.get("qty", 0))
		if id != "" and qty > 0:
			var item = CraftingManager.create_item_by_id(id)
			if item:
				inventory[i] = {"item": item, "quantity": qty}
				continue
		inventory[i] = {"item": null, "quantity": 0}
	inventory_changed.emit()

func add_item(item: Item, quantity: int = 1) -> bool:
	# Try stacking first
	for i in inventory.size():
		var slot = inventory[i]
		if slot.item and slot.item.id == item.id:
			var room = item.max_stack - slot.quantity
			if room > 0:
				var take = min(quantity, room)
				slot.quantity += take
				quantity -= take
				if quantity <= 0:
					inventory_changed.emit()
					return true
	# Empty slot
	for i in inventory.size():
		if inventory[i].item == null:
			var take = min(quantity, item.max_stack)
			inventory[i] = {"item": item, "quantity": take}
			quantity -= take
			if quantity <= 0:
				inventory_changed.emit()
				return true
	inventory_changed.emit()
	return false
