extends Node2D
const Actions = preload("res://Forest/equipment/ActionFrames.gd")
const Appearance = preload("res://Forest/equipment/Appearance.gd")
const GearSkin = preload("res://Forest/equipment/EquipmentSkin.gd")
const OUTPUT := "res://../art/forest-playtest/v6/"
var count := 0
var failures: Array[String] = []
var player
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(value: bool, label: String):
	count += 1
	if not value: failures.append(label)
	print(("PASS " if value else "FAIL ")+label)
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args(): get_tree().quit(1); return
	player = preload("res://Player/player.tscn").instantiate()
	for state in player.states.values(): state.free()
	player.set_script(preload("res://Forest/ForestPlayer.gd"))
	add_child(player)
	player.set_physics_process(false)
	var source: SpriteFrames = Actions.install(player._base_frames)
	var skin := GearSkin.new()
	var armor := {"head":ItemDB.make("leather_helmet"),"chest":ItemDB.make("leather_chestplate"),"legs":ItemDB.make("leather_leggings")}
	var original_hash := source.get_frame_texture("idle_down",0).get_image().get_data().hex_encode().sha256_text()
	var clock := Time.get_ticks_usec()
	var basic := skin.build(source,{},null)
	print("PERF default_skin_ms=",(Time.get_ticks_usec()-clock)/1000.0)
	var dressed := skin.build(source,armor,null)
	clock = Time.get_ticks_usec()
	var custom := skin.build(source,{},null,{"skin":"umber","hair":"silver","hair_style":"tied","cloth":"river","trousers":"slate"})
	print("PERF custom_skin_ms=",(Time.get_ticks_usec()-clock)/1000.0)
	var cropped := skin.build(source,{},null,{"hair_style":"cropped"})
	check(Appearance.normalize({"skin":"invalid","unknown":true})==Appearance.DEFAULTS,"invalid saved choices normalize to stable defaults")
	check(skin.build(source,armor,null)==dressed,"same appearance uses frame cache")
	check(basic!=custom and basic!=cropped,"customization keys isolate cached frames")
	check(source.get_frame_texture("idle_down",0).get_image().get_data().hex_encode().sha256_text()==original_hash,"source textures remain unchanged after all wardrobe variants")
	var board := Image.create(256,256,false,Image.FORMAT_RGBA8)
	var dirs := ["down","right","left","up"]
	for d in dirs.size():
		var clip: String = "idle_"+dirs[d]
		for row in 4:
			var frameset: SpriteFrames = [source,basic,dressed,custom][row]
			board.blend_rect(frameset.get_frame_texture(clip,0).get_image(),Rect2i(0,0,64,64),Vector2i(d*64,row*64))
		check(basic.get_frame_texture(clip,0).get_image().get_data()!=custom.get_frame_texture(clip,0).get_image().get_data(),dirs[d]+" custom appearance changes actual pixels")
		check(basic.get_frame_texture(clip,0).get_image().get_data()!=cropped.get_frame_texture(clip,0).get_image().get_data(),dirs[d]+" cropped hair differs from swept hair")
	board.save_png(OUTPUT+"wardrobe-native.png")
	board.resize(1024,1024,Image.INTERPOLATE_NEAREST)
	board.save_png(OUTPUT+"wardrobe-review.png")
	for dir in dirs:
		var signatures := {}
		var row := 0
		var sheet := Image.create(512,64*Actions.DURATIONS.size(),false,Image.FORMAT_RGBA8)
		for kind in Actions.DURATIONS:
			var clip: String = kind+"_"+dir
			check(source.get_frame_count(clip)==8,clip+" has eight authored frames")
			check(is_equal_approx(8.0/source.get_animation_speed(clip),Actions.duration(kind)),clip+" preserves real gameplay duration")
			var bytes := PackedByteArray()
			var poses := {}
			var helmet_fit := true
			var hands_free := true
			for f in 8:
				var metadata: Dictionary = skin.pose(clip,f)
				check(metadata.has("hand") and metadata.has("head_rows"),clip+" frame "+str(f)+" has grip and exact head silhouette")
				var raw: Image = source.get_frame_texture(clip,f).get_image()
				bytes.append_array(raw.get_data())
				poses[raw.get_data().hex_encode().sha256_text()] = true
				var armored: Image = dressed.get_frame_texture(clip,f).get_image()
				helmet_fit = helmet_fit and crown_is_attached(armored,metadata,dir)
				var unarmored: Image = basic.get_frame_texture(clip,f).get_image()
				var head_rect := Rect2i(int(metadata.head_origin[0])-2,int(metadata.head_origin[1])-2,18,17)
				for grip in ["hand","offhand"]:
					for dy in 2:
						var point := Vector2i(int(metadata[grip][0]),int(metadata[grip][1])+dy)
						if not head_rect.has_point(point) and raw.get_pixelv(point).a > .95:
							hands_free = hands_free and armored.get_pixelv(point).is_equal_approx(unarmored.get_pixelv(point))
				sheet.blend_rect(armored,Rect2i(0,0,64,64),Vector2i(f*64,row*64))
			check(helmet_fit,clip+" helmet follows all eight head silhouettes")
			check(hands_free,clip+" equipment preserves visible authored hand endpoints")
			check(poses.size()>=3,clip+" contains actual changed anatomy poses")
			var signature := bytes.hex_encode().sha256_text()
			check(not signatures.has(signature),clip+" is distinct from every other action sheet")
			signatures[signature]=true
			row += 1
		var path: String = OUTPUT+"actions-"+dir+"-native.png"
		sheet.save_png(path)
	# Check every legacy and new cel, including idle glances and compressed hurt
	# silhouettes; action-only coverage previously missed the idle-facing bug.
	for clip in source.get_animation_names():
		var fitted := true
		for frame in source.get_frame_count(clip):
			var metadata: Dictionary = skin.pose(clip,frame)
			if metadata.is_empty(): continue
			fitted = fitted and crown_is_attached(dressed.get_frame_texture(clip,frame).get_image(),metadata,str(clip).get_slice("_",str(clip).get_slice_count("_")-1))
		check(fitted,str(clip)+" generated crown follows head origin and facing on every cel")
	var bone_armor := {"head":ItemDB.make("bone_helmet"),"chest":ItemDB.make("bone_chestplate"),"legs":ItemDB.make("bone_leggings")}
	var bone_frames := skin.build(source,bone_armor,null)
	check(bone_frames != dressed and bone_frames.get_frame_texture("idle_down",0).get_image().get_data()!=dressed.get_frame_texture("idle_down",0).get_image().get_data(),"armor IDs distinguish leather and bone with identical occupied slots")
	var mixed := skin.build(source,{"head":bone_armor.head,"chest":armor.chest,"legs":armor.legs},null)
	check(mixed != bone_frames and mixed != dressed,"independent mixed armor slots produce their own cache entry")
	for set_name in ["leather","bone","crystal"]:
		var helmet := {"head":ItemDB.make(set_name+"_helmet")}
		var flax_frames := skin.build(source,helmet,null,{"hair":"flax"})
		var dark_frames := skin.build(source,helmet,null,{"hair":"charcoal"})
		var hidden_hair := true
		for clip in source.get_animation_names():
			for frame in source.get_frame_count(clip):
				hidden_hair = hidden_hair and flax_frames.get_frame_texture(clip,frame).get_image().get_data()==dark_frames.get_frame_texture(clip,frame).get_image().get_data()
		check(hidden_hair,set_name+" helmet fully occludes underlying hair color in every cel")
	var mount_skin = preload("res://Forest/creatures/MountedAppearance.gd").new()
	player.appearance = Appearance.DEFAULTS.duplicate()
	var standard: SpriteFrames = mount_skin.build("stego",player)
	player.appearance = Appearance.normalize({"skin":"umber","hair":"silver","cloth":"river"})
	var customized: SpriteFrames = mount_skin.build("stego",player)
	check(standard != customized and standard.get_frame_texture("idle_side",0).get_image().get_data()!=customized.get_frame_texture("idle_side",0).get_image().get_data(),"mounted rider reflects current saved appearance, with distinct cache entry")
	player.equipped_armor = armor.duplicate()
	var leather_mount: SpriteFrames = mount_skin.build("stego",player)
	player.equipped_armor = bone_armor.duplicate()
	var bone_mount: SpriteFrames = mount_skin.build("stego",player)
	check(leather_mount != bone_mount and leather_mount.get_frame_texture("idle_side",0).get_image().get_data()!=bone_mount.get_frame_texture("idle_side",0).get_image().get_data(),"mounted cache distinguishes actual armor IDs and rendered set")
	player.equipped_armor = {}
	player.animated_sprite.sprite_frames = custom
	player.action_kind = "bow_draw"
	player.action_time = .2
	player.animated_sprite.play("bow_draw_right")
	player.animated_sprite.set_frame_and_progress(4,0)
	clock = Time.get_ticks_usec()
	var bow: SpriteFrames = mount_skin.build("stego",player)
	print("PERF mounted_action_build_ms=",(Time.get_ticks_usec()-clock)/1000.0)
	check(bow.get_frame_texture("idle_side",0).get_image().get_data()!=customized.get_frame_texture("idle_side",0).get_image().get_data(),"mounted aiming uses actual custom hero action pose")
	var tiny := SpriteFrames.new()
	tiny.add_animation("idle_down")
	tiny.add_frame("idle_down",source.get_frame_texture("idle_down",0))
	for skin_option in Appearance.OPTIONS.skin:
		for cloth_option in Appearance.OPTIONS.cloth:
			skin.build(tiny,{},null,{"skin":skin_option.id,"cloth":cloth_option.id})
	check(skin.cache.size()<=12,"skin preview cache is bounded after repeated customization")
	for f in 8:
		player.animated_sprite.set_frame_and_progress(f,0)
		for color in ["moss","clay","ochre","river"]:
			player.appearance.cloth=color
			mount_skin.build("stego",player)
	check(mount_skin._cache.size()<=24,"mounted action cache is bounded across repeated frames and appearances")
	var mount_board := Image.create(96*3,80,false,Image.FORMAT_RGBA8)
	for i in 3: mount_board.blend_rect([standard,customized,bow][i].get_frame_texture("idle_side",0).get_image(),Rect2i(0,0,96,80),Vector2i(i*96,0))
	mount_board.save_png(OUTPUT+"mounted-appearance-native.png")
	mount_board.resize(1152,320,Image.INTERPOLATE_NEAREST)
	mount_board.save_png(OUTPUT+"mounted-appearance-review.png")
	player.queue_free()
	await get_tree().process_frame
	print("CHARACTER_PASS6 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)



func crown_is_attached(image: Image, metadata: Dictionary, fallback_direction: String) -> bool:
	# Independently probe the authored crown center at the live head top. The
	# expected color comes from the PNG, never from the compositor or old palette.
	var direction := str(metadata.get("head_facing",fallback_direction))
	var path := "res://Forest/equipment/art/wardrobe/leather_head_"+direction+".png"
	var art: Image = load(path).get_image()
	var reference_x := 32 if direction in ["left","right"] else 31
	var crown_color := art.get_pixel(reference_x,22)
	var row: Array = metadata.head_rows[0]
	var center := int(round((float(row[0])+float(row[1]))*.5))
	var at := Vector2i(int(metadata.head_origin[0])+center,int(metadata.head_origin[1]))
	return crown_color.a > .95 and image.get_pixelv(at).is_equal_approx(crown_color)
