extends SceneTree

var failures := 0

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func controls_fit(node: Node) -> bool:
	var fits:=true
	if node is Control and node.is_visible_in_tree() and not Rect2(0,0,480,270).encloses(node.get_global_rect()): fits=false
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			if not Rect2(0,0,480,270).encloses(child.get_global_rect()):
				print("Outside native viewport: ",child.name," ",child.get_global_rect())
				fits=false
		if not controls_fit(child): fits=false
	return fits

func buttons_separate(node: Node) -> bool:
	var buttons: Array=[]
	for child in node.get_children():
		if child is Button and child.visible: buttons.append(child)
	for i in buttons.size():
		for j in range(i+1,buttons.size()):
			if buttons[i].get_rect().intersects(buttons[j].get_rect()):
				print("Overlapping buttons: ",buttons[i].text," / ",buttons[j].text)
				return false
	return true

func run():
	var menu = load("res://Forest/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu._show_guide()
	await process_frame
	await process_frame
	check(menu._details.position.y + menu._details.size.y <= 270, "Title guide fits screen %s" % menu._details.size)
	menu._close_details()
	menu._new_expedition()
	await process_frame
	# Existing journey confirmation leads into creation; it never starts play directly.
	if is_instance_valid(menu._details): menu._show_creator()
	await process_frame
	check(is_instance_valid(menu._creator) and current_scene==menu,"New expedition opens keeper creator before forest")
	menu._creator._cycle("cloth",1)
	var chosen: Dictionary=menu._creator.draft.duplicate()
	menu._creator._accept()
	await process_frame
	await process_frame
	var game = current_scene
	check(game.has_method("save_journey"), "New expedition enters forest scene")
	check(game.player.appearance==chosen,"Created appearance reaches new forest")
	var creator=load("res://UI/CharacterCreator.gd").new()
	creator.configure(game.player.appearance,game.player,false)
	game.add_child(creator)
	await process_frame
	creator.show_gear=false
	creator._refresh()
	await process_frame
	check(controls_fit(creator.root) and buttons_separate(creator.root),"Editing creator buttons fit and do not overlap, including clothing preview")
	creator._cancel()
	await process_frame
	game._show_pause()
	await process_frame
	check(game._panel.position.y + game._panel.size.y <= 270, "Pause menu fits screen %s" % game._panel.size)
	game._show_journal()
	await process_frame
	await process_frame
	check(controls_fit(game._panel),"First camp journal and all content fit native screen %s" % game._panel.size)
	game._show_field_skills()
	await process_frame
	await process_frame
	check(controls_fit(game._panel),"Field skills journal and all content fit native screen %s" % game._panel.size)
	game._show_map()
	await process_frame
	check(game._panel.position.y + game._panel.size.y <= 270, "Map fits screen %s" % game._panel.size)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../art/forest-playtest/map.png")
	game._close_overlay()
	change_scene_to_file("res://Forest/MainMenu.tscn")
	await process_frame
	await process_frame
	check(get_nodes_in_group("player").is_empty(), "Returning to title removes old player")
	check(get_nodes_in_group("forest_creatures").is_empty(), "Returning to title removes old wildlife")
	check(current_scene.has_method("_start"), "Title returns after forest scene")
	root.get_node("AudioManager").stop_music()
	await create_timer(0.15).timeout
	print("MENU FLOW: %d failures" % failures)
	quit(failures)
