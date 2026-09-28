extends Node2D
const Actions = preload("res://Forest/equipment/ActionFrames.gd")
const Appearance = preload("res://Forest/equipment/Appearance.gd")
const GearSkin = preload("res://Forest/equipment/EquipmentSkin.gd")
const Kit = preload("res://Tests/keeper_test_kit.gd")
const OUTPUT := "res://../art/forest-playtest/v6/"
const SETS := ["moss","leather","bone","crystal","tide","rex"]
## Short gestures; every other tool/action clip has eight frames (contact on 4).
const SIX_FRAME_CLIPS := ["place","interact"]
## A worn helmet still shows a few fringe pixels of the chosen hair colour.
const HAIR_FRINGE := 12
## Minimum helmet pixels on any cel, and the share that must sit on the head.
const HELMET_MIN := 24
const HELMET_ON_HEAD := 0.9
var count := 0
var failures: Array[String] = []
var player
var skin
var helmet_memo := {}
var plain_look: Dictionary = {}
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
	skin = GearSkin.new()
	var armor := {"head":ItemDB.make("leather_helmet"),"chest":ItemDB.make("leather_chestplate"),"legs":ItemDB.make("leather_leggings")}
	var original_hash := source.get_frame_texture("idle_down",0).get_image().get_data().hex_encode().sha256_text()
	var clock := Time.get_ticks_usec()
	var basic: SpriteFrames = skin.build(source,{},null)
	print("PERF default_skin_ms=",(Time.get_ticks_usec()-clock)/1000.0)
	var dressed: SpriteFrames = skin.build(source,armor,null)
	clock = Time.get_ticks_usec()
	var custom: SpriteFrames = skin.build(source,{},null,{"skin":"umber","hair":"silver","hair_style":"tied","cloth":"river","trousers":"slate"})
	print("PERF custom_skin_ms=",(Time.get_ticks_usec()-clock)/1000.0)
	var cropped: SpriteFrames = skin.build(source,{},null,{"hair_style":"cropped"})
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
	# Looks for the grip checks. Fists are found by re-rendering the cel with
	# marker-coloured hands, so bare skin and any glove colour are handled alike.
	var bare_look: Dictionary = skin.look_for({},{})
	var dressed_look: Dictionary = skin.look_for(armor,{})
	var fist_totals := [0,0]
	for dir in dirs:
		var signatures := {}
		var row := 0
		var sheet := Image.create(512,64*Actions.DURATIONS.size(),false,Image.FORMAT_RGBA8)
		for kind in Actions.DURATIONS:
			var clip: String = kind+"_"+dir
			var frames := source.get_frame_count(clip)
			var authored := 6 if kind in SIX_FRAME_CLIPS else 8
			check(frames==authored,clip+" has its %d authored frames (got %d)" % [authored,frames])
			var length := 0.0
			for f in frames: length += source.get_frame_duration(clip,f)
			check(is_equal_approx(length/source.get_animation_speed(clip),Actions.duration(kind)),clip+" preserves real gameplay duration")
			var bytes := PackedByteArray()
			var poses := {}
			var grips := true
			var bare_fists := true
			var upright := 0
			var armored_fists := 0
			for f in frames:
				var metadata: Dictionary = skin.pose(clip,f)
				var raw: Image = source.get_frame_texture(clip,f).get_image()
				bytes.append_array(raw.get_data())
				poses[raw.get_data().hex_encode().sha256_text()] = true
				var armored: Image = dressed.get_frame_texture(clip,f).get_image()
				sheet.blend_rect(armored,Rect2i(0,0,64,64),Vector2i(f*64,row*64))
				if not metadata.has("hand") or not metadata.has("offhand"):
					grips = false
					continue
				var hand := Vector2(metadata.hand[0],metadata.hand[1])
				grips = grips and Rect2(0,0,64,64).has_point(hand) and Rect2(0,0,64,64).has_point(Vector2(metadata.offhand[0],metadata.offhand[1]))
				# The grip anchor must land on the fist the rig drew (tumbling roll
				# cels rotate the render, not the anchor). Bare fists always show;
				# a raised fist may tuck behind a shoulder guard or helmet.
				if Kit.tumbling(kind,dir,f): continue
				upright += 1
				bare_fists = bare_fists and Kit.near(Kit.fist_footprint(skin,kind,dir,f,bare_look,raw),hand)
				if Kit.near(Kit.fist_footprint(skin,kind,dir,f,dressed_look,armored),hand): armored_fists += 1
			check(grips,clip+" every frame has grip anchors inside the cel")
			check(helmet_attached(dressed,clip),clip+" helmet follows the head on every frame")
			check(bare_fists,clip+" grip anchor lands on the drawn bare fist on every upright frame")
			check(armored_fists*2>=upright,clip+" armour keeps the fist visible at the grip anchor (%d/%d frames)" % [armored_fists,upright])
			fist_totals[0] += armored_fists
			fist_totals[1] += upright
			check(poses.size()>=3,clip+" contains actual changed anatomy poses")
			var signature := bytes.hex_encode().sha256_text()
			check(not signatures.has(signature),clip+" is distinct from every other action sheet")
			signatures[signature]=true
			row += 1
		var path: String = OUTPUT+"actions-"+dir+"-native.png"
		sheet.save_png(path)
	check(fist_totals[0]*10>=fist_totals[1]*9,"armoured fists stay visible at their grip anchors on at least 90%% of action frames (%d/%d)" % fist_totals)
	# Check every legacy and new cel, including idle glances, blinks, hurt and
	# the tumbling roll/death cels: the helmet is drawn on the head itself.
	for clip in source.get_animation_names():
		check(helmet_attached(dressed,str(clip)),str(clip)+" helmet sits on the rendered head on every cel")
	var bone_armor := {"head":ItemDB.make("bone_helmet"),"chest":ItemDB.make("bone_chestplate"),"legs":ItemDB.make("bone_leggings")}
	var bone_frames: SpriteFrames = skin.build(source,bone_armor,null)
	check(bone_frames != dressed and bone_frames.get_frame_texture("idle_down",0).get_image().get_data()!=dressed.get_frame_texture("idle_down",0).get_image().get_data(),"armor IDs distinguish leather and bone with identical occupied slots")
	var mixed: SpriteFrames = skin.build(source,{"head":bone_armor.head,"chest":armor.chest,"legs":armor.legs},null)
	check(mixed != bone_frames and mixed != dressed,"independent mixed armor slots produce their own cache entry")
	# Helmets replace the hair: only a few fringe pixels may still show the
	# chosen hair colour, where a bare head shows it on every cel.
	var bare_flax: SpriteFrames = skin.build(source,{},null,{"hair":"flax"})
	var bare_dark: SpriteFrames = skin.build(source,{},null,{"hair":"charcoal"})
	var bare_hair := 9999
	for clip in source.get_animation_names():
		for frame in source.get_frame_count(clip):
			bare_hair = mini(bare_hair,Kit.diff(bare_flax.get_frame_texture(clip,frame).get_image(),bare_dark.get_frame_texture(clip,frame).get_image()))
	check(bare_hair>HAIR_FRINGE*2,"bare heads show the hair colour on every cel (least %d px)" % bare_hair)
	for set_name in SETS:
		var helmet := {"head":ItemDB.make(set_name+"_helmet")}
		var flax_frames: SpriteFrames = skin.build(source,helmet,null,{"hair":"flax"})
		var dark_frames: SpriteFrames = skin.build(source,helmet,null,{"hair":"charcoal"})
		var worst := 0
		for clip in source.get_animation_names():
			for frame in source.get_frame_count(clip):
				worst = maxi(worst,Kit.diff(flax_frames.get_frame_texture(clip,frame).get_image(),dark_frames.get_frame_texture(clip,frame).get_image()))
		check(worst<=HAIR_FRINGE,set_name+" helmet hides the hair colour in every cel (at most %d fringe px, got %d)" % [HAIR_FRINGE,worst])
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


## Every cel of `clip` in the leather-dressed frames carries a helmet
## (>= HELMET_MIN px against the same outfit without one) and that helmet sits
## on the head the rig drew in that cel (glances, blinks and tumbles included).
func helmet_attached(frames: SpriteFrames, clip: String) -> bool:
	if helmet_memo.has(clip): return helmet_memo[clip]
	var bits: Array = skin.split_clip(clip)
	if plain_look.is_empty():
		plain_look = skin.look_for({"chest":ItemDB.make("leather_chestplate"),"legs":ItemDB.make("leather_leggings")},{})
	var ok := frames.get_frame_count(clip) > 0
	for f in frames.get_frame_count(clip):
		var worn: Image = frames.get_frame_texture(clip,f).get_image()
		var plain: Image = skin.render_cel(bits[0],bits[1],f,plain_look)
		var fit: Dictionary = Kit.helmet_fit(skin,bits[0],bits[1],f,worn,plain,plain_look)
		if fit.pixels < HELMET_MIN or fit.inside < HELMET_ON_HEAD:
			print("  helmet off the head: %s[%d] %s" % [clip,f,fit])
			ok = false
	helmet_memo[clip] = ok
	return ok
