extends Node2D
## Rendered look-book of pass 12 (not --headless). Writes
## C:/Cravera/art/pass12/look-*.png (960x540). Shots are added as the pass
## goes; run it after each piece to check it in the game itself.
const OUT := "C:/Cravera/art/pass12/"
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


func put(at: Vector2) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector2.ZERO


func cell_at(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


func clear_near(at: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < radius: c.queue_free()


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
	if "--only-ground" in OS.get_cmdline_user_args():
		await _grounding()
	else:
		await _boat()
		await _parasaur()
		await _grounding()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)


## The rowboat: paddling four ways (driven, as the keeper's own input would),
## moored as it was left, and Old Maw's shadow turning round it.
func _boat() -> void:
	var open := Vector2i(9999, 9999)
	for c in world.deep:
		var ring := true
		for y in range(-5, 6):
			for x in range(-7, 8):
				ring = ring and world.deep.has(c + Vector2i(x, y))
		if ring:
			open = c
			break
	if open == Vector2i(9999, 9999): return
	var keeper = scene.player
	# Straight onto the deep: a boat laid there and boarded.
	world._spawn_prop(open, "boat")
	world.props[open].is_placed = true
	world.placed[open] = "boat"
	put(cell_at(open) + Vector2(8, 0))
	scene.boating.board(open)
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1).normalized()]:
		for i in 30:
			keeper.velocity = dir * 70.0
			keeper.last_facing = ("right" if dir.x > 0 else "left") if absf(dir.x) > absf(dir.y) else ("down" if dir.y > 0 else "up")
			keeper.move_and_slide()
			await get_tree().physics_frame
		await grab("boat-%s" % ("e" if dir == Vector2.RIGHT else ("s" if dir == Vector2.DOWN else ("w" if dir == Vector2.LEFT else ("n" if dir == Vector2.UP else "se")))))
	keeper.velocity = Vector2.ZERO
	await wait(0.4)
	await grab("boat-rest")
	var maw = scene.maw
	if is_instance_valid(maw):
		for turn in [Vector2(1, 0.4), Vector2(-0.3, 1), Vector2(-1, -0.6)]:
			maw.global_position = keeper.global_position + Vector2(90, 40)
			maw._heading = turn.normalized()
			maw.state = "roam"
			maw.set_process(false)
			maw.queue_redraw()
			await wait(0.2)
			await grab("maw-%d" % int(round(rad_to_deg(turn.angle()))))
		maw.set_process(true)
	scene.boating.leave()
	await wait(0.3)
	await grab("boat-moored")


## A parasaur walking toward the camera, and grazing from the front.
func _parasaur() -> void:
	var at: Vector2 = world.get_spawnable_position(Vector2(-230, 170))
	clear_near(at, 300.0)
	put(at + Vector2(0, 60))
	scene.player.visible = false
	var p = scene._spawn_creature("parasaur", at + Vector2(-40, -30))
	var q = scene._spawn_creature("parasaur", at + Vector2(40, -30))
	await wait(0.3)
	p.dormant = true
	q.dormant = true
	p.process_mode = Node.PROCESS_MODE_DISABLED
	q.process_mode = Node.PROCESS_MODE_DISABLED
	p._face(Vector2.DOWN, true)
	p._play_clip("walk", true)
	q._face(Vector2.DOWN, true)
	q._play_clip("eat", true)
	p._sprite.play()
	q._sprite.play()
	await wait(0.5)
	await grab("parasaur-front")
	scene.player.visible = true


## Everything should sit in the ground (pass 12): close looks at the wild
## props by day, with the sun's shadows as the game draws them.
func _grounding() -> void:
	var kinds := ["mesa", "palm", "pine", "birch", "dead_tree", "cactus", "tree", "rock", "chalk_rock", "bone_pile"]
	for kind in kinds:
		var found := Vector2i(9999, 9999)
		for c in world.props:
			var p = world.props[c]
			if is_instance_valid(p) and p.kind == kind and not p.is_placed:
				found = c
				break
		if found == Vector2i(9999, 9999): continue
		put(cell_at(found) + Vector2(40, 30))
		scene.player.visible = false
		await wait(0.6)
		await grab("ground-" + kind)
	scene.player.visible = true
