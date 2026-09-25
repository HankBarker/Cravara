extends Node2D
## Rendered look at the Blender-made dinosaur (pass 12, tools/blender): the
## Scarhorn in the world beside a PixelLab allosaur, walking and running with
## the keeper in each facing, biting, roaring, and slumping dead.
## Writes C:/Cravera/art/blender/carno/look-*.png (960x540).
##   godot --rendering-method gl_compatibility --resolution 960x540 --path game
##         res://Tests/BlenderCapture.tscn -- --no-save-playtest --blender-playtest
const OUT := "C:/Cravera/art/blender/carno/"
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
	img.save_png(OUT + "look-" + label + ".png")
	print("CAPTURED ", label)


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		scene.player.current_health = scene.player.max_health


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
	await get_tree().create_timer(1.5).timeout
	world = scene.world
	scene.hud.visible = false
	var keeper = scene.player
	var home: Vector2 = keeper.global_position
	var carnos: Array = get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.species == "carno")
	var follower = carnos.filter(func(c): return c.tamed and c.order == "follow").front()
	var stayer = carnos.filter(func(c): return c.tamed and c.order == "stay").front()
	var wild = carnos.filter(func(c): return not c.tamed).front()
	# 1. Beside the PixelLab allosaur.
	keeper.global_position = stayer.global_position + Vector2(20, 60)
	await wait(0.8)
	await grab("compare")
	# 2. Walking with the keeper: side, down, up.
	for leg in [["east", Vector2(1, 0)], ["south", Vector2(0, 1)], ["north", Vector2(0, -1)]]:
		keeper.global_position = home
		follower.global_position = home + Vector2(-50, 0) * leg[1].x + Vector2(0, -50) * leg[1].y
		await wait(0.3)
		var t := 0.0
		while t < 1.6:
			keeper.global_position += leg[1] * 60.0 * get_process_delta_time()
			await get_tree().process_frame
			t += get_process_delta_time()
		await grab("follow-" + leg[0])
	# 3. The wild one: it runs the keeper down, bites, roars; then falls.
	keeper.global_position = wild.global_position + Vector2(-150, 10)
	keeper.is_invulnerable = true
	await wait(1.4)
	await grab("hunt")
	await wait(1.0)
	await grab("hunt2")
	wild.take_damage(99999, keeper)
	await wait(1.4)
	await grab("dead")
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
