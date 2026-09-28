extends Node2D
## Rendered look at the Bonelands (not --headless): where the forest opens
## onto them, the dry wash, a waterhole, deep in the badlands, and the map of
## the whole world. Writes C:/Cravera/art/world-v2/bonelands-*.png (960x540).
const OUT := "C:/Cravera/art/world-v2/"
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
	img.save_png(OUT + "bonelands-" + label + ".png")


func visit(label: String, cell: Vector2i) -> void:
	scene.player.global_position = world.get_spawnable_position(Vector2(cell * 16) + Vector2(8, 8))
	for i in 12: await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await grab(label)


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.42
	await get_tree().create_timer(1.0).timeout
	world = scene.world
	scene.hud.visible = false
	var hole := Vector2i(9999, 9999)
	for c in world.water:
		if world.BONELANDS.has_point(c) and c.x > 80:
			hole = c
			break
	var wash := Vector2i(100, int(round(sin(100 * 0.06) * 10.0 + sin(100 * 0.021 + 1.3) * 7.0)))
	await visit("edge", Vector2i(57, -2))
	await visit("wash", wash + Vector2i(0, 3))
	if hole != Vector2i(9999, 9999): await visit("waterhole", hole + Vector2i(0, 4))
	await visit("deep", Vector2i(140, 20))
	scene.hud.visible = true
	scene._show_map()
	await get_tree().create_timer(0.4).timeout
	await grab("map")
	scene._close_overlay()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
