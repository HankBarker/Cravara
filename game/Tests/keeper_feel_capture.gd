extends Node2D
## Rendered game-feel review of the forest Keeper (needs a window, not --headless):
##   godot --rendering-method gl_compatibility --resolution 960x540 --max-fps 60 --path game res://Tests/KeeperFeelCapture.tscn -- --no-save-playtest
## Drives the real FSM and input routing (Input actions, pushed key/mouse
## events) through: acceleration and braking, footstep dust on dirt and grass,
## sprinting into water (splash, waterline, wading steps), the dodge roll (and
## the HUD focus fix), a skid, dagger and axe hits on a creature (spark,
## hitstop, camera kick), getting hurt (white flash, facing, shake decay) and
## the gesture clips. Writes C:/Cravera/art/keeper-v2/feel/*.png (full frames
## plus a 3x contact sheet) and prints FEEL lines with the measured numbers.

const OUT := "C:/Cravera/art/keeper-v2/feel/"
const CW := 104
const CH := 76
const COLS := 6
var scene
var player
var camera: Camera2D
var sheet: Image
var cells := 0
var checks := 0
var failures: Array[String] = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("FEEL PASS " if ok else "FEEL FAIL ") + message)
	if not ok:
		failures.append(message)


func note(message: String) -> void:
	print("FEEL " + message)


func physics(frames := 1) -> void:
	for i in frames:
		await get_tree().physics_frame


func shot(label: String, full := false) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	if full:
		img.save_png(OUT + label + ".png")
	var centre: Vector2i = Vector2i(get_viewport().get_canvas_transform() * player.global_position) + Vector2i(0, 2)
	var rect := Rect2i(centre - Vector2i(CW / 2, CH / 2), Vector2i(CW, CH)).intersection(Rect2i(0, 0, 480, 270))
	var crop := img.get_region(rect)
	var x := (cells % COLS) * CW
	var y := (cells / COLS) * CH
	if y + CH <= sheet.get_height():
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(x, y))
		cells += 1


func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	get_viewport().push_input(event, true)


func tap(code: int) -> void:
	key(code, true)
	await get_tree().process_frame
	key(code, false)
	await get_tree().process_frame


func mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	get_viewport().push_input(event, true)
	for i in 3:
		await get_tree().process_frame


func aim_at(world_position: Vector2) -> void:
	for attempt in 4:
		var pos: Vector2 = get_viewport().get_canvas_transform() * world_position
		get_viewport().warp_mouse(pos)
		var event := InputEventMouseMotion.new()
		event.position = pos
		event.global_position = pos
		get_viewport().push_input(event, true)
		await get_tree().process_frame
		if scene.get_global_mouse_position().distance_to(world_position) < 2.0:
			return


func release_all() -> void:
	for action in ["Up", "Down", "Left", "Right", "Sprint"]:
		Input.action_release(action)


func place(at: Vector2) -> void:
	release_all()
	player.velocity = Vector2.ZERO
	player.knockback_velocity = Vector2.ZERO
	player.global_position = at
	player.switch_state("idle")
	await physics(3)


## A clear stretch of ground `span` cells wide to the right of `cell` (and
## `south` rows below it, where a tree's canopy would hide the Keeper).
func clear_row(cell: Vector2i, span: int, south := 1) -> bool:
	for dx in span:
		for dy in range(-1, south + 1):
			var c := cell + Vector2i(dx, dy)
			if scene.world.props.has(c) or scene.world.water.has(c):
				return false
	return true


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	GameSettings.screen_shake = true
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	player = scene.player
	camera = player.get_node("Camera2D")
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.queue_free()
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.43
	await get_tree().create_timer(0.6).timeout
	if player.has_method("finish_skin"):
		player.finish_skin()
	sheet = Image.create(CW * COLS, CH * 9, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("10201d"))
	await dust_palette()
	await test_acceleration()
	await test_footsteps()
	await test_water()
	await test_roll()
	await test_skid()
	await test_combat()
	await test_hurt()
	await test_gestures()
	sheet.save_png(OUT + "keeper-feel-sheet.png")
	var big := sheet.duplicate()
	big.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "keeper-feel-sheet-3x.png")
	release_all()
	print("KEEPER_FEEL_CAPTURE cells=%d checks=%d failures=%d" % [cells, checks, failures.size()])
	for failure in failures:
		print("  - " + failure)
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


## Reference frame: walk-strength and run-strength puffs on dirt, grass, wood.
func dust_palette() -> void:
	await place(Vector2(-40, 8))
	var Puff = preload("res://Forest/fx/Puff.gd")
	var Surface = preload("res://Forest/fx/Surface.gd")
	var i := 0
	for surface in ["dirt", "grass", "wood"]:
		for strength in [0.85, 1.25]:
			var puff = Puff.new()
			puff.dust(Vector2.ZERO, Vector2.RIGHT, Surface.dust(surface), 1 if strength < 1 else 2, 3, strength)
			puff.spawn(scene.world, player.global_position + Vector2(-60 + i * 22, 30), -10.0)
			i += 1
	await physics(5)
	await shot("dust-palette", true)
	await physics(20)


# ---------------------------------------------------------------- movement
func test_acceleration() -> void:
	await place(Vector2(-40, 8))
	var speeds: Array[float] = []
	Input.action_press("Right")
	for i in 10:
		await physics()
		speeds.append(snappedf(player.velocity.x, 0.1))
	note("walk start velocity.x per physics frame: %s" % str(speeds))
	check(player.state == "walk" and is_equal_approx(player.velocity.x, 76.0), "walk reaches exactly walk_speed 76 (accelerated, not snapped)")
	check(speeds[0] < 76.0, "first walking frame is below full speed (acceleration)")
	check(camera.offset == Vector2.ZERO and camera.position == Vector2.ZERO, "camera stays locked while moving")
	Input.action_release("Right")
	speeds.clear()
	var start_x: float = player.global_position.x
	for i in 6:
		await physics()
		speeds.append(snappedf(player.velocity.x, 0.1))
	note("walk stop velocity.x per physics frame: %s  slide %.1f px" % [str(speeds), player.global_position.x - start_x])
	check(player.velocity == Vector2.ZERO and player.state == "idle", "walk brakes to a full stop within 6 frames")
	check(camera.offset == Vector2.ZERO, "camera offset exactly zero while idle")
	# Sprint to full speed, then hysteresis on diagonals.
	Input.action_press("Right")
	Input.action_press("Sprint")
	for i in 12:
		await physics()
	check(is_equal_approx(player.velocity.length(), 125.0), "sprint reaches exactly sprint_speed 125")
	Input.action_press("Down")
	await physics(3)
	check(player.last_facing == "right", "adding Down to a rightward run keeps the right-facing view (hysteresis)")
	Input.action_release("Right")
	await physics(2)
	check(player.last_facing == "down", "releasing Right turns to face down")
	Input.action_press("Right")
	await physics(3)
	check(player.last_facing == "down", "adding Right to a downward run keeps the down-facing view")
	release_all()
	await physics(8)


## Walk for `frames` physics frames, snapping each footfall's dust at its
## fullest (a few frames after the foot lands); the first one is saved whole.
func capture_steps(label: String, frames: int) -> void:
	var seen: int = player.feel.steps
	var due := -1
	var taken := 0
	for i in frames:
		await physics()
		if player.feel.steps != seen:
			seen = player.feel.steps
			due = i + 5
		if i == due:
			await shot("%s-%d" % [label, taken], taken == 0)
			taken += 1


func test_footsteps() -> void:
	# Dirt: the camp path around the origin.
	var dirt_start := Vector2(-56, 8)
	await place(dirt_start)
	var steps_before: int = player.feel.steps
	Input.action_press("Right")
	await capture_steps("walk-dirt", 44)
	release_all()
	note("dirt walk: %d footfalls in 44 frames, last surface %s" % [player.feel.steps - steps_before, player.feel.last_surface])
	check(player.feel.steps - steps_before >= 2 and player.feel.last_surface == "dirt", "walking the camp path lands dirt footfalls")
	# Grass: find a clear meadow row.
	var grass_cell := Vector2i(-20, -12)
	for y in range(-14, 14):
		for x in range(-30, -6):
			var c := Vector2i(x, y)
			if scene.world.terrain.get(c, -1) == 0 and clear_row(c, 8):
				grass_cell = c
				break
		if scene.world.terrain.get(grass_cell, -1) == 0 and clear_row(grass_cell, 8):
			break
	await place(Vector2(grass_cell * 16) + Vector2(8, 0))
	check(player.feel != null and not player.feel.feet_in_water, "feel component attached, dry on grass")
	steps_before = player.feel.steps
	Input.action_press("Right")
	Input.action_press("Sprint")
	await capture_steps("run-grass", 40)
	release_all()
	note("grass run: %d footfalls in 40 frames, last surface %s" % [player.feel.steps - steps_before, player.feel.last_surface])
	check(player.feel.steps - steps_before >= 2 and player.feel.last_surface in ["grass", "moss"], "running the meadow lands grass footfalls")
	await physics(10)
	# Timber floor: lay a short boardwalk and walk it.
	var floor_cell := Vector2i(-3, 2)
	for dx in 8:
		scene.world._spawn_floor(floor_cell + Vector2i(dx, 0))
	await place(Vector2(floor_cell * 16) + Vector2(8, 0))
	check(preload("res://Forest/fx/Surface.gd").at(scene.world, scene, player.global_position + Vector2(0, 8)) == "wood", "timber floor reads as a wooden surface")
	steps_before = player.feel.steps
	Input.action_press("Right")
	await capture_steps("walk-wood", 40)
	release_all()
	check(player.feel.steps > steps_before and player.feel.last_surface == "wood", "boardwalk footfalls read as wood")
	for dx in 8:
		scene.world._remove_floor(floor_cell + Vector2i(dx, 0))
	await physics(10)


func test_water() -> void:
	# A bank with dry run-up to the west of the river.
	var bank := Vector2i.ZERO
	var found := false
	for y in range(-45, 45):
		for x in range(-50, 50):
			var c := Vector2i(x, y)
			if scene.world.water.has(c) and scene.world.water.has(c + Vector2i(1, 0)) and scene.world.water.has(c + Vector2i(2, 0)) and clear_row(c - Vector2i(5, 0), 5):
				bank = c
				found = true
				break
		if found:
			break
	check(found, "found a clear river bank for the wading check")
	if not found:
		return
	# Clear the scenery around the ford so no canopy hides the Keeper.
	for dy in range(-3, 6):
		for dx in range(-7, 5):
			if scene.world.props.has(bank + Vector2i(dx, dy)):
				scene.world._remove_prop(bank + Vector2i(dx, dy))
	await place(Vector2((bank - Vector2i(5, 0)) * 16) + Vector2(8, 0))
	Input.action_press("Right")
	Input.action_press("Sprint")
	var entered := -1
	for i in 70:
		await physics()
		if entered < 0 and player.feel.feet_in_water:
			entered = i
			await shot("water-entry-splash", true)

		elif entered >= 0 and i - entered in [4, 9, 16, 24]:
			await shot("water-wade-%02d" % (i - entered), i - entered == 16)
		if entered >= 0 and i - entered > 26:
			break
	check(entered >= 0, "feet (sampled at +8) register entering water")
	check(player.in_water and player.walk_speed == 40 and player.sprint_speed == 52, "wading speeds unchanged (walk 40 / sprint 52)")
	note("wading velocity %.1f px/s (sprint_speed %d)" % [player.velocity.length(), player.sprint_speed])
	release_all()
	await physics(20)
	await shot("water-standing", true)
	var material: ShaderMaterial = player.animated_sprite.material
	check(material != null and float(material.get_shader_parameter("waterline")) < 20.0, "waterline shader active while wading")
	# Roll through the shallows.
	Input.action_press("Left")
	await physics(2)
	await tap(KEY_SPACE)
	await physics(4)
	await shot("water-roll", true)
	release_all()
	await physics(30)
	# Walk back out.
	Input.action_press("Left")
	var left_at := -1
	for i in 90:
		await physics()
		if left_at < 0 and not player.feel.feet_in_water:
			left_at = i
			await physics(3)
			await shot("water-exit-splash")
			break
	release_all()
	check(left_at >= 0 and float(material.get_shader_parameter("waterline")) > 100.0, "leaving water clears the waterline")
	await physics(10)


func test_roll() -> void:
	await place(Vector2(-56, 8))
	# HUD focus: click the Satchel charm twice (open, close); Space must then
	# roll instead of pressing the charm again.
	var charm: Control = scene.hud.shortcut_buttons[0]
	var centre := charm.get_global_rect().get_center()
	await mouse(centre, true)
	await mouse(centre, false)
	check(scene.hud.is_open(), "Satchel charm click opens the satchel")
	await mouse(centre, true)
	await mouse(centre, false)
	check(not scene.hud.is_open(), "second charm click closes it")
	check(get_viewport().gui_get_focus_owner() == null, "HUD charm keeps no keyboard focus after a click")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_press("Right")
	await physics(8)
	var start: Vector2 = player.global_position
	key(KEY_SPACE, true)
	await physics()
	key(KEY_SPACE, false)
	check(not scene.hud.is_open(), "Space does not re-press the Satchel charm")
	check(player.state == "roll", "Space starts a dodge roll")
	check(player.roll_invulnerable, "roll grants i-frames from its first frame")
	var hp: int = player.current_health
	player.take_damage(10, null)
	check(player.current_health == hp, "a hit during the roll's i-frames is ignored")
	var frames := 0
	while player.state == "roll" and frames < 40:
		if frames in [1, 4, 8, 12, 16, 21]:
			await shot("roll-%02d" % frames, frames in [4, 12])
		await physics()
		frames += 1
	var travelled: float = player.global_position.distance_to(start)
	note("roll lasted %d physics frames and travelled %.1f px" % [frames, travelled])
	check(frames >= 22 and frames <= 27, "roll lasts ~0.4 s")
	check(not player.roll_invulnerable and player.state == "walk", "roll ends vulnerable, straight back into walking")
	key(KEY_SPACE, true)
	await physics()
	key(KEY_SPACE, false)
	check(player.state != "roll", "cooldown refuses an immediate second roll")
	# ~0.12 s of cooldown left: the press is buffered and fires when it ends.
	await physics(13)
	key(KEY_SPACE, true)
	await physics()
	key(KEY_SPACE, false)
	check(player.state != "roll", "still cooling down")
	await physics(8)
	check(player.state == "roll", "a press late in the cooldown is buffered into a roll")
	while player.state == "roll":
		await physics()
	release_all()
	await physics(30)
	# Refusals: mounted-like states are covered by can_roll(); check locked and acting.
	scene.hud.open_panels()
	await get_tree().process_frame
	await tap(KEY_SPACE)
	await physics(2)
	check(player.controls_locked and player.state != "roll", "no roll while the satchel is open (controls locked)")
	scene.hud.close_panels()
	await get_tree().process_frame
	await physics(12)
	player.play_action("pickup", player.global_position + Vector2(0, 16))
	player.request_roll()
	await physics(2)
	check(player.state != "roll", "no roll during play_action")
	player.stop_action()
	await physics(12)


func test_skid() -> void:
	await place(Vector2(-72, 8))
	Input.action_press("Right")
	Input.action_press("Sprint")
	await physics(16)
	Input.action_release("Right")
	Input.action_press("Left")
	await physics(3)
	await shot("skid", true)
	release_all()
	await physics(12)


# ---------------------------------------------------------------- combat
func test_combat() -> void:
	await place(Vector2(-48, 8))
	var target = scene._spawn_creature("trike", player.global_position + Vector2(24, 0))
	target.set_physics_process(false)
	await physics(2)
	for entry in [[2, "bone_dagger"], [0, "basic_axe"]]:
		InventoryManager.selected_slot_index = entry[0]
		InventoryManager.inventory_changed.emit()
		await aim_at(target.global_position)
		var hp: int = target.health
		player.switch_state("attack")
		check(player.state == "attack", "%s swing starts" % entry[1])
		var hit_frame := -1
		var min_scale := 1.0
		var kicked := false
		for i in 50:
			await get_tree().process_frame
			min_scale = minf(min_scale, Engine.time_scale)
			kicked = kicked or camera.offset != Vector2.ZERO
			if hit_frame < 0 and target.health < hp:
				hit_frame = i
				await shot("hit-%s-contact" % entry[1], true)
				await get_tree().process_frame
				await shot("hit-%s-after" % entry[1])
			if player.state != "attack" and hit_frame >= 0:
				break
		check(hit_frame >= 0, "%s swing damages the creature" % entry[1])
		check(min_scale < 0.2, "%s hit triggers hitstop (time_scale dipped to %.2f)" % [entry[1], min_scale])
		if entry[1] == "basic_axe":
			check(kicked, "heavy axe hit kicks the camera")
		await get_tree().create_timer(0.8).timeout
		check(is_equal_approx(Engine.time_scale, 1.0), "time scale restored after hitstop")
		check(camera.offset == Vector2.ZERO, "camera shake decays back to exactly zero")
	target.queue_free()
	await physics(4)


func test_hurt() -> void:
	await place(Vector2(-48, 8))
	player.last_facing = "left"
	player.animated_sprite.play("idle_left")
	var raptor = scene._spawn_creature("raptor", player.global_position + Vector2(26, 2))
	raptor.set_physics_process(false)
	player.is_invulnerable = false
	await physics(2)
	player.take_damage(12, raptor)
	check(player.state == "hurt" and player.last_facing == "right", "hurt turns to face the attacker")
	check(player.animated_sprite.modulate.a < 0.6, "i-frame blink semantics kept (modulate.a < 0.6 while flashing)")
	await shot("hurt-flash", true)
	var material: ShaderMaterial = player.animated_sprite.material
	check(material != null and float(material.get_shader_parameter("flash")) > 0.5, "white flash is up on the hit")
	var peak := Vector2.ZERO
	for i in 20:
		await get_tree().process_frame
		if camera.offset.length() > peak.length():
			peak = camera.offset
		if i == 5:
			await shot("hurt-recoil")
	note("hurt camera peak offset %s" % str(peak))
	check(peak != Vector2.ZERO, "hurt shakes the camera")
	await get_tree().create_timer(1.2).timeout
	check(camera.offset == Vector2.ZERO and float(material.get_shader_parameter("flash")) == 0.0, "shake and flash fully decay")
	GameSettings.set_screen_shake(false)
	player.is_invulnerable = false
	player.take_damage(5, raptor)
	var any := false
	for i in 10:
		await get_tree().process_frame
		any = any or camera.offset != Vector2.ZERO
	check(not any, "screen shake setting off: no camera offset")
	GameSettings.set_screen_shake(true)
	raptor.queue_free()
	player.current_health = player.max_health
	await get_tree().create_timer(0.8).timeout


# ---------------------------------------------------------------- gestures
func test_gestures() -> void:
	await place(Vector2(-40, 8))
	player.current_hunger = 40
	player._meal_cooldown = 0
	check(player.eat(ItemDB.make("berry")), "eating still succeeds synchronously")
	check(str(player.animated_sprite.animation).begins_with("eat_") and player.action_time == 0.0, "eat plays its clip without an action lock")
	await get_tree().create_timer(0.3).timeout
	await shot("gesture-eat", true)
	Input.action_press("Right")
	await physics(3)
	check(player.state == "walk" and str(player.animated_sprite.animation).begins_with("walk_"), "walking cancels a gesture at once")
	release_all()
	await physics(12)
	for entry in [["craft", Vector2(0, -20), 0.3], ["place", Vector2(20, 0), 0.18], ["interact", Vector2(0, 20), 0.15], ["cheer", Vector2.INF, 0.34]]:
		var target: Vector2 = Vector2.INF if entry[1] == Vector2.INF else player.global_position + entry[1]
		check(player.play_gesture(entry[0], target), "%s gesture plays" % entry[0])
		await get_tree().create_timer(entry[2]).timeout
		await shot("gesture-" + entry[0], true)
		await get_tree().create_timer(0.9).timeout
		check(str(player.animated_sprite.animation).begins_with("idle_"), "%s returns to idle" % entry[0])
	Input.action_press("Right")
	await physics(4)
	check(not player.play_gesture("eat"), "no gesture while walking")
	release_all()
	await physics(10)
