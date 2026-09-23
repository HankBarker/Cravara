extends Node2D
const SAVE := "user://forest_pass4_root_test.json"
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
	# Helmet follows cel outlines and idle glances, preserving eyes and source.
	player.equip_armor("head",ItemDB.make("leather_helmet"))
	var source: SpriteFrames=player._base_frames
	var dressed: SpriteFrames=player.animated_sprite.sprite_frames
	var sheet:=Image.create(64*12,64*8,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("16332c"))
	var row:=0
	var outline_changes:=0
	for facing in ["down","up","left","right"]:
		var animation: String="idle_"+facing
		var prior: Dictionary={}
		for i in source.get_frame_count(animation):
			var pose: Dictionary=player._skin.pose(animation,i)
			var img: Image=dressed.get_frame_texture(animation,i).get_image()
			var raw: Image=source.get_frame_texture(animation,i).get_image()
			var origin:=Vector2i(int(pose.head_origin[0]),int(pose.head_origin[1]))
			var actual_facing := str(pose.get("head_facing",facing))
			var art_path := "res://Forest/equipment/art/wardrobe/leather_head_"+actual_facing+".png"
			var art: Image = load(art_path).get_image()
			var center := int(round((float(pose.head_rows[0][0])+float(pose.head_rows[0][1]))*.5))
			var crown := origin+Vector2i(center,0)
			var expected := art.get_pixel(32 if actual_facing in ["left","right"] else 31,22)
			check(expected.a > .95 and img.get_pixelv(crown).is_equal_approx(expected),"helmet crown follows "+animation+" frame "+str(i))
			var ear_x := int(pose.head_rows[8][1]) if actual_facing=="left" else int(pose.head_rows[8][0])
			var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Forest/equipment/art/pose_anchors.json"))
			var original_pose: Dictionary = reference["idle_"+actual_facing][5 if actual_facing=="left" else 0]
			var original_ear := int(original_pose.head_rows[8][1]) if actual_facing=="left" else int(original_pose.head_rows[8][0])
			var ear_color := art.get_pixel(int(original_pose.head_origin[0])+original_ear,30)
			if ear_color.a < .95:
				var darkest := 1.0
				for ay in art.get_height():
					for ax in art.get_width():
						var candidate := art.get_pixel(ax,ay)
						if candidate.a > .95 and candidate.get_luminance() < darkest:
							darkest = candidate.get_luminance()
							ear_color = candidate
			check(ear_color.a > .95 and img.get_pixelv(origin+Vector2i(ear_x,8)).is_equal_approx(ear_color),"helmet covers ear in "+animation+" frame "+str(i))
			if not prior.is_empty() and (prior.head_rows!=pose.head_rows or prior.head_origin!=pose.head_origin): outline_changes+=1
			prior=pose
			sheet.blend_rect(raw,Rect2i(0,0,64,64),Vector2i(i*64,row*128))
			sheet.blend_rect(img,Rect2i(0,0,64,64),Vector2i(i*64,row*128+64))
		row+=1
	check(outline_changes>3,"idle comparison exercises actual head silhouette and position changes")
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
