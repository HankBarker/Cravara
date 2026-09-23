extends Node
## Native GUI regression: screenshots + real viewport keyboard/mouse dispatch.
var failures := 0
var stage: Node
var hud: CanvasLayer
const OUT := "C:/Cravera/art/forest-playtest/pass2-ui"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_meta("forest_continue",false)
	stage = load("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+label+".png")

func key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await settle()
	ev = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = false
	Input.parse_input_event(ev)
	await settle()

func physical(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await settle()

func hold(code: int) -> void:
	await physical(code,true)
	await get_tree().create_timer(0.42).timeout
	await settle()

func click(button: Control) -> void:
	var p := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = p
		event.global_position = p
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event,true)
		await settle()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await settle()
	hud = stage.hud
	await capture("01-hud")
	await key(KEY_TAB)
	check(hud.inventory_panel.visible and hud.recipes_panel.visible,"Tab failed to open satchel")
	await capture("02-satchel")
	await key(KEY_K)
	check(hud.equipment_panel.visible and not hud.inventory_panel.visible,"K failed to switch to gear")
	check(hud.armor_buttons.size()==7,"Equipment needs 7 slots")
	await capture("03-equipment")
	await click(hud.armor_buttons.light)
	check(hud._equipment_target=="light","Equipment light slot did not accept a GUI click")
	check(hud.equipment_list.get_child_count()>0,"Torch candidate missing")
	if stage.player.has_method("get_equipment"):
		await click(hud.equipment_list.get_child(0))
		check(stage.player.get_equipment("light")!=null,"GUI torch equip failed")
		await capture("04-equipped-light")
		var gear := {"head":"leather_helmet","chest":"leather_chestplate","legs":"leather_leggings","trinket_0":"crystal_pendant","trinket_1":"hunter_charm","trinket_2":"river_totem"}
		for slot in gear:
			InventoryManager.add_item(ItemDB.make(gear[slot]))
			await click(hud.armor_buttons[slot])
			check(hud.equipment_list.get_child(0) is Button,"Missing gear candidate for "+slot)
			if hud.equipment_list.get_child(0) is Button: await click(hud.equipment_list.get_child(0))
			check(stage.player.get_equipment(slot)!=null,"GUI equip failed for "+slot)
		await capture("04b-full-equipment")
	await key(KEY_P)
	check(hud.roster_panel.visible,"P failed to open roster")
	var dino: Node = get_tree().get_nodes_in_group("forest_creatures")[0]
	dino.tamed = true
	dino.order = "follow"
	hud._refresh_roster()
	await settle()
	await capture("05-roster")
	hud.show_companion_commands(dino)
	await settle()
	check(is_instance_valid(hud.command_panel),"Individual command menu missing")
	await capture("06-commands")
	for child in hud.command_panel.get_children():
		if child is Button and child.text == "Stay":
			await click(child)
			break
	if dino.has_method("set_order"): check(dino.order == "stay","Stay button failed")
	var other: Node = get_tree().get_nodes_in_group("forest_creatures")[1]
	other.tamed = true
	other.set_order("follow")
	hud.show_companion_commands(null)
	await settle()
	for child in hud.command_panel.get_children():
		if child is Button and child.text == "Passive":
			await click(child)
			break
	check(dino.stance == "passive" and other.stance == "passive","Group stance did not apply to both")
	hud.show_companion_commands(dino)
	await settle()
	for child in hud.command_panel.get_children():
		if child is Button and child.text == "Neutral":
			await click(child)
			break
	check(dino.stance == "neutral" and other.stance == "passive","Individual stance changed other companion")
	hud.show_companion_commands(dino)
	dino.is_dead = true
	hud._apply_companion_command("order","roam")
	check(other.order == "follow","Dead companion command incorrectly broadcast to group")
	await key(KEY_P)
	await key(KEY_ESCAPE)
	check(not hud.is_open(),"Escape failed to close all UI")
	# Exercise root's physical-key routing rather than calling the command API.
	dino.is_dead = false
	dino.tamed = true
	dino.position = stage.player.position+Vector2(20,0)
	dino.set_physics_process(false)
	dino.set_order("follow")
	other.position = stage.player.position+Vector2(200,0)
	other.set_physics_process(false)
	var aim := InputEventMouseMotion.new()
	aim.position = Vector2(470,5)
	get_viewport().push_input(aim,true)
	await settle()
	await hold(KEY_E)
	check(hud.is_open() and hud._command_target == dino,"Held E failed to open targeted orders")
	check(dino.order == "follow","Held E also triggered tap order cycle")
	check(stage.player.controls_locked,"Orders panel did not lock player controls")
	var locked_position: Vector2 = stage.player.position
	await physical(KEY_D,true)
	await get_tree().create_timer(0.12).timeout
	await physical(KEY_D,false)
	check(stage.player.position.distance_to(locked_position)<1,"Player moved behind orders panel")
	await capture("07-held-e-orders")
	await physical(KEY_E,false)
	await key(KEY_ESCAPE)
	await key(KEY_E)
	check(hud.is_open() and hud._command_target == dino,"Quick E failed to open unsaddled companion orders")
	check(dino.order == "follow","Quick E unexpectedly cycled companion order")
	await key(KEY_ESCAPE)
	await hold(KEY_Q)
	check(hud.is_open() and not hud._command_is_group and hud._command_target == dino,"Held Q failed to target nearby companion")
	await capture("08-held-q-orders")
	await physical(KEY_Q,false)
	await key(KEY_ESCAPE)
	dino.position = stage.player.position+Vector2(180,0)
	await hold(KEY_Q)
	check(hud.is_open() and hud._command_is_group,"Held Q away from companions failed to open group orders")
	await physical(KEY_Q,false)
	await key(KEY_ESCAPE)
	dino.position = stage.player.position+Vector2(20,0)
	dino.tamed = false
	await hold(KEY_E)
	check(not hud.is_open(),"Wild dinosaur incorrectly exposed companion orders")
	await physical(KEY_E,false)
	# A corpse closer to the player must not intercept interaction with a live bond.
	dino.is_dead = true
	dino.position = stage.player.position+Vector2(5,0)
	other.tamed = true
	other.position = stage.player.position+Vector2(28,0)
	await hold(KEY_E)
	check(hud.is_open() and hud._command_target == other,"Nearest corpse intercepted live companion interaction")
	await physical(KEY_E,false)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(stage._overlay_kind == "pause" and get_tree().paused,"Physical Escape failed to pause")
	check(stage._panel.get_global_rect().end.y<=270,"Pause overlay overflows screen")
	await capture("09-pause")
	await key(KEY_ESCAPE)
	await key(KEY_J)
	check(stage._overlay_kind == "journal","Physical J failed to open journal")
	check(stage._panel.get_global_rect().end.y<=270,"Journal overlay overflows screen")
	await capture("10-journal")
	await key(KEY_ESCAPE)
	var menu: Control = load("res://Forest/MainMenu.tscn").instantiate()
	stage.hide()
	stage.hud.hide()
	stage.set_process(false)
	stage.set_physics_process(false)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 40
	add_child(menu_layer)
	menu_layer.add_child(menu)
	menu._show_guide()
	await settle()
	check(menu._details.get_global_rect().end.y<=270,"Title guide overflows screen")
	await capture("11-title-guide")
	print("UI_V2_TEST failures=",failures)
	get_tree().quit(1 if failures else 0)
