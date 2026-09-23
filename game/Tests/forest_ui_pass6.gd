extends "res://Tests/forest_interaction_pass4.gd"
const SAVE6 := "user://forest_ui_pass6_test.json"
const OUT6 := "C:/Cravera/art/forest-playtest/pass6-ui"
class MenuFixture extends "res://Forest/MainMenu.gd":
	var did_start:=false
	func _start(continue_save: bool):
		did_start=true
		get_tree().set_meta("forest_continue",continue_save)

func button_with_text(parent: Node,text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text==text: return child
		var result:=button_with_text(child,text)
		if result: return result
	return null

func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT6+"/"+name+".png")

func snapshot(source: Array) -> String:
	var rows: Array=[]
	for slot in source: rows.append([slot.item.id if slot.item else "",slot.quantity])
	return JSON.stringify(rows)

func count_all(id: String,containers: Array) -> int:
	var count:=InventoryManager.get_item_count(id)
	for storage in containers:
		for slot in storage.inventory:
			if slot.item and slot.item.id==id: count+=slot.quantity
	return count

func chest_at(cell: Vector2i):
	stage.world._spawn_prop(cell,"chest")
	return stage.world.props[cell].get_node("PlacedObject")

func clear_inventory():
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}

func run():
	DirAccess.make_dir_recursive_absolute(OUT6)
	await settle()
	hud=stage.hud
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	for y in range(-6,7):
		for x in range(-6,15):
			var cell:=Vector2i(x,y)
			if stage.world.props.has(cell): stage.world.props[cell].free(); stage.world.props.erase(cell)
			stage.world.water.erase(cell)
	stage.player.position=Vector2.ZERO
	clear_inventory()
	InventoryManager.hotbar_start=8
	InventoryManager.selected_slot_index=10
	InventoryManager.inventory[10]={"item":ItemDB.make("basic_pickaxe"),"quantity":1}
	InventoryManager.inventory[8]={"item":ItemDB.make("log"),"quantity":17}
	InventoryManager.inventory[0]={"item":ItemDB.make("stone"),"quantity":32}
	InventoryManager.inventory[2]={"item":ItemDB.make("log"),"quantity":61}
	InventoryManager.inventory[17]={"item":ItemDB.make("log"),"quantity":60}
	InventoryManager.inventory_changed.emit()
	var protected:=snapshot(InventoryManager.inventory.slice(8,16))
	var log_total:=InventoryManager.get_item_count("log")
	await key(KEY_TAB)
	await get_tree().create_timer(0.32).timeout
	await click(hud.sort_button)
	check(snapshot(InventoryManager.inventory.slice(8,16))==protected and InventoryManager.selected_slot_index==10,"Sort button preserves exact current hotbar and selection")
	check(InventoryManager.get_item_count("log")==log_total and InventoryManager.get_item_count("stone")==32,"Sort merges stacks without loss")
	var capacity_ok:=true
	for slot in InventoryManager.inventory:
		if slot.item and slot.quantity>slot.item.max_stack: capacity_ok=false
	check(capacity_ok,"Every sorted stack respects its item capacity")
	var sorted:=snapshot(InventoryManager.inventory)
	await click(hud.sort_button)
	check(snapshot(InventoryManager.inventory)==sorted,"Sorting is stable when already sorted")
	InventoryManager.hotbar_start=32
	InventoryManager.selected_slot_index=34
	InventoryManager.inventory[34]={"item":ItemDB.make("berry"),"quantity":7}
	var final_pouch:=snapshot(InventoryManager.inventory.slice(32,35))
	InventoryManager.sort_backpack()
	check(snapshot(InventoryManager.inventory.slice(32,35))==final_pouch and InventoryManager.selected_slot_index==34,"Three-slot final hotbar pouch remains protected")
	clear_inventory()
	InventoryManager.hotbar_start=0
	InventoryManager.selected_slot_index=0
	InventoryManager.inventory[0]={"item":ItemDB.make("log"),"quantity":4}
	InventoryManager.inventory[8]={"item":ItemDB.make("log"),"quantity":10}
	InventoryManager.inventory[9]={"item":ItemDB.make("berry"),"quantity":3}
	var near=chest_at(Vector2i(0,2))
	var blocked=chest_at(Vector2i(3,-1))
	var far=chest_at(Vector2i(12,0))
	for i in near.inventory.size(): near.inventory[i]={"item":ItemDB.make("stone"),"quantity":99}
	near.inventory[0]={"item":ItemDB.make("log"),"quantity":97}
	blocked.inventory[0]={"item":ItemDB.make("log"),"quantity":5}
	far.inventory[0]={"item":ItemDB.make("log"),"quantity":5}
	stage.world._spawn_prop(Vector2i(2,-1),"wood_wall")
	InventoryManager.inventory_changed.emit()
	await get_tree().physics_frame
	var all_logs:=count_all("log",[near,blocked,far])
	await click(hud.quick_stack_button)
	check(near.inventory[0].quantity==99 and InventoryManager.inventory[8].quantity==8,"Quick-stack fills capacity and retains overflow")
	check(blocked.inventory[0].quantity==5 and far.inventory[0].quantity==5,"Quick-stack cannot cross walls or distance limit")
	check(InventoryManager.inventory[0].quantity==4 and InventoryManager.inventory[9].quantity==3,"Quick-stack preserves hotbar and unmatched item types")
	check(count_all("log",[near,blocked,far])==all_logs,"Quick-stack conserves exact total across all sources")
	near.inventory[1]={"item":null,"quantity":0}
	await click(hud.quick_stack_button)
	check(near.inventory[1].item.id=="log" and near.inventory[1].quantity==8 and InventoryManager.inventory[8].item==null,"Matching chest may receive overflow in empty slot")
	check(count_all("log",[near,blocked,far])==all_logs,"Second quick-stack does not duplicate items")
	InventoryManager.inventory[10]={"item":ItemDB.make("basic_pickaxe"),"quantity":1}
	InventoryManager.inventory_changed.emit()
	await motion(hud.slots[10].get_global_rect().get_center())
	await get_tree().create_timer(0.85).timeout
	var tip: String=hud.slots[10].tooltip_text
	check(tip.contains("Damage") and tip.contains("Mining"),"Tool tooltip exposes actual damage and mining stats")
	check(preload("res://UI/ItemDetails.gd").text(ItemDB.make("cooked_meat")).contains("Fullness"),"Food tooltip includes fullness duration")
	await shot("01-sort-stack-stats")
	await key(KEY_K)
	stage.player.equip_armor("head",ItemDB.make("leather_helmet"))
	var initial_look: Dictionary=stage.player.appearance.duplicate()
	var inv_before:=snapshot(InventoryManager.inventory)
	await click(button_with_text(hud.equipment_panel,"Appearance"))
	var editor=hud.appearance_editor
	check(is_instance_valid(editor) and editor.is_open(),"Gear appearance button opens creator")
	var original_image: int=hash(editor.avatar.sprite_frames.get_frame_texture("idle_down",0).get_image().get_data())
	await click(editor.selectors.skin)
	check(hash(editor.avatar.sprite_frames.get_frame_texture("idle_down",0).get_image().get_data())!=original_image,"Skin choice updates live preview")
	await click(button_with_text(editor.root,"Turn preview"))
	check(editor.avatar.animation=="idle_left","Creator preview turns with button")
	await click(button_with_text(editor.root,"Preview: equipped"))
	check(not editor.show_gear,"Clothing-only preview can hide equipment without unequipping")
	await shot("02-appearance-editor")
	await key(KEY_ESCAPE)
	check(stage.player.appearance==initial_look and snapshot(InventoryManager.inventory)==inv_before,"Cancel appearance leaves player and inventory unchanged")
	await click(button_with_text(hud.equipment_panel,"Appearance"))
	editor=hud.appearance_editor
	await click(editor.selectors.cloth)
	await click(editor.selectors.hair_style)
	var wanted: Dictionary=editor.draft.duplicate()
	await click(button_with_text(editor.root,"Save look"))
	check(stage.player.appearance==wanted and stage.player.equipped_armor.head.id=="leather_helmet","Saving look updates player while retaining helmet")
	check(snapshot(InventoryManager.inventory)==inv_before,"Appearance save consumes no inventory")
	hud.close_panels()
	check(stage.save_journey(SAVE6),"Customized keeper saves to isolated journey")
	stage.player.apply_appearance({})
	check(stage._load_journey(SAVE6) and stage.player.appearance==wanted,"Root restore preserves customized appearance")
	await settle()
	# Transaction fixtures above were direct-spawned, not player-built saved props.
	chest_at(Vector2i(0,2))
	var companion=stage._spawn_creature("stego",Vector2(24,0))
	companion.tamed=true
	companion.set_order("stay")
	companion.set_stance("passive")
	hud.show_companion_commands(companion)
	await settle()
	await click(button_with_text(hud.command_panel,"Set work home"))
	check(companion.worker.anchor.distance_to(companion.global_position)<1,"Command button records worker home")
	await click(button_with_text(hud.command_panel,"Assign chest"))
	check(companion.worker.assigned_chest!=Vector2i(2147483647,2147483647),"Command button assigns nearby work chest")
	await shot("04-worker-commands")
	await click(button_with_text(hud.command_panel,"Work"))
	check(companion.order=="work" and not hud.is_open(),"Work command dispatches through actual button")
	companion.set_order("stay")
	companion.position=Vector2(24,0)
	hud.show_companion_commands(companion)
	await settle()
	await click(button_with_text(hud.command_panel,"Pet"))
	check(stage.player.action_kind=="pet" and not hud.is_open(),"Nearby pet button plays original keeper action")
	stage.queue_free()
	await settle()
	var menu:=MenuFixture.new()
	add_child(menu)
	await settle()
	await click(button_with_text(menu,"NEW EXPEDITION"))
	if is_instance_valid(menu._details): await click(button_with_text(menu._details,"CREATE YOUR KEEPER"))
	check(not menu.did_start and is_instance_valid(menu._creator),"New expedition opens creator before entering forest")
	var creator_controls_fit:=true
	for control in menu._creator.root.get_children():
		if control is Button and not Rect2(Vector2(24,12),Vector2(432,246)).encloses(control.get_rect()): creator_controls_fit=false
	check(creator_controls_fit,"Creator buttons fit inside native-resolution carved frame")
	await click(menu._creator.selectors.hair)
	var new_look: Dictionary=menu._creator.draft.duplicate()
	await shot("03-new-keeper")
	await click(button_with_text(menu._creator.root,"Begin journey"))
	check(menu.did_start and get_tree().get_meta("forest_appearance")==new_look,"Beginning expedition passes chosen appearance through root metadata")
	menu.queue_free()
	await settle()
	stage=load("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await settle()
	check(stage.player.appearance==new_look,"New forest initializes original player with creator appearance")
	if FileAccess.file_exists(SAVE6): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE6))
	print("FOREST_UI_PASS6: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)

