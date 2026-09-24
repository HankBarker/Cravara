extends "res://Tests/forest_ui_v3_test.gd"
## Exercises the session's real viewport routing, independently of mount unit tests.
var checks := 0

func _enter_tree(): SaveManager.disable_for_playtest()

func check(ok: bool, message: String):
	checks += 1
	super.check(ok,message)

func physical(code: int, pressed: bool, echo := false):
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	Input.parse_input_event(event)
	await settle()

func key(code: int):
	await physical(code,true)
	await physical(code,false)

func motion(pos: Vector2, held := false):
	if DisplayServer.get_name()!="headless": get_viewport().warp_mouse(pos)
	var event:=InputEventMouseMotion.new()
	event.position=get_viewport().get_final_transform()*pos
	event.global_position=event.position
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await settle()

func mouse(pos: Vector2, pressed: bool):
	if DisplayServer.get_name()!="headless": get_viewport().warp_mouse(pos)
	var event:=InputEventMouseButton.new()
	event.position=get_viewport().get_final_transform()*pos
	event.global_position=event.position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	Input.parse_input_event(event)
	await settle()

func hold(code: int):
	await physical(code,true)
	await get_tree().create_timer(0.4).timeout
	await settle()
	await physical(code,false)

func point_at(world_position: Vector2):
	# Mounted seating updates during physics, then Camera2D updates its canvas.
	# At 120 rendered frames / 60 physics ticks, three process frames alone do
	# not guarantee both have settled. OS warp events can also arrive one frame
	# after the synthetic event. Recalculate the transform instead of widening
	# the world-space aim tolerance or testing against an old screen coordinate.
	for attempt in 5:
		await get_tree().physics_frame
		await get_tree().process_frame
		var pos: Vector2=stage.get_viewport().get_canvas_transform()*world_position
		await motion(pos)
		if stage.get_global_mouse_position().distance_to(world_position)<1: return
		print("Re-aim after camera/OS update #",attempt+1," actual=",stage.get_global_mouse_position()," expected=",world_position," canvas=",get_viewport().get_canvas_transform()," final=",get_viewport().get_final_transform())

func right_click(world_position: Vector2):
	await point_at(world_position)
	var pos: Vector2=stage.get_viewport().get_canvas_transform()*world_position
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*pos
		event.global_position=event.position
		event.button_index=MOUSE_BUTTON_RIGHT
		event.pressed=pressed
		Input.parse_input_event(event)
		await settle()

func select_item(id: String, amount: int):
	InventoryManager.inventory[0]={"item":ItemDB.make(id),"quantity":amount}
	InventoryManager.selected_slot_index=0
	InventoryManager.inventory_changed.emit()

func interaction_shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Cravera/art/forest-playtest/pass4-ui/"+name+".png")

func run():
	await settle()
	hud=stage.hud
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}
	var settings_path:=ProjectSettings.globalize_path(GameSettings.SETTINGS_PATH)
	var settings_hash:=FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing"
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	for y in range(-8,9):
		for x in range(-8,9):
			var cell:=Vector2i(x,y)
			if stage.world.props.has(cell):
				stage.world.props[cell].free()
				stage.world.props.erase(cell)
			stage.world.water.erase(cell)
	await settle()
	stage.player.position=Vector2(0,0)
	var stego=stage._spawn_creature("stego",Vector2(28,0))
	stego.tamed=true
	stego.saddle=ItemDB.make("stego_saddle")
	stego.set_order("stay")
	stego.set_stance("passive")
	await settle()
	await motion(Vector2(470,5))
	await physical(KEY_E,true)
	check(not stego.is_mounted(),"E press waits for tap-or-hold decision")
	await physical(KEY_E,false)
	check(stego.is_mounted() and stage.player.mounted_creature==stego,"Quick E release mounts nearest saddled companion")
	var previous_order: String=stego.order
	await hold(KEY_E)
	check(hud.is_open() and hud._command_target==stego and not hud._command_is_group,"Held E while riding targets mounted companion")
	check(stego.is_mounted() and stego.order==previous_order,"Held E release neither dismounts nor cycles orders")
	await interaction_shot("05-mounted-command-input")
	check(stage.player.controls_locked,"Companion commands lock mounted movement")
	var menu_position: Vector2=stego.position
	await physical(KEY_W,true)
	await get_tree().create_timer(0.18).timeout
	await physical(KEY_W,false)
	check(stego.position.distance_to(menu_position)<0.1,"Actual movement key cannot move mount behind commands")
	await key(KEY_ESCAPE)
	await key(KEY_E)
	check(not stego.is_mounted(),"Quick E dismounts after closing commands")
	stage.player.position=stego.position+Vector2(0,28)
	await hold(KEY_Q)
	check(hud._command_target==stego and not hud._command_is_group,"Held Q near companion targets that individual")
	await key(KEY_ESCAPE)
	stage.player.position=Vector2(-100,-100)
	await hold(KEY_Q)
	check(hud.is_open() and hud._command_is_group,"Held Q away from companions opens group orders")
	await key(KEY_ESCAPE)
	var wild=stage._spawn_creature("dodo",Vector2(-80,-100))
	wild.set_physics_process(false)
	await hold(KEY_E)
	check(not hud.is_open(),"Held E near wild dinosaur does not expose companion orders")
	wild.queue_free()
	await settle()
	stage.world._spawn_prop(Vector2i(-5,-5),"workbench")
	var bench=stage.world.props[Vector2i(-5,-5)]
	stage.player.position=bench.position+Vector2(0,26)
	await motion(Vector2(470,5))
	await key(KEY_E)
	check(hud.inventory_panel.visible,"E opens nearby workbench without cursor targeting")
	await key(KEY_ESCAPE)
	stage.player.position=stego.position+Vector2(0,28)
	await motion(Vector2(470,5))
	await key(KEY_E)
	check(stego.is_mounted(),"Companion can be remounted after workbench use")
	var target=stage._spawn_creature("trike",stego.position+Vector2(32,0))
	target.set_physics_process(false)
	var hp_before: int=target.health
	await point_at(target.position)
	var attack_point: Vector2=get_viewport().get_canvas_transform()*target.position
	check(stage.get_global_mouse_position().distance_to(target.position)<1,"Mouse aim reaches strike target in active renderer")
	await mouse(attack_point,true)
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"Attack test holds real Input mouse state")
	await get_tree().create_timer(0.5).timeout
	check(target.health==hp_before-18,"Mounted left-click resolves one directional stego strike")
	await get_tree().create_timer(0.8).timeout
	check(target.health==hp_before-18,"Holding attack mouse does not retrigger damage")
	await mouse(attack_point,false)
	select_item("berry",4)
	stego.health=int(stego.stats.hp)-45
	var mount_hp: int=stego.health
	await physical(KEY_F,true)
	await physical(KEY_F,true,true)
	await physical(KEY_F,false)
	check(stego.health==mount_hp+18 and InventoryManager.get_item_count("berry")==3,"F plus key-repeat heals once and consumes exactly one berry")
	await key(KEY_F)
	check(stego.health==mount_hp+18 and InventoryManager.get_item_count("berry")==3,"Feed cooldown blocks immediate duplicate heal and consumption")
	await key(KEY_TAB)
	var safe_point:=Vector2(240,40)
	await mouse(safe_point,true)
	# Expire food cooldown, so this checks modal blocking rather than cooldown.
	await get_tree().create_timer(2.6).timeout
	await physical(KEY_F,true)
	await physical(KEY_F,false)
	await key(KEY_ESCAPE)
	await get_tree().create_timer(1.25).timeout
	check(target.health==hp_before-18 and stego._mount_controller._strike_time==0,"Mouse held across modal close cannot leak into mounted attack")
	check(InventoryManager.get_item_count("berry")==3,"F behind modal cannot consume mount food")
	await mouse(safe_point,false)
	await key(KEY_E)
	await key(KEY_TAB)
	await mouse(safe_point,true)
	await key(KEY_ESCAPE)
	await get_tree().create_timer(0.25).timeout
	check(stage.player.state!="attack" and stage.player._swing_time==0,"Mouse held across modal close cannot leak into survivor tool swing")
	await mouse(safe_point,false)
	stage.player.respawning=true
	stage._respawn_left=3.0
	for code in [KEY_TAB,KEY_K,KEY_P,KEY_E,KEY_Q]: await key(code)
	check(not hud.is_open() and stage._command_key==0,"Respawn blocks shortcuts and interaction hold state")
	stage.player.respawning=false
	stage._respawn_left=0
	await settle()
	# The normal right-click path must accept overhead roofing and floor underlays.
	stego.position=Vector2(110,110)
	target.queue_free()
	stage.player.position=Vector2(0,32)
	stage.world._spawn_prop(Vector2i(0,0),"wood_wall")
	select_item("thatch_roof",2)
	await settle()
	await right_click(stage.world.props[Vector2i(0,0)].position)
	check(stage.world.roofs.has(Vector2i(0,0)) and InventoryManager.get_item_count("thatch_roof")==1,"Right-click roofs occupied wall tile and consumes exactly one roof")
	stage.world._spawn_prop(Vector2i(2,1),"wood_door")
	stage.player.position=Vector2(32,48)
	select_item("wood_floor",2)
	await settle()
	await right_click(stage.world.props[Vector2i(2,1)].position)
	check(stage.world.floors.has(Vector2i(2,1)) and InventoryManager.get_item_count("wood_floor")==1,"Right-click floors beneath door through actual selection routing")
	check((FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing")==settings_hash,"Interaction regression preserves real settings file")
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("INTERACTION PASS 4: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)



