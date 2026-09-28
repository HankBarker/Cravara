extends Node2D
var scene
var player
var failures:=0
var checks:=0
func _enter_tree():SaveManager.disable_for_playtest()
func _ready():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func capture(name:String):
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://../art/character-pass7/"+name+".png")==OK,"rendered "+name)
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args():get_tree().quit(1);return
	get_viewport().content_scale_size=Vector2i(480,270)
	get_viewport().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene=preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene);player=scene.player
	for creature in get_tree().get_nodes_in_group("forest_creatures"):creature.queue_free()
	TimeCycle.paused=true;TimeCycle.time_of_day=.43
	await get_tree().create_timer(.6).timeout
	player.position=scene.world.get_spawnable_position(Vector2.ZERO)
	for family in ["leather","bone","crystal"]:
		player._set_equipment("head",ItemDB.make(family+"_helmet"))
		player._set_equipment("chest",ItemDB.make(family+"_chestplate"))
		player._set_equipment("legs",ItemDB.make(family+"_leggings"))
		player.last_facing="down";player.animated_sprite.play("idle_down")
		await get_tree().create_timer(.12).timeout
		await capture("world-"+family)
	var creature=preload("res://Forest/creatures/ForestCreature.gd").new()
	creature.species="stego";creature.tamed=true
	creature.saddle=ItemDB.make("stego_saddle")
	creature.position=scene.world.get_spawnable_position(player.position+Vector2(24,12))
	scene.add_child(creature);creature.set_order("stay");creature.set_stance("passive")
	player.position=creature.position
	check(creature.mount(player),"crystal keeper mounts as real player entity")
	for direction in ["Right","Left","Up","Down"]:
		Input.action_press(direction)
		await get_tree().create_timer(.28).timeout
		check(player.mounted_creature==creature and creature._mount_controller.visible,"mounted "+direction+" remains synchronized")
		await capture("mounted-crystal-"+direction.to_lower())
		Input.action_release(direction)
	check(creature.dismount(),"dismount returns same equipped keeper")
	check(player.get_equipment("head").id=="crystal_helmet","dismount retains real armor")
	scene.queue_free();await get_tree().process_frame
	AudioManager.stop_music();await get_tree().create_timer(.5).timeout
	print("WARDROBE_WORLD_PASS7 assertions=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
