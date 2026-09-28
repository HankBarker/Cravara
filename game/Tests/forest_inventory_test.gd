extends SceneTree
var failures := 0
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func clear(inv):
	for i in inv.inventory.size(): inv.inventory[i] = {"item":null,"quantity":0}
func run():
	var inv = root.get_node("InventoryManager")
	var db = root.get_node("ItemDB")
	var craft = root.get_node("CraftingManager")
	clear(inv)
	var log_item = db.make("log")
	check(inv.add_item(log_item, log_item.max_stack*2+3), "Multi-stack addition rejected")
	check(inv.get_item_count("log") == log_item.max_stack*2+3, "Multi-stack addition lost items")
	check(inv.remove_item("log", log_item.max_stack+1), "Cross-stack removal failed")
	check(inv.get_item_count("log") == log_item.max_stack+2, "Cross-stack removal wrong")
	for i in inv.inventory.size(): inv.inventory[i] = {"item":db.make("bucket"),"quantity":1}
	inv.inventory[0] = {"item":log_item,"quantity":log_item.max_stack-1}
	check(not inv.add_item(log_item, 2),"Overflow addition accepted")
	check(inv.inventory[0].quantity == log_item.max_stack-1,"Overflow addition mutated stack")
	check(not craft.try_craft("plank"),"Full output inventory craft accepted")
	check(inv.inventory[0].quantity == log_item.max_stack-1,"Failed craft lost ingredients")
	clear(inv)
	inv.add_item(log_item,1)
	check(craft.try_craft("plank"),"Valid craft failed")
	check(inv.get_item_count("plank") == 2 and inv.get_item_count("log") == 0,"Craft yield/cost wrong")
	inv.add_item(db.make("plank"),3)
	inv.add_item(db.make("plant_fiber"),2)
	check(not craft.try_craft("bucket"),"Station gate bypassed")
	var stations: Array[String] = ["workbench"]
	craft.set_nearby_stations(stations)
	check(craft.try_craft("bucket"),"Station craft failed")
	check(not craft.try_craft("unknown",{}),"Unknown recipe accepted")
	clear(inv)
	check(not craft.try_craft("basic_axe",{}),"Caller-provided free costs bypassed recipe")
	inv.inventory[0] = {"item":db.make("plank"),"quantity":1}
	inv.inventory[1] = {"item":db.make("plank"),"quantity":2}
	inv.inventory[2] = {"item":db.make("stone"),"quantity":2}
	check(craft.try_craft("basic_axe"),"Split ingredient stacks failed")
	check(inv.get_item_count("plank") == 0 and inv.get_item_count("stone") == 0,"Ingredient residue after craft")
	for i in inv.inventory.size(): inv.inventory[i] = {"item":db.make("bucket"),"quantity":1}
	inv.inventory[0] = {"item":db.make("log"),"quantity":1}
	check(craft.try_craft("plank"),"Craft failed to reuse emptied ingredient slot")
	check(inv.inventory[0].item.id == "plank" and inv.inventory[0].quantity == 2,"Freed slot output wrong")
	clear(inv)
	inv.inventory[0] = {"item":log_item,"quantity":log_item.max_stack-1}
	inv.inventory[1] = {"item":log_item,"quantity":5}
	inv.swap_items(1,0)
	check(inv.inventory[0].quantity == log_item.max_stack and inv.inventory[1].quantity == 4,"Stack merge conservation failed")
	for id in db.all_ids(): check(db.make(id).icon != null, "Missing icon " + id)
	var hud_script = load("res://UI/ForestHUD.gd")
	check(hud_script != null,"HUD parse failed")
	if hud_script:
		var hud = hud_script.new()
		root.add_child(hud)
		hud.inventory_panel.show()
		hud.recipes_panel.show()
		hud.update_inventory_display()
		await process_frame
		hud.queue_free()
		await process_frame
	print("FOREST INVENTORY TESTS: %d failures" % failures)
	quit(failures)

