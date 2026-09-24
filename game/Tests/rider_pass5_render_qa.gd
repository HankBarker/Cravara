extends Node2D
const Kit = preload("res://Tests/keeper_test_kit.gd")
var count := 0
var failures: Array[String] = []
var scene
var player
const OUTPUT := "res://../art/forest-playtest/v5/"
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
	player.last_facing="right"
	player.animated_sprite.play("idle_right")
	await get_tree().create_timer(0.2).timeout
	await capture("hero-basic-cloth.png")
	# Standing hero, seated rider (the rig's "ride" pose) and seated rider in a
	# helmet, all dressed with the player's actual appearance.
	var comparison := Image.create(256,192,false,Image.FORMAT_RGBA8)
	var dirs := ["down","right","left","up"]
	player.finish_skin()
	var skin = player._skin
	var cloth: Dictionary = skin.look_for({},player.appearance)
	var helmet: Dictionary = skin.look_for({"head":ItemDB.make("leather_helmet")},player.appearance)
	for i in dirs.size():
		var clip: String = "idle_"+dirs[i]
		var standing: Image = player.animated_sprite.sprite_frames.get_frame_texture(clip,0).get_image()
		var seated: Image = skin.render_cel("ride",dirs[i],0,cloth)
		var seated_helmet: Image = skin.render_cel("ride",dirs[i],0,helmet)
		comparison.blend_rect(standing,Rect2i(0,0,64,64),Vector2i(i*64,0))
		comparison.blend_rect(seated,Rect2i(0,0,64,64),Vector2i(i*64,64))
		comparison.blend_rect(seated_helmet,Rect2i(0,0,64,64),Vector2i(i*64,128))
		check(Kit.diff(standing,seated)>30,dirs[i]+" seated rider is reposed from the standing hero")
		var fit: Dictionary=Kit.helmet_fit(skin,"ride",dirs[i],0,seated_helmet,seated,cloth)
		check(fit.pixels>=24 and fit.inside>=0.9,dirs[i]+" seated rider wears the helmet on its head %s" % fit)
	check(comparison.save_png(OUTPUT+"hero-standing-seated-helmet-native.png")==OK,"four-direction source identity and dark helmet comparison exported")
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
		# The hero sprite hides while riding; the mount's composite frame on
		# screen carries the seated, dressed rider instead.
		var clip_now := str(mount._sprite.animation)
		var shown: Image = mount._sprite.sprite_frames.get_frame_texture(clip_now,mount._sprite.frame).get_image()
		var creature_only: Image = preload("res://Forest/creatures/MountedAppearance.gd").new().build(kind).get_frame_texture(clip_now,mount._sprite.frame).get_image()
		var rider_look: Dictionary = skin.look_for(player.equipped_armor,player.appearance,player.equipped_light)
		var ride_cel: Image = skin.render_cel("ride","right",0,rider_look)
		var rider_head := Kit.crop(ride_cel,Kit.head_footprint(skin,"ride","right",0,rider_look,ride_cel))
		var added: int = Kit.opaque(shown)-Kit.opaque(creature_only)
		check(not player.animated_sprite.visible and Kit.contains_sprite(shown,rider_head) and added>=Kit.opaque(ride_cel)/3,kind+" seated, helmeted rider is visible in the mount's current frame (%d px added, head drawn)" % added)
		check(mount._sprite.animation == "walk_side" and player.animated_sprite.animation == "idle_right",kind+" actual side pose retained at capture")
		print("POSE ",kind," side creature=",mount._sprite.animation," rider=",player.animated_sprite.animation," seat=",mount._mount_controller.riding_offset())
		await capture("mounted-"+kind+"-side.png")
		Input.action_release("Right")
		Input.action_press("Left")
		await get_tree().create_timer(0.65).timeout
		check(mount._facing=="side" and mount._sprite.flip_h,kind+" true left-facing source cel")
		await capture("mounted-"+kind+"-left.png")
		Input.action_release("Left")
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
		check(str(mount._sprite.animation).begins_with("attack_"),kind+" real strike animation visible")
		await capture("mounted-"+kind+"-attack.png")
		var board := Image.create(96*8,80*3,false,Image.FORMAT_RGBA8)
		for row in 3:
			var clip: String = ["walk_side","walk_down","attack_side"][row]
			for frame in mount._sprite.sprite_frames.get_frame_count(clip):
				var im: Image = mount._sprite.sprite_frames.get_frame_texture(clip,frame).get_image()
				board.blend_rect(im,Rect2i(Vector2i.ZERO,im.get_size()),Vector2i(frame*96,row*80))
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
	print("RIDER_PASS5_RENDER_QA assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

