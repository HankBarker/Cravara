extends Node2D
## Rendered look at pass 10 (not --headless): the talk panel while the keeper
## walks on, Skarn's den asleep and then awake (roar, boss bar), and the new
## beasts (allosaurus, lystrosaurus) in the Bonelands. Writes
## C:/Cravera/art/pass10/look-*.png (960x540).
const OUT := "C:/Cravera/art/pass10/"
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


func settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func put_keeper(at: Vector2) -> void:
	scene.player.global_position = world.get_spawnable_position(at)
	scene.player.velocity = Vector2.ZERO
	await settle(0.6)


func clear_beasts_near(at: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species != "alpha" and c.global_position.distance_to(at) < radius: c.queue_free()
	await get_tree().process_frame


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
	TimeCycle.time_of_day = 0.4
	await settle(1.2)
	world = scene.world
	# Talking to Orrin, then walking on with the panel still open.
	var orrin = scene.folk.actors.get("guide")
	if is_instance_valid(orrin):
		await put_keeper(orrin.global_position + Vector2(-26, 10))
		scene._talk_to(orrin)
		await settle(0.5)
		await grab("talk")
		scene.player.walk_to(scene.player.global_position + Vector2(-22, 14))
		await settle(0.8)
		await grab("talk-walking")
		scene.talk.close()
	# Skarn's den: asleep among the bones, then awake.
	var boss = scene.boss
	if is_instance_valid(boss) and boss.den != Vector2i(9999, 9999):
		var centre: Vector2 = boss.centre()
		await clear_beasts_near(centre, 400.0)
		# Beside the den, just outside waking distance, with Skarn asleep in view.
		await put_keeper(centre + Vector2(7.5 * 16.0, 2.5 * 16.0))
		await grab("den")
		scene.player.global_position = world.get_spawnable_position(centre + Vector2(0, 5.0 * 16.0))
		await settle(0.5)
		await grab("den-roar")
		await settle(1.4)
		await grab("den-fight")
		boss._rest()
		await settle(0.3)
	# The Bonelands' beasts, close up.
	var plain := Vector2(118 * 16, 6 * 16)
	await put_keeper(plain)
	await clear_beasts_near(scene.player.global_position, 500.0)
	var here: Vector2 = scene.player.global_position
	var still: Array = []
	var allo = scene._spawn_creature("allo", world.get_spawnable_position(here + Vector2(80, -16)))
	still.append(allo)
	for i in 3:
		still.append(scene._spawn_creature("lystro", world.get_spawnable_position(here + Vector2(-86 + i * 20, 26 + (i % 2) * 12))))
	await settle(0.4)
	# Held still, side-on, for the picture.
	for c in still:
		if not is_instance_valid(c): continue
		c._face(Vector2.LEFT if c == allo else Vector2.RIGHT, true)
		c._play_clip("idle", true)
		c.process_mode = Node.PROCESS_MODE_DISABLED
	await settle(0.3)
	await grab("bonelands-beasts")
	for c in still:
		if is_instance_valid(c): c.queue_free()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
