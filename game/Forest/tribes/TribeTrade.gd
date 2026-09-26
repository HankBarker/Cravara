extends RefCounted
## Trading with the Sunward (pass 12) through the folk dialogue: the same
## calls FolkManager answers (coins, wares, buy, sell, ...), for the
## "tribe_sunward" talker. A tribe the keeper wronged won't deal
## (TribeKeeper.anger).

const Tribes = preload("res://Forest/tribes/Tribes.gd")

var tribes
## The dialogue closes when the one it's talking to walks off: id -> node.
var actors := {}
var folk := {}


func _init(keeper_of_tribes) -> void:
	tribes = keeper_of_tribes


func open_with(person: Node2D) -> void:
	actors[person.trade_id] = person
	folk[person.trade_id] = {}


## The camp the one talking belongs to (pass 13), and its page for the dialogue.
func camp_id(id: String) -> String:
	var who = actors.get(id)
	return tribes.camp_of(who) if is_instance_valid(who) else ""


func camp_page(id: String) -> Dictionary:
	var vid := camp_id(id)
	if vid == "": return {}
	var Camps = tribes.Camps
	var tribe: String = str(tribes.villages.get(vid, {}).get("tribe", ""))
	var st := int(tribes.standing.get(vid, 0))
	return {"camp": vid, "name": Camps.name_of(vid), "standing": st, "word": Camps.word(st, tribe), "request": tribes.request_of(vid), "ready": tribes.request_met(vid)}


func camp_give(id: String) -> String:
	var vid := camp_id(id)
	return tribes.give(vid) if vid != "" else "There's no camp here."


func camp_gift(id: String) -> String:
	var vid := camp_id(id)
	return tribes.gift(vid) if vid != "" else "There's no camp here."


func coins() -> int:
	return InventoryManager.get_item_count(Tribes.COIN)


func wares(_id: String) -> Dictionary:
	return Tribes.STOCK.duplicate() if tribes.can_trade("sunward") else {}


## What the tribe pays for (the dialogue's sell list).
func buys_for(_id: String) -> Dictionary:
	return Tribes.BUYS if tribes.can_trade("sunward") else {}


func buy(id: String, item_id: String) -> String:
	if not tribes.can_trade("sunward"): return _pick_angry()
	var offer: Array = wares(id).get(item_id, [])
	if offer.is_empty(): return "We don't have that."
	var price := int(offer[0])
	var count := int(offer[1])
	if coins() < price: return "That's %d coins, and you carry %d." % [price, coins()]
	var item: Item = ItemDB.make(item_id)
	if item == null: return "We don't have that."
	if not InventoryManager.add_item(item, count): return "Your pack is full, stranger."
	InventoryManager.remove_item(Tribes.COIN, price)
	AudioManager.play_sfx("equip_gear")
	return "%s%s for %d coins. The sun keep you. (%d left)" % [item.name, " x%d" % count if count > 1 else "", price, coins()]


func sell(item_id: String) -> String:
	if not tribes.can_trade("sunward"): return _pick_angry()
	var price := int(Tribes.BUYS.get(item_id, 0))
	if price <= 0 or InventoryManager.get_item_count(item_id) <= 0: return "You have none of that."
	if not InventoryManager.remove_item(item_id, 1): return "You have none of that."
	if not InventoryManager.add_item(ItemDB.make(Tribes.COIN), price):
		InventoryManager.add_item(ItemDB.make(item_id), 1)
		return "Your pack is full, stranger."
	AudioManager.play_sfx("harvest_plant")
	return "Good. %d coins. You carry %d." % [price, coins()]


func _pick_angry() -> String:
	var lines: Array = Tribes.LINES.sunward_angry
	return str(lines[randi() % lines.size()])


# The rest of what the dialogue may ask a folk manager.
func meet(_id: String) -> void:
	pass


func help() -> String:
	return "Go south where the sand is deep and you'll find the Scarhorn. Go north and the cold finds you. Carry a sail-scale charm."


func tend() -> String:
	return "We tend our own beasts."


func release(_id: String) -> bool:
	return false


func recipes_with(_id: String) -> Array:
	return []
