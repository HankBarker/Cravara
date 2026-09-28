extends Node2D
const SAVE := "user://forest_pass4_root_test.json"
const Kit = preload("res://Tests/keeper_test_kit.gd")
var failures: Array[String] = []
var count := 0
var stage
var player
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func check(ok: bool, note: String):
	count += 1
	print(("PASS " if ok else "FAIL ")+note)
	if not ok: failures.append(note)
func key(code: int, pressed := true):
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	get_viewport().push_input(event,true)
func tap(code: int):
	key(code)
	key(code,false)
func screenshot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../art/forest-pass4/"+name+".png")
func run():
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	player = stage.player
	for dino in get_tree().get_nodes_in_group("forest_creatures"): dino.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# E works near a bench without having to aim the cursor exactly at it.
	var bench
	for prop in stage.world.props.values():
		if prop.kind=="workbench": bench=prop; break
	player.position=bench.position+Vector2(0,26)
	player.controls_locked=false
	var motion:=InputEventMouseMotion.new()
	motion.position=Vector2(470,260)
	get_viewport().push_input(motion,true)
	tap(KEY_E)
	await get_tree().process_frame
	check(stage.hud.is_open(),"nearby workbench opens with E without cursor targeting")
	stage.hud.close_panels()
	await get_tree().process_frame
	# Helmet follows the head through idle breathing, blinks and glances,
	# keeps the face visible, hides the hair, and never touches the source.
	var source: SpriteFrames=player._base_frames
	var source_before: Dictionary={}
	for facing in ["down","up","left","right"]:
		for i in source.get_frame_count("idle_"+facing): source_before["%s%d" % [facing,i]]=source.get_frame_texture("idle_"+facing,i).get_image().get_data()
	player.equip_armor("head",ItemDB.make("leather_helmet"))
	player.finish_skin()
	var dressed: SpriteFrames=player.animated_sprite.sprite_frames
	var skin=player._skin
	var motion_lib=skin.shared().motion
	var bare_look: Dictionary=skin.look_for({},player.appearance,player.equipped_light)
	var helmet: Dictionary={"head":player.get_equipment("head")}
	# Same helmet, other hair colour / skin tone: only fringe pixels may differ
	# for the hair; the face under the helmet must still take the skin tone.
	var other_hair: Dictionary=player.appearance.duplicate()
	other_hair.hair="charcoal" if other_hair.hair!="charcoal" else "flax"
	var other_skin: Dictionary=player.appearance.duplicate()
	other_skin.skin="umber" if other_skin.skin!="umber" else "warm"
	var hair_look: Dictionary=skin.look_for(helmet,other_hair,player.equipped_light)
	var bare_hair_look: Dictionary=skin.look_for({},other_hair,player.equipped_light)
	var skin_look: Dictionary=skin.look_for(helmet,other_skin,player.equipped_light)
	var idle_frames:=1
	for facing in ["down","up","left","right"]: idle_frames=maxi(idle_frames,source.get_frame_count("idle_"+facing))
	var sheet:=Image.create(64*idle_frames,64*8,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("16332c"))
	var row:=0
	var head_moves:=0
	for facing in ["down","up","left","right"]:
		var animation: String="idle_"+facing
		var prior: Array=[]
		var crops: Array=[]
		for i in source.get_frame_count(animation):
			var pose: Dictionary=player._skin.pose(animation,i)
			var img: Image=dressed.get_frame_texture(animation,i).get_image()
			var raw: Image=source.get_frame_texture(animation,i).get_image()
			var plain: Image=skin.render_cel("idle",facing,i,bare_look)
			var fit: Dictionary=Kit.helmet_fit(skin,"idle",facing,i,img,plain,bare_look)
			check(fit.pixels>=24 and fit.inside>=0.9,"helmet crown follows "+animation+" frame "+str(i)+" %s" % fit)
			var hair_fringe:=Kit.diff(img,skin.render_cel("idle",facing,i,hair_look))
			var bare_hair:=Kit.diff(plain,skin.render_cel("idle",facing,i,bare_hair_look))
			check(hair_fringe<=12 and bare_hair>24,"helmet covers hair and ears in "+animation+" frame "+str(i)+" (%d px vs %d bare)" % [hair_fringe,bare_hair])
			if facing!="up":
				# The face stays visible under the helmet: the skin tone reaches
				# pixels of the helmeted head itself (not just the hands).
				var toned:=Kit.changed(img,skin.render_cel("idle",facing,i,skin_look))
				var head:=Kit.head_footprint(skin,"idle",facing,i,skin.look_for(helmet,player.appearance,player.equipped_light),img)
				var face:=0
				for p in toned:
					if head.has(p): face+=1
				check(face>=3,"helmet preserves the face in "+animation+" frame "+str(i)+" (%d px)" % face)
			crops.append(Kit.crop(img,Kit.changed(img,plain)).get_data())
			if not prior.is_empty() and prior!=pose.head: head_moves+=1
			prior=pose.head
			sheet.blend_rect(raw,Rect2i(0,0,64,64),Vector2i(i*64,row*128))
			sheet.blend_rect(img,Rect2i(0,0,64,64),Vector2i(i*64,row*128+64))
		# A glance swaps the head view: the helmet must turn with it (its pixels
		# change against a plain, open-eyed frame, wherever it sits in the cel).
		var plain_frame:=-1
		for i in crops.size():
			var p: Dictionary=motion_lib.pose("idle",facing,i)
			if not p.has("head_view") and not p.get("blink",false):
				plain_frame=i
				break
		for i in crops.size():
			if motion_lib.pose("idle",facing,i).has("head_view"):
				check(plain_frame>=0 and crops[i]!=crops[plain_frame],"helmet turns with the "+animation+" glance (frame %d)" % i)
		row+=1
	check(head_moves>3,"idle comparison exercises actual head position changes (%d)" % head_moves)
	var untouched:=true
	for facing in ["down","up","left","right"]:
		for i in source.get_frame_count("idle_"+facing): untouched=untouched and source.get_frame_texture("idle_"+facing,i).get_image().get_data()==source_before["%s%d" % [facing,i]]
	check(untouched,"equipping a helmet leaves the source idle cels untouched")
	sheet.save_png("res://../art/forest-pass4/helmet-idle-comparison.png")
	# Bed binding uses a safe location and persists through journey restore.
	var cell:=Vector2i(0,3)
	for y in range(-1,7):
		for x in range(-3,4):
			var c:=Vector2i(x,y)
			if stage.world.props.has(c): stage.world.props[c].free(); stage.world.props.erase(c)
			stage.world.water.erase(c)
	stage.world._spawn_prop(cell,"hide_bed")
	var bed=stage.world.props[cell]
	stage.world.placed[cell]="hide_bed"
	player.position=bed.position+Vector2(0,28)
	check(stage.set_spawn_bed(bed),"bed binds nearby player spawn")
	var spawn: Vector2=stage.get_respawn_position()
	check(spawn.distance_to(bed.position)<100,"bed returns a nearby clear respawn point")
	check(stage.save_journey(SAVE),"journey saves bed binding")
	stage._has_spawn_bed=false
	check(stage._load_journey(SAVE) and stage._has_spawn_bed and stage._spawn_bed_cell==cell,"bed binding restores without disturbing journey")
	await get_tree().process_frame
	# Actual fatal damage, countdown, blocked input, and recovered physics.
	player.is_invulnerable=false
	player.take_damage(9999)
	await get_tree().process_frame
	check(player.respawning and not player.is_physics_processing(),"death enters countdown with movement stopped")
	check(is_instance_valid(stage._death_screen) and stage._respawn_left>4.8,"death screen begins a five-second countdown")
	await screenshot("death-screen")
	tap(KEY_TAB)
	tap(KEY_ESCAPE)
	check(not stage.hud.is_open() and not get_tree().paused,"death blocks satchel and pause shortcuts")
	await get_tree().create_timer(1.1).timeout
	check(player.respawning and stage._respawn_left>3 and stage._respawn_left<4,"countdown advances in real game time")
	await get_tree().create_timer(4.1).timeout
	check(not player.respawning and player.is_physics_processing() and player.state=="idle","respawn reenables physics and idle state without reload")
	check(player.current_health==player.max_health and player.position.distance_to(spawn)<10,"respawn restores vitality at bound bed")
	var start: Vector2=player.position
	Input.action_press("Right")
	await get_tree().create_timer(0.3).timeout
	Input.action_release("Right")
	check(player.position.distance_to(start)>5,"player actually walks after respawning")
	# Removed beds fall back safely instead of trapping the next death.
	bed=stage.world.props.get(cell)
	bed.free()
	stage.world.props.erase(cell)
	stage.get_respawn_position()
	check(not stage._has_spawn_bed,"destroyed spawn bed falls back to camp")
	DirAccess.remove_absolute(SAVE)
	await get_tree().create_timer(player.invulnerability_duration+0.1).timeout
	stage.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("FOREST_ROOT_PASS4 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
