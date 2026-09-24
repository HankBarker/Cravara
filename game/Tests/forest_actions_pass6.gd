extends "res://Tests/forest_interaction_pass4.gd"
## End-to-end mouse/keyboard routing and actual in-game presentation.
func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Cravera/art/forest-pass6/"+name+".png")
func pause_action():
	await get_tree().create_timer(0.72).timeout
	await settle()
func left_world(target: Vector2, pressed: bool):
	await point_at(target)
	await mouse(stage.get_viewport().get_canvas_transform()*target,pressed)
func run():
	await settle()
	hud=stage.hud
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	for y in range(-3,4):
		for x in range(-3,4):
			stage.world._remove_prop(Vector2i(x,y))
	stage.player.position=Vector2.ZERO
	stage.player.apply_appearance({"skin":"umber","hair":"silver","hair_style":"tied","cloth":"river"})
	stage.player.equip_armor("head",ItemDB.make("leather_helmet"))
	stage.player.equip_armor("chest",ItemDB.make("leather_chestplate"))
	stage.player.equip_armor("legs",ItemDB.make("leather_leggings"))
	await settle()
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}
	var point:=Vector2(40,8)
	select_item("garden_hoe",1)
	await right_click(point)
	check(stage.gardening.plots.has(Vector2i(2,0)),"Real right-click tills visible aimed plot")
	check(stage.player.action_kind=="hoe","Right-click till routes to hoe animation")
	await shot("01-garden-hoe")
	await pause_action()
	select_item("berry_seed",3)
	await right_click(point)
	check(stage.gardening.plots[Vector2i(2,0)].seed=="berry_seed","Real seed right-click plants crop")
	check(stage.player.action_kind=="pickup","Sowing plays reach-down pose")
	await pause_action()
	select_item("water_bucket",1)
	await right_click(point)
	check(stage.gardening.plots[Vector2i(2,0)].watered and InventoryManager.inventory[0].item.id=="bucket","Real watering uses bucket and leaves empty container")
	await pause_action()
	stage.gardening._process(90)
	await shot("02-ripe-garden")
	await point_at(point)
	await key(KEY_E)
	check(stage.gardening.plots[Vector2i(2,0)].seed=="","Real E gathers ripe crop")
	await pause_action()
	select_item("reed_bow",1)
	InventoryManager.add_item(ItemDB.make("bone_arrow"),12)
	await left_world(Vector2(130,0),true)
	await get_tree().create_timer(0.8).timeout
	check(stage.bow.drawing and stage.player.action_kind=="bow_draw","Holding mouse preserves fully drawn body pose beyond cast duration")
	check(stage.player.animated_sprite.frame>=6,"Held bow reaches final draw cel")
	await shot("03-bow-draw")
	await left_world(Vector2(130,0),false)
	check(stage.bow.shots_fired==1 and InventoryManager.get_item_count("bone_arrow")==11,"Real release shoots exactly once and spends one arrow")
	check(stage.player.action_kind=="bow_release","Release uses its own body animation")
	await shot("04-bow-release")
	await pause_action()
	await left_world(Vector2(130,0),true)
	await key(KEY_TAB)
	await settle()
	check(not stage.bow.drawing,"Opening satchel cancels held draw")
	await left_world(Vector2(130,0),false)
	check(InventoryManager.get_item_count("bone_arrow")==11,"Canceled draw cannot fire through inventory")
	hud.close_panels()
	await pause_action()
	for entry in [["basic_axe","axe"],["basic_pickaxe","pickaxe"],["bone_dagger","weapon"],["shard_sword","sword"]]:
		select_item(entry[0],1)
		await left_world(Vector2(28,10),true)
		check(str(stage.player.animated_sprite.animation).begins_with(entry[1]),entry[0]+" click selects proper weapon pose")
		await left_world(Vector2(28,10),false)
		await pause_action()
	var stego=stage._spawn_creature("stego",Vector2(25,0))
	stego.tamed=true
	stego.saddle=ItemDB.make("stego_saddle")
	stego.set_order("stay")
	await settle()
	check(stego.mount(stage.player),"Mount prepared for real-input ranged check")
	select_item("reed_bow",1)
	await left_world(stage.player.global_position+Vector2(120,-10),true)
	await get_tree().create_timer(0.65).timeout
	check(stage.bow.drawing and stage.player.action_kind=="bow_draw","Real mounted click draws survivor bow")
	check(stego._mount_controller._strike_time<=0,"Bow draw does not also trigger dinosaur tail attack")
	await shot("05-mounted-bow")
	var ammo: int=InventoryManager.get_item_count("bone_arrow")
	await left_world(stage.player.global_position+Vector2(120,-10),false)
	check(InventoryManager.get_item_count("bone_arrow")==ammo-1,"Real mounted release consumes one arrow")
	await pause_action()
	await shot("06-forest-survivor")
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("FOREST_ACTIONS_PASS6 assertions=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
