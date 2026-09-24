extends "res://Tests/forest_ui_v3_test.gd"
const OUT4 := "C:/Cravera/art/forest-playtest/pass4-ui"

func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT4+"/"+name+".png")

func run():
	DirAccess.make_dir_recursive_absolute(OUT4)
	await settle()
	hud=stage.hud
	var settings_path := ProjectSettings.globalize_path(GameSettings.SETTINGS_PATH)
	var settings_hash := FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing"
	var initial_shortcuts: bool = GameSettings.shortcut_buttons_visible
	GameSettings.set_shortcut_buttons(true)
	check(hud.shortcut_buttons.size()==3,"Exactly three corner shortcut charms")
	for button in hud.shortcut_buttons:
		check(button.visible,"Shortcut initially visible: "+button.caption)
	await click(hud.shortcut_buttons[0])
	check(hud.inventory_panel.visible,"Satchel charm accepts actual click")
	await key(KEY_TAB)
	await click(hud.shortcut_buttons[1])
	check(hud.equipment_panel.visible,"Gear charm accepts actual click")
	await key(KEY_K)
	await click(hud.shortcut_buttons[2])
	check(hud.roster_panel.visible,"Companions charm accepts actual click")
	await key(KEY_P)
	await shot("01-shortcut-charms")
	var settings = load("res://UI/SettingsPanel.gd").new()
	add_child(settings)
	settings.show_settings()
	await settle()
	await click(settings.controls.shortcuts)
	check(not GameSettings.shortcut_buttons_visible,"Shortcut setting toggles live")
	for button in hud.shortcut_buttons: check(not button.visible,"Only shortcut charm hidden")
	check(hud.hotbar[0].visible,"Hotbar remains visible when shortcut buttons hidden")
	await shot("02-settings")
	settings._close(true)
	await settle()
	await key(KEY_TAB)
	check(hud.inventory_panel.visible,"Hidden shortcuts retain Tab")
	await key(KEY_K)
	check(hud.equipment_panel.visible,"Hidden shortcuts retain K")
	await key(KEY_P)
	check(hud.roster_panel.visible,"Hidden shortcuts retain P")
	await key(KEY_ESCAPE)
	await shot("03-clean-hud")
	stage.player.respawning=true
	stage._respawn_left=3.0
	for code in [KEY_TAB,KEY_K,KEY_P]: await key(code)
	check(not hud.is_open(),"Respawning blocks Tab/K/P menus")
	stage.player.respawning=false
	stage._respawn_left=0.0
	for cue in ["satchel_open","satchel_close","equip_gear","unequip_gear"]:
		var path: String = AudioManager.get_leather_cue_path(cue)
		check(path.contains("/leather/") and ResourceLoader.exists(path),"Recorded leather cue: "+cue)
		var stream: AudioStream = load(path)
		check(stream.get_length()>0.15 and stream.get_length()<1.1,"Leather cue duration valid")
	var drops: Array[Node] = []
	for i in 4:
		var drop = load("res://Items/DroppedItem.tscn").instantiate()
		drop.setup_item(ItemDB.make(["torch","log","stone","stego_saddle"][i]),i+1)
		drop.position=stage.player.position+Vector2(-36+i*25,-30)
		stage.add_child(drop)
		drops.append(drop)
		var rendered: Vector2 = drop.sprite.texture.get_size()*drop.sprite.scale
		check(maxf(rendered.x,rendered.y)<=12.01,"Drop miniature size: "+drop.item.id)
	var ground: Vector2=drops[0].position
	var collider: Vector2=drops[0].get_node("CollisionShape2D").global_position
	var visual_y: float=drops[0].sprite.position.y
	await get_tree().create_timer(0.45).timeout
	check(drops[0].position==ground and drops[0].get_node("CollisionShape2D").global_position==collider,"Bobbing never moves pickup collision")
	check(drops[0].sprite.position.y!=visual_y,"Collectible icon bobs")
	GameSettings.set_shortcut_buttons(true)
	await shot("04-miniature-drops")
	for drop in drops: drop.queue_free()
	await settle()
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":ItemDB.make("bucket"),"quantity":1}
	InventoryManager.inventory_changed.emit()
	var waiting = load("res://Items/DroppedItem.tscn").instantiate()
	waiting.setup_item(ItemDB.make("torch"),3)
	waiting.position=stage.player.position
	stage.add_child(waiting)
	await get_tree().create_timer(0.5).timeout
	check(is_instance_valid(waiting) and InventoryManager.get_item_count("torch")==0,"Full inventory preserves complete dropped stack")
	InventoryManager.inventory[0]={"item":null,"quantity":0}
	InventoryManager.inventory_changed.emit()
	await get_tree().create_timer(0.5).timeout
	check(not is_instance_valid(waiting) and InventoryManager.get_item_count("torch")==3,"Stack picks up after space opens without reentering area")
	GameSettings.set_shortcut_buttons(initial_shortcuts)
	check((FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing")==settings_hash,"Settings file unchanged by UI test")
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("UI_V4_TEST failures=",failures)
	get_tree().quit(1 if failures else 0)
