extends Node2D
## Rendered in-world review of the dinosaur v2 animations and moves (needs a
## window, not --headless):
##   godot --rendering-method gl_compatibility --resolution 960x540 --path game res://Tests/DinoCapture.tscn -- --no-save-playtest
## Every species in the real forest: resting, walking, running or grazing,
## each attack on a wind-up frame and on its contact frame (with the engine's
## effects: stomp rings, charge lanes, impact sparks), a flinch and the fall.
## Writes C:/Cravera/art/dino-v2/world/dino-sheet.png (+ -2x) and one PNG per cell.

const OUT := "C:/Cravera/art/dino-v2/world/"
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const QuietExit = preload("res://Tests/quiet_exit.gd")
const CW := 150
const CH := 120
const SPECIES := ["rex", "raptor", "stego", "trike", "longneck", "dodo", "allo", "lystro", "alpha"]
var scene
var player
var cells: Array = []   # [label, Image]
var checks := 0
var failures: Array[String] = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("DINO_CAPTURE FAIL ", label)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func grab(label: String, focus: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	var at := Vector2i((get_viewport().get_canvas_transform() * focus).round()) - Vector2i(CW / 2, CH / 2 + 14)
	var rect := Rect2i(at, Vector2i(CW, CH)).intersection(Rect2i(0, 0, 480, 270))
	var cell := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	cell.blit_rect(img, rect, rect.position - at)
	cells.append([label, cell])


## A tamed creature on "stay" never picks its own fights: the test drives it.
func actor(kind: String, at: Vector2):
	var c = scene._spawn_creature(kind, at)
	c.tamed = true
	c.order = "stay"
	c.set_physics_process(false)
	return c


## A sturdy wild dummy to strike at.
func dummy(at: Vector2):
	var d = scene._spawn_creature("raptor", at)
	d.set_physics_process(false)
	d.health = 99999
	d.stats = d.stats.duplicate()
	d.stats.hp = 99999
	d.visible = false
	return d


func step(c, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		c._physics_process(get_physics_process_delta_time())
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	player = scene.player
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.queue_free()
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.43
	await get_tree().create_timer(0.6).timeout
	player.controls_locked = true
	player.position = scene.world.get_spawnable_position(Vector2(40, 30))
	player.visible = false
	var spot: Vector2 = player.global_position
	# The folk step off the stage (Orrin keeps camp right here).
	if scene.get("folk") != null:
		for person in scene.folk.actors.values():
			if is_instance_valid(person): person.visible = false
	# Nothing tall near the stage.
	for prop in scene.world.props.values():
		if prop.global_position.distance_to(spot) < 120.0:
			prop.visible = false
	await frames(10)
	for sp in SPECIES:
		# The last one's loot off the stage first.
		for drop in get_tree().get_nodes_in_group("dropped_items"):
			drop.queue_free()
		await frames(1)
		await species_row(sp, spot)
	build_sheet()
	print("DINO_CAPTURE cells=%d checks=%d failures=%d" % [cells.size(), checks, failures.size()])
	await QuietExit.settle(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func species_row(sp: String, spot: Vector2) -> void:
	var c = actor(sp, spot)
	await frames(2)
	c._face(Vector2.RIGHT, true)
	c._play_clip("idle", true)
	await frames(3)
	await grab(sp + " idle", c.global_position)
	# Walking (and running) as the real driver picks the clip from the speed.
	for clip in ["walk", "run"]:
		if not DinoArt.has_clip(c.art_key, clip):
			continue
		c.velocity = Vector2(float(c.body.walk if clip == "walk" else c.body.run_at + 4.0), 0)
		c._update_animation()
		c._sprite.pause()
		c._sprite.frame = 2
		c.velocity = Vector2.ZERO
		await frames(2)
		check(c._clip == clip, sp + " plays " + clip)
		await grab(sp + " " + clip, c.global_position)
	for clip in ["eat", "sniff", "roar"]:
		if DinoArt.has_clip(c.art_key, clip):
			c._play_clip(clip, true)
			c._sprite.pause()
			c._sprite.frame = int(DinoArt.clip(c.art_key, clip).frames) / 2
			await frames(2)
			await grab(sp + " " + clip, c.global_position)
			break
	# Every move against a dummy: a wind-up frame, then the contact frame. Tail
	# sweeps twice: at a target below the rear (the tail swings toward the
	# viewer) and at one above it (away, behind the body).
	var plays: Array = []
	for m in c.moves.moves():
		plays.append([m, ""])
		if m.shape == "tail":
			plays.append([m, " far"])
	for play in plays:
		var m: Dictionary = play[0]
		var tag: String = str(m.id) + str(play[1])
		c.global_position = spot
		c._face(Vector2.RIGHT, true)
		var gap: float = maxf(4.0, float(m.range[1]) - 6.0)
		if m.kind in ["charge", "pounce"]:
			gap = float(m.range[0]) + 20.0
		var dir := Vector2.RIGHT
		if m.shape == "tail":
			dir = Vector2(-0.8, -0.7 if play[1] != "" else 0.7).normalized()
		var target = dummy(spot + dir * (float(c.stats.radius) + 7.0 + gap))
		await frames(1)
		check(c.moves.start(m, target), "%s %s starts" % [sp, tag])
		if m.shape == "tail":
			check(c.moves.strike_clip == ("tail_swing_far" if play[1] != "" else "tail_swing"), "%s %s plays its side's sweep" % [sp, tag])
		var hit_at := DinoArt.hit_time(c.art_key, c.moves.strike_clip, c.moves._view)
		var lead: float = c.moves._windup_length() if m.kind == "charge" else 0.0
		await step(c, lead + hit_at * 0.55)
		await grab("%s %s wind-up" % [sp, tag], c.global_position)
		var hp: int = target.health
		for i in 90:
			await step(c, get_physics_process_delta_time())
			if target.health < hp:
				break
		check(target.health < hp, "%s %s lands in the world" % [sp, tag])
		await frames(2)
		await grab("%s %s contact" % [sp, tag], c.global_position)
		while c.moves.busy():
			await step(c, get_physics_process_delta_time())
		target.queue_free()
		c._knock = Vector2.ZERO
		c.velocity = Vector2.ZERO
	c.global_position = spot
	c._face(Vector2.RIGHT, true)
	c.take_damage(1, spot + Vector2(-30, 0))
	c._sprite.pause()
	c._sprite.frame = 1
	await frames(2)
	await grab(sp + " hurt", c.global_position)
	c.health = 1
	c.take_damage(5, spot + Vector2(-30, 0))
	c._sprite.pause()
	c._sprite.frame = int(DinoArt.clip(c.art_key, "death").frames) - 1
	await frames(2)
	await grab(sp + " death", c.global_position)
	c.queue_free()
	await frames(2)


func build_sheet() -> void:
	var cols := 9
	var rows := (cells.size() + cols - 1) / cols
	var sheet := Image.create(CW * cols, (CH + 10) * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in cells.size():
		var cell: Image = cells[i][1]
		var x := (i % cols) * CW
		var y := (i / cols) * (CH + 10)
		sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i(x, y + 10))
		cell.save_png(OUT + str(cells[i][0]).replace(" ", "-") + ".png")
	sheet.save_png(OUT + "dino-sheet.png")
	var big := sheet.duplicate()
	big.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "dino-sheet-2x.png")
	var labels := []
	for i in cells.size():
		labels.append("%d:%s" % [i, cells[i][0]])
	print("DINO_CAPTURE cells: ", ", ".join(labels))
