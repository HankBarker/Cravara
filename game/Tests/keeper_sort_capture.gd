extends Node2D
## Rendered Y-sort regression for the Keeper (needs a window, not --headless):
##   godot --rendering-method gl_compatibility --resolution 960x540 --path game res://Tests/KeeperSortCapture.tscn -- --no-save-playtest
## The Keeper used to sort by the origin at the body centre, 11 px above the
## soles, so beside a tree the body was drawn behind it while the feet stood
## in front of its base. The Keeper now sorts by the feet (ForestPlayer.SORT_Y),
## like creatures and props by their bases. Each case renders the same frame
## with and without the tree and compares the Keeper's torso pixels: identical
## means the Keeper is drawn in front of the tree. Writes C:/Cravera/art/keeper-v2/sort/.

const OUT := "C:/Cravera/art/keeper-v2/sort/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
var scene
var player
var checks := 0
var failures: Array[String] = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	# Captures pause the tree so nothing (breath, camera, particles) moves
	# between the with/without renders; this driver keeps running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("SORT PASS " if ok else "SORT FAIL ") + message)
	if not ok:
		failures.append(message)


func frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func capture() -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	return img


## Torso pixels (5 x 7 around the body centre) that differ between two renders.
func torso_diff(a: Image, b: Image) -> int:
	var at := Vector2i((get_viewport().get_canvas_transform() * player.global_position).round())
	var n := 0
	for dy in range(-5, 2):
		for dx in range(-2, 3):
			var q := at + Vector2i(dx, dy)
			if a.get_pixelv(q) != b.get_pixelv(q):
				n += 1
	return n


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

	# Structure: the sprite node carries the sort line; the drawing never moved.
	var sprite: AnimatedSprite2D = player.animated_sprite
	check(player.y_sort_enabled, "the player sorts its children with the world")
	check(sprite.position == Vector2(0, player.SORT_Y), "the sprite node sits on the sort line (+%d)" % int(player.SORT_Y))
	check(sprite.position + sprite.offset == Vector2.ZERO, "the body is drawn exactly where it was (cel centre on the origin)")
	check(player.feel.ground.position == sprite.position and player.feel.front.position == sprite.position, "shadow and water arc share the body's sort line")
	check(player.feel.ground.get_index() < sprite.get_index() and sprite.get_index() < player.feel.front.get_index(), "tree order breaks the tie: shadow, body, water")

	var tree = null
	for prop in scene.world.props.values():
		if prop.kind == "tree" and prop.global_position.distance_to(player.global_position) < 400.0:
			tree = prop
			break
	if tree == null:
		for prop in scene.world.props.values():
			if prop.kind == "tree":
				tree = prop
				break
	check(tree != null, "the forest has a tree to stand beside")
	if tree == null:
		await finish()
		return
	# Nothing else near the trunk: only the tree and the Keeper can overlap.
	for prop in scene.world.props.values():
		if prop != tree and prop.global_position.distance_to(tree.global_position) < 96.0:
			prop.visible = false
	sprite.play("idle_down")
	sprite.pause()
	sprite.frame = 0
	var base_line: float = tree.global_position.y
	# [feet sort line relative to the tree's base line, expected in front].
	# The +3 and +1 cases are the old bug: sorted by the body centre 8 px
	# higher, the Keeper was drawn behind a trunk the feet stood in front of.
	var cases := [
		[3.0, true],
		[1.0, true],
		[-3.0, false],
		[-8.0, false],
	]
	for c in cases:
		var feet: float = c[0]
		var in_front: bool = c[1]
		player.global_position = Vector2(tree.global_position.x, base_line + feet - player.SORT_Y)
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		await frames(8)
		get_tree().paused = true
		tree.visible = true
		await frames(2)
		var with_tree := await capture()
		tree.visible = false
		await frames(2)
		var without_tree := await capture()
		tree.visible = true
		get_tree().paused = false
		var diff := torso_diff(with_tree, without_tree)
		var label := "feet %+d px %s the trunk base" % [int(feet), "below" if feet > 0 else "above"]
		with_tree.save_png(OUT + "sort-%+d.png" % int(feet))
		if in_front:
			check(diff == 0, label + ": the Keeper is drawn over the tree (%d torso px changed)" % diff)
		else:
			check(diff >= 3, label + ": the trunk covers the Keeper (%d torso px changed)" % diff)
	await finish()


func finish() -> void:
	print("KEEPER_SORT checks=%d failures=%d" % [checks, failures.size()])
	await QuietExit.settle(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)
