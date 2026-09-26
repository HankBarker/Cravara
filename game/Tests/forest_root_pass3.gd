extends Node2D
const SAVE_PATH := "user://forest_root_pass3_test.json"
const Kit = preload("res://Tests/keeper_test_kit.gd")
var count := 0
var failures: Array[String] = []
var scene
var player
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func check(ok: bool,message: String):
	count += 1
	if not ok:
		failures.append(message)
		push_error(message)
func key(code: int):
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	get_viewport().push_input(e,true)
	e = e.duplicate()
	e.pressed = false
	get_viewport().push_input(e,true)
func reset_health(hp: int,hunger: int):
	player.current_health = hp
	player.current_hunger = hunger
	player._regen_accum = 0
	player._food_healing.clear()
	player._meal_cooldown = 0
	player.food_satiation_left = 0
func in_view(control: Control) -> bool:
	var r := control.get_global_rect()
	return r.position.x >= 0 and r.position.y >= 0 and r.end.x <= 480 and r.end.y <= 270
func run():
	check("--no-save-playtest" in OS.get_cmdline_user_args(),"regression run disables user-save writes")
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	get_viewport().content_scale_size = Vector2i(480,270)
	var defaults = preload("res://Autoloads/GameSettings.gd").new()
	check(defaults.camera_follow_mode == "tight","fresh settings default to tight follow")
	defaults.free()
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	player = scene.player
	for c in get_tree().get_nodes_in_group("forest_creatures"): c.queue_free()
	await get_tree().process_frame
	for x in range(-6,7):
		for y in range(-5,6):
			var cell := Vector2i(x,y)
			if scene.world.props.has(cell): scene.world._remove_prop(cell)
	player.position = Vector2.ZERO
	var camera: Camera2D = player.get_node("Camera2D")
	check(not camera.position_smoothing_enabled and camera.offset == Vector2.ZERO,"tight camera has no smoothing or lookahead")
	Input.action_press("Right")
	for i in 12: await get_tree().physics_frame
	Input.action_release("Right")
	check(player.position.x > 0 and camera.position == Vector2.ZERO and camera.offset == Vector2.ZERO,"camera stays directly attached during actual movement")
	GameSettings.set_camera_follow("smooth")
	check(camera.position_smoothing_enabled,"smooth camera option takes effect live")
	GameSettings.set_camera_follow("tight")
	player.set_physics_process(false)
	scene.set_process(false)
	reset_health(50,50)
	player._tick_recovery(10)
	check(player.current_health == 56,"fed passive recovery restores 0.6 health per second")
	reset_health(50,0)
	player._tick_recovery(10)
	check(player.current_health == 50,"empty hunger blocks passive regeneration")
	reset_health(50,50)
	check(player.eat(ItemDB.make("berry")),"berry can be eaten")
	check(player.current_health == 50 and player._food_healing.size() == 1,"berry healing begins as a timed effect, not instant health")
	player._tick_recovery(5)
	check(player.current_health == 55 and player._food_healing.size() == 1,"berry heals gradually alongside normal recovery")
	player._tick_recovery(5)
	check(player.current_health == 61 and player._food_healing.is_empty(),"berry totals five food healing over ten seconds and expires")
	reset_health(30,50)
	player.eat(ItemDB.make("cooked_meat"))
	player._tick_recovery(15)
	check(player.current_health == 54 and player._food_healing.size() == 1,"cooked food heals gradually at its own rate")
	player._tick_recovery(15)
	check(player.current_health == 78 and player._food_healing.is_empty(),"cooked meal totals thirty timed healing and expires")
	reset_health(99,80)
	player.eat(ItemDB.make("cooked_meat"))
	player._tick_recovery(5)
	check(player.current_health == player.max_health,"food cannot exceed maximum health")
	reset_health(50,50)
	player.eat(ItemDB.make("berry"))
	player.current_hunger = 0
	player._tick_recovery(10)
	check(player.current_health == 50 and player._food_healing.is_empty(),"food regeneration stops at zero hunger and effect still expires")
	reset_health(50,80)
	player.current_stamina = 20
	scene.hud.open_panels()
	scene._process(0.01)
	var hunger_before: int = player.current_hunger
	player.food_satiation_left = 0
	player._hunger_accum = 0
	player._physics_process(90)
	# (Pass 14: no breath, so no stamina to recover.)
	check(player.controls_locked and player.current_hunger < hunger_before and player.current_health > 50,"inventory panel blocks movement while gentle hunger and recovery continue")
	scene.hud.close_panels()
	player.controls_locked = false

	# Source-frame integrity and frame-locked headwear across running and attacks.
	var source: SpriteFrames = player._base_frames
	var original: Dictionary = {}
	for animation in source.get_animation_names():
		for i in source.get_frame_count(animation):
			original[str(animation)+str(i)] = source.get_frame_texture(animation,i).get_image().get_data()
	player.animated_sprite.play("run_right")
	player.animated_sprite.set_frame_and_progress(3,0.42)
	player._set_equipment("head",ItemDB.make("leather_helmet"))
	player._set_equipment("chest",ItemDB.make("leather_chestplate"))
	player._set_equipment("legs",ItemDB.make("leather_leggings"))
	player._set_equipment("light",ItemDB.make("lantern"))
	player.finish_skin()
	var worn: SpriteFrames = player.animated_sprite.sprite_frames
	# The same outfit without the helmet: diffing it against the worn cels
	# isolates the helmet pixels of every frame.
	var skin = player._skin
	var no_helmet: Dictionary = skin.look_for({"chest":player.get_equipment("chest"),"legs":player.get_equipment("legs")},player.appearance,player.equipped_light)
	check(player.animated_sprite.animation == "run_right" and player.animated_sprite.frame == 3 and is_equal_approx(player.animated_sprite.frame_progress,0.42),"changing gear preserves current animation frame and progress")
	var unchanged := true
	var timings := true
	for animation in source.get_animation_names():
		if source.get_frame_count(animation) != worn.get_frame_count(animation) or source.get_animation_speed(animation) != worn.get_animation_speed(animation) or source.get_animation_loop(animation) != worn.get_animation_loop(animation): timings = false
		for i in source.get_frame_count(animation):
			if source.get_frame_texture(animation,i).get_image().get_data() != original[str(animation)+str(i)]: unchanged = false
			if source.get_frame_duration(animation,i) != worn.get_frame_duration(animation,i): timings = false
	check(unchanged,"equipment compositor leaves every original source frame byte-for-byte unchanged")
	check(timings,"equipment compositor preserves all frame counts, durations, speeds and loops")
	var sheet := Image.create(512,1024,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("18332e"))
	var row := 0
	var varying_heads := false
	for facing in ["down","left","right","up"]:
		for motion in ["run","pickaxe"]:
			var animation: String = motion+"_"+facing
			var previous_head: Array = []
			var changed_pixels := true
			var cap_tracks := true
			for i in source.get_frame_count(animation):
				var base: Image = source.get_frame_texture(animation,i).get_image()
				var dressed: Image = worn.get_frame_texture(animation,i).get_image()
				if base.get_data() == dressed.get_data(): changed_pixels = false
				var head: Array = player._skin.pose(animation,i).head
				if not previous_head.is_empty() and head != previous_head: varying_heads = true
				previous_head = head
				# The helmet is drawn on the head the rig drew in this very frame.
				var plain: Image = skin.render_cel(motion,facing,i,no_helmet)
				var fit: Dictionary = Kit.helmet_fit(skin,motion,facing,i,dressed,plain,no_helmet)
				if fit.pixels < 24 or fit.inside < 0.9:
					cap_tracks = false
					print("helmet off head ",animation," ",i," ",fit)
				sheet.blend_rect(base,Rect2i(0,0,64,64),Vector2i(i*64,row*64))
				sheet.blend_rect(dressed,Rect2i(0,0,64,64),Vector2i(i*64,(row+1)*64))
			check(changed_pixels,motion+" "+facing+" renders visible equipment in every frame")
			check(cap_tracks,motion+" "+facing+" helmet follows the per-frame head (drawn on the rendered head)")
			row += 2
	check(varying_heads,"motion test exercises actual changing head anchors")
	DirAccess.make_dir_recursive_absolute("res://../art/forest-playtest/v3")
	check(sheet.save_png("res://../art/forest-playtest/v3/equipment-motion-native.png") == OK,"exports native-resolution base/worn motion comparison")

	# Root routing, selected satchel page persistence, and equipment effects.
	var stego = load("res://Forest/creatures/ForestCreature.gd").new()
	stego.species = "stego"
	stego.tamed = true
	stego.saddle = ItemDB.make("stego_saddle")
	stego.position = player.position
	scene.add_child(stego)
	stego.set_order("stay")
	check(stego.mount(player),"root integration companion mounts")
	key(KEY_E)
	await get_tree().process_frame
	check(not stego.is_mounted() and player.mounted_creature == null,"actual root E input dismounts active mount")
	for selected in [3,19,34]:
		InventoryManager.selected_slot_index = selected
		InventoryManager.hotbar_start = (selected/8)*8
		check(scene.save_journey(SAVE_PATH),"selected page journey saves")
		InventoryManager.selected_slot_index = 0
		InventoryManager.hotbar_start = 0
		check(scene._load_journey(SAVE_PATH),"selected page journey reloads")
		check(InventoryManager.selected_slot_index == selected and InventoryManager.hotbar_start == (selected/8)*8,"selected slot and visible hotbar page restored for slot %d" % selected)
		await get_tree().process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	scene._show_pause()
	await get_tree().process_frame
	await get_tree().process_frame
	check(in_view(scene._panel),"pause panel fits native 480x270 viewport")
	scene._close_overlay()
	scene._show_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	var settings = scene._overlay.get_children().filter(func(n): return n.get_script() == preload("res://UI/SettingsPanel.gd"))
	if settings.is_empty(): settings = scene.get_children().filter(func(n):return n.get_script() == preload("res://UI/SettingsPanel.gd"))
	check(not settings.is_empty(),"pause creates shared settings panel")
	if not settings.is_empty():
		var box = settings[0]
		check(in_view(box.panel),"settings panel fits native viewport")
		var contained := true
		for child in box.panel.get_children():
			if child is Control and not in_view(child): contained = false
		check(contained,"settings labels and controls fit native viewport")
		box._close(false)
	scene._close_overlay()
	scene.queue_free()
	await get_tree().process_frame
	var menu = preload("res://Forest/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	check(in_view(menu._buttons),"title menu buttons fit native viewport with settings entry")
	menu.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	await get_tree().create_timer(0.2).timeout
	print("FOREST_ROOT_PASS3 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
