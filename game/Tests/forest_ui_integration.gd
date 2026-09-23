extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func key(code: int):
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
func click(pos: Vector2):
	var motion := InputEventMouseMotion.new()
	motion.position=pos
	motion.global_position=pos
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=pos
		event.global_position=pos
		event.pressed=pressed
		root.push_input(event,true)
func run():
	root.content_scale_size=Vector2i(480,270)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(960,540)
	var scene=load("res://Forest/ForestPlaytest.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await create_timer(0.6).timeout
	var hud=scene.hud
	key(KEY_C)
	await process_frame
	check(hud.is_open(),"C opens crafting in full scene")
	var search=hud.recipes_panel.get_children().filter(func(n): return n is LineEdit)[0]
	search.grab_focus()
	key(KEY_TAB)
	await process_frame
	check(not hud.is_open(),"Tab closes focused crafting search")
	key(KEY_C)
	await process_frame
	var inv=root.get_node("InventoryManager")
	var db=root.get_node("ItemDB")
	inv.inventory[11]={"item":db.make("leather_helmet"),"quantity":1}
	inv.inventory_changed.emit()
	await process_frame
	var slot=hud.slots[11]
	click(slot.global_position+Vector2(10,10))
	await process_frame
	check(scene.player.equipped_armor.head != null,"GUI mouse click equips helmet")
	check(inv.get_item_count("leather_helmet")==0,"Equipped helmet removed exactly once")
	hud._unequip("head")
	check(scene.player.equipped_armor.head == null and inv.get_item_count("leather_helmet")==1,"Unequip returns helmet")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Cravera/art/forest-playtest/inventory-integration.png")
	hud.close_panels()
	click(hud.hotbar[1].global_position+Vector2(10,10))
	await process_frame
	check(inv.selected_slot_index==1,"GUI hotbar click selects pickaxe")
	check(scene.player.state!="attack","GUI hotbar click does not attack")
	var chest_cell:=Vector2i(-3,2)
	if scene.world.props.has(chest_cell): scene.world._remove_prop(chest_cell)
	scene.world._spawn_prop(chest_cell,"chest")
	var chest=scene.world.props[chest_cell].get_node("PlacedObject")
	scene.player.position=Vector2(-60,40)
	await create_timer(0.2).timeout
	var aim:=InputEventMouseMotion.new()
	aim.position=root.get_canvas_transform() * chest.global_position
	aim.global_position=aim.position
	root.push_input(aim,true)
	root.warp_mouse(aim.position)
	await create_timer(0.1).timeout
	print("CHEST AIM ",scene.get_global_mouse_position()," expected ",chest.global_position," locked ",scene.player.controls_locked," hover ",root.gui_get_hovered_control()," creature ",scene._nearest_creature())
	key(KEY_E)
	await process_frame
	check(hud.is_chest_open_for(chest),"E opens placed chest through scene routing")
	if hud.is_chest_open_for(chest):
		hud.transfer_slot(hud.hotbar[1])
		check(chest.inventory[0].item != null and chest.inventory[0].item.id=="basic_pickaxe","Shift transfer moves inventory tool into chest")
		key(KEY_TAB)
		await process_frame
		check(not hud.is_open() and hud._active_chest==null,"Tab closes chest and inventory together")
	var drag=root.get_node("DragController")
	drag.start_drag(hud.hotbar[1],db.make("basic_pickaxe").icon,1)
	scene.queue_free()
	await process_frame
	check(drag.dragged_slot==null and drag.dragged_icon==null,"Scene exit clears persistent drag state")
	root.get_node("AudioManager").stop_music()
	await create_timer(0.15).timeout
	print("FULL UI INTEGRATION: %d failures" % failures)
	quit(failures)



