extends Node2D
const Actions = preload("res://Forest/equipment/ActionFrames.gd")
const OUTPUT := "res://../art/forest-playtest/v6/"
var scene
var player
var count := 0
var failures: Array[String] = []
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(value: bool,label: String):
	count += 1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures.append(label)
func capture(file_name: String):
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUTPUT+file_name)==OK,"captured "+file_name)
func pause(seconds: float): await get_tree().create_timer(seconds).timeout
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args(): get_tree().quit(1); return
	get_viewport().content_scale_size=Vector2i(480,270)
	get_viewport().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene=preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	player=scene.player
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	TimeCycle.paused=true
	TimeCycle.time_of_day=.43
	await pause(.6)
	player.position=scene.world.get_spawnable_position(Vector2.ZERO)
	player._set_equipment("head",ItemDB.make("leather_helmet"))
	player._set_equipment("chest",ItemDB.make("leather_chestplate"))
	player._set_equipment("legs",ItemDB.make("leather_leggings"))
	get_viewport().warp_mouse(Vector2(280,135))
	await pause(.12)
	var title := Label.new()
	title.position=Vector2(120,54)
	title.add_theme_font_size_override("font_size",11)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(title)
	var playback := Image.create(64*8,64*Actions.DURATIONS.size(),false,Image.FORMAT_RGBA8)
	var row := 0
	for kind in Actions.DURATIONS:
		player.stop_action()
		var target: Vector2=player.position+Vector2(100,0)
		var tool_id: String={"axe":"basic_axe","pickaxe":"basic_pickaxe","weapon":"bone_dagger","sword":"shard_sword"}.get(kind,"")
		if not tool_id.is_empty():
			InventoryManager.inventory[0]={"item":ItemDB.make(tool_id),"quantity":1}
			InventoryManager.selected_slot_index=0
			InventoryManager.inventory_changed.emit()
			player.switch_state("attack")
		else: player.play_action(kind,target)
		title.text="Native action playback: "+kind.replace("_"," ")
		var seen := {}
		var previous := -1
		var remaining: float=Actions.duration(kind)
		while remaining>0:
			await get_tree().process_frame
			remaining-=get_process_delta_time()
			var clip: String=str(player.animated_sprite.animation)
			if clip.begins_with(kind+"_"):
				var frame: int=player.animated_sprite.frame
				seen[frame]=true
				if frame!=previous:
					playback.blend_rect(player.animated_sprite.sprite_frames.get_frame_texture(clip,frame).get_image(),Rect2i(0,0,64,64),Vector2i(frame*64,row*64))
					previous=frame
				if frame==4 and kind in ["axe","pickaxe","bow_draw","hoe"]:
					await capture("in-game-action-"+kind+".png")
		check(seen.size()>=5,kind+" actual running player advances through five or more distinct animation frames")
		print("TIMELINE ",kind," frames=",seen.keys())
		await pause(.08)
		row+=1
	playback.save_png(OUTPUT+"actual-playback-native.png")
	player.apply_appearance({"skin":"umber","hair":"silver","cloth":"river","trousers":"slate","hair_style":"tied"})
	player._set_equipment("head",null)
	player._set_equipment("chest",null)
	player._set_equipment("legs",null)
	player.stop_action()
	InventoryManager.inventory[0]={"item":ItemDB.make("reed_bow"),"quantity":1}
	InventoryManager.add_item(ItemDB.make("bone_arrow"),8)
	InventoryManager.selected_slot_index=0
	InventoryManager.inventory_changed.emit()
	var mount=load("res://Forest/creatures/ForestCreature.gd").new()
	mount.species="stego"
	mount.tamed=true
	mount.position=player.position
	mount.saddle=ItemDB.make("stego_saddle")
	scene.add_child(mount)
	mount.set_order("stay")
	mount.set_stance("passive")
	check(mount.mount(player),"custom hero mounts real saddled stego")
	Input.action_press("Right")
	await pause(.18)
	Input.action_release("Right")
	# The draw pose follows the real cursor (BowController): put it right of the
	# rider now, since other windows may have moved the OS cursor meanwhile.
	get_viewport().warp_mouse(get_viewport().get_canvas_transform()*(player.global_position+Vector2(60,0)))
	await get_tree().process_frame
	check(scene.bow.begin_draw(player.position+Vector2(100,0)),"real mounted bow draw starts")
	await pause(.70)
	check(player.action_kind=="bow_draw" and player.animated_sprite.frame==7,"draw stays at full tension during charge")
	var aim: Vector2=player.get_global_mouse_position()-player.global_position
	var aim_facing: String=("right" if aim.x>0 else "left") if absf(aim.x)>absf(aim.y) else ("down" if aim.y>0 else "up")
	check(str(player.animated_sprite.animation)=="bow_draw_"+aim_facing,"mount does not override aiming action (%s, aim %s)" % [player.animated_sprite.animation,aim_facing])
	title.text="Custom hero, seated bow draw, actual game"
	await capture("in-game-mounted-custom-bow.png")
	check(scene.bow.release(player.position+Vector2(100,0)),"real mounted arrow release")
	await pause(.08)
	check(player.action_kind=="bow_release","release recoil remains attached to mount")
	await capture("in-game-mounted-bow-release.png")
	await pause(.3)
	check(mount.dismount(),"custom hero safely dismounts after firing")
	scene.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("CHARACTER_PASS6_RENDER assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
