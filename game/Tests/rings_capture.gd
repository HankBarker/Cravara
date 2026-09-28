extends Node2D
## Pass 15: a ring world (a new journey's), rendered: the keeper stood in each
## land in turn. Writes C:/Cravera/art/pass15/rings-<seed>-<land>.png.
##     godot --rendering-method gl_compatibility --resolution 960x540 --path game res://Tests/RingsCapture.tscn -- --no-save-playtest --rings SEED [--depth 0.35]
const OUT := "C:/Cravera/art/pass15/"
var scene
var world
var keeper


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT + label + ".png")
	print("CAPTURED ", label)


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		keeper.current_health = keeper.max_health


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--rings")
	var seed := int(args[at + 1]) if at >= 0 and at + 1 < args.size() else 11
	var depth := 0.35
	var at_d := args.find("--depth")
	if at_d >= 0 and at_d + 1 < args.size(): depth = float(args[at_d + 1])
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.42
	await get_tree().create_timer(1.2).timeout
	world = scene.world
	keeper = scene.player
	for land in ["forest", "glassmere", "dunes", "pale_hills", "bonelands"]:
		var c: Vector2i = world.layout.centre(land, depth if land != "forest" else 0.8)
		var spot: Vector2 = world.get_open_position(Vector2(c) * 16.0 + Vector2(8, 8), 40.0)
		keeper.global_position = spot
		keeper.velocity = Vector2.ZERO
		keeper.get_node("Camera2D").reset_smoothing()
		for creature in get_tree().get_nodes_in_group("forest_creatures"):
			if creature.global_position.distance_to(spot) < 140.0: creature.queue_free()
		scene.hud.visible = false
		await wait(1.0)
		await grab("rings-%d-%s" % [seed, land])
		scene.hud.visible = true
	# The small places and the new ruins.
	var shots := {}
	for name in world.micro_at: shots[name] = world.micro_at[name]
	for poi in world.pois:
		if str(poi.name) in ["The Drowned Hall", "The Sand Temple", "The Bone Shrine", "The Ash Moot"]: shots[str(poi.name).to_lower().replace(" ", "_")] = poi.cell
	for name in shots:
		var look: Vector2 = Vector2(shots[name]) * 16.0 + Vector2(8, 40)
		keeper.global_position = world.get_open_position(look, 12.0)
		keeper.velocity = Vector2.ZERO
		keeper.get_node("Camera2D").reset_smoothing()
		for creature in get_tree().get_nodes_in_group("forest_creatures"):
			if creature.global_position.distance_to(look) < 100.0 and not creature.tamed and bool(creature.stats.predator): creature.queue_free()
		scene.hud.visible = false
		await wait(1.0)
		await grab("rings-%d-%s" % [seed, name])
		scene.hud.visible = true
	# The caves: a mouth outside, then each kind's inside.
	if world.caves:
		var seen := {}
		for cave in world.caves.caves:
			if seen.has(cave.kind): continue
			seen[cave.kind] = true
			if cave.kind == "hollow":
				keeper.global_position = Vector2(cave.out) * 16.0 + Vector2(8, 24)
				keeper.get_node("Camera2D").reset_smoothing()
				scene.hud.visible = false
				await wait(0.8)
				await grab("rings-%d-cave-mouth" % seed)
			scene.cave_travel(cave.mouth, true)
			var inner: Array = world.caves.inner_floor(cave, 10.0)
			if not inner.is_empty():
				var mid := Vector2.ZERO
				for c in inner: mid += Vector2(c)
				mid /= float(inner.size())
				keeper.global_position = world.get_open_position(mid * 16.0, 10.0)
				keeper.get_node("Camera2D").reset_smoothing()
			for creature in get_tree().get_nodes_in_group("forest_creatures"):
				if creature.global_position.distance_to(keeper.global_position) < 300.0: creature.set_physics_process(false)
			scene.hud.visible = false
			await wait(1.0)
			await grab("rings-%d-cave-%s" % [seed, cave.kind])
			scene.hud.visible = true
			scene.cave_travel(cave.exit, false)
			await wait(0.3)
	# The map: the ring world square, its caves marked.
	scene.hud.visible = true
	scene._show_map()
	await wait(0.5)
	await grab("rings-%d-map" % seed)
	scene._close_overlay()
	print("RINGS_CAPTURE done")
	get_tree().quit(0)
