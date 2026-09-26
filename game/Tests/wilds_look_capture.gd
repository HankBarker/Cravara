extends Node2D
## Rendered look at the wilds all round (pass 11, not --headless): Glassmere
## (the shore, the big island, the deep water, the piranha bay), the Pale
## Hills (the old road, the pines, the last Keeper's camp), the Sunscar Dunes
## (cacti and mesas, an oasis, the Ossuary), and the map of it all.
## Writes C:/Cravera/art/pass11/wilds-*.png (960x540).
const OUT := "C:/Cravera/art/pass11/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
var scene
var world


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
	img.save_png(OUT + "wilds-" + label + ".png")


func visit(label: String, at: Vector2, exact := false) -> void:
	scene.player.global_position = at if exact else world.get_spawnable_position(at)
	scene.player.velocity = Vector2.ZERO
	for i in 14: await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await grab(label)


func cell_at(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


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
	TimeCycle.time_of_day = 0.42
	await get_tree().create_timer(1.2).timeout
	world = scene.world
	scene.hud.visible = false
	var gen = preload("res://Forest/world/WildsGen.gd").new(world)
	var lake: Vector2 = gen.lake_centre
	# Glassmere: its eastern shore, and out over the water to the big island.
	await visit("glassmere-shore", cell_at(Vector2i(int(lake.x) + 44, int(lake.y))))
	await visit("glassmere-west", cell_at(Vector2i(-62, 20)))
	var isle := Vector2i(9999, 9999)
	for poi in world.pois:
		if poi.name == "The Fishers' Shrine": isle = poi.cell
	if isle != Vector2i(9999, 9999): await visit("glassmere-isle", cell_at(isle + Vector2i(0, 3)))
	if world.piranha_bay != Vector2i(9999, 9999): await visit("glassmere-bay", cell_at(world.piranha_bay) + Vector2(0, -40), true)
	# The Pale Hills.
	await visit("pale-road", cell_at(Vector2i(-20, int(round(gen.road_y(-20))))))
	await visit("pale-edge", cell_at(Vector2i(10, -62)))
	for poi in world.pois:
		if poi.name == "The Last Keeper's Camp": await visit("pale-camp", cell_at(poi.cell + Vector2i(0, 5)))
	# The Sunscar Dunes.
	await visit("dunes-north", cell_at(Vector2i(-20, 60)))
	await visit("dunes-deep", cell_at(Vector2i(90, 100)))
	if world.ossuary != Vector2i(9999, 9999): await visit("dunes-ossuary", cell_at(world.ossuary + Vector2i(0, 7)))
	scene.hud.visible = true
	scene._show_map()
	await get_tree().create_timer(0.4).timeout
	await grab("map")
	scene._close_overlay()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
