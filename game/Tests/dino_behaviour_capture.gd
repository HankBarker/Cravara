extends Node2D
## Rendered review of the dinosaur behaviours in the real forest (window):
##   godot --rendering-method gl_compatibility --resolution 960x540 --path game res://Tests/DinoBehaviourCapture.tscn -- --no-save-playtest
## Four scenes, each a strip of frames 0.4 s apart around an invulnerable
## keeper: a raptor pack circling and darting in, the rex locking on (roar),
## stalking and charging, a stego herd grazing that turns on whoever strikes
## one of them, and a dodo flock scattering from a sprint. Prints what each
## creature was doing so the behaviour can be checked, and writes
## C:/Cravera/art/dino-v2/world/behaviour-<scene>.png.

const OUT := "C:/Cravera/art/dino-v2/world/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
const VIEW := Vector2i(220, 150)
var scene
var player
var checks := 0
var failures: Array[String] = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("BEHAVIOUR PASS " if ok else "BEHAVIOUR FAIL ") + label)
	if not ok:
		failures.append(label)


func shot() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	var at := Vector2i((get_viewport().get_canvas_transform() * player.global_position).round()) - VIEW / 2
	var rect := Rect2i(at, VIEW).intersection(Rect2i(0, 0, 480, 270))
	var cell := Image.create(VIEW.x, VIEW.y, false, Image.FORMAT_RGBA8)
	cell.blit_rect(img, rect, rect.position - at)
	return cell


func strip(name: String, cells: Array) -> void:
	var cols := 6
	var rows := (cells.size() + cols - 1) / cols
	var sheet := Image.create(VIEW.x * cols, VIEW.y * rows, false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, VIEW), Vector2i((i % cols) * VIEW.x, (i / cols) * VIEW.y))
	sheet.save_png(OUT + "behaviour-" + name + ".png")


func spawn(kind: String, offset: Vector2):
	var c = scene._spawn_creature(kind, player.global_position + offset)
	return c


func clear() -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		c.queue_free()
	await get_tree().create_timer(0.2).timeout


## Record states for `seconds`, a frame every 0.4 s.
func watch(seconds: float, actors: Array) -> Array:
	var cells: Array = []
	var log := {}
	var t := 0.0
	while t < seconds:
		await get_tree().create_timer(0.4).timeout
		t += 0.4
		cells.append(await shot())
		for a in actors:
			if is_instance_valid(a):
				var line: Array = log.get(a, [])
				line.append("%s:%s" % [a.state, a._clip])
				log[a] = line
	for a in log:
		print("BEHAVIOUR ", a.species, " ", " ".join(log[a]))
	return [cells, log]


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
	await clear()
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.43
	await get_tree().create_timer(0.6).timeout
	player.controls_locked = true
	player.position = scene.world.get_spawnable_position(Vector2(40, 30))
	# The keeper stands still and cannot be hurt: only the dinosaurs act.
	player.max_health = 99999
	player.current_health = 99999
	var spot: Vector2 = player.global_position
	for prop in scene.world.props.values():
		if prop.global_position.distance_to(spot) < 110.0:
			prop.visible = false

	# 1. Raptor pack.
	var r1 = spawn("raptor", Vector2(-90, -20))
	var r2 = spawn("raptor", Vector2(90, 25))
	# (Pass 13: a fed hunter lets a keeper be; a hungry pack comes for them.)
	r1.sated = 0.0
	r2.sated = 0.0
	var res: Array = await watch(6.0, [r1, r2])
	strip("raptors", res[0])
	var moves := 0
	for a in [r1, r2]:
		for s in res[1].get(a, []):
			if s.begins_with("attack"):
				moves += 1
	check(moves > 0, "the raptor pack attacks the keeper")
	var circled := false
	for s in res[1].get(r1, []) + res[1].get(r2, []):
		if s.begins_with("hunt:run") or s.begins_with("hunt:walk"):
			circled = true
	check(circled, "raptors move around between attacks")
	await clear()

	# 2. The rex.
	player.global_position = spot
	var rex = spawn("rex", Vector2(130, 0))
	res = await watch(6.0, [rex])
	strip("rex", res[0])
	var lines: Array = res[1].get(rex, [])
	check(lines.any(func(s): return s.ends_with(":roar")), "the rex roars when it locks on")
	check(lines.any(func(s): return s.begins_with("attack")), "the rex attacks (charge or bite)")
	await clear()

	# 3. A stego herd grazing; a blow turns the herd.
	player.global_position = spot
	var herd := [spawn("stego", Vector2(-70, -30)), spawn("stego", Vector2(-40, 40)), spawn("stego", Vector2(-100, 30))]
	res = await watch(4.0, herd)
	var grazed := false
	for a in herd:
		for s in res[1].get(a, []):
			if s.ends_with(":eat"):
				grazed = true
	check(grazed, "the herd grazes while left alone")
	herd[0].take_damage(1, player)
	var res2: Array = await watch(5.0, herd)
	strip("herd", res[0] + res2[0])
	var defended := 0
	for a in herd.slice(1):
		if is_instance_valid(a) and a._threat == player:
			defended += 1
	check(defended == 2, "the whole herd turns on the keeper who struck one of them")
	await clear()

	# 4. Dodos scatter from a sprint.
	player.global_position = spot
	var flock := [spawn("dodo", Vector2(30, 0)), spawn("dodo", Vector2(40, 16)), spawn("dodo", Vector2(46, -12))]
	var start := {}
	for d in flock:
		start[d] = d.global_position.distance_to(player.global_position)
	player.velocity = Vector2(125, 0)
	res = await watch(2.4, flock)
	player.velocity = Vector2.ZERO
	strip("dodos", res[0])
	var fled := 0
	for d in flock:
		if is_instance_valid(d) and d.global_position.distance_to(player.global_position) > start[d] + 20.0:
			fled += 1
	check(fled >= 2, "a rushing keeper scatters the dodo flock (%d fled)" % fled)
	print("DINO_BEHAVIOUR checks=%d failures=%d" % [checks, failures.size()])
	await QuietExit.settle(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)
