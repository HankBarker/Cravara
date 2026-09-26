extends Node
const _Foods = preload("res://Forest/life/Foods.gd")

## Pass 14: forty pockets, eight across (five pouches of eight; was 35).
const MAX_INVENTORY_SIZE = 40
var inventory: Array[Dictionary] = []
var selected_slot_index: int = 0
var hotbar_start: int = 0
signal inventory_changed
signal item_picked_up(item: Item, quantity: int)

func get_hotbar_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in range(hotbar_start,mini(hotbar_start+8,inventory.size())): indices.append(i)
	return indices

func cycle_hotbar() -> void:
	var relative := clampi(selected_slot_index-hotbar_start,0,7)
	hotbar_start = (hotbar_start+8) if hotbar_start+8 < inventory.size() else 0
	selected_slot_index = mini(hotbar_start+relative,inventory.size()-1)
	inventory_changed.emit()

func select_hotbar(position: int) -> void:
	var indices := get_hotbar_indices()
	if position >= 0 and position < indices.size():
		selected_slot_index = indices[position]
		inventory_changed.emit()

func scroll_hotbar(direction: int) -> void:
	var indices := get_hotbar_indices()
	if indices.is_empty(): return
	selected_slot_index = indices[posmod(selected_slot_index-hotbar_start+direction,indices.size())]
	inventory_changed.emit()

func _ready() -> void:
	for i in MAX_INVENTORY_SIZE:
		inventory.append({"item": null, "quantity": 0})

func capacity_for(item: Item) -> int:
	if item == null: return 0
	var capacity := 0
	for slot in inventory:
		if slot.item == null: capacity += item.max_stack
		elif slot.item.id == item.id: capacity += maxi(0, item.max_stack - int(slot.quantity))
	return capacity

# Atomic: false means no inventory mutation. Pickups can safely remain in the world.
func add_item(item: Item, quantity: int = 1) -> bool:
	if item == null or quantity <= 0 or capacity_for(item) < quantity: return false
	var remaining := quantity
	for slot in inventory:
		if slot.item and slot.item.id == item.id:
			var amount := mini(remaining, maxi(0, item.max_stack - int(slot.quantity)))
			slot.quantity += amount
			remaining -= amount
	for i in inventory.size():
		if remaining == 0: break
		if inventory[i].item == null:
			var amount := mini(remaining, item.max_stack)
			inventory[i] = {"item": item, "quantity": amount}
			remaining -= amount
	inventory_changed.emit()
	item_picked_up.emit(item, quantity)
	return true

func find_empty_slot() -> int:
	for i in inventory.size():
		if inventory[i].item == null: return i
	return -1

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or get_item_count(item_id) < quantity: return false
	# Pass 15: "any:fish" takes the commonest of its group first (Foods.gd).
	var members: Array = _Foods.group(item_id)
	if not members.is_empty():
		var left := quantity
		for id in members:
			var take := mini(left, get_item_count(str(id)))
			if take > 0: remove_item(str(id), take)
			left -= take
			if left <= 0: break
		return true
	var remaining := quantity
	for i in inventory.size():
		var slot := inventory[i]
		if slot.item and slot.item.id == item_id:
			var amount := mini(remaining, int(slot.quantity))
			slot.quantity -= amount
			remaining -= amount
			if slot.quantity == 0: inventory[i] = {"item": null, "quantity": 0}
			if remaining == 0: break
	inventory_changed.emit()
	return true

func get_item_count(item_id: String) -> int:
	var total := 0
	if item_id.begins_with("any:"):
		for id in _Foods.group(item_id): total += get_item_count(str(id))
		return total
	for slot in inventory:
		if slot.item and slot.item.id == item_id: total += int(slot.quantity)
	return total

func get_selected_item() -> Item:
	if selected_slot_index < 0 or selected_slot_index >= inventory.size(): return null
	return inventory[selected_slot_index].item

func swap_items(from_index: int, to_index: int) -> void:
	if from_index == to_index or mini(from_index, to_index) < 0 or maxi(from_index, to_index) >= inventory.size(): return
	var a := inventory[from_index]
	var b := inventory[to_index]
	if a.item and b.item and a.item.id == b.item.id:
		var amount := mini(int(a.quantity), maxi(0, b.item.max_stack - int(b.quantity)))
		b.quantity += amount
		a.quantity -= amount
		if a.quantity == 0: inventory[from_index] = {"item": null, "quantity": 0}
	else:
		inventory[from_index] = b
		inventory[to_index] = a
	inventory_changed.emit()

## Only reorganize the backpack outside the currently visible hotbar pouch.
func sort_backpack() -> int:
	if is_instance_valid(DragController.dragged_slot): return 0
	var protected:=get_hotbar_indices()
	var destinations: Array[int]=[]
	var stacks: Array[Dictionary]=[]
	for i in inventory.size():
		if i in protected: continue
		destinations.append(i)
		var slot: Dictionary=inventory[i]
		if slot.item:
			var left: int=slot.quantity
			for stack in stacks:
				if stack.item.id==slot.item.id:
					var moved:=mini(left,maxi(0,int(stack.item.max_stack)-int(stack.quantity)))
					stack.quantity+=moved
					left-=moved
			if left>0: stacks.append({"item":slot.item,"quantity":left})
	stacks.sort_custom(func(a,b): return (a.item.name+"/"+a.item.id).naturalnocasecmp_to(b.item.name+"/"+b.item.id)<0)
	var changed:=0
	for j in destinations.size():
		var replacement: Dictionary=stacks[j] if j<stacks.size() else {"item":null,"quantity":0}
		if inventory[destinations[j]]!=replacement: changed+=1
		inventory[destinations[j]]=replacement
	if changed: inventory_changed.emit()
	return changed

## Matching item types only; protected hotbar, distance and wall checks are atomic.
func quick_stack_nearby(player: Node2D, radius := 80.0) -> Dictionary:
	var result:={"moved":0,"chests":0,"blocked":0}
	if not is_instance_valid(player) or is_instance_valid(DragController.dragged_slot): return result
	var protected:=get_hotbar_indices()
	var chests:=get_tree().get_nodes_in_group("chests")
	chests.sort_custom(func(a,b): return a.global_position.distance_squared_to(player.global_position)<b.global_position.distance_squared_to(player.global_position))
	for chest in chests:
		if not is_instance_valid(chest) or chest.is_queued_for_deletion() or chest.global_position.distance_to(player.global_position)>radius: continue
		var ray:=PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,8),chest.global_position,16)
		var excluded: Array[RID]=[]
		if player is CollisionObject2D: excluded.append(player.get_rid())
		if chest is CollisionObject2D: excluded.append(chest.get_rid())
		if chest.get_parent() is CollisionObject2D: excluded.append(chest.get_parent().get_rid())
		ray.exclude=excluded
		if not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			result.blocked+=1
			continue
		var matching: Dictionary={}
		for entry in chest.inventory:
			if entry.item: matching[entry.item.id]=true
		var chest_moved:=0
		for i in inventory.size():
			var source: Dictionary=inventory[i]
			if i in protected or not source.item or not matching.has(source.item.id): continue
			for entry in chest.inventory:
				if entry.item and entry.item.id==source.item.id:
					var moved:=mini(int(source.quantity),maxi(0,int(entry.item.max_stack)-int(entry.quantity)))
					entry.quantity+=moved
					source.quantity-=moved
					chest_moved+=moved
			for j in chest.inventory.size():
				if source.quantity<=0: break
				if chest.inventory[j].item==null:
					var moved:=mini(int(source.quantity),int(source.item.max_stack))
					chest.inventory[j]={"item":source.item,"quantity":moved}
					source.quantity-=moved
					chest_moved+=moved
			if source.quantity<=0: inventory[i]={"item":null,"quantity":0}
		if chest_moved:
			result.chests+=1
			result.moved+=chest_moved
			chest.inventory_changed.emit()
	if result.moved: inventory_changed.emit()
	return result
