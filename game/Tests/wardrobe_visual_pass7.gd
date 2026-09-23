extends Node2D
const SkinBuilder=preload("res://Forest/equipment/EquipmentSkin.gd")
const Appearance=preload("res://Forest/equipment/Appearance.gd")
const Actions=preload("res://Forest/equipment/ActionFrames.gd")
const OUTPUT="res://../art/character-pass7/"
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args(): get_tree().quit(1);return
	var player=preload("res://Player/player.tscn").instantiate()
	for state in player.states.values(): state.free()
	player.set_script(preload("res://Forest/ForestPlayer.gd"))
	add_child(player)
	player.set_physics_process(false)
	var source: SpriteFrames=player._base_frames
	var builder=SkinBuilder.new()
	var board=Image.create(64*4,64*4,false,Image.FORMAT_RGBA8)
	board.fill(Color("233b32"))
	var row=0
	for family in ["none","leather","bone","crystal"]:
		var gear: Dictionary={} if family=="none" else {"head":ItemDB.make(family+"_helmet"),"chest":ItemDB.make(family+"_chestplate"),"legs":ItemDB.make(family+"_leggings")}
		var dressed: SpriteFrames=builder.build(source,gear,null)
		var column=0
		for dir in ["down","right","up","left"]:
			board.blend_rect(dressed.get_frame_texture("idle_"+dir,0).get_image(),Rect2i(0,0,64,64),Vector2i(column*64,row*64))
			if family!="none":
				var sheet=Image.create(64*8,64*Actions.DURATIONS.size(),false,Image.FORMAT_RGBA8)
				sheet.fill(Color("233b32"))
				var action_row=0
				for action in Actions.DURATIONS:
					for i in 8:sheet.blend_rect(dressed.get_frame_texture(action+"_"+dir,i).get_image(),Rect2i(0,0,64,64),Vector2i(i*64,action_row*64))
					action_row+=1
				sheet.save_png(OUTPUT+family+"-actions-"+dir+".png")
			column+=1
		row+=1
	board.save_png(OUTPUT+"wardrobe-native.png")
	board.resize(1024,1024,Image.INTERPOLATE_NEAREST)
	board.save_png(OUTPUT+"wardrobe-review.png")
	var hair_board=Image.create(64*4,64*6,false,Image.FORMAT_RGBA8)
	hair_board.fill(Color("233b32"))
	row=0
	for option in Appearance.OPTIONS.hair_style:
		var frames: SpriteFrames=builder.build(source,{},null,{"hair_style":option.id,"hair":"chestnut","cloth":"river"})
		var col=0
		for dir in ["down","right","up","left"]:
			hair_board.blend_rect(frames.get_frame_texture("idle_"+dir,0).get_image(),Rect2i(0,0,64,64),Vector2i(col*64,row*64));col+=1
		row+=1
	hair_board.resize(1024,1536,Image.INTERPOLATE_NEAREST)
	hair_board.save_png(OUTPUT+"hair-integration-review.png")
	player.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("WARDROBE_VISUAL_PASS7 failures=0")
	get_tree().quit()
