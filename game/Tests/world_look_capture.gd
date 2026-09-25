extends Node2D
## Rendered look-book of the forest ground (not --headless): the real forest at
## midday with the HUD hidden, at spots that show each ground feature. Writes
## C:/Cravera/art/world-v2/look-*.png (480x270 frames at 2x) and a contact sheet.
const OUT := "C:/Cravera/art/world-v2/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
var scene
var shots: Array = []

func _enter_tree() -> void:
	SaveManager.disable_for_playtest()

func _ready() -> void:
	call_deferred("run")

func grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	shots.append([label, img])
	var big := img.duplicate()
	big.resize(960, 540, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "look-" + label + ".png")

func visit(label: String, at: Vector2) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector2.ZERO
	for i in 20: await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await grab(label)

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
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.5
	scene.hud.visible = false
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.queue_free()
	# A small garden by the camp: a bed of four, two of them watered.
	var soil := {}
	for c in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 4), Vector2i(3, 4)]:
		scene.gardening.plots[c] = {"seed": "", "growth": 0.0, "watered": c.x == 3}
	await get_tree().create_timer(1.2).timeout
	var world = scene.world
	# The darkest moss nearest the camp, and a stretch of sandy shore.
	var moss := Vector2.ZERO
	var sand := Vector2.ZERO
	var best_moss := 1e9
	var best_sand := 1e9
	for c in world.terrain:
		var d: float = Vector2(c).length()
		if world.terrain[c] == 3 and d < best_moss and d > 8:
			best_moss = d
			moss = Vector2(c) * 16
		if world.ground_style.get(c, "") == "sand" and d < best_sand and d > 10:
			best_sand = d
			sand = Vector2(c) * 16
	await visit("camp", Vector2(8, 24))
	await visit("trail", Vector2(-128, -40))
	await visit("ford", Vector2(288, 96))
	await visit("river", Vector2(300, -260))
	await visit("lake", Vector2(-330, 330))
	await visit("shore", sand)
	await visit("moss", moss)
	await visit("tribe-camp", Vector2(512, -300))
	# Every point of interest, the camera just below it.
	for poi in world.pois:
		print("WORLD_LOOK poi %s %s at %s" % [poi.name, poi.kind, poi.cell])
		await visit("poi-" + str(poi.kind), Vector2(poi.cell) * 16 + Vector2(8, 40))
	# Companion pieces that carry a carving of their own.
	for c in world.lore_at:
		var kind: String = world.props[c].kind
		if world.pois.any(func(poi): return poi.cell == c):
			continue
		print("WORLD_LOOK piece %s (%s) at %s" % [kind, world.lore_at[c], c])
		await visit("piece-" + kind, Vector2(c) * 16 + Vector2(8, 40))
	# Long morning shadows: every stone, column and idol casts its own.
	TimeCycle.time_of_day = 0.31
	for poi in world.pois:
		if poi.kind in ["ruin_stones", "ruin_temple", "ruin_hall", "grove_shrine"]:
			await visit("shadow-" + str(poi.kind), Vector2(poi.cell) * 16 + Vector2(8, 40))
	TimeCycle.time_of_day = 0.5
	var rows: int = int(ceil(shots.size() / 3.0))
	var sheet := Image.create(480 * 3 + 8, 274 * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in shots.size():
		var img: Image = shots[i][1]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 480, 270), Vector2i((i % 3) * 484, (i / 3) * 274))
	sheet.save_png(OUT + "look-sheet.png")
	# Frame budget at a busy meadow: uncapped (no vsync either, or this only
	# measures the monitor's refresh rate), after things settle.
	scene.player.global_position = Vector2(-128, -40)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(1.5).timeout
	var frames := 0
	var clock := 0.0
	var draws := 0
	while clock < 3.0:
		await get_tree().process_frame
		clock += get_process_delta_time()
		frames += 1
		draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("WORLD_LOOK fps=%.0f draw_calls=%d flora=%d" % [frames / clock, draws, world.flora.instance_count()])
	print("WORLD_LOOK shots=%d ground_revision=%d" % [shots.size(), world.surface.revision])
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
