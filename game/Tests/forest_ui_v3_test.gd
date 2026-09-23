extends Node
var failures := 0
var stage: Node
var hud: CanvasLayer
const OUT := "C:/Cravera/art/forest-playtest/pass3-ui"

class Storage extends Node:
	signal inventory_changed
	var inventory: Array[Dictionary] = []
	func _init():
		for i in 16: inventory.append({"item":null,"quantity":0})

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.persistence_enabled = false
	stage = load("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	call_deferred("run")

func check(ok: bool,message: String):
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures += 1

func settle():
	for i in 3: await get_tree().process_frame

func capture(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+name+".png")

func mouse(pos: Vector2,pressed: bool):
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event,true)
	await settle()

func motion(pos: Vector2,held: bool = false):
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(event,true)
	await settle()

func drag(a: Control,b: Control):
	var start := a.get_global_rect().get_center()
	var finish := b.get_global_rect().get_center()
	await motion(start)
	await mouse(start,true)
	await motion(start.lerp(finish,0.5),true)
	check(DragController.is_dragging and is_instance_valid(DragController.dragged_icon),"Held drag creates UI preview")
	await motion(finish,true)
	await mouse(finish,false)
	check(not is_instance_valid(DragController.dragged_slot),"Release clears drag state")

func click(b: Control):
	var p := b.get_global_rect().get_center()
	await motion(p)
	await mouse(p,true)
	await mouse(p,false)

func key(code: int):
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event,true)
		await settle()

func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	await settle()
	hud = stage.hud
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}
	var timber: Item = ItemDB.make("log")
	InventoryManager.inventory[0]={"item":timber,"quantity":4}
	InventoryManager.inventory[1]={"item":timber,"quantity":timber.max_stack-2}
	InventoryManager.inventory[3]={"item":ItemDB.make("stone"),"quantity":6}
	InventoryManager.inventory[4]={"item":ItemDB.make("leather_helmet"),"quantity":1}
	InventoryManager.inventory_changed.emit()
	await key(KEY_TAB)
	await get_tree().create_timer(0.35).timeout
	await drag(hud.slots[0],hud.slots[1])
	check(InventoryManager.inventory[0].quantity==2 and InventoryManager.inventory[1].quantity==timber.max_stack,"Partial merge conserves overflow")
	await drag(hud.slots[0],hud.slots[2])
	check(InventoryManager.inventory[0].item==null and InventoryManager.inventory[2].quantity==2,"Drag to empty moves full stack")
	await drag(hud.slots[2],hud.slots[3])
	check(InventoryManager.inventory[2].item.id=="stone" and InventoryManager.inventory[3].item.id=="log","Different stacks swap")
	await drag(hud.slots[4],hud.slots[5])
	check(stage.player.get_equipment("head")==null and InventoryManager.inventory[5].item.id=="leather_helmet","Armor drag never quick-equips")
	await click(hud.slots[5])
	check(stage.player.get_equipment("head")!=null and InventoryManager.inventory[5].item==null,"Armor click-release equips once")
	var start: Vector2 = hud.slots[2].get_global_rect().get_center()
	await motion(start)
	await mouse(start,true)
	await motion(Vector2(465,20),true)
	await mouse(Vector2(465,20),false)
	check(InventoryManager.inventory[2].item.id=="stone" and InventoryManager.inventory[2].quantity==6,"Outside release safely cancels")
	await capture("01-satchel")
	var chest := Storage.new()
	add_child(chest)
	chest.inventory[0]={"item":timber,"quantity":3}
	hud.open_chest(chest)
	await settle()
	await drag(hud.slots[3],hud.chest_slots[0])
	check(chest.inventory[0].quantity==5 and InventoryManager.inventory[3].item==null,"Player-to-chest merge conserves items")
	await drag(hud.chest_slots[0],hud.slots[3])
	check(chest.inventory[0].item==null and InventoryManager.inventory[3].quantity==5,"Chest-to-player drag works")
	hud.close_panels()
	InventoryManager.hotbar_start=0
	InventoryManager.selected_slot_index=0
	var snapshot := []
	for slot in InventoryManager.inventory: snapshot.append([slot.item.id if slot.item else "",slot.quantity])
	for page in [8,16,24,32,0]:
		await key(KEY_CAPSLOCK)
		check(InventoryManager.hotbar_start==page,"CapsLock advances to page "+str(page))
		if page==32:
			check(InventoryManager.get_hotbar_indices()==[32,33,34],"Final pouch exposes only 3 real slots")
			await key(KEY_3)
			check(InventoryManager.selected_slot_index==34,"Numeric3 selects absolute slot34")
			await key(KEY_8)
			check(InventoryManager.selected_slot_index==34,"Unavailable numeric8 cannot escape final pouch")
			await capture("02-last-pouch")
	var after := []
	for slot in InventoryManager.inventory: after.append([slot.item.id if slot.item else "",slot.quantity])
	check(snapshot==after,"Pouch cycling never rotates inventory")
	var settings = load("res://UI/SettingsPanel.gd").new()
	var settings_path := ProjectSettings.globalize_path(GameSettings.SETTINGS_PATH)
	var settings_hash := FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing"
	add_child(settings)
	settings.show_settings()
	await settle()
	var original_shadow: bool = GameSettings.shadows_enabled
	await click(settings.controls.shadows)
	check(GameSettings.shadows_enabled!=original_shadow,"Settings shadow toggle previews live")
	await capture("03-settings")
	await key(KEY_ESCAPE)
	check(GameSettings.shadows_enabled==original_shadow and not settings.visible,"Cancel restores setting without saving")
	check((FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing")==settings_hash,"Settings test preserves user's settings file")
	var stego: Node
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.species == "stego":
			stego=creature
			break
	if stego:
		stego.tamed = true
		stego.position = stage.player.position+Vector2(25,0)
		stego.set_order("stay")
		InventoryManager.add_item(ItemDB.make("stego_saddle"))
		hud.show_companion_commands(stego)
		await settle()
		for child in hud.command_panel.get_children():
			if child is Button and child.text=="Equip saddle":
				await click(child)
				break
		check(stego.saddle!=null,"Saddle button equips from inventory")
		await capture("04-saddle-commands")
		for child in hud.command_panel.get_children():
			if child is Button and child.text=="Ride":
				await click(child)
				break
		check(stego.is_mounted(),"Ride button mounts saddled companion")
		if stego.is_mounted(): stego.dismount()
		check(not stego.is_mounted(),"Dismount returns rider")
	print("UI_V3_TEST failures=",failures)
	get_tree().quit(1 if failures else 0)
