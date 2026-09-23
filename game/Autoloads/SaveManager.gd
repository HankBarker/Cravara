extends Node

# Persists player state, time of day, and placed objects (including chest
# contents) to user://save.json. Auto-saves every 60s and on quit.
# Loads on first frame after playground is ready.

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 60.0

var _accum: float = 0.0
var _initial_loaded: bool = false
var _persistence_enabled: bool = true

func _ready():
	# Isolated creature playtests must never load or overwrite a player's save.
	if "--no-save-playtest" in OS.get_cmdline_user_args():
		disable_for_playtest()
		return
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_on_quit)
	call_deferred("_initial_load")

func disable_for_playtest():
	_persistence_enabled = false
	set_process(false)

func _process(delta):
	_accum += delta
	if _accum >= AUTOSAVE_INTERVAL:
		_accum = 0.0
		save_now()

func _on_quit():
	save_now()
	get_tree().quit()

func _initial_load():
	# Give playground.tscn a frame to instantiate (player, etc.)
	await get_tree().process_frame
	if not _persistence_enabled:
		return
	_initial_loaded = true
	if FileAccess.file_exists(SAVE_PATH):
		load_now()

func save_now():
	if not _persistence_enabled:
		return
	var state := _collect_state()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state, "  "))
		f.close()

func load_now() -> bool:
	if not _persistence_enabled:
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	_apply_state(parsed)
	return true

# ---------- COLLECT ----------

func _collect_state() -> Dictionary:
	var state := {}
	var player = get_tree().get_first_node_in_group("player")
	if player:
		state["player"] = {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"health": player.current_health,
			"hunger": player.current_hunger,
			"stamina": player.current_stamina,
			"inventory": _serialize_inventory(InventoryManager.inventory),
			"armor": {
				"head": _id_of(player.equipped_armor.get("head")),
				"chest": _id_of(player.equipped_armor.get("chest")),
				"legs": _id_of(player.equipped_armor.get("legs")),
			}
		}

	state["world"] = {
		"time_of_day": (TimeCycle.time_of_day if TimeCycle else 0.5),
		"placed": _collect_placed_objects()
	}
	return state

func _serialize_inventory(inv: Array) -> Array:
	var out := []
	for slot in inv:
		if slot.item:
			out.append({"id": slot.item.id, "qty": slot.quantity})
		else:
			out.append({"id": "", "qty": 0})
	return out

func _id_of(item) -> String:
	return item.id if item else ""

func _collect_placed_objects() -> Array:
	var out := []
	for node in get_tree().get_nodes_in_group("placed_objects"):
		if not is_instance_valid(node):
			continue
		var entry := {
			"id": str(node.get_meta("item_id", "")),
			"x": node.global_position.x,
			"y": node.global_position.y
		}
		if node.has_method("get_save_data"):
			entry["data"] = node.get_save_data()
		out.append(entry)
	return out

# ---------- APPLY ----------

func _apply_state(data: Dictionary):
	var player = get_tree().get_first_node_in_group("player")
	if player and data.has("player"):
		var p: Dictionary = data["player"]
		player.global_position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		player.current_health = int(p.get("health", player.max_health))
		player.current_hunger = int(p.get("hunger", player.max_hunger))
		player.current_stamina = float(p.get("stamina", player.max_stamina))
		_restore_inventory(p.get("inventory", []))
		_restore_armor(player, p.get("armor", {}))
		SignalBus.player_health_changed.emit(player.current_health, player.max_health)
		SignalBus.player_hunger_changed.emit(player.current_hunger, player.max_hunger)
		SignalBus.player_stamina_changed.emit(player.current_stamina, player.max_stamina)

	if data.has("world"):
		var w: Dictionary = data["world"]
		if TimeCycle and w.has("time_of_day"):
			TimeCycle.time_of_day = float(w["time_of_day"])
		for entry in w.get("placed", []):
			_respawn_placed_object(entry)

func _restore_inventory(saved: Array):
	for i in range(InventoryManager.inventory.size()):
		InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	for i in range(min(saved.size(), InventoryManager.inventory.size())):
		var entry = saved[i]
		var id: String = str(entry.get("id", ""))
		var qty: int = int(entry.get("qty", 0))
		if id == "" or qty <= 0:
			continue
		var item = CraftingManager.create_item_by_id(id)
		if item:
			InventoryManager.inventory[i] = {"item": item, "quantity": qty}
	InventoryManager.inventory_changed.emit()

func _restore_armor(player, armor_data: Dictionary):
	for slot_name in ["head", "chest", "legs"]:
		var id: String = str(armor_data.get(slot_name, ""))
		if id == "":
			continue
		var item = CraftingManager.create_item_by_id(id)
		if item:
			player.equip_armor(slot_name, item)

func _respawn_placed_object(entry: Dictionary):
	var id: String = str(entry.get("id", ""))
	if id == "":
		return
	var template = CraftingManager.create_item_by_id(id)
	if not template or template.place_scene == "":
		return
	var scene = load(template.place_scene)
	if not scene:
		return
	var inst = scene.instantiate()
	inst.global_position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
	inst.set_meta("item_id", id)
	inst.add_to_group("placed_objects")
	get_tree().current_scene.add_child(inst)
	if entry.has("data") and inst.has_method("apply_save_data"):
		inst.apply_save_data(entry["data"])
