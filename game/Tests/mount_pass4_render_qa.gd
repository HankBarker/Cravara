extends Node2D
var count := 0
var failures: Array[String] = []
var scene
var player
const OUTPUT := "res://../art/forest-playtest/v4/"
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, message: String):
	count += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:
		failures.append(message)
		push_error(message)
func frames(n: int):
	for i in n: await get_tree().physics_frame
func capture(file_name: String):
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.save_png(OUTPUT+file_name) == OK,"captured "+file_name)
func spawn(species: String, pos: Vector2):
	var creature = load("res://Forest/creatures/ForestCreature.gd").new()
	creature.species = species
	creature.tamed = true
	creature.position = scene.world.get_spawnable_position(pos)
	creature.saddle = ItemDB.make(species+"_saddle")
	scene.add_child(creature)
	creature.set_order("stay")
	creature.set_stance("passive")
	return creature
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	GameSettings.set_camera_follow("tight")
	get_viewport().content_scale_size = Vector2i(480,270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	player = scene.player
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.43
	await get_tree().create_timer(0.6).timeout
	player._set_equipment("head",ItemDB.make("leather_helmet"))
	player._set_equipment("chest",ItemDB.make("leather_chestplate"))
	player._set_equipment("legs",ItemDB.make("leather_leggings"))
	player._set_equipment("light",ItemDB.make("lantern"))
	for kind in ["stego","trike"]:
		var mount = spawn(kind,Vector2(-20,0))
		player.position = mount.position
		check(mount.mount(player),kind+" mounts actual rendered player")
		Input.action_press("Right")
		await get_tree().create_timer(0.30).timeout
		check(mount._mount_controller.visible and mount.saddle != null and player.mounted_creature == mount,kind+" saddle overlay and rider are active")
		check(mount._sprite.animation == "walk_side" and player.animated_sprite.animation == "idle_right",kind+" actual side pose retained at capture")
		print("POSE ",kind," side creature=",mount._sprite.animation," rider=",player.animated_sprite.animation," seat=",mount._mount_controller.riding_offset())
		await capture("mounted-"+kind+"-side.png")
		Input.action_release("Right")
		Input.action_press("Up")
		await get_tree().create_timer(0.65).timeout
		check(mount._facing == "up",kind+" true up facing")
		await capture("mounted-"+kind+"-up.png")
		Input.action_release("Up")
		Input.action_press("Down")
		await get_tree().create_timer(0.65).timeout
		check(mount._facing == "down",kind+" true down facing")
		await capture("mounted-"+kind+"-down.png")
		Input.action_release("Down")
		await get_tree().create_timer(0.12).timeout
		check(mount.mount_attack(mount.position+Vector2(100,0)),kind+" rendered mounted attack begins")
		await get_tree().create_timer(0.34).timeout
		var strike: String = "tail_swing" if kind == "stego" else "gore"
		check(str(mount._sprite.animation).begins_with(strike+"_"),kind+" real strike animation visible")
		await capture("mounted-"+kind+"-attack.png")
		var cell := Vector2i(mount._sprite.sprite_frames.get_frame_texture("idle_side",0).get_size())
		var board := Image.create(cell.x*13,cell.y*3,false,Image.FORMAT_RGBA8)
		for row in 3:
			var clip: String = ["walk_side","walk_down",strike+"_side"][row]
			for frame in mini(13,mount._sprite.sprite_frames.get_frame_count(clip)):
				var im: Image = mount._sprite.sprite_frames.get_frame_texture(clip,frame).get_image()
				board.blend_rect(im,Rect2i(Vector2i.ZERO,im.get_size()),Vector2i(frame*cell.x,row*cell.y))
		check(board.save_png(OUTPUT+kind+"-composite-native.png")==OK,kind+" native animation contact sheet saved")
		mount.health -= 9
		var food_before := InventoryManager.get_item_count("berry")
		var feed := InputEventKey.new()
		feed.physical_keycode = KEY_F
		feed.pressed = true
		scene._unhandled_input(feed)
		check(mount.health==int(mount.stats.hp) and InventoryManager.get_item_count("berry")==food_before-1,kind+" root F route feeds and heals mounted animal")
		check(mount.dismount(),kind+" dismounts after actual movement")
		mount.queue_free()
		await frames(2)
	player.position = scene.world.get_spawnable_position(Vector2.ZERO)
	var target = spawn("trike",Vector2(370,-80))
	scene.locate_companion(target)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(is_instance_valid(scene._locator) and scene._locator.target == target,"root locate creates tracking marker for selected animal")
	var marker = scene._locator
	check(marker.marker.visible and marker.ui.visible,"locator canvas marker is visible")
	var expected := "%d tiles" % int(target.position.distance_to(player.position)/16)
	check(marker.label.text == expected,"locator label reports live tile distance")
	check(marker.marker.position.x >= 30 and marker.marker.position.x <= 450 and marker.marker.position.y >= 62 and marker.marker.position.y <= 219,"offscreen locator stays within visible HUD bounds")
	await capture("companion-locator-offscreen.png")
	var old_text: String = marker.label.text
	target.position += Vector2(100,80)
	player.position += Vector2(-25,0)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(is_instance_valid(marker) and marker.label.text != old_text,"locator survives target and player movement and refreshes distance")
	expected = "%d tiles" % int(target.position.distance_to(player.position)/16)
	check(marker.label.text == expected,"moving target distance remains accurate")
	target.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(not is_instance_valid(marker) and not is_instance_valid(scene._locator),"target removal cleans up tracking marker and its UI")
	scene.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("MOUNT_PASS4_RENDER_QA assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

