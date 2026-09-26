extends Node2D
## Rendered look at the opening (not --headless): three of the story's
## paintings with their lines, then the keeper walking out of the first
## camp's tent and Orrin's first words. Writes C:/Cravera/art/intro/look-*.png
## (960x540).
const OUT := "C:/Cravera/art/intro/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
var stage


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


func seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	get_tree().set_meta("forest_intro", true)
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	var intro = stage._intro
	for wanted in [0, 1, 4, 7]:
		while intro._index < wanted:
			intro._begin_fade_out()
			await seconds(1.2)
		await seconds(3.4)
		await grab("plate-%d" % (wanted + 1))
	intro._finish()
	await seconds(1.5)
	await grab("waking")
	var waited := 0.0
	while not stage.talk.is_open() and waited < 8.0:
		await seconds(0.2)
		waited += 0.2
	await seconds(3.0)
	await grab("orrin")
	stage.talk._advance_script()
	stage.talk._advance_script()
	await seconds(4.0)
	await grab("orrin-2")
	stage.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
